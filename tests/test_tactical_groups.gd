extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SENSOR_TRACK_SCRIPT := preload("res://src/simulation/sensor_track.gd")
const MISSILE_PROFILE: MissileProfile = preload("res://data/balance/default_missile.tres")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var battle = BATTLE_SCENE.instantiate()
	battle.benchmark_empty_scenario = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)

	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	profile.weapon_system_profiles = []
	profile.missile_capacity = 0
	profile.missile_launcher_count = 0
	profile.sensor_range = 100.0
	profile.active_emission_detection_range = 600.0
	profile.active_radar_emission_strength = 1.0
	var first: TacticalUnit = battle._spawn_unit(
		"GROUPE-1", 0, Vector2(-500.0, -100.0), profile
	)
	var second: TacticalUnit = battle._spawn_unit(
		"GROUPE-2", 0, Vector2(-500.0, 100.0), profile
	)
	var target: TacticalUnit = battle._spawn_unit("CIBLE", 1, Vector2.ZERO, profile)
	first.tactical_group_id = 0
	second.tactical_group_id = 1
	first.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	second.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	target.sensor_mode = TacticalUnit.SensorMode.ACTIVE
	battle._update_sensor_picture()

	var command_track = battle._get_sensor_track(0, target)
	var first_track = battle._get_unit_sensor_track(first, target)
	var second_track = battle._get_unit_sensor_track(second, target)
	if command_track == null or command_track.get_state() != SENSOR_TRACK_SCRIPT.State.SIGNAL:
		failures.append("la vue de commandement fusionne encore les relèvements bruts de groupes isolés")
	if (
		first_track == null
		or second_track == null
		or first_track.get_state() != SENSOR_TRACK_SCRIPT.State.SIGNAL
		or second_track.get_state() != SENSOR_TRACK_SCRIPT.State.SIGNAL
	):
		failures.append("deux groupes isolés fabriquent encore une piste triangulée commune")
	if battle._launcher_has_fire_control_solution(second, target):
		failures.append("une piste globale fuit encore comme solution de tir vers un groupe isolé")

	var missile := TacticalMissile.new()
	battle.missiles_layer.add_child(missile)
	missile.launch(second.global_position, target, 0, MISSILE_PROFILE)
	missile.set_meta("guidance_group_id", second.tactical_group_id)
	battle._update_missile_guidance()
	if missile.external_guidance_available:
		failures.append("un missile reçoit encore le guidage de la piste globale de l'armée")

	var awacs_profile: UnitProfile = load("res://data/balance/awacs_unit.tres").duplicate(true)
	awacs_profile.weapon_system_profiles = []
	var command_ship: TacticalUnit = battle._spawn_unit(
		"COMMANDEMENT", 0, Vector2(-800.0, 0.0), awacs_profile
	)
	command_ship.tactical_group_id = 2
	command_ship.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	battle._update_sensor_picture()
	second_track = battle._get_unit_sensor_track(second, target)
	if (
		second_track == null
		or second_track.get_state() < SENSOR_TRACK_SCRIPT.State.TRACKED
		or not battle._launcher_has_fire_control_solution(second, target)
	):
		failures.append("le bâtiment de commandement ne remonte pas une piste synthétique exploitable")
	elif (
		second_track.classification_state != SENSOR_TRACK_SCRIPT.Classification.CONFIRMED
		or second_track.classification_label != "FRÉGATE"
	):
		failures.append("le rapport de commandement ne transmet pas le type confirmé")
	battle._update_missile_guidance()
	if not missile.external_guidance_available:
		failures.append("le guidage ne reprend pas après la fusion intergroupes du commandement")

	battle.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Groupes tactiques validés : pistes disjointes, rapports de commandement et guidage local.")
	quit(0)
