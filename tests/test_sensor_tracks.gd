extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SENSOR_TRACK_SCRIPT := preload("res://src/simulation/sensor_track.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_track_prediction_and_aging(failures)
	_test_battlefield_fusion(failures)
	_test_sensor_demo(failures)
	_test_automatic_awacs_emission(failures)
	_test_passive_triangulation(failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Pistes capteurs validées : fusion par camp, prédiction, incertitude et vieillissement.")
	quit(0)


func _test_track_prediction_and_aging(failures: Array[String]) -> void:
	var target := Node2D.new()
	root.add_child(target)
	var track = SENSOR_TRACK_SCRIPT.new(0, target, 20.0)
	track.begin_sensor_pass()
	track.observe(
		SENSOR_TRACK_SCRIPT.State.IDENTIFIED,
		Vector2.ZERO,
		Vector2(30.0, 0.0),
		2.0
	)
	track.begin_sensor_pass()
	track.advance(2.0)
	if track.get_state() != SENSOR_TRACK_SCRIPT.State.TRACKED:
		failures.append("une identification perdue ne rétrograde pas progressivement en piste")
	if track.estimated_position.distance_to(Vector2(60.0, 0.0)) > 0.01:
		failures.append("la piste perdue ne propage pas le dernier vecteur connu")
	if track.uncertainty_radius <= 2.0:
		failures.append("l'incertitude d'une piste perdue n'augmente pas")
	track.advance(6.0)
	if track.get_state() != SENSOR_TRACK_SCRIPT.State.SIGNAL:
		failures.append("une vieille piste ne devient pas un simple signal")
	track.advance(8.0)
	if track.get_state() != SENSOR_TRACK_SCRIPT.State.HIDDEN:
		failures.append("un contact sans nouvelle observation ne finit pas par disparaître")
	target.free()


func _test_battlefield_fusion(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.benchmark_empty_scenario = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	profile.weapon_system_profiles = []
	profile.missile_capacity = 0
	profile.missile_launcher_count = 0
	var friendly: TacticalUnit = battle._spawn_unit("CAPTEUR", 0, Vector2.ZERO, profile)
	var enemy: TacticalUnit = battle._spawn_unit("CONTACT", 1, Vector2(80.0, 0.0), profile)
	battle._update_sensor_picture()
	var friendly_track = battle._get_sensor_track(0, enemy)
	var enemy_track = battle._get_sensor_track(1, friendly)
	if friendly_track == null or friendly_track.get_state() != SENSOR_TRACK_SCRIPT.State.TRACKED:
		failures.append("le camp bleu ne fusionne pas son observation proche")
	if enemy_track == null or enemy_track.get_state() != SENSOR_TRACK_SCRIPT.State.TRACKED:
		failures.append("le camp rouge ne possède pas son propre tableau de pistes")

	enemy.global_position = Vector2(3000.0, 0.0)
	enemy.velocity = Vector2(25.0, 0.0)
	battle._update_sensor_picture()
	battle._advance_sensor_tracks(2.0)
	if enemy.intel_state != TacticalUnit.IntelState.TRACKED:
		failures.append("la présentation joueur ne reflète pas le vieillissement de la piste")
	if enemy.contact_offset == Vector2.ZERO:
		failures.append("le symbole vieilli révèle encore la position réelle du contact")
	if battle._launcher_has_fire_control_solution(friendly, enemy):
		failures.append("une piste devenue trop incertaine fournit encore une solution de tir")
	battle.free()


func _test_sensor_demo(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.sensor_demo = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	if battle.friendly_units.size() != 1 or battle.enemy_units.size() != 1:
		failures.append("le scénario capteurs ne contient pas un observateur et un contact")
	elif battle.enemy_units[0].navigation_route.is_empty():
		failures.append("le contact du scénario capteurs ne possède pas sa route de sortie")
	if battle.selected_units.size() != 1 or battle.selected_units[0].sensor_mode != TacticalUnit.SensorMode.ACTIVE:
		failures.append("la plateforme de veille n'est pas sélectionnée avec son radar actif")
	if not battle.enemy_units[0].invulnerable:
		failures.append("le contact de calibration peut être détruit")
	var observed_states: Dictionary = {}
	var target: TacticalUnit = battle.enemy_units[0]
	for _tick: int in 700:
		target._physics_process(0.05)
		battle._advance_sensor_tracks(0.05)
		battle._update_sensor_picture_if_due(0.05)
		observed_states[target.intel_state] = true
	for expected_state: int in [
		TacticalUnit.IntelState.IDENTIFIED,
		TacticalUnit.IntelState.TRACKED,
		TacticalUnit.IntelState.SIGNAL,
		TacticalUnit.IntelState.HIDDEN,
	]:
		if not observed_states.has(expected_state):
			failures.append("le scénario capteurs ne traverse pas l'état de renseignement %d" % expected_state)
	battle.free()


func _test_automatic_awacs_emission(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.benchmark_empty_scenario = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	var awacs_profile: UnitProfile = load("res://data/balance/awacs_unit.tres").duplicate(true)
	var frigate_profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	var awacs: TacticalUnit = battle._spawn_unit("EYE", 0, Vector2.ZERO, awacs_profile)
	var frigate: TacticalUnit = battle._spawn_unit("TIREUR", 0, Vector2(100.0, 0.0), frigate_profile)
	var emitter_hunter: TacticalUnit = battle._spawn_unit("VEILLE ROUGE", 1, Vector2(500.0, 0.0), frigate_profile)
	awacs.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	battle._update_sensor_picture()
	battle._update_sensor_picture()
	if awacs.datalink_emission_mode != TacticalUnit.DatalinkEmissionMode.FIRE_CONTROL:
		failures.append("l'AWACS ne passe pas automatiquement en émission de conduite de tir")
	if not is_equal_approx(
		awacs.get_electromagnetic_signature(),
		awacs_profile.data_link_profile.fire_control_emission_strength
	):
		failures.append("le flux électromagnétique AWACS ne suit pas son profil")
	var hostile_track = battle._get_sensor_track(1, awacs)
	if hostile_track == null or not bool(hostile_track.last_observation_channels & SENSOR_TRACK_SCRIPT.Channel.RADIO):
		failures.append("le camp adverse ne détecte pas la liaison AWACS par radio passive")
	frigate.global_position = Vector2(3000.0, 0.0)
	battle._update_sensor_picture()
	if awacs.datalink_emission_mode != TacticalUnit.DatalinkEmissionMode.SILENT:
		failures.append("l'AWACS continue d'émettre sans bâtiment relié")
	if emitter_hunter.destroyed:
		failures.append("la cible de veille électromagnétique a été détruite pendant le test")
	battle.free()


func _test_passive_triangulation(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.benchmark_empty_scenario = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	profile.weapon_system_profiles = []
	profile.missile_capacity = 0
	profile.missile_launcher_count = 0
	var first: TacticalUnit = battle._spawn_unit("CAPTEUR-A", 0, Vector2(-200.0, -100.0), profile)
	var second: TacticalUnit = battle._spawn_unit("CAPTEUR-B", 0, Vector2(-200.0, 100.0), profile)
	var target: TacticalUnit = battle._spawn_unit("SOURCE", 1, Vector2(100.0, 0.0), profile)
	first.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	second.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	battle._update_sensor_picture()
	var track = battle._get_sensor_track(0, target)
	if track == null or track.get_state() != SENSOR_TRACK_SCRIPT.State.TRACKED:
		failures.append("deux relèvements passifs séparés ne construisent pas une piste")
	elif track.bearing_observer_count < 2 or not bool(track.last_observation_channels & SENSOR_TRACK_SCRIPT.Channel.TRIANGULATED):
		failures.append("la piste fusionnée n'enregistre pas sa triangulation")
	elif track.triangulation_quality <= 0.08:
		failures.append("la géométrie des capteurs ne réduit pas l'incertitude")
	second.global_position = Vector2(-3000.0, 100.0)
	battle._update_sensor_picture()
	if track.bearing_observer_count != 1:
		failures.append("un capteur sorti de portée compte encore dans la triangulation")
	battle.free()
