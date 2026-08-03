extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var battle = BATTLE_SCENE.instantiate()
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)

	var awacs: TacticalUnit = battle.friendly_units[0]
	var launcher: TacticalUnit = battle.friendly_units[1]
	var second_launcher: TacticalUnit = battle.friendly_units[2]
	var target: TacticalUnit = battle.enemy_units[0]
	awacs.global_position = Vector2.ZERO
	launcher.global_position = Vector2(-1500.0, 0.0)
	second_launcher.global_position = Vector2(-1450.0, 120.0)
	target.global_position = Vector2(1000.0, 0.0)
	awacs.sensor_mode = TacticalUnit.SensorMode.ACTIVE
	battle._update_sensor_picture()
	_select_only(battle, [launcher])

	battle.offensive_weapon_selection = battle.OffensiveWeaponSelection.MISSILES
	battle.fire_doctrine = battle.FireDoctrine.ECONOMY
	var shots: int = battle._issue_attack_zone(target.global_position)
	if shots != 0 or battle.active_fire_missions.size() != 1:
		failures.append("une mission hors portée ne reste pas mémorisée sans tirer")
	else:
		var waiting_mission: FireMission = battle.active_fire_missions[0]
		if waiting_mission.state != FireMission.State.BLOCKED or "PORTÉE" not in waiting_mission.status_text:
			failures.append("une mission bloquée n'explique pas son attente de portée")
	if launcher.has_move_target or not launcher.navigation_route.is_empty():
		failures.append("une mission de feu différée déclenche un mouvement automatique")

	# Modifier l'interface après l'ordre ne doit pas modifier l'arme et la doctrine capturées.
	battle.offensive_weapon_selection = battle.OffensiveWeaponSelection.RAILGUN
	battle.fire_doctrine = battle.FireDoctrine.SATURATION
	launcher.global_position = Vector2(300.0, 0.0)
	battle._update_sensor_picture()
	if battle.missiles_layer.get_child_count() != 1:
		failures.append("la mission ne tire pas son missile capturé lorsque la portée devient valide")
	elif battle.active_fire_missions[0].state != FireMission.State.FIRED:
		failures.append("la mission ne se termine pas après son premier engagement")

	# Deux groupes peuvent conserver deux zones différentes ; Échap annule seulement la sélection.
	battle.offensive_weapon_selection = battle.OffensiveWeaponSelection.MISSILES
	battle.fire_doctrine = battle.FireDoctrine.SALVO
	_select_only(battle, [launcher])
	battle._issue_attack_zone(Vector2(-3000.0, -3000.0))
	_select_only(battle, [second_launcher])
	battle._issue_attack_zone(Vector2(3000.0, 3000.0))
	if battle.active_fire_missions.size() != 2:
		failures.append("deux groupes ne peuvent pas conserver deux missions de feu distinctes")
	battle._cancel_selected_fire_missions()
	if battle.active_fire_missions.size() != 1:
		failures.append("l'annulation retire des missions qui n'appartiennent pas à la sélection")
	elif launcher not in battle.active_fire_missions[0].assigned_units:
		failures.append("l'annulation conserve la mauvaise mission de feu")

	battle.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Missions de feu validées : mémoire, attente, capture W/D, exécution et annulation sélective.")
	quit(0)


func _select_only(battle, units: Array) -> void:
	battle._clear_selection()
	for unit: TacticalUnit in units:
		battle.selected_units.append(unit)
		unit.set_selected(true)
	battle._refresh_range_visualization()
