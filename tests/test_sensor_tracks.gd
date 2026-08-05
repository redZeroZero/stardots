extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SENSOR_TRACK_SCRIPT := preload("res://src/simulation/sensor_track.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_track_prediction_and_aging(failures)
	_test_independent_classification(failures)
	_test_battlefield_fusion(failures)
	_test_sensor_demo(failures)
	_test_thermal_demo(failures)
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


func _test_independent_classification(failures: Array[String]) -> void:
	var target := Node2D.new()
	root.add_child(target)
	var track = SENSOR_TRACK_SCRIPT.new(0, target, 20.0)
	track.observe(
		SENSOR_TRACK_SCRIPT.State.SIGNAL,
		Vector2.ZERO,
		Vector2.ZERO,
		90.0,
		SENSOR_TRACK_SCRIPT.Channel.THERMAL
	)
	if track.classification_state != SENSOR_TRACK_SCRIPT.Classification.UNKNOWN:
		failures.append("un simple signal thermique révèle déjà le type du contact")
	track.observe(
		SENSOR_TRACK_SCRIPT.State.TRACKED,
		Vector2.ZERO,
		Vector2.ZERO,
		20.0,
		SENSOR_TRACK_SCRIPT.Channel.THERMAL,
		1,
		0.0,
		[],
		SENSOR_TRACK_SCRIPT.Classification.ESTIMATED,
		"FRÉGATE"
	)
	if track.get_classification_display() != "FRÉGATE ?":
		failures.append("la classification probable n'est pas distinguée de la confirmation")
	track.begin_sensor_pass()
	track.advance(4.0)
	if (
		track.get_state() == SENSOR_TRACK_SCRIPT.State.TRACKED
		or track.classification_state != SENSOR_TRACK_SCRIPT.Classification.ESTIMATED
	):
		failures.append("la classification ne reste pas indépendante du vieillissement cinématique")
	track.observe(
		SENSOR_TRACK_SCRIPT.State.TRACKED,
		Vector2.ZERO,
		Vector2.ZERO,
		20.0,
		SENSOR_TRACK_SCRIPT.Channel.ACTIVE_RADAR,
		1,
		0.0,
		[],
		SENSOR_TRACK_SCRIPT.Classification.CONFIRMED,
		"FRÉGATE"
	)
	if track.get_state() != SENSOR_TRACK_SCRIPT.State.TRACKED or track.get_classification_display() != "FRÉGATE":
		failures.append("la confirmation du type modifie la qualité cinématique de la piste")
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
	if friendly_track == null or friendly_track.get_state() != SENSOR_TRACK_SCRIPT.State.IDENTIFIED:
		failures.append("le camp bleu ne fusionne pas son observation proche")
	if enemy_track == null or enemy_track.get_state() != SENSOR_TRACK_SCRIPT.State.IDENTIFIED:
		failures.append("le camp rouge ne possède pas son propre tableau de pistes")
	if friendly_track != null and friendly_track.designation != "BANDIT-01":
		failures.append("la première piste hostile ne reçoit pas une désignation stable")
	if enemy.get_contact_label() != "BANDIT-01 — FRÉGATE":
		failures.append("la présentation passive proche ne confirme pas le type")

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
	if battle.friendly_units.size() != 2 or battle.enemy_units.size() != 4:
		failures.append("le scénario capteurs ne contient pas le capteur, le tireur et quatre contacts")
		battle.free()
		return
	var sensor: TacticalUnit = battle.friendly_units[0]
	var shooter: TacticalUnit = battle.friendly_units[1]
	if (
		battle.selected_units.size() != 2
		or sensor.sensor_mode != TacticalUnit.SensorMode.ACTIVE
		or shooter.get_anti_ship_burst_capacity() <= 0
	):
		failures.append("le capteur actif et le tireur missile ne sont pas prêts et sélectionnés")
	battle.tactical_overlay._rebuild_engagement_groups()
	if battle.tactical_overlay.show_collective_sensor_fill:
		failures.append("les remplissages collectifs de capteurs restent activés")
	var has_passive_envelope: bool = false
	var has_active_envelope: bool = false
	for group: Dictionary in battle.tactical_overlay.engagement_groups:
		has_passive_envelope = has_passive_envelope or not group.passive_sensor.contours.is_empty()
		has_active_envelope = has_active_envelope or not group.active_sensor.contours.is_empty()
	if not has_passive_envelope or not has_active_envelope:
		failures.append("la démo ne distingue pas les enveloppes passive et active")
	battle._update_sensor_picture()
	for target: TacticalUnit in battle.enemy_units:
		var initial_track = battle._get_sensor_track(0, target)
		if not target.invulnerable or not target.fixed_in_place:
			failures.append("un contact de la formation n'est pas fixe et indestructible")
		if initial_track == null or initial_track.get_state() != SENSOR_TRACK_SCRIPT.State.SIGNAL:
			failures.append("un contact de la formation n'apparaît pas initialement comme blip")
		if battle._launcher_has_fire_control_solution(shooter, target):
			failures.append("le tireur possède déjà une solution sur un simple blip")
	sensor.global_position = battle.enemy_units[0].global_position - Vector2(500.0, 0.0)
	battle._update_sensor_picture()
	for target: TacticalUnit in battle.enemy_units:
		var acquired_track = battle._get_sensor_track(0, target)
		if acquired_track == null or acquired_track.get_state() != SENSOR_TRACK_SCRIPT.State.IDENTIFIED:
			failures.append("la portée passive garantie ne révèle pas le vaisseau")
		elif not battle._launcher_has_fire_control_solution(shooter, target):
			failures.append("le tireur ne reçoit pas de solution après l'acquisition")
	battle.free()


func _test_thermal_demo(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.thermal_demo = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	if battle.friendly_units.size() != 1 or battle.enemy_units.size() != 2:
		failures.append("la démo thermique ne contient pas le veilleur et ses deux cibles")
		battle.free()
		return
	var sensor: TacticalUnit = battle.friendly_units[0]
	var cold_target: TacticalUnit = battle.enemy_units[0]
	var hot_target: TacticalUnit = battle.enemy_units[1]
	if sensor.sensor_mode != TacticalUnit.SensorMode.ACTIVE:
		failures.append("la démo thermique ne commence pas avec les deux références visibles au radar")
	var cold_distance: float = sensor.global_position.distance_to(cold_target.global_position)
	var hot_distance: float = sensor.global_position.distance_to(hot_target.global_position)
	if not is_equal_approx(cold_target.get_passive_detection_signature(), 1.0):
		failures.append("la référence froide de la démo ne reste pas à la portée nominale")
	if not is_equal_approx(hot_target.get_passive_detection_signature(), 2.3):
		failures.append("la référence chaude de la démo n'illustre pas l'amplification thermique")
	if sensor.sensor_range * cold_target.get_passive_detection_signature() >= cold_distance:
		failures.append("la cible froide n'est pas au-delà de la garantie passive")
	if sensor.sensor_range * hot_target.get_passive_detection_signature() <= hot_distance:
		failures.append("la chaleur n'étend pas la portée passive jusqu'à la cible chaude")
	sensor.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	battle._update_sensor_picture()
	var cold_track = battle._get_sensor_track(0, cold_target)
	var hot_track = battle._get_sensor_track(0, hot_target)
	if cold_track == null or cold_track.observation_floor > 0.0:
		failures.append("la cible froide reste observée hors de la portée passive nominale")
	if (
		hot_track == null
		or hot_track.observation_floor < SENSOR_TRACK_SCRIPT.IDENTIFIED_CONFIDENCE
		or not bool(hot_track.last_observation_channels & SENSOR_TRACK_SCRIPT.Channel.THERMAL)
	):
		failures.append("la cible chaude n'est pas maintenue par le canal thermique passif")
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
	profile.sensor_range = 100.0
	var first: TacticalUnit = battle._spawn_unit("CAPTEUR-A", 0, Vector2(-200.0, -100.0), profile)
	var second: TacticalUnit = battle._spawn_unit("CAPTEUR-B", 0, Vector2(-200.0, 100.0), profile)
	var target: TacticalUnit = battle._spawn_unit("SOURCE", 1, Vector2(100.0, 0.0), profile)
	first.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	second.sensor_mode = TacticalUnit.SensorMode.PASSIVE
	target.sensor_mode = TacticalUnit.SensorMode.ACTIVE
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
