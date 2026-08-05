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

	if battle.friendly_units.size() != 8 or not battle.enemy_units.is_empty():
		failures.append("la démo ne contient pas exactement sa TF de huit bâtiments")
	if battle.task_force_demo_force == null or battle.task_force_demo_motion == null:
		failures.append("la démo ne construit pas le modèle et le contrôleur de TF")
	elif battle.task_force_demo_force.members.size() != 8:
		failures.append("la TF de démonstration ne référence pas tous ses bâtiments")
	if battle.task_force_demo_scout == null:
		failures.append("la démo ne désigne pas son éclaireur manipulable")
	var flip_members: int = 0
	for unit: TacticalUnit in battle.friendly_units:
		if unit.propulsion_doctrine == UnitProfile.PropulsionDoctrine.FLIP_AND_BURN:
			flip_members += 1
	if flip_members != 3:
		failures.append("la démo ne contient pas ses trois membres flip-and-burn")
	if not battle.objective_label.text.contains("CTRL+CLIC MICRO"):
		failures.append("le bandeau n'explique pas les commandes de formation")

	battle.selection_start = battle.friendly_units[0].global_position
	battle.selection_end = battle.selection_start
	battle._finish_selection(false)
	if battle.selected_units.size() != battle.task_force_demo_force.members.size():
		failures.append("un clic sur un membre ne sélectionne pas toute la TF")
	var boxed_unit_position: Vector2 = battle.friendly_units[0].global_position
	battle.selection_start = boxed_unit_position - Vector2(12.0, 12.0)
	battle.selection_end = boxed_unit_position + Vector2(12.0, 12.0)
	battle._finish_selection(false)
	if battle.selected_units.size() != battle.task_force_demo_force.members.size():
		failures.append("un cadre autour d'un membre ne sélectionne pas toute la TF")
	battle.selection_start = battle.friendly_units[0].global_position
	battle.selection_end = battle.selection_start
	battle._finish_selection(false, true)
	if battle.selected_units != [battle.friendly_units[0]]:
		failures.append("Ctrl+clic ne permet pas de sélectionner un membre seul")
	for unit: TacticalUnit in battle.friendly_units:
		if unit not in battle.selected_units:
			battle.selected_units.append(unit)
			unit.set_selected(true)

	var swarm_tight_event := InputEventKey.new()
	swarm_tight_event.pressed = true
	# Sur AZERTY, la touche physique 3 produit un guillemet sans Majuscule.
	swarm_tight_event.keycode = KEY_QUOTEDBL
	swarm_tight_event.physical_keycode = KEY_3
	battle._unhandled_input(swarm_tight_event)
	if (
		battle.task_force_demo_force.formation_shape != TaskForce.FormationShape.SWARM
		or battle.task_force_demo_force.formation_spacing != TaskForce.FormationSpacing.TIGHT
	):
		failures.append("la touche 3 ne bascule pas vers l'essaim serré")
	var swarm_loose_event := InputEventKey.new()
	swarm_loose_event.pressed = true
	swarm_loose_event.keycode = KEY_KP_4
	swarm_loose_event.physical_keycode = KEY_KP_4
	battle._unhandled_input(swarm_loose_event)
	battle.task_force_demo_motion.update(0.0)
	if (
		battle.task_force_demo_force.formation_shape != TaskForce.FormationShape.SWARM
		or battle.task_force_demo_force.formation_spacing != TaskForce.FormationSpacing.LOOSE
	):
		failures.append("la touche 4 du pavé numérique ne bascule pas vers l'essaim lâche")

	if not battle._handle_task_force_demo_key(KEY_T):
		failures.append("la commande de détachement n'est pas consommée")
	elif (
		battle.task_force_demo_force.get_member_status(battle.task_force_demo_scout)
		!= TaskForce.PhysicalStatus.DETACHED
	):
		failures.append("la commande T ne détache pas l'éclaireur")
	if battle.task_force_demo_motion.calculate_current_slots().has(battle.task_force_demo_scout):
		failures.append("l'éclaireur détaché conserve un emplacement visible")
	if not battle._handle_task_force_demo_key(KEY_R):
		failures.append("la commande de rattachement n'est pas consommée")
	elif (
		battle.task_force_demo_force.get_member_status(battle.task_force_demo_scout)
		!= TaskForce.PhysicalStatus.INTEGRATED
	):
		failures.append("la commande R ne rend pas son statut initial à l'éclaireur")

	var initial_anchor: Vector2 = battle.task_force_demo_motion.anchor_position
	battle._issue_move_order(Vector2(200.0, 400.0))
	battle._issue_move_order(Vector2(1200.0, 900.0), false, true, PI, true)
	if battle.task_force_demo_motion.navigation_route.size() != 2:
		failures.append("Shift ne conserve pas les waypoints dans la démo")
	elif not battle.task_force_demo_motion.navigation_route[-1].has_final_heading:
		failures.append("le vecteur final de TF n'est pas conservé")
	for _tick: int in 20:
		battle.task_force_demo_motion.update(0.05)
		for unit: TacticalUnit in battle.friendly_units:
			unit._physics_process(0.05)
	if battle.task_force_demo_motion.anchor_position.distance_to(initial_anchor) <= 1.0:
		failures.append("un clic droit collectif ne met pas l'ancre en mouvement")

	battle.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Démo Task Force validée : composition, commandes, détachement et mouvement.")
	quit(0)
