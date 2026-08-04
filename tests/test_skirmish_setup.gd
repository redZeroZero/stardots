extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	SkirmishCatalog.consume_pending_deployment()
	var battle = BATTLE_SCENE.instantiate()
	battle.skirmish_setup_enabled = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)

	if not battle.deployment_mode or not battle.skirmish_setup_panel.visible:
		failures.append("le lancement libre n'ouvre pas l'interface de déploiement")
	elif not battle.get_viewport_rect().encloses(battle.skirmish_setup_panel.get_global_rect()):
		failures.append("le panneau de déploiement déborde de la fenêtre")
	if not battle.friendly_units.is_empty() or not battle.enemy_units.is_empty():
		failures.append("la carte d'escarmouche ne commence pas vide")
	if battle.skirmish_catalog_entries.size() != 7:
		failures.append("le catalogue n'expose pas les sept bâtiments disponibles")
	var frigate_entry: Dictionary = SkirmishCatalog.find_entry(battle.skirmish_catalog_entries, "frigate")
	var arsenal_entry: Dictionary = SkirmishCatalog.find_entry(battle.skirmish_catalog_entries, "arsenal")
	if frigate_entry.is_empty() or arsenal_entry.is_empty():
		failures.append("le catalogue ne distingue pas la frégate et l'arsenal")
	else:
		var frigate_profile: UnitProfile = frigate_entry["profile"]
		var arsenal_profile: UnitProfile = arsenal_entry["profile"]
		if frigate_profile.active_sensor_range != 1800.0 or not frigate_profile.data_link_profile.can_transmit:
			failures.append("la frégate n'a pas son capteur généraliste et son partage de pistes")
		if arsenal_profile.active_sensor_range != 1008.0 or arsenal_profile.data_link_profile.can_transmit:
			failures.append("l'arsenal ne conserve pas son capteur court et sa réception seule")
	if battle.units_layer.process_mode != Node.PROCESS_MODE_DISABLED:
		failures.append("les unités peuvent simuler pendant le déploiement")

	var blue: TacticalUnit = battle._spawn_skirmish_unit(
		"awacs", 0, Vector2(-3000.0, 0.0), INF, 2
	)
	var red: TacticalUnit = battle._spawn_skirmish_unit(
		"railgun", 1, Vector2(3000.0, 0.0)
	)
	if blue == null or red == null:
		failures.append("le catalogue ne permet pas de poser les bâtiments choisis")
	else:
		if blue.callsign != "B-EYE-01" or red.callsign != "R-RAIL-01":
			failures.append("les indicatifs de déploiement ne sont pas stables et lisibles")
		if blue.tactical_group_id != 2:
			failures.append("le groupe tactique choisi n'est pas appliqué au bâtiment")
		if not is_equal_approx(blue.rotation, PI * 0.5) or not is_equal_approx(red.rotation, -PI * 0.5):
			failures.append("les bâtiments ne font pas face au camp opposé par défaut")
		battle._rotate_deployment_selection(1)
		if not is_equal_approx(red.rotation, -PI * 0.5 + deg_to_rad(15.0)):
			failures.append("la rotation de la sélection ne change pas le cap de 15 degrés")
		battle._spawn_skirmish_unit("frigate", 0, Vector2(-2800.0, 180.0))
		battle._delete_deployment_selection()
		if battle.friendly_units.size() != 1:
			failures.append("la suppression conserve une unité retirée dans la flotte")

	if battle.skirmish_setup_panel.launch_button.disabled:
		failures.append("le lancement reste bloqué avec un bâtiment dans chaque camp")
	if not battle._launch_skirmish():
		failures.append("une composition valide ne lance pas l'escarmouche")
	else:
		if battle.deployment_mode or not battle.skirmish_battle_active:
			failures.append("la transition ne quitte pas correctement le déploiement")
		if battle.units_layer.process_mode != Node.PROCESS_MODE_INHERIT:
			failures.append("la simulation des unités ne reprend pas au lancement")
		if battle.skirmish_setup_panel.visible or not battle.edit_setup_margin.visible:
			failures.append("les interfaces de préparation et de bataille ne basculent pas")
		if battle.skirmish_deployment_snapshot.size() != 2:
			failures.append("la composition n'est pas mémorisée pour rejouer")
		elif int(battle.skirmish_deployment_snapshot[0].get("group_id", -1)) != 2:
			failures.append("le groupe tactique n'est pas mémorisé avec le déploiement")
		if red.intel_state != TacticalUnit.IntelState.HIDDEN:
			failures.append("le camp rouge reste révélé après le lancement")
		battle.ai_decision_remaining = 0.0
		battle._update_ai(0.1)
		if not red.has_move_target:
			failures.append("l'IA rouge n'entame pas sa recherche sans contact initial")
		red.destroyed = true
		battle._update_fleet_battle_victory()
		if not battle.match_over or battle.victory_label.text != "VICTOIRE BLEUE":
			failures.append("l'annihilation ne termine pas l'escarmouche libre")

	var saved_deployment: Array[Dictionary] = battle.skirmish_deployment_snapshot.duplicate(true)
	battle.free()

	SkirmishCatalog.stage_reload(saved_deployment, false)
	var edited = BATTLE_SCENE.instantiate()
	edited.skirmish_setup_enabled = true
	root.add_child(edited)
	edited.set_process(false)
	edited.set_physics_process(false)
	if not edited.deployment_mode or edited.friendly_units.size() != 1 or edited.enemy_units.size() != 1:
		failures.append("le retour au déploiement ne restaure pas la composition")
	elif edited.friendly_units[0].tactical_group_id != 2:
		failures.append("le retour au déploiement perd l'affectation au groupe tactique")
	edited.free()

	SkirmishCatalog.stage_reload(saved_deployment, true)
	var replay = BATTLE_SCENE.instantiate()
	replay.skirmish_setup_enabled = true
	root.add_child(replay)
	replay.set_process(false)
	replay.set_physics_process(false)
	if not replay.skirmish_battle_active or replay.skirmish_deployment_snapshot.size() != 2:
		failures.append("REJOUER ne relance pas automatiquement la même composition")
	replay.free()
	SkirmishCatalog.consume_pending_deployment()

	var free_test = BATTLE_SCENE.instantiate()
	free_test.skirmish_setup_enabled = true
	root.add_child(free_test)
	free_test.set_process(false)
	free_test.set_physics_process(false)
	free_test._spawn_skirmish_unit("frigate", 0, Vector2.ZERO)
	if free_test.skirmish_setup_panel.launch_button.disabled or not free_test._launch_skirmish():
		failures.append("un groupe bleu seul ne peut pas lancer le test libre")
	else:
		free_test._update_fleet_battle_victory()
		if not free_test.skirmish_free_test_active or free_test.match_over:
			failures.append("le test libre se termine immédiatement faute d'adversaire")
		if free_test.objective_label.text != "TEST LIBRE — SIMULATION SANS ADVERSAIRE":
			failures.append("l'interface n'identifie pas le mode de test libre")
	free_test.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Escarmouche libre validée : catalogue, placement, cap, lancement, IA et victoire.")
	quit(0)
