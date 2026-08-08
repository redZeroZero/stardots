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

	var forces: Array[TaskForce] = battle.task_force_registry.get_forces(0)
	if forces.size() != 3:
		failures.append("le registre IHM n'expose pas les trois Task Forces dans l'ordre")
	else:
		if battle.task_force_list.get_child_count() != 5:
			failures.append("la barre TF ne construit pas une tuile par formation")
		elif not battle.task_force_list.get_child(2).text.contains("[1]"):
			failures.append("la tuile TF n'affiche pas son raccourci")
		elif battle.task_force_list.get_child(2).tooltip_text.is_empty():
			failures.append("la tuile TF n'a pas de tooltip d'interaction")
		var first_force: TaskForce = forces[0]
		var first_unit: TacticalUnit = first_force.members[0]
		battle.selection_state.select_task_force(first_force)
		battle._update_status()
		if battle.selection_state.selected_task_force != first_force or battle.selected_units.size() != 4:
			failures.append("l'état partagé ne sélectionne pas une Task Force entière")
		if battle.roster_list.get_child_count() != 4:
			failures.append("le roster ne présente pas tous les membres de la TF")
		elif battle.roster_list.get_child(0).tooltip_text.is_empty():
			failures.append("la tuile roster n'a pas de tooltip d'interaction")
		battle.selection_state.select_unit(first_unit, first_force)
		battle._update_status()
		if battle.selected_units != [first_unit] or not first_unit.selected:
			failures.append("l'état partagé ne produit pas une micro-sélection cohérente")
		if battle.roster_list.get_child_count() != 4:
			failures.append("la micro-sélection masque le roster de sa Task Force")
		battle._on_roster_tile_pressed(first_force.members[1], first_force)
		if battle.selected_units != [first_force.members[1]]:
			failures.append("un clic roster ne synchronise pas la micro-sélection monde")

		var unit_snapshot := TacticalUiContract.build_unit_snapshot(
			first_unit,
			TacticalUiContract.NetworkState.ISOLATED,
			TacticalUiContract.OffensiveState.DEGRADED,
			TacticalUiContract.AlertFlag.INCOMING_MISSILE
		)
		var snapshots: Array[TacticalUiContract.UnitSnapshot] = [unit_snapshot]
		var force_snapshot := TacticalUiContract.build_task_force_snapshot(
			first_force,
			snapshots,
			first_force
		)
		if unit_snapshot.identity != first_unit.callsign or unit_snapshot.structure_ratio <= 0.0:
			failures.append("le snapshot unité ne reprend pas l'état réel du bâtiment")
		if (
			force_snapshot.network_state != TacticalUiContract.NetworkState.ISOLATED
			or force_snapshot.offensive_state != TacticalUiContract.OffensiveState.DEGRADED
			or not force_snapshot.selected
		):
			failures.append("le snapshot TF ne synthétise pas ses membres")

	var shortcut := InputEventKey.new()
	shortcut.pressed = true
	shortcut.physical_keycode = KEY_3
	if TacticalUiContract.task_force_shortcut_index(shortcut) != 2:
		failures.append("le contrat de raccourci TF ne suit pas la position physique")
	shortcut.shift_pressed = true
	if TacticalUiContract.task_force_shortcut_index(shortcut) != -1:
		failures.append("Maj+chiffre entre encore en conflit avec la sélection TF")
	if TacticalUiContract.can_present_hostile_contact(false):
		failures.append("la politique de visibilité révèle un contact inconnu")
	if TacticalUiContract.can_present_enemy_loss(false):
		failures.append("la politique de visibilité révèle une perte non confirmée")
	if TacticalUiContract.block_reason_label(FireMission.BlockReason.OVERHEATED) != "SURCHAUFFE":
		failures.append("le vocabulaire typé des blocages n'est pas stable")
	var log := TacticalEventLog.new()
	log.append_event(1, "piste acquise")
	log.append_event(1, "piste acquise")
	if log.get_lines().size() != 1:
		failures.append("le journal répète un événement identique sans changement")
	for event_index: int in 7:
		log.append_event(event_index + 2, "événement %d" % event_index)
	if log.get_lines().size() != TacticalEventLog.MAXIMUM_EVENTS or "piste acquise" in log.get_text():
		failures.append("le journal ne conserve pas une fenêtre compacte des événements")
	var invalid_registry := TaskForceRegistry.new()
	if invalid_registry.rebuild_from_tactical_groups(battle.friendly_units):
		failures.append("le registre accepte silencieusement une TF dépassant dix bâtiments")
	elif invalid_registry.validation_errors.is_empty():
		failures.append("le registre ne fournit pas le motif d'une composition invalide")

	battle.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Contrats IHM validés : TF, sélection, snapshots, visibilité, raccourcis et blocages.")
	quit(0)
