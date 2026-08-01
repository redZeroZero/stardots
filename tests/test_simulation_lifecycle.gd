extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var battlefield = load("res://scenes/main.tscn").instantiate()
	root.add_child(battlefield)
	battlefield.set_process(false)
	battlefield.set_physics_process(false)
	var failures: Array[String] = []

	if Engine.physics_ticks_per_second != SimulationClock.TICK_RATE:
		failures.append("le moteur physique n'est pas cadencé sur l'horloge de simulation à 20 Hz")

	var unit: TacticalUnit = battlefield.friendly_units[1]
	unit.cut_engines()
	unit.velocity = Vector2(60.0, 0.0)
	var position_at_victory: Vector2 = unit.global_position
	battlefield._end_match(0)
	var simulation_layers: Array[Node] = [
		battlefield.units_layer,
		battlefield.missiles_layer,
		battlefield.pdc_projectiles_layer,
		battlefield.stations_layer,
	]
	for layer: Node in simulation_layers:
		if layer.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("une couche de simulation reste active après la victoire: %s" % layer.name)
	if unit.can_process():
		failures.append("les unités peuvent encore recevoir des callbacks après la victoire")
	if not battlefield.simulation_clock.paused or not battlefield.match_over:
		failures.append("l'état de fin de partie n'est pas cohérent avec le gel de la simulation")
	await physics_frame
	await physics_frame
	if unit.global_position != position_at_victory:
		failures.append("une unité continue de dériver après la victoire")

	battlefield.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Cycle de simulation validé : cadence 20 Hz et gel complet à la victoire.")
	quit(0)
