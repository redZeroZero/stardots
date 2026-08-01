extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var profile: UnitProfile = load("res://data/balance/default_unit.tres")
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("ROUTE", 0, Vector2.ZERO, profile)
	unit.set_navigation_order(Vector2(220.0, 0.0))
	unit.set_navigation_order(Vector2(220.0, 220.0), false, true, PI, true)

	if unit.navigation_route.size() != 2:
		failures.append("le waypoint ajouté ne conserve pas la route")
	elif unit.navigation_route[0].passage_mode != NavigationWaypoint.PassageMode.FLY_THROUGH:
		failures.append("le point intermédiaire n'est pas traversé")
	elif absf(wrapf(unit.navigation_route[0].final_heading - PI, -PI, PI)) > 0.001:
		failures.append("le cap intermédiaire ne suit pas le segment suivant")
	elif unit.navigation_route[0].planned_speed >= profile.tactical_speed_limit:
		failures.append("un virage à angle droit ne réduit pas la vitesse planifiée")

	var reversal := TacticalUnit.new()
	root.add_child(reversal)
	reversal.configure("REVERSAL", 0, Vector2.ZERO, profile)
	reversal.set_navigation_order(Vector2(150.0, 0.0))
	reversal.set_navigation_order(Vector2.ZERO, false, true)
	if reversal.navigation_route[0].planned_speed > profile.station_keeping_speed:
		failures.append("un demi-tour ne prévoit pas une vitesse presque nulle")

	var crossing_speed: float = 0.0
	var previous_route_size: int = unit.navigation_route.size()
	for frame: int in 3600:
		unit._physics_process(1.0 / 60.0)
		if previous_route_size == 2 and unit.navigation_route.size() == 1:
			crossing_speed = unit.velocity.length()
		previous_route_size = unit.navigation_route.size()
		if unit.navigation_route.is_empty() and not unit.is_orienting_to_final_heading:
			break
	if crossing_speed <= profile.station_keeping_speed:
		failures.append("le bâtiment freine au waypoint intermédiaire")
	if unit.global_position.distance_to(Vector2(220.0, 220.0)) > profile.arrival_radius:
		failures.append("la route n'atteint pas son dernier point")
	if absf(wrapf(unit.rotation - PI, -PI, PI)) > deg_to_rad(0.6):
		failures.append("le cap final demandé n'est pas respecté")

	var flyby := TacticalUnit.new()
	root.add_child(flyby)
	flyby.configure("FLYBY", 0, Vector2.ZERO, profile)
	flyby.set_navigation_order(Vector2(180.0, 0.0), true)
	for frame: int in 1800:
		flyby._physics_process(1.0 / 60.0)
		if flyby.navigation_route.is_empty():
			break
	var flyby_position: Vector2 = flyby.global_position
	for frame: int in 60:
		flyby._physics_process(1.0 / 60.0)
	if flyby.velocity.length() <= profile.station_keeping_speed:
		failures.append("l'ordre traverser annule la vélocité")
	if flyby.global_position.distance_to(flyby_position) <= 1.0:
		failures.append("le bâtiment ne poursuit pas sa dérive après le point traversé")

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Navigation validée : waypoints, traversée, dérive et cap final.")
	quit(0)
