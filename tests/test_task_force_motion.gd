extends SceneTree

const FORMATION_PROFILE: TaskForceFormationProfile = preload(
	"res://data/balance/default_task_force_formation.tres"
)
const MAIN_DRIVE_PROFILE: PropulsionProfile = preload("res://data/propulsion/main_drive.tres")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var unit_profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	unit_profile.weapon_system_profiles = []
	unit_profile.missile_capacity = 0
	unit_profile.missile_launcher_count = 0
	var task_force := TaskForce.new(0, 0)
	var units: Array[TacticalUnit] = []
	for index: int in 5:
		var member_profile: UnitProfile = unit_profile.duplicate(true)
		if index < 2:
			member_profile.propulsion_profile = MAIN_DRIVE_PROFILE
		var unit := TacticalUnit.new()
		root.add_child(unit)
		unit.configure("MOBILE-%02d" % (index + 1), 0, Vector2.ZERO, member_profile)
		unit.set_physics_process(false)
		units.append(unit)
		task_force.add_member(
			unit,
			TaskForce.PhysicalStatus.SUPPORT
			if index == 4
			else TaskForce.PhysicalStatus.INTEGRATED
		)

	var initial_anchor := Vector2(-900.0, 200.0)
	task_force.set_formation(TaskForce.FormationShape.SWARM, TaskForce.FormationSpacing.TIGHT)
	var controller := TaskForceMotion.new()
	controller.configure(task_force, FORMATION_PROFILE, initial_anchor, PI * 0.5)
	_place_units_at_slots(controller.calculate_current_slots())
	controller.request_formation_refresh()
	var detached: TacticalUnit = units[3]
	var start_position: Vector2 = units[0].global_position
	var destination := Vector2(900.0, -300.0)
	controller.issue_move_order(destination, PI * 0.5, true)
	var used_moving_slot_guidance: bool = false
	var flipped_to_brake_in_formation: bool = false
	for _tick: int in 900:
		controller.update(0.05)
		for unit: TacticalUnit in units:
			unit._physics_process(0.05)
		used_moving_slot_guidance = used_moving_slot_guidance or units[0].formation_guidance_active
		if units[0].velocity.length() > 10.0:
			var forward: Vector2 = Vector2.UP.rotated(units[0].rotation)
			flipped_to_brake_in_formation = (
				flipped_to_brake_in_formation
				or forward.dot(units[0].velocity.normalized()) < -0.75
			)
	if not used_moving_slot_guidance:
		failures.append("la TF n'utilise pas le guidage d'emplacement mobile")
	if not flipped_to_brake_in_formation:
		failures.append("un membre flip-and-burn ne se retourne pas pour freiner dans la TF")
	if units[0].global_position.distance_to(start_position) < 1200.0:
		failures.append("la TF ne parcourt pas réellement sa route")
	if controller.anchor_position.distance_to(destination) > 1.0 or controller.has_move_order:
		failures.append("l'ancre de TF n'achève pas son ordre")
	_validate_slot_errors(controller, 18.0, failures)
	if units[4].global_position.x >= controller.anchor_position.x:
		failures.append("l'unité en appui ne termine pas derrière la TF orientée à droite")
	for unit: TacticalUnit in units:
		if unit.show_navigation_route:
			failures.append("une unité intégrée affiche encore ses micro-corrections de route")

	var first_waypoint := Vector2(900.0, 300.0)
	var final_waypoint := Vector2(300.0, 600.0)
	var stable_final_heading: float = PI
	controller.issue_navigation_order(first_waypoint)
	controller.issue_navigation_order(
		final_waypoint,
		false,
		true,
		stable_final_heading,
		true
	)
	if controller.navigation_route.size() != 2:
		failures.append("un waypoint ajouté ne reste pas dans la route collective")
	elif (
		controller.navigation_route[0].passage_mode
		!= NavigationWaypoint.PassageMode.FLY_THROUGH
	):
		failures.append("un waypoint intermédiaire n'est pas traversé")
	elif not is_equal_approx(controller.navigation_route[-1].final_heading, stable_final_heading):
		failures.append("le cap final collectif n'est pas stable dans la route")
	# Force un retardataire afin de vérifier que les membres déjà arrivés ne
	# l'attendent pas avant de prendre leur cap final.
	units[1].global_position += Vector2(-240.0, 100.0)
	var oriented_while_another_rejoined: bool = false
	for _tick: int in 900:
		controller.update(0.05)
		for unit: TacticalUnit in units:
			unit._physics_process(0.05)
		if (
			not controller.has_move_order
			and not controller.is_orienting_to_final_heading
			and controller.anchor_velocity == Vector2.ZERO
		):
			var has_guided_member: bool = false
			var has_oriented_member: bool = false
			for unit: TacticalUnit in units:
				has_guided_member = has_guided_member or unit.formation_guidance_active
				has_oriented_member = (
					has_oriented_member
					or (
						not unit.formation_guidance_active
						and (
							unit.is_orienting_to_final_heading
							or absf(angle_difference(unit.rotation, stable_final_heading)) <= 0.03
						)
					)
				)
			oriented_while_another_rejoined = (
				oriented_while_another_rejoined
				or (has_guided_member and has_oriented_member)
			)
	if not oriented_while_another_rejoined:
		failures.append("les membres arrivés attendent encore le dernier retardataire pour s'orienter")
	if controller.anchor_position.distance_to(final_waypoint) > 1.0:
		failures.append("la TF n'achève pas sa route à plusieurs waypoints")
	if controller.is_orienting_to_final_heading:
		failures.append("la TF ne termine pas sa rotation vers le cap final collectif")
	for unit: TacticalUnit in units:
		if absf(angle_difference(unit.rotation, stable_final_heading)) > 0.03:
			failures.append(
				"%s ne partage pas le cap final (écart %.3f, slot %.2f, vitesse %.2f, guidage %s)"
				% [
					unit.callsign,
					absf(angle_difference(unit.rotation, stable_final_heading)),
					unit.global_position.distance_to(controller.calculate_current_slots()[unit]),
					unit.velocity.length(),
					str(unit.formation_guidance_active),
				]
			)
			break

	detached.velocity = Vector2.ZERO
	if not controller.set_member_status(detached, TaskForce.PhysicalStatus.DETACHED):
		failures.append("le contrôleur ne détache pas une unité")
	elif not detached.show_navigation_route:
		failures.append("une unité détachée ne retrouve pas son propre vecteur de navigation")
	var detached_position: Vector2 = detached.global_position
	var second_destination := Vector2(900.0, 900.0)
	controller.issue_move_order(second_destination)
	_simulate(controller, units, 500)
	if detached.global_position.distance_to(detached_position) > 0.1:
		failures.append("une unité détachée continue de poursuivre un emplacement collectif")
	if controller.calculate_current_slots().has(detached):
		failures.append("une unité détachée reste dans la géométrie mobile")

	if not controller.set_member_status(detached, TaskForce.PhysicalStatus.INTEGRATED):
		failures.append("le contrôleur ne rattache pas une unité")
	elif detached.show_navigation_route:
		failures.append("une unité rattachée réaffiche les micro-corrections de formation")
	_simulate(controller, units, 300)
	if not controller.calculate_current_slots().has(detached):
		failures.append("une unité rattachée ne retrouve pas d'emplacement")
	elif detached.global_position.distance_to(controller.calculate_current_slots()[detached]) > 18.0:
		failures.append("une unité rattachée ne rejoint pas la formation")

	for unit: TacticalUnit in units:
		unit.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Mouvement de TF validé : inertie, cohésion, appui, détachement et retour.")
	quit(0)


func _place_units_at_slots(slots: Dictionary) -> void:
	for unit: TacticalUnit in slots:
		unit.global_position = slots[unit]
		unit.velocity = Vector2.ZERO
		unit.cut_engines()


func _simulate(controller: TaskForceMotion, units: Array[TacticalUnit], ticks: int) -> void:
	for _tick: int in ticks:
		controller.update(0.05)
		for unit: TacticalUnit in units:
			unit._physics_process(0.05)


func _validate_slot_errors(
	controller: TaskForceMotion,
	maximum_error: float,
	failures: Array[String]
) -> void:
	var slots: Dictionary = controller.calculate_current_slots()
	for unit: TacticalUnit in slots:
		if unit.global_position.distance_to(slots[unit]) > maximum_error:
			failures.append("une unité ne reforme pas la TF à destination")
