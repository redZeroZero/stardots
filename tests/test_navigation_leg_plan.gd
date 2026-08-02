extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var symmetric_plan := NavigationLegPlan.calculate(
		1000.0, 0.0, 1000.0, 0.0, 10.0, 10.0, 0.0, false
	)
	if absf(symmetric_plan.braking_distance - 500.0) > 0.1:
		failures.append("un trajet symétrique sans plafond ne commence pas son freinage à mi-distance")

	var angular_speed: float = deg_to_rad(100.0)
	var angular_acceleration: float = deg_to_rad(180.0)
	var turn_duration: float = NavigationLegPlan.half_turn_duration(angular_speed, angular_acceleration)
	var long_plan := NavigationLegPlan.calculate(
		2400.0, 0.0, 95.0, 0.0, 38.0, 38.0, turn_duration, true
	)
	if not is_equal_approx(long_plan.cruise_speed, 95.0):
		failures.append("le trajet long n'atteint pas sa vitesse de croisière")
	if long_plan.turn_start_remaining <= long_plan.braking_distance:
		failures.append("le retournement ne réserve pas le temps de rotation avant le freinage")
	if long_plan.turn_start_remaining >= 1200.0:
		failures.append("un trajet plafonné déclenche encore systématiquement le retournement à mi-distance")
	if long_plan.phase(long_plan.turn_start_remaining - 0.1, 95.0) != NavigationLegPlan.Phase.TURN:
		failures.append("le plan n'entre pas dans sa phase de retournement au seuil calculé")
	if long_plan.phase(long_plan.braking_distance - 0.1, 95.0) != NavigationLegPlan.Phase.BRAKE:
		failures.append("le plan n'entre pas dans sa phase de freinage au seuil calculé")

	var hybrid_plan := NavigationLegPlan.calculate(
		2400.0, 0.0, 95.0, 0.0, 38.0, 38.0, turn_duration, true, 11.4, 0.60
	)
	if hybrid_plan.pre_turn_braking_distance <= 0.0:
		failures.append("le plan hybride ne réserve pas de rétrofreinage avant son retournement")
	if hybrid_plan.turn_start_remaining >= long_plan.turn_start_remaining:
		failures.append("le plan hybride ne repousse pas le retournement par rapport au flip-and-burn")
	if hybrid_plan.phase(hybrid_plan.pre_turn_braking_start_remaining - 0.1, 95.0) != NavigationLegPlan.Phase.RETRO_BRAKE:
		failures.append("le plan hybride n'entre pas dans sa phase de rétrofreinage")
	if absf(hybrid_plan.pre_turn_braking_speed_limit(hybrid_plan.turn_start_remaining) - hybrid_plan.turn_speed) > 0.1:
		failures.append("le rétrofreinage hybride n'atteint pas la vitesse prévue au retournement")

	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	profile.propulsion_profile = null
	profile.propulsion_doctrine = UnitProfile.PropulsionDoctrine.FLIP_AND_BURN
	profile.retrograde_thrust_multiplier = 0.1
	profile.lateral_thrust_multiplier = 0.1
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("CACHE", 0, Vector2.ZERO, profile)
	unit.set_navigation_order(Vector2(2400.0, 0.0))
	var cached_plan: NavigationLegPlan = unit.active_leg_plan
	for frame: int in 300:
		unit._physics_process(1.0 / 60.0)
	if unit.active_leg_plan != cached_plan:
		failures.append("le plan de vol est recalculé pendant les ticks d'un même segment")
	unit.free()

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Plan de vol validé : profils symétrique/plafonné, avance du flip, phases et cache par segment.")
	quit(0)
