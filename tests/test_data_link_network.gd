extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")
const NETWORK_SCRIPT := preload("res://src/simulation/data_link_network.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_directional_links_and_relay(failures)
	_test_track_access(failures)
	_test_homogeneous_frigate_group(failures)
	_test_network_demo(failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Réseau de données validé : réception, émission, relais et piste locale isolée.")
	quit(0)


func _make_unit(callsign: String, position: Vector2, profile: UnitProfile) -> TacticalUnit:
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure(callsign, 0, position, profile)
	return unit


func _test_directional_links_and_relay(failures: Array[String]) -> void:
	var standard_profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	var transmitter_profile: UnitProfile = standard_profile.duplicate(true)
	var receiver_profile: UnitProfile = standard_profile.duplicate(true)
	receiver_profile.data_link_profile = load("res://data/data_links/receiver_only_tactical_link.tres")
	var awacs_profile: UnitProfile = load("res://data/balance/awacs_unit.tres").duplicate(true)
	var isolated_profile: UnitProfile = standard_profile.duplicate(true)
	isolated_profile.data_link_profile = null
	var source: TacticalUnit = _make_unit("SOURCE", Vector2.ZERO, transmitter_profile)
	var relay: TacticalUnit = _make_unit("RELAIS", Vector2(1000.0, 0.0), awacs_profile)
	var receiver: TacticalUnit = _make_unit("RÉCEPTEUR", Vector2(2500.0, 0.0), receiver_profile)
	var isolated: TacticalUnit = _make_unit("ISOLÉ", Vector2(400.0, 0.0), isolated_profile)
	var network = NETWORK_SCRIPT.new()
	network.rebuild([source, relay, receiver, isolated])
	if not network.can_transfer(source, receiver):
		failures.append("un relais AWACS ne propage pas les données entre deux bâtiments hors portée directe")
	if network.can_transfer(source, isolated) or network.can_transfer(isolated, source):
		failures.append("une plateforme sans profil de liaison participe encore au réseau")

	var non_relay: TacticalUnit = _make_unit("NON-RELAIS", Vector2(1000.0, 300.0), transmitter_profile)
	var distant_receiver: TacticalUnit = _make_unit("DISTANT", Vector2(2200.0, 300.0), receiver_profile)
	network.rebuild([source, non_relay, distant_receiver])
	if network.can_transfer(source, distant_receiver):
		failures.append("un transceiver standard relaie des données sans capacité de relais")
	for unit: TacticalUnit in [source, relay, receiver, isolated, non_relay, distant_receiver]:
		unit.free()


func _test_track_access(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.benchmark_empty_scenario = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	var standard_profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	var transmitter_profile: UnitProfile = standard_profile.duplicate(true)
	var receiver_profile: UnitProfile = standard_profile.duplicate(true)
	receiver_profile.data_link_profile = load("res://data/data_links/receiver_only_tactical_link.tres")
	var isolated_profile: UnitProfile = standard_profile.duplicate(true)
	isolated_profile.data_link_profile = null
	var source: TacticalUnit = battle._spawn_unit("CAPTEUR", 0, Vector2.ZERO, transmitter_profile)
	var receiver: TacticalUnit = battle._spawn_unit("RÉSEAU", 0, Vector2(-800.0, 0.0), receiver_profile)
	var isolated: TacticalUnit = battle._spawn_unit("LOCAL", 0, Vector2(-800.0, 80.0), isolated_profile)
	var target: TacticalUnit = battle._spawn_unit("CIBLE", 1, Vector2(300.0, 0.0), standard_profile)
	source.sensor_mode = TacticalUnit.SensorMode.ACTIVE
	battle._update_sensor_picture()
	var track = battle._get_sensor_track(0, target)
	if track == null or not battle._unit_can_access_track(receiver, track):
		failures.append("un récepteur relié ne reçoit pas la piste du capteur allié")
	if track != null and battle._unit_can_access_track(isolated, track):
		failures.append("une unité isolée reçoit une piste qu'elle n'observe pas localement")
	receiver.global_position = Vector2(-1500.0, 0.0)
	battle._update_sensor_picture()
	if track != null and battle._unit_can_access_track(receiver, track):
		failures.append("une unité hors portée conserve un accès réseau immédiat à la piste")
	battle.free()


func _test_homogeneous_frigate_group(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.benchmark_empty_scenario = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	var frigate_profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	var sensor: TacticalUnit = battle._spawn_unit("FRÉGATE-CAPTEUR", 0, Vector2.ZERO, frigate_profile)
	var shooter: TacticalUnit = battle._spawn_unit("FRÉGATE-TIREUR", 0, Vector2(-1100.0, 0.0), frigate_profile)
	var target: TacticalUnit = battle._spawn_unit("CIBLE", 1, Vector2(600.0, 0.0), frigate_profile)
	sensor.sensor_mode = TacticalUnit.SensorMode.ACTIVE
	battle._update_sensor_picture()
	var track = battle._get_sensor_track(0, target)
	if track == null or not battle._unit_can_access_track(shooter, track):
		failures.append("une frégate ne partage pas sa piste avec une consœur reliée")
	elif not battle._launcher_has_fire_control_solution(shooter, target):
		failures.append("la piste partagée entre frégates n'atteint pas la qualité de tir")
	if battle._sensor_range_ratio(shooter, target) <= 1.0:
		failures.append("le tireur homogène observe localement la cible lointaine du test")
	battle.free()


func _test_network_demo(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.network_demo = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	if battle.friendly_units.size() != 4 or battle.enemy_units.size() != 1:
		failures.append("le scénario réseau ne crée pas TX, relais, récepteur, isolé et contact")
		battle.free()
		return
	var receiver: TacticalUnit = battle.friendly_units[2]
	var isolated: TacticalUnit = battle.friendly_units[3]
	if receiver.get_data_link_role_name() != "RÉCEPTEUR":
		failures.append("RX-01 n'utilise pas un profil de réception seule")
	if isolated.get_data_link_role_name() != "ISOLÉ":
		failures.append("ISOLÉ-01 possède encore un nœud de données")
	if battle._count_accessible_tracks(receiver) < 1:
		failures.append("RX-01 ne reçoit pas la piste transmise via le relais")
	if battle._count_accessible_tracks(isolated) != 0:
		failures.append("ISOLÉ-01 affiche une piste qu'il ne détecte ni ne reçoit")
	battle.free()
