extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile: MissileProfile = load("res://data/balance/default_missile.tres")
	var target := Node2D.new()
	root.add_child(target)
	target.global_position = Vector2(1000.0, 0.0)
	var missile := TacticalMissile.new()
	root.add_child(missile)
	missile.launch(Vector2.ZERO, target, 0, profile)
	var failures: Array[String] = []

	if absf(missile.velocity.length() - profile.launch_speed) > 0.01:
		failures.append("la vitesse de lancement n'est pas appliquée")
	for frame: int in 30:
		missile._physics_process(1.0 / 60.0)
	var approach_speed: float = missile.velocity.length()
	if approach_speed <= profile.launch_speed or approach_speed > profile.cruise_speed:
		failures.append("l'accélération d'approche ne respecte pas son profil")

	target.global_position = missile.global_position + Vector2(80.0, 0.0)
	missile._physics_process(1.0 / 60.0)
	if not missile.terminal_guidance or missile.velocity.length() <= approach_speed:
		failures.append("la phase terminale ne déclenche pas sa poussée supplémentaire")

	target.global_position = missile.global_position + Vector2(0.0, 80.0)
	var direction_before_turn: float = missile.velocity.angle()
	missile._physics_process(1.0 / 60.0)
	var observed_turn: float = absf(wrapf(missile.velocity.angle() - direction_before_turn, -PI, PI))
	var maximum_turn: float = deg_to_rad(profile.terminal_turn_rate_degrees) / 60.0
	if observed_turn <= 0.0 or observed_turn > maximum_turn + 0.0001:
		failures.append("la manœuvre terminale ne respecte pas sa vitesse de rotation")

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Missile validé : lancement, accélération d'approche, sprint et virage terminal.")
	quit(0)
