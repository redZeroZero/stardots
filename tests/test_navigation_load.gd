extends SceneTree

const SIMULATED_TICKS: int = 400
const SIMULATION_DELTA: float = 1.0 / 20.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var results: Array[Dictionary] = []
	for unit_count: int in [100, 250, 500]:
		var result: Dictionary = _benchmark_navigation(unit_count)
		results.append(result)
		if float(result["average_tick_msec"]) > 20.0:
			failures.append("la navigation de %d unités dépasse 20 ms par tick" % unit_count)
	if float(results[2]["average_tick_msec"]) > float(results[0]["average_tick_msec"]) * 8.0:
		failures.append("le coût de navigation croît plus vite que prévu entre 100 et 500 unités")

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	for result: Dictionary in results:
		print(
			"Charge navigation %3d unités : plans %.1f ms, tick moyen %.3f ms." % [
				result["unit_count"], result["planning_msec"], result["average_tick_msec"],
			]
		)
	quit(0)


func _benchmark_navigation(unit_count: int) -> Dictionary:
	var base_profile: UnitProfile = load("res://data/balance/default_unit.tres")
	var profiles: Array[UnitProfile] = []
	for doctrine: int in [
		UnitProfile.PropulsionDoctrine.FLIP_AND_BURN,
		UnitProfile.PropulsionDoctrine.HOLD_ATTITUDE,
		UnitProfile.PropulsionDoctrine.HYBRID,
	]:
		var profile: UnitProfile = base_profile.duplicate(true)
		profile.propulsion_profile = null
		profile.propulsion_doctrine = doctrine
		if doctrine != UnitProfile.PropulsionDoctrine.HOLD_ATTITUDE:
			profile.retrograde_thrust_multiplier = 0.25
			profile.lateral_thrust_multiplier = 0.35
		profiles.append(profile)

	var units: Array[TacticalUnit] = []
	var planning_start_usec: int = Time.get_ticks_usec()
	for index: int in unit_count:
		var unit := TacticalUnit.new()
		root.add_child(unit)
		var start_position := Vector2(float(index % 25) * 12.0, float(index / 25) * 12.0)
		unit.configure("LOAD-%03d" % index, 0, start_position, profiles[index % profiles.size()])
		unit.set_navigation_order(start_position + Vector2(800.0, 0.0))
		unit.set_process(false)
		unit.set_physics_process(false)
		units.append(unit)
	var planning_msec: float = float(Time.get_ticks_usec() - planning_start_usec) / 1000.0

	var simulation_start_usec: int = Time.get_ticks_usec()
	for tick: int in SIMULATED_TICKS:
		for unit: TacticalUnit in units:
			unit._physics_process(SIMULATION_DELTA)
	var simulation_msec: float = float(Time.get_ticks_usec() - simulation_start_usec) / 1000.0
	for unit: TacticalUnit in units:
		unit.free()
	return {
		"unit_count": unit_count,
		"planning_msec": planning_msec,
		"average_tick_msec": simulation_msec / float(SIMULATED_TICKS),
	}
