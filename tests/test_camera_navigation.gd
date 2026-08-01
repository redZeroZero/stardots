extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var battlefield = load("res://scenes/main.tscn").instantiate()
	root.add_child(battlefield)
	battlefield.set_process(false)
	var failures: Array[String] = []
	var camera: Camera2D = battlefield.tactical_camera
	var start_position: Vector2 = camera.position
	var screen_delta := Vector2(100.0, 50.0)
	battlefield._pan_camera_by_screen_delta(screen_delta)
	var expected_position: Vector2 = start_position - screen_delta / camera.zoom
	if camera.position.distance_to(expected_position) > 0.01:
		failures.append("le glisser de carte ne compense pas correctement le niveau de zoom")

	var minimap: TacticalMinimap = battlefield.tactical_minimap
	minimap._move_camera_to_map_position(minimap.size * 0.5)
	if camera.position.distance_to(Vector2.ZERO) > 0.01:
		failures.append("le centre de la minimap ne place pas la caméra au centre du théâtre")

	camera.position = Vector2(100000.0, 100000.0)
	battlefield._clamp_camera_to_world()
	if not battlefield.WORLD_RECT.has_point(camera.position):
		failures.append("la caméra peut sortir des limites opérationnelles")

	battlefield.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Caméra validée : glisser au zoom, navigation minimap et limites opérationnelles.")
	quit(0)
