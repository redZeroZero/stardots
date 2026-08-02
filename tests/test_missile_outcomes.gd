extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var base_profile: MissileProfile = load("res://data/balance/default_missile.tres")

	var expiration_profile: MissileProfile = base_profile.duplicate(true)
	expiration_profile.maximum_lifetime = 0.01
	var expiration_target := Node2D.new()
	root.add_child(expiration_target)
	expiration_target.global_position = Vector2(1000.0, 0.0)
	var expiring_missile := TacticalMissile.new()
	root.add_child(expiring_missile)
	var expiration_detonations: Array[bool] = []
	var expiration_finished: Array[TacticalMissile] = []
	expiring_missile.detonated.connect(
		func(_position, _radius, _damage, intercepted, _team):
			expiration_detonations.append(intercepted)
	)
	expiring_missile.finished.connect(
		func(missile: TacticalMissile): expiration_finished.append(missile)
	)
	expiring_missile.launch(Vector2.ZERO, expiration_target, 0, expiration_profile)
	expiring_missile._physics_process(0.02)
	if not expiration_detonations.is_empty():
		failures.append("l'expiration naturelle est encore signalée comme une détonation ou une interception")
	if expiration_finished.size() != 1 or not expiring_missile.is_queued_for_deletion():
		failures.append("l'expiration naturelle ne termine pas proprement le missile")

	var stale_target := Node2D.new()
	root.add_child(stale_target)
	stale_target.global_position = Vector2(100.0, 0.0)
	var stale_missile := TacticalMissile.new()
	root.add_child(stale_missile)
	var stale_detonations: Array[bool] = []
	var stale_impacts: Array[Node2D] = []
	stale_missile.detonated.connect(
		func(_position, _radius, _damage, intercepted, _team):
			stale_detonations.append(intercepted)
	)
	stale_missile.impacted.connect(func(target: Node2D): stale_impacts.append(target))
	stale_missile.launch(Vector2.ZERO, stale_target, 0, base_profile)
	stale_missile.set_external_guidance(false)
	stale_target.global_position = Vector2(1000.0, 0.0)
	stale_missile.global_position = Vector2(97.5, 0.0)
	stale_missile.velocity = Vector2(45.0, 0.0)
	stale_missile._physics_process(0.01)
	if stale_detonations != [false]:
		failures.append("la dernière position connue ne produit pas la détonation attendue")
	if not stale_impacts.is_empty():
		failures.append("une détonation sur piste perdue est encore comptée comme un impact")

	var proximity_target := Node2D.new()
	root.add_child(proximity_target)
	proximity_target.global_position = Vector2(100.0, 0.0)
	var proximity_missile := TacticalMissile.new()
	root.add_child(proximity_missile)
	var proximity_impacts: Array[Node2D] = []
	proximity_missile.impacted.connect(func(target: Node2D): proximity_impacts.append(target))
	proximity_missile.launch(Vector2.ZERO, proximity_target, 0, base_profile)
	proximity_missile.global_position = Vector2(75.0, 0.0)
	proximity_missile.velocity = Vector2(45.0, 0.0)
	proximity_missile.distance_travelled = base_profile.warhead_arming_distance
	proximity_missile._physics_process(0.01)
	if proximity_impacts != [proximity_target]:
		failures.append("une détonation de proximité valide n'est plus comptée comme un impact")

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Issues missile validées : expiration, piste perdue et impact de proximité.")
	quit(0)
