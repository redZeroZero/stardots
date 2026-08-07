extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var battle = BATTLE_SCENE.instantiate()
	battle.task_force_demo = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	for unit: TacticalUnit in battle.friendly_units:
		unit.set_physics_process(false)

	if battle.friendly_units.size() != 20 or not battle.enemy_units.is_empty():
		failures.append("la démo ne contient pas exactement ses vingt bâtiments")
	if battle.task_force_demo_forces.size() != 3 or battle.task_force_demo_motions.size() != 3:
		failures.append("la démo ne construit pas ses trois Task Forces")
	else:
		var expected_sizes: Array[int] = [4, 6, 10]
		for force_index: int in expected_sizes.size():
			if battle.task_force_demo_forces[force_index].members.size() != expected_sizes[force_index]:
				failures.append("la démo ne respecte pas les tailles 4, 6 et 10")
				break
	if not battle.objective_label.text.contains("G MOUVEMENT PARALLÈLE"):
		failures.append("le bandeau n'explique pas comment lancer les trois TF")
	var swarm_event := InputEventKey.new()
	swarm_event.pressed = true
	# La position physique de 3 doit fonctionner également sur AZERTY.
	swarm_event.keycode = KEY_QUOTEDBL
	swarm_event.physical_keycode = KEY_3
	battle._unhandled_input(swarm_event)
	for force: TaskForce in battle.task_force_demo_forces:
		if (
			force.formation_shape != TaskForce.FormationShape.SWARM
			or force.formation_spacing != TaskForce.FormationSpacing.TIGHT
		):
			failures.append("la touche 3 ne change pas les deux TF sélectionnées")
			break
	for motion: TaskForceMotion in battle.task_force_demo_motions:
		motion.set_formation(TaskForce.FormationShape.LINE, TaskForce.FormationSpacing.TIGHT)
	battle.tactical_overlay._rebuild_engagement_groups()
	if battle.tactical_overlay.engagement_groups.size() != 3:
		failures.append("les enveloppes ne sont pas regroupées en exactement trois TF")
	else:
		for group: Dictionary in battle.tactical_overlay.engagement_groups:
			if group.weapon.contours.size() != 1:
				failures.append("l'enveloppe orange d'une TF reste découpée")
			if group.passive_sensor.contours.size() != 1:
				failures.append("l'enveloppe bleue d'une TF reste découpée")

	var first_force: TaskForce = battle.task_force_demo_forces[0]
	var first_motion: TaskForceMotion = battle.task_force_demo_motions[0]
	var first_unit: TacticalUnit = first_force.members[0]
	battle.selection_start = first_unit.global_position
	battle.selection_end = battle.selection_start
	battle._finish_selection(false)
	if battle.selected_units.size() != first_force.members.size():
		failures.append("un clic sur un membre ne sélectionne pas sa propre TF")
	if not battle._handle_task_force_demo_key(KEY_KP_4):
		failures.append("la touche 4 du pavé numérique n'est pas consommée")
	elif (
		first_force.formation_shape != TaskForce.FormationShape.SWARM
		or first_force.formation_spacing != TaskForce.FormationSpacing.LOOSE
		or battle.task_force_demo_forces[1].formation_shape != TaskForce.FormationShape.LINE
	):
		failures.append("un changement de formation ne cible pas uniquement la TF sélectionnée")
	first_motion.set_formation(TaskForce.FormationShape.LINE, TaskForce.FormationSpacing.TIGHT)

	battle.selection_start = first_unit.global_position
	battle.selection_end = battle.selection_start
	battle._finish_selection(false, true)
	if battle.selected_units != [first_unit]:
		failures.append("Ctrl+clic ne permet pas de sélectionner un membre seul")
	if first_unit.show_support_ranges or first_unit.show_individual_weapon_ranges:
		failures.append("une micro de TF réaffiche les secteurs techniques séparés")
	var slots_before_micro: Dictionary = first_motion.calculate_current_slots()
	battle._issue_move_order(first_unit.global_position + Vector2(300.0, -120.0))
	if first_force.get_member_status(first_unit) != TaskForce.PhysicalStatus.DETACHED:
		failures.append("un ordre individuel ne détache pas son destinataire")
	var slots_after_micro: Dictionary = first_motion.calculate_current_slots()
	for unit: TacticalUnit in first_force.members:
		if unit == first_unit:
			continue
		if not Vector2(slots_after_micro[unit]).is_equal_approx(slots_before_micro[unit]):
			failures.append("un ordre individuel redistribue le reste de la formation")
			break
	first_motion.rejoin_member(first_unit)

	var start_positions: Array[Vector2] = []
	for motion: TaskForceMotion in battle.task_force_demo_motions:
		start_positions.append(motion.anchor_position)
	if not battle._handle_task_force_demo_key(KEY_G):
		failures.append("la commande G ne lance pas les trois mouvements")
	for _tick: int in 100:
		for motion: TaskForceMotion in battle.task_force_demo_motions:
			motion.update(0.05)
		for unit: TacticalUnit in battle.friendly_units:
			unit._physics_process(0.05)
	var reference_distance: float = (
		battle.task_force_demo_motions[0].anchor_position.x - start_positions[0].x
	)
	for motion_index: int in range(1, battle.task_force_demo_motions.size()):
		var travelled_distance: float = (
			battle.task_force_demo_motions[motion_index].anchor_position.x
			- start_positions[motion_index].x
		)
		if not is_equal_approx(travelled_distance, reference_distance):
			failures.append("les TF homogènes ne suivent pas le même mouvement d'ancre")
			break

	battle.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Démo Task Force validée : formations de quatre, six et dix bâtiments.")
	quit(0)
