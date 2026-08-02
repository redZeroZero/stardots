extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var start_usec: int = Time.get_ticks_usec()
	var unit_profile: UnitProfile = load("res://data/balance/default_unit.tres")
	var missile_profile: MissileProfile = load("res://data/balance/default_missile.tres")
	var units: Array[TacticalUnit] = []

	for index: int in 160:
		var unit := TacticalUnit.new()
		root.add_child(unit)
		unit.configure(
			"LOAD-%03d" % index,
			index % 2,
			Vector2(float(index % 20) * 90.0, float(index / 20) * 90.0),
			unit_profile
		)
		if unit.team_id != 0:
			unit.set_intel_state(1 + index % 3, Vector2(12.0, -8.0))
		unit.set_selected(index % 24 == 0)
		unit.set_visual_zoom([0.15, 0.42, 1.0][index % 3])
		unit.set_process(false)
		unit.set_physics_process(false)
		units.append(unit)

	for index: int in 80:
		var missile := TacticalMissile.new()
		root.add_child(missile)
		missile.launch(
			Vector2(float(index % 20) * 70.0, float(index / 20) * 110.0),
			units[index % units.size()],
			index % 2,
			missile_profile
		)
		missile.set_visual_zoom(0.15 if index % 2 == 0 else 0.42)
		missile.set_physics_process(false)

	await process_frame
	await process_frame
	var elapsed_msec: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	if root.get_child_count() < 240:
		failures.append("la scène de charge n'a pas créé tous ses éléments tactiques")
	if elapsed_msec > 2000.0:
		failures.append("le rafraîchissement de 160 unités et 80 missiles dépasse 2 secondes")

	for child in root.get_children():
		child.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Charge visuelle validée : 160 unités et 80 missiles en %.1f ms." % elapsed_msec)
	quit(0)
