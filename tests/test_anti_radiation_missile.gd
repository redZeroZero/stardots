extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")
const MISSILE_SCRIPT := preload("res://src/tactical_missile.gd")
const UNIT_SCRIPT := preload("res://src/tactical_unit.gd")
const MISSILE_PROFILE: MissileProfile = preload("res://data/munitions/anti_radiation_missile.tres")
const OFFENSIVE_ANTI_RADIATION: int = 3
const FIRE_ECONOMY: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_passive_homing_and_emission_memory(failures)
	_test_radiation_demo_and_fire_control(failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Antirayonnement validé : relèvement radio, mémoire, reprise et tir spécialisé.")
	quit(0)


func _test_passive_homing_and_emission_memory(failures: Array[String]) -> void:
	var emitter_profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	emitter_profile.weapon_system_profiles = []
	var emitter := UNIT_SCRIPT.new() as TacticalUnit
	root.add_child(emitter)
	emitter.configure("ÉMETTEUR", 1, Vector2(500.0, 0.0), emitter_profile)
	emitter.sensor_mode = TacticalUnit.SensorMode.ACTIVE

	var missile := MISSILE_SCRIPT.new() as TacticalMissile
	root.add_child(missile)
	var impacts: Array[Node2D] = []
	missile.impacted.connect(func(target: Node2D): impacts.append(target))
	missile.launch(Vector2.ZERO, emitter, 0, MISSILE_PROFILE, emitter.global_position)
	missile._physics_process(0.05)
	if not missile.is_anti_radiation() or not missile.has_radiation_lock():
		failures.append("l'ARM n'acquiert pas un radar actif dans la portée de son autodirecteur")
	emitter.global_position = Vector2(520.0, 20.0)
	missile._physics_process(0.05)
	if missile.last_known_position.distance_to(emitter.global_position) > 0.01:
		failures.append("l'ARM ne met pas à jour le relèvement d'un émetteur actif")

	emitter.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	var remembered_position: Vector2 = missile.last_known_position
	emitter.global_position = Vector2(650.0, 80.0)
	missile._physics_process(0.05)
	if missile.has_radiation_lock() or missile.last_known_position != remembered_position:
		failures.append("l'ARM continue de suivre la position réelle après extinction de l'émetteur")
	emitter.sensor_mode = TacticalUnit.SensorMode.ACTIVE
	missile._physics_process(0.05)
	if not missile.has_radiation_lock() or missile.last_known_position.distance_to(emitter.global_position) > 0.01:
		failures.append("l'ARM ne reprend pas une émission qui réapparaît")
	for tick: int in 300:
		if missile.exploding:
			break
		missile._physics_process(0.05)
	if impacts != [emitter]:
		failures.append("l'ARM ne produit pas d'impact de proximité sur un émetteur persistant")
	missile.free()
	emitter.free()


func _test_radiation_demo_and_fire_control(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.radiation_demo = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	if battle.friendly_units.size() != 1 or battle.enemy_units.size() != 1:
		failures.append("le scénario antirayonnement ne crée pas le chasseur et son émetteur")
		battle.free()
		return
	var hunter: TacticalUnit = battle.friendly_units[0]
	var emitter: TacticalUnit = battle.enemy_units[0]
	var system: WeaponSystemProfile = hunter.get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_RADIATION
	)
	if system == null or system.missile_profile.seeker_mode != MissileProfile.SeekerMode.ANTI_RADIATION:
		failures.append("le chasseur d'émetteurs ne possède pas ses cellules ARM")
	if not emitter.invulnerable or not emitter.fixed_in_place or emitter.sensor_mode != TacticalUnit.SensorMode.ACTIVE:
		failures.append("la cible de calibration n'est pas un émetteur actif fixe et indestructible")
	if not battle._has_current_radio_bearing(0, emitter):
		failures.append("le récepteur passif du chasseur ne produit pas de relèvement radio")

	battle.offensive_weapon_selection = OFFENSIVE_ANTI_RADIATION
	battle.fire_doctrine = FIRE_ECONOMY
	var shots: int = battle._issue_attack_zone(emitter.global_position)
	if shots != 1 or battle.missiles_layer.get_child_count() != 1:
		failures.append("l'ordre ANTIRAD ne lance pas exactement un missile en économie")
	elif not battle.missiles_layer.get_child(0).is_anti_radiation():
		failures.append("l'ordre ANTIRAD lance une munition conventionnelle")
	if system != null and hunter.get_weapon_system_ammunition(system) != 3:
		failures.append("le tir ARM ne consomme pas une cellule fixe")

	emitter.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	battle._advance_sensor_tracks(0.5)
	battle._update_sensor_picture()
	if battle._has_current_radio_bearing(0, emitter):
		failures.append("un émetteur silencieux conserve indéfiniment un relèvement de tir ARM")
	battle.free()
