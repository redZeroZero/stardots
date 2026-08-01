extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var missile_profile: MissileProfile = load("res://data/balance/default_missile.tres")
	var missile := TacticalMissile.new()
	root.add_child(missile)
	missile.profile = missile_profile
	missile.team_id = 1
	missile.integrity = missile_profile.maximum_integrity
	missile.global_position = Vector2(40.0, 0.0)
	missile.add_to_group("active_missiles")

	var projectile := PdcProjectile.new()
	root.add_child(projectile)
	projectile.launch(Vector2.ZERO, Vector2(100.0, 0.0), 0, 100.0, 1.0, 9.0, 4.0, 0.0)
	for frame: int in 30:
		projectile._physics_process(1.0 / 60.0)
		if projectile.is_queued_for_deletion():
			break

	var failures: Array[String] = []
	if not projectile.is_queued_for_deletion():
		failures.append("la rafale ne rencontre pas le missile sur sa trajectoire")
	if absf(missile.integrity - (missile_profile.maximum_integrity - 9.0)) > 0.01:
		failures.append("la collision cinétique n'applique pas les dégâts prévus")

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("PDC cinétique validé : trajectoire persistante, collision et dégâts.")
	quit(0)
