extends SceneTree

const FORMATION_PROFILE: TaskForceFormationProfile = preload(
	"res://data/balance/default_task_force_formation.tres"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var task_force := TaskForce.new(0, 0)
	var units: Array[TacticalUnit] = []
	for index: int in 10:
		var unit := TacticalUnit.new()
		unit.callsign = "GÉOMÉTRIE-%02d" % (index + 1)
		unit.team_id = 0
		root.add_child(unit)
		units.append(unit)
		var status: TaskForce.PhysicalStatus = TaskForce.PhysicalStatus.INTEGRATED
		if index >= 6 and index < 8:
			status = TaskForce.PhysicalStatus.SUPPORT
		elif index >= 8:
			status = TaskForce.PhysicalStatus.DETACHED
		task_force.add_member(unit, status)

	var anchor := Vector2(1000.0, 800.0)
	task_force.set_formation(TaskForce.FormationShape.LINE, TaskForce.FormationSpacing.TIGHT)
	var tight_line: Dictionary = TaskForceFormation.calculate_slots(
		task_force, anchor, 0.0, FORMATION_PROFILE
	)
	_validate_membership(tight_line, units, failures)
	_validate_line(tight_line, units, anchor, FORMATION_PROFILE.tight_unit_spacing, failures)
	_validate_support(
		tight_line,
		units,
		anchor,
		FORMATION_PROFILE.tight_support_distance,
		FORMATION_PROFILE.tight_unit_spacing,
		failures
	)

	task_force.set_formation(TaskForce.FormationShape.LINE, TaskForce.FormationSpacing.LOOSE)
	var loose_line: Dictionary = TaskForceFormation.calculate_slots(
		task_force, anchor, 0.0, FORMATION_PROFILE
	)
	if (
		Vector2(loose_line[units[0]]).distance_to(Vector2(loose_line[units[1]]))
		<= Vector2(tight_line[units[0]]).distance_to(Vector2(tight_line[units[1]]))
	):
		failures.append("la ligne lâche n'augmente pas l'espacement physique")

	var rotated_line: Dictionary = TaskForceFormation.calculate_slots(
		task_force, anchor, PI * 0.5, FORMATION_PROFILE
	)
	if not is_equal_approx(Vector2(rotated_line[units[0]]).x, anchor.x):
		failures.append("la ligne ne tourne pas avec le cap de la Task Force")

	task_force.set_formation(TaskForce.FormationShape.SWARM, TaskForce.FormationSpacing.TIGHT)
	var tight_swarm: Dictionary = TaskForceFormation.calculate_slots(
		task_force, anchor, 0.0, FORMATION_PROFILE
	)
	_validate_swarm(tight_swarm, units, anchor, FORMATION_PROFILE.tight_unit_spacing, failures)
	task_force.set_formation(TaskForce.FormationShape.SWARM, TaskForce.FormationSpacing.LOOSE)
	var loose_swarm: Dictionary = TaskForceFormation.calculate_slots(
		task_force, anchor, 0.0, FORMATION_PROFILE
	)
	if (
		Vector2(loose_swarm[units[0]]).distance_to(anchor)
		<= Vector2(tight_swarm[units[0]]).distance_to(anchor)
	):
		failures.append("l'essaim lâche n'occupe pas plus d'espace que l'essaim serré")

	for unit: TacticalUnit in units:
		task_force.set_member_status(unit, TaskForce.PhysicalStatus.INTEGRATED)
	task_force.set_formation(TaskForce.FormationShape.SWARM, TaskForce.FormationSpacing.TIGHT)
	var maximum_swarm: Dictionary = TaskForceFormation.calculate_slots(
		task_force, anchor, 0.0, FORMATION_PROFILE
	)
	_validate_maximum_swarm(
		maximum_swarm,
		units,
		anchor,
		FORMATION_PROFILE.tight_unit_spacing,
		failures
	)

	for unit: TacticalUnit in units:
		unit.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Géométrie de TF validée : ligne, essaim, espacement, appui et rotation.")
	quit(0)


func _validate_membership(
	slots: Dictionary,
	units: Array[TacticalUnit],
	failures: Array[String]
) -> void:
	if slots.size() != 8:
		failures.append("la géométrie ne contient pas exactement les unités intégrées et en appui")
	for index: int in 8:
		if not slots.has(units[index]):
			failures.append("une unité intégrée ou en appui ne reçoit pas d'emplacement")
	for index: int in range(8, 10):
		if slots.has(units[index]):
			failures.append("une unité détachée reçoit encore un emplacement collectif")


func _validate_line(
	slots: Dictionary,
	units: Array[TacticalUnit],
	anchor: Vector2,
	spacing: float,
	failures: Array[String]
) -> void:
	var center := Vector2.ZERO
	for index: int in 6:
		var slot: Vector2 = slots[units[index]]
		center += slot
		if not is_equal_approx(slot.y, anchor.y):
			failures.append("un emplacement intégré sort du front de ligne")
		if index > 0 and not is_equal_approx(
			slot.distance_to(Vector2(slots[units[index - 1]])), spacing
		):
			failures.append("l'espacement de ligne n'est pas constant")
	center /= 6.0
	if not center.is_equal_approx(anchor):
		failures.append("la ligne n'est pas centrée sur l'ancre")


func _validate_support(
	slots: Dictionary,
	units: Array[TacticalUnit],
	anchor: Vector2,
	support_distance: float,
	spacing: float,
	failures: Array[String]
) -> void:
	var first: Vector2 = slots[units[6]]
	var second: Vector2 = slots[units[7]]
	if not is_equal_approx(first.y, anchor.y + support_distance):
		failures.append("l'appui n'est pas placé derrière la formation")
	if not is_equal_approx(first.distance_to(second), spacing):
		failures.append("les unités en appui ne respectent pas l'espacement choisi")
	if not ((first + second) * 0.5).is_equal_approx(anchor + Vector2.DOWN * support_distance):
		failures.append("l'écran d'appui n'est pas centré derrière la formation")


func _validate_swarm(
	slots: Dictionary,
	units: Array[TacticalUnit],
	anchor: Vector2,
	spacing: float,
	failures: Array[String]
) -> void:
	var center := Vector2.ZERO
	for index: int in 6:
		var slot: Vector2 = slots[units[index]]
		center += slot
		if not is_equal_approx(slot.distance_to(anchor), spacing):
			failures.append("l'essaim de six unités ne forme pas un anneau régulier")
	center /= 6.0
	if not center.is_equal_approx(anchor):
		failures.append("l'essaim n'est pas centré sur l'ancre")


func _validate_maximum_swarm(
	slots: Dictionary,
	units: Array[TacticalUnit],
	anchor: Vector2,
	spacing: float,
	failures: Array[String]
) -> void:
	if slots.size() != TaskForce.MAXIMUM_SIZE:
		failures.append("l'essaim maximal ne reçoit pas dix emplacements")
	var centered_units: int = 0
	for first_index: int in units.size():
		var first_slot: Vector2 = slots[units[first_index]]
		if first_slot.is_equal_approx(anchor):
			centered_units += 1
		for second_index: int in range(first_index + 1, units.size()):
			var second_slot: Vector2 = slots[units[second_index]]
			if first_slot.distance_to(second_slot) < spacing - 0.01:
				failures.append("l'essaim maximal place deux unités sous l'espacement minimal")
	if centered_units != 1:
		failures.append("l'essaim maximal ne possède pas exactement un élément central")
