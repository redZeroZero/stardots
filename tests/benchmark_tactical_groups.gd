extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")
const STANDARD_PROFILE: UnitProfile = preload("res://data/balance/default_unit.tres")
const AWACS_PROFILE: UnitProfile = preload("res://data/balance/awacs_unit.tres")
const UNIT_COUNT: int = 500
const MEASURED_SENSOR_PASSES: int = 8
const PHYSICS_TICKS_PER_SENSOR_PASS: float = 4.0
const LOCAL_TOPOLOGY_BUDGET_MSEC: float = 160.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var results: Array[Dictionary] = [
		_benchmark_configuration("mono-groupe compact actif", 1, 0, false, true),
		_benchmark_configuration("20 groupes compacts actifs", 10, 0, false, true),
		_benchmark_configuration("compacts + 2 AWACS", 10, 1, false, true),
		_benchmark_configuration("20 groupes dispersés passifs", 10, 0, true, false),
		_benchmark_configuration("dispersés + 4 AWACS", 10, 2, true, false),
	]
	var failures: Array[String] = []
	for result: Dictionary in results:
		print(
			"Réseau %-24s : capteurs %.3f ms/passe (%.3f ms/tick), %.1f pistes/groupe." % [
				result["label"],
				result["sensor_pass_msec"],
				float(result["sensor_pass_msec"]) / PHYSICS_TICKS_PER_SENSOR_PASS,
				result["tracks_per_group"],
			]
		)
		if (
			String(result["label"]).contains("dispersé")
			and float(result["sensor_pass_msec"]) > LOCAL_TOPOLOGY_BUDGET_MSEC
		):
			failures.append(
				"%s dépasse le budget local de %.0f ms/passe" % [
					result["label"], LOCAL_TOPOLOGY_BUDGET_MSEC,
				]
			)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _benchmark_configuration(
	label: String,
	groups_per_team: int,
	bridge_count_per_team: int,
	dispersed_groups: bool,
	active_sensors: bool
) -> Dictionary:
	var battle = BATTLE_SCENE.instantiate()
	battle.benchmark_empty_scenario = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)

	var standard_profile: UnitProfile = STANDARD_PROFILE.duplicate(true)
	standard_profile.weapon_system_profiles = []
	standard_profile.missile_capacity = 0
	standard_profile.missile_launcher_count = 0
	var awacs_profile: UnitProfile = AWACS_PROFILE.duplicate(true)
	awacs_profile.weapon_system_profiles = []
	var side_count: int = UNIT_COUNT / 2
	for index: int in UNIT_COUNT:
		var team_id: int = 0 if index < side_count else 1
		var side_index: int = index if team_id == 0 else index - side_count
		var group_id: int = (
			side_index / 25
			if dispersed_groups
			else side_index % groups_per_team
		)
		var group_slot: int = side_index % 25
		var bridge_spacing: int = maxi(1, groups_per_team / maxi(1, bridge_count_per_team))
		var is_bridge: bool = (
			bridge_count_per_team > 0
			and (
				(group_slot == 0 and group_id % bridge_spacing == 0)
				if dispersed_groups
				else side_index < bridge_count_per_team
			)
		)
		var profile: UnitProfile = awacs_profile if is_bridge else standard_profile
		var position: Vector2
		if dispersed_groups:
			position = Vector2(
				(-225.0 if team_id == 0 else 225.0) + float(group_slot % 5) * 8.0,
				-3150.0 + float(group_id) * 700.0 + float(group_slot / 5) * 8.0
			)
		else:
			var side_x: float = -320.0 if team_id == 0 else 320.0
			position = Vector2(
				side_x + float(side_index % 20) * 8.0,
				-360.0 + float(side_index / 20) * 28.0
			)
		var unit: TacticalUnit = battle._spawn_unit(
			"GROUP-LOAD-%03d" % index,
			team_id,
			position,
			profile
		)
		unit.tactical_group_id = group_id
		unit.sensor_mode = (
			TacticalUnit.SensorMode.ACTIVE
			if active_sensors
			else TacticalUnit.SensorMode.PASSIVE
		)
		unit.set_process(false)
		unit.set_physics_process(false)

	# La première passe construit les groupes, le graphe et les caches.
	battle._update_sensor_picture()
	var start_usec: int = Time.get_ticks_usec()
	for _pass_index: int in MEASURED_SENSOR_PASSES:
		battle._update_sensor_picture()
	var elapsed_usec: int = Time.get_ticks_usec() - start_usec

	var total_tracks: int = 0
	var total_groups: int = 0
	for groups: Dictionary in battle.tactical_groups_by_team:
		for group: TacticalGroup in groups.values():
			total_tracks += group.track_picture.tracks.size()
			total_groups += 1
	var result := {
		"label": label,
		"sensor_pass_msec": float(elapsed_usec) / float(MEASURED_SENSOR_PASSES) / 1000.0,
		"tracks_per_group": float(total_tracks) / float(maxi(1, total_groups)),
	}
	battle.free()
	return result
