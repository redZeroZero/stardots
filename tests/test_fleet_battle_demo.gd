extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var battle = BATTLE_SCENE.instantiate()
	battle.fleet_battle_demo = true
	battle.fleet_battle_seed = 424242
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)

	if battle.friendly_units.size() != 12 or battle.enemy_units.size() != 10:
		failures.append("le scénario ne crée pas la flotte bleue de 12 et les 10 raiders rouges")
	_validate_blue_fleet(battle.friendly_units, failures)
	_validate_red_fleet(battle.enemy_units, failures)
	if not battle.objective_label.text.contains("424242"):
		failures.append("la graine rejouable n'est pas affichée dans l'interface")
	if battle.enemy_units[0].sensor_mode != TacticalUnit.SensorMode.PASSIVE:
		failures.append("le relais rouge ne commence pas en silence radar")
	if battle._data_link_can_transfer_now(battle.enemy_units[0], battle.enemy_units[1]):
		failures.append("le relais rouge partage encore ses pistes pendant sa fenêtre de silence")
	var replay = BATTLE_SCENE.instantiate()
	replay.fleet_battle_demo = true
	replay.fleet_battle_seed = 424242
	root.add_child(replay)
	replay.set_process(false)
	replay.set_physics_process(false)
	for index: int in mini(battle.friendly_units.size(), replay.friendly_units.size()):
		if battle.friendly_units[index].global_position != replay.friendly_units[index].global_position:
			failures.append("une même graine ne reproduit pas le déploiement bleu")
			break
	replay.free()

	battle.ai_decision_remaining = 0.0
	battle._update_ai(0.1)
	if not battle.enemy_units[1].has_move_target:
		failures.append("le groupe rouge n'exécute pas son approche préplanifiée pendant le silence")
	if battle.enemy_units[2].has_move_target:
		failures.append("le railgun rouge de réserve quitte sa position avant tout contact partagé")

	battle.simulation_clock.tick_index = battle.RED_LINK_BURST_START_TICK
	battle._update_sensor_picture()
	if battle.enemy_units[0].datalink_emission_mode == TacticalUnit.DatalinkEmissionMode.SILENT:
		failures.append("le relais rouge n'ouvre pas sa fenêtre courte de transmission")
	if not battle._data_link_can_transfer_now(battle.enemy_units[0], battle.enemy_units[1]):
		failures.append("la fenêtre radio rouge n'autorise pas le partage réel des pistes")
	battle.ai_decision_remaining = 0.0
	battle._update_ai(0.1)
	if not battle.friendly_units.any(_has_tactical_order) and battle.missiles_launched[0] == 0:
		failures.append("aucun bâtiment bleu ne reçoit de plan tactique automatique")
	if not battle.enemy_units.any(_has_tactical_order) and battle.missiles_launched[1] == 0:
		failures.append("aucun bâtiment rouge ne reçoit de plan tactique automatique")
	var reserve_railgun: TacticalUnit = battle.enemy_units[2]
	if reserve_railgun.has_move_target:
		failures.append("le railgun rouge de réserve avance avant la diversion missile")
	battle.missiles_launched[1] = 1
	battle.ai_decision_remaining = 0.0
	battle._update_ai(0.1)
	if not reserve_railgun.has_move_target and not reserve_railgun.is_orienting_to_final_heading:
		failures.append("le railgun rouge de réserve ne rejoint pas l'action après la diversion")

	var blue_launcher: TacticalUnit = battle.friendly_units[5]
	var red_launcher: TacticalUnit = battle.enemy_units[4]
	for friendly: TacticalUnit in battle.friendly_units:
		friendly.destroyed = friendly != blue_launcher
	for enemy: TacticalUnit in battle.enemy_units:
		enemy.destroyed = enemy != red_launcher
	blue_launcher.global_position = Vector2(-200.0, 360.0)
	red_launcher.global_position = Vector2(200.0, 360.0)
	blue_launcher.hull = 20.0
	red_launcher.hull = 20.0
	blue_launcher.sensor_mode = TacticalUnit.SensorMode.ACTIVE
	red_launcher.sensor_mode = TacticalUnit.SensorMode.ACTIVE
	blue_launcher.weapon_cooldown_remaining = 0.0
	red_launcher.weapon_cooldown_remaining = 0.0
	battle._update_sensor_picture()
	var blue_plan: Dictionary = battle.blue_fleet_pilot.plan_engagement(blue_launcher, red_launcher)
	var red_plan: Dictionary = battle.red_fleet_pilot.plan_engagement(red_launcher, blue_launcher)
	battle._execute_tactical_plan(blue_launcher, red_launcher, battle.blue_fleet_pilot)
	battle._execute_tactical_plan(red_launcher, blue_launcher, battle.red_fleet_pilot)
	var blue_missiles: int = 0
	var red_missiles: int = 0
	for missile in battle.missiles_layer.get_children():
		if missile.team_id == 0:
			blue_missiles += 1
		else:
			red_missiles += 1
	if blue_missiles == 0 or red_missiles == 0:
		failures.append(
			"tir bilatéral incomplet (bleu %d/%s/%s, rouge %d/%s/%s)"
			% [
				blue_missiles, blue_plan.get("should_fire", false), battle._launcher_has_fire_control_solution(blue_launcher, red_launcher),
				red_missiles, red_plan.get("should_fire", false), battle._launcher_has_fire_control_solution(red_launcher, blue_launcher),
			]
		)
	var second_blue_launcher: TacticalUnit = battle.friendly_units[6]
	second_blue_launcher.destroyed = false
	var second_blue_system: WeaponSystemProfile = second_blue_launcher.get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_SHIP
	)
	if battle._get_ai_missile_shot_count(
		second_blue_launcher,
		red_launcher,
		second_blue_system,
		battle.BLUE_FLEET_DOCTRINE
	) != 0:
		failures.append("une cible déjà couverte par les missiles en vol reçoit une réservation supplémentaire")
	if battle.BLUE_FLEET_DOCTRINE.allow_total_saturation:
		failures.append("la doctrine bleue ignore l'économie et vide encore automatiquement ses cellules")

	for enemy: TacticalUnit in battle.enemy_units:
		enemy.destroyed = true
	battle._update_fleet_battle_victory()
	if not battle.match_over or battle.victory_label.text != "VICTOIRE BLEUE":
		failures.append("l'annihilation de la flotte rouge ne conclut pas la bataille")

	battle.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Bataille automatique validée : 12 contre 10, groupes rouges, fenêtres radio et victoire.")
	quit(0)


func _validate_blue_fleet(units: Array[TacticalUnit], failures: Array[String]) -> void:
	var has_awacs: bool = false
	var has_laser_pdc: bool = false
	var has_interceptor: bool = false
	var has_medium_missile: bool = false
	var has_long_cells: bool = false
	var has_anti_radiation: bool = false
	for unit: TacticalUnit in units:
		if unit.fixed_in_place or unit.invulnerable:
			failures.append("la flotte bleue contient une unité fixe ou invulnérable")
		if unit.provides_fire_control_data():
			has_awacs = true
		if unit.unit_profile.tactical_role == "CELLULES LONGUE PORTÉE" and (
			unit.active_sensor_range != 560.0 or unit.can_transmit_data()
		):
			failures.append("un arsenal bleu ne conserve pas sa dépendance au réseau")
		for system: WeaponSystemProfile in unit.weapon_system_profiles:
			has_laser_pdc = has_laser_pdc or system.family == WeaponSystemProfile.Family.LASER_PDC
			has_interceptor = has_interceptor or system.tactical_role == WeaponSystemProfile.TacticalRole.INTERCEPTOR
			has_medium_missile = has_medium_missile or (
				system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_SHIP
				and system.feed_type == WeaponSystemProfile.FeedType.MAGAZINE
			)
			has_long_cells = has_long_cells or (
				system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_SHIP
				and system.feed_type == WeaponSystemProfile.FeedType.FIXED_CELLS
			)
			has_anti_radiation = has_anti_radiation or system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_RADIATION
	if not (has_awacs and has_laser_pdc and has_interceptor and has_medium_missile and has_long_cells and has_anti_radiation):
		failures.append("la flotte bleue ne couvre pas sa doctrine réseau et missiles")


func _validate_red_fleet(units: Array[TacticalUnit], failures: Array[String]) -> void:
	var has_relay: bool = false
	var has_laser_pdc: bool = false
	var has_interceptor: bool = false
	var has_medium_missile: bool = false
	var railgun_count: int = 0
	var anti_radiation_count: int = 0
	for unit: TacticalUnit in units:
		if unit.fixed_in_place or unit.invulnerable:
			failures.append("la flotte rouge contient une unité fixe ou invulnérable")
		has_relay = has_relay or unit.provides_fire_control_data()
		for system: WeaponSystemProfile in unit.weapon_system_profiles:
			has_laser_pdc = has_laser_pdc or system.family == WeaponSystemProfile.Family.LASER_PDC
			has_interceptor = has_interceptor or system.tactical_role == WeaponSystemProfile.TacticalRole.INTERCEPTOR
			has_medium_missile = has_medium_missile or system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_SHIP
			if system.family == WeaponSystemProfile.Family.RAILGUN:
				railgun_count += 1
			if system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_RADIATION:
				anti_radiation_count += 1
	if not (
		has_relay
		and has_laser_pdc
		and has_interceptor
		and has_medium_missile
		and railgun_count == 3
		and anti_radiation_count == 2
	):
		failures.append("la flotte rouge ne couvre pas trois railguns et deux chasseurs antirayonnement")


func _has_tactical_order(unit: TacticalUnit) -> bool:
	return unit.has_move_target or unit.is_orienting_to_final_heading
