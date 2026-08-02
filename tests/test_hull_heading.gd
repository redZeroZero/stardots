extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var profile: UnitProfile = load("res://data/balance/default_unit.tres")
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("CAP-DROIT", 0, Vector2.ZERO, profile)
	unit.set_navigation_order(Vector2(800.0, 0.0))
	var route_heading: float = PI * 0.5
	var heading_was_aligned: bool = false
	var observed_braking: bool = false
	var previous_speed: float = 0.0
	for frame: int in 2400:
		unit._physics_process(1.0 / 60.0)
		var heading_error: float = absf(wrapf(unit.rotation - route_heading, -PI, PI))
		if heading_error <= deg_to_rad(0.5):
			heading_was_aligned = true
		if heading_was_aligned and heading_error > deg_to_rad(0.6):
			failures.append("la coque quitte le cap du segment pendant un trajet rectiligne")
			break
		if previous_speed > 70.0 and unit.velocity.length() < previous_speed - 0.05:
			observed_braking = true
			if heading_error > deg_to_rad(0.6):
				failures.append("le freinage fait pivoter la coque hors du cap de route")
				break
		previous_speed = unit.velocity.length()
		if not unit.has_move_target and not unit.is_orienting_to_final_heading:
			break
	if not heading_was_aligned or not observed_braking:
		failures.append("le scénario n'a pas couvert l'alignement et le freinage rectiligne")

	var routed := TacticalUnit.new()
	root.add_child(routed)
	routed.configure("CAP-ROUTE", 0, Vector2.ZERO, profile)
	routed.set_navigation_order(Vector2(220.0, 0.0))
	routed.set_navigation_order(Vector2(220.0, 220.0), false, true, PI, true)
	var previous_rotation: float = routed.rotation
	var accumulated_rotation: float = 0.0
	for frame: int in 3600:
		routed._physics_process(1.0 / 60.0)
		accumulated_rotation += absf(wrapf(routed.rotation - previous_rotation, -PI, PI))
		previous_rotation = routed.rotation
		if routed.navigation_route.is_empty() and not routed.is_orienting_to_final_heading:
			break
	if accumulated_rotation > deg_to_rad(220.0):
		failures.append("la coque oscille au lieu de suivre progressivement les segments de route (rotation cumulée %.1f°)" % rad_to_deg(accumulated_rotation))
	if absf(wrapf(routed.rotation - PI, -PI, PI)) > deg_to_rad(0.6):
		failures.append("la coque ne termine pas sur le cap final du dernier segment")

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Cap de coque validé : stable en ligne droite, au freinage et sur une route à waypoints.")
	quit(0)
