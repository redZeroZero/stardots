extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var base_profile: UnitProfile = load("res://data/balance/default_unit.tres")

	var hold_profile: UnitProfile = base_profile.duplicate(true)
	hold_profile.propulsion_profile = null
	hold_profile.propulsion_doctrine = UnitProfile.PropulsionDoctrine.HOLD_ATTITUDE
	var hold_result: Dictionary = _observe_straight_maneuver(hold_profile, "CAP")
	if hold_result["flipped"]:
		failures.append("la doctrine cap maintenu retourne la coque pendant le freinage")
	if float(hold_result["maximum_cruise_error"]) > deg_to_rad(0.7):
		failures.append("la doctrine cap maintenu ne stabilise pas la coque sur la route")

	var flip_profile: UnitProfile = base_profile.duplicate(true)
	flip_profile.propulsion_profile = null
	flip_profile.propulsion_doctrine = UnitProfile.PropulsionDoctrine.FLIP_AND_BURN
	flip_profile.retrograde_thrust_multiplier = 0.1
	flip_profile.lateral_thrust_multiplier = 0.1
	var flip_result: Dictionary = _observe_straight_maneuver(flip_profile, "FLIP")
	if not flip_result["flipped"]:
		failures.append("la doctrine flip-and-burn ne retourne pas la coque pour freiner")
	if int(flip_result["turn_reversals"]) > 4:
		failures.append("la doctrine flip-and-burn oscille au lieu d'exécuter des phases stables")

	var capable_hybrid: UnitProfile = base_profile.duplicate(true)
	capable_hybrid.propulsion_profile = null
	capable_hybrid.propulsion_doctrine = UnitProfile.PropulsionDoctrine.HYBRID
	capable_hybrid.retrograde_thrust_multiplier = 1.0
	capable_hybrid.lateral_thrust_multiplier = 1.0
	var capable_result: Dictionary = _observe_straight_maneuver(capable_hybrid, "HYBRIDE-FORT")
	if capable_result["flipped"]:
		failures.append("la doctrine hybride retourne une coque disposant d'une rétropropulsion suffisante")

	var limited_hybrid: UnitProfile = base_profile.duplicate(true)
	limited_hybrid.propulsion_profile = null
	limited_hybrid.propulsion_doctrine = UnitProfile.PropulsionDoctrine.HYBRID
	limited_hybrid.retrograde_thrust_multiplier = 0.15
	limited_hybrid.lateral_thrust_multiplier = 0.15
	var limited_result: Dictionary = _observe_straight_maneuver(limited_hybrid, "HYBRIDE-FAIBLE")
	if not limited_result["flipped"]:
		failures.append("la doctrine hybride n'utilise pas le moteur principal quand les propulseurs secondaires sont insuffisants")

	for result: Dictionary in [hold_result, flip_result, capable_result, limited_result]:
		if not result["completed"]:
			failures.append("la doctrine %s ne termine pas sa manœuvre" % result["name"])

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Propulsion validée : cap maintenu, flip-and-burn et hybride selon les capacités technologiques.")
	quit(0)


func _observe_straight_maneuver(profile: UnitProfile, test_name: String) -> Dictionary:
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure(test_name, 0, Vector2.ZERO, profile)
	unit.set_navigation_order(Vector2(800.0, 0.0))
	var route_heading: float = PI * 0.5
	var opposite_heading: float = -PI * 0.5
	var reached_cruise: bool = false
	var flipped: bool = false
	var maximum_cruise_error: float = 0.0
	var previous_rotation: float = unit.rotation
	var previous_turn_sign: float = 0.0
	var turn_reversals: int = 0
	for frame: int in 3600:
		unit._physics_process(1.0 / 60.0)
		if unit.velocity.length() >= profile.tactical_speed_limit * 0.90:
			reached_cruise = true
		if reached_cruise and unit.has_move_target:
			var route_error: float = absf(wrapf(unit.rotation - route_heading, -PI, PI))
			if unit.velocity.length() >= profile.tactical_speed_limit * 0.85:
				maximum_cruise_error = maxf(maximum_cruise_error, route_error)
			if absf(wrapf(unit.rotation - opposite_heading, -PI, PI)) <= deg_to_rad(12.0):
				flipped = true
		var rotation_delta: float = wrapf(unit.rotation - previous_rotation, -PI, PI)
		var turn_sign: float = signf(rotation_delta) if absf(rotation_delta) > deg_to_rad(0.02) else 0.0
		if turn_sign != 0.0 and previous_turn_sign != 0.0 and turn_sign != previous_turn_sign:
			turn_reversals += 1
		if turn_sign != 0.0:
			previous_turn_sign = turn_sign
		previous_rotation = unit.rotation
		if not unit.has_move_target and not unit.is_orienting_to_final_heading:
			break
	var result := {
		"name": test_name,
		"completed": not unit.has_move_target and not unit.is_orienting_to_final_heading,
		"flipped": flipped,
		"maximum_cruise_error": maximum_cruise_error,
		"turn_reversals": turn_reversals,
	}
	unit.free()
	return result
