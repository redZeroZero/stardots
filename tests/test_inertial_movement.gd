extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile: UnitProfile = load("res://data/balance/default_unit.tres")
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("TEST", 0, Vector2.ZERO, profile)
	unit.set_move_target(Vector2(500.0, 0.0))

	var speed_after_half_second: float = 0.0
	var speed_after_two_seconds: float = 0.0
	var observed_maximum_speed: float = 0.0
	for frame: int in 180:
		unit._update_inertial_movement(1.0 / 60.0)
		observed_maximum_speed = maxf(observed_maximum_speed, unit.velocity.length())
		if frame == 30:
			speed_after_half_second = unit.velocity.length()
		elif frame == 120:
			speed_after_two_seconds = unit.velocity.length()

	var failures: Array[String] = []
	if speed_after_two_seconds <= speed_after_half_second:
		failures.append("le bâtiment n'accélère pas progressivement")
	if observed_maximum_speed > profile.tactical_speed_limit + 0.01:
		failures.append("la vitesse tactique maximale est dépassée")

	var velocity_before_reversal: Vector2 = unit.velocity
	var rotation_before_reversal: float = unit.rotation
	unit.set_move_target(Vector2(-200.0, 0.0))
	unit._update_inertial_movement(1.0 / 60.0)
	if unit.velocity.dot(velocity_before_reversal) <= 0.0:
		failures.append("la vélocité s'inverse instantanément")
	if absf(wrapf(unit.rotation - rotation_before_reversal, -PI, PI)) > 0.1:
		failures.append("la coque pivote instantanément")

	for frame: int in 1800:
		unit._physics_process(1.0 / 60.0)
		if not unit.has_move_target and not unit.is_orienting_to_final_heading:
			break
	if unit.has_move_target or unit.is_orienting_to_final_heading or unit.global_position.distance_to(Vector2(-200.0, 0.0)) > profile.arrival_radius:
		failures.append("le bâtiment ne s'immobilise pas à destination (position=%s vitesse=%.2f distance=%.2f)" % [
			unit.global_position, unit.velocity.length(), unit.global_position.distance_to(Vector2(-200.0, 0.0)),
		])

	var resting_heading: float = unit.rotation
	for frame: int in 300:
		unit._physics_process(1.0 / 60.0)
	if absf(wrapf(unit.rotation - resting_heading, -PI, PI)) > 0.001:
		failures.append("la coque ne conserve pas son orientation à l'arrêt")
	unit.set_move_target(unit.global_position)
	for frame: int in 60:
		unit._physics_process(1.0 / 60.0)
	if absf(wrapf(unit.rotation - resting_heading, -PI, PI)) > 0.001:
		failures.append("une correction nulle fait pivoter la coque")

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Cinématique inertielle validée : accélération, demi-tour, limite, arrêt et cap stable.")
	quit(0)
