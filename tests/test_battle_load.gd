extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")
const MISSILE_SCRIPT := preload("res://src/tactical_missile.gd")
const UNIT_PROFILE: UnitProfile = preload("res://data/balance/default_unit.tres")
const MISSILE_PROFILE: MissileProfile = preload("res://data/balance/default_missile.tres")
const SIMULATED_TICKS: int = 40
const SIMULATION_DELTA: float = 1.0 / 20.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var results: Array[Dictionary] = []
	for unit_count: int in [100, 250, 500]:
		var result: Dictionary = _benchmark_battle(unit_count)
		results.append(result)
		if float(result["average_tick_msec"]) > 50.0:
			failures.append("la bataille de %d unités dépasse 50 ms par tick" % unit_count)

	for result: Dictionary in results:
		print(
			"Charge bataille %3d unités / %2d missiles : tick %.3f ms " % [
				result["unit_count"], result["missile_count"], result["average_tick_msec"],
			]
			+ "(mouvement %.3f, capteurs %.3f, IA %.3f, guidage %.3f, PDC %.3f)." % [
				result["movement_msec"], result["sensors_msec"], result["ai_msec"],
				result["guidance_msec"], result["pdc_msec"],
			]
		)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _benchmark_battle(unit_count: int) -> Dictionary:
	var battle = BATTLE_SCENE.instantiate()
	battle.benchmark_empty_scenario = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)

	var profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	profile.missile_launcher_count = 0
	profile.missile_capacity = 0
	var all_units: Array[TacticalUnit] = []
	var side_count: int = unit_count / 2
	for index: int in unit_count:
		var team_id: int = 0 if index < side_count else 1
		var side_index: int = index if team_id == 0 else index - side_count
		var side_x: float = -320.0 if team_id == 0 else 320.0
		var position := Vector2(
			side_x + float(side_index % 20) * 8.0,
			-360.0 + float(side_index / 20) * 28.0
		)
		var unit: TacticalUnit = battle._spawn_unit("LOAD-%03d" % index, team_id, position, profile)
		unit.set_navigation_order(position + Vector2(500.0 if team_id == 0 else -500.0, 0.0))
		unit.set_process(false)
		unit.set_physics_process(false)
		all_units.append(unit)

	var missile_count: int = maxi(10, unit_count / 10)
	for index: int in missile_count:
		var team_id: int = index % 2
		var targets = battle.enemy_units if team_id == 0 else battle.friendly_units
		var target: TacticalUnit = targets[index % targets.size()]
		var missile: TacticalMissile = MISSILE_SCRIPT.new()
		battle.missiles_layer.add_child(missile)
		missile.launch(Vector2(-80.0 if team_id == 0 else 80.0, target.global_position.y), target, team_id, MISSILE_PROFILE)
		missile.set_process(false)
		missile.set_physics_process(false)

	var movement_usec: int = 0
	var sensors_usec: int = 0
	var ai_usec: int = 0
	var guidance_usec: int = 0
	var pdc_usec: int = 0
	for tick: int in SIMULATED_TICKS:
		var operation_start: int = Time.get_ticks_usec()
		for unit: TacticalUnit in all_units:
			unit._physics_process(SIMULATION_DELTA)
		movement_usec += Time.get_ticks_usec() - operation_start

		operation_start = Time.get_ticks_usec()
		battle._update_sensor_picture_if_due(SIMULATION_DELTA)
		sensors_usec += Time.get_ticks_usec() - operation_start

		operation_start = Time.get_ticks_usec()
		battle._update_ai(SIMULATION_DELTA)
		ai_usec += Time.get_ticks_usec() - operation_start

		operation_start = Time.get_ticks_usec()
		battle._update_missile_guidance()
		guidance_usec += Time.get_ticks_usec() - operation_start

		operation_start = Time.get_ticks_usec()
		battle._update_point_defense(SIMULATION_DELTA)
		pdc_usec += Time.get_ticks_usec() - operation_start

	var divisor: float = float(SIMULATED_TICKS) * 1000.0
	var result := {
		"unit_count": unit_count,
		"missile_count": missile_count,
		"movement_msec": float(movement_usec) / divisor,
		"sensors_msec": float(sensors_usec) / divisor,
		"ai_msec": float(ai_usec) / divisor,
		"guidance_msec": float(guidance_usec) / divisor,
		"pdc_msec": float(pdc_usec) / divisor,
	}
	result["average_tick_msec"] = (
		float(movement_usec + sensors_usec + ai_usec + guidance_usec + pdc_usec) / divisor
	)
	battle.free()
	return result
