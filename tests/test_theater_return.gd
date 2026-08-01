extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var battlefield = load("res://scenes/main.tscn").instantiate()
	root.add_child(battlefield)
	battlefield.set_process(false)
	var unit: TacticalUnit = battlefield.friendly_units[1]
	var start_position := Vector2(battlefield.WORLD_RECT.end.x + 60.0, 500.0)
	unit.global_position = start_position
	unit.velocity = Vector2(70.0, 0.0)
	var initial_velocity: Vector2 = unit.velocity
	var failures: Array[String] = []

	battlefield._update_theater_bounds()
	var safe_rect: Rect2 = battlefield.WORLD_RECT.grow(-battlefield.THEATER_RETURN_MARGIN)
	if not unit.is_returning_to_theater or not unit.has_move_target:
		failures.append("la sortie du théâtre ne crée pas d'ordre de retour")
	if not safe_rect.has_point(unit.move_target):
		failures.append("le point de retour automatique n'est pas situé dans la zone sûre")
	if unit.global_position != start_position or unit.velocity != initial_velocity:
		failures.append("le retour automatique téléporte le bâtiment ou annule son inertie")

	for frame: int in 2400:
		unit._physics_process(1.0 / 60.0)
		battlefield._update_theater_bounds()
		if not unit.is_returning_to_theater:
			break
	if unit.is_returning_to_theater or not safe_rect.has_point(unit.global_position):
		failures.append("le calculateur ne ramène pas le bâtiment dans le théâtre")

	battlefield.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Limite opérationnelle validée : retour inertiel automatique sans téléportation.")
	quit(0)
