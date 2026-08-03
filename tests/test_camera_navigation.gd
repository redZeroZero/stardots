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

	battlefield._clear_selection()
	var selected_unit: TacticalUnit = battlefield.friendly_units[0]
	battlefield.selected_units.append(selected_unit)
	selected_unit.set_selected(true)
	var ctrl_right_press := InputEventMouseButton.new()
	ctrl_right_press.button_index = MOUSE_BUTTON_RIGHT
	ctrl_right_press.pressed = true
	ctrl_right_press.ctrl_pressed = true
	battlefield._handle_mouse_button(ctrl_right_press)
	if not battlefield.is_panning_camera or battlefield.is_defining_move_order:
		failures.append("Ctrl + clic droit ne donne pas priorité au déplacement de caméra avec une sélection")
	var ctrl_right_release := InputEventMouseButton.new()
	ctrl_right_release.button_index = MOUSE_BUTTON_RIGHT
	ctrl_right_release.pressed = false
	battlefield._handle_mouse_button(ctrl_right_release)
	if battlefield.is_panning_camera or selected_unit.has_move_target:
		failures.append("le déplacement caméra Ctrl + droit laisse un ordre de navigation parasite")

	var alt_right_press := InputEventMouseButton.new()
	alt_right_press.button_index = MOUSE_BUTTON_RIGHT
	alt_right_press.pressed = true
	alt_right_press.alt_pressed = true
	battlefield._handle_mouse_button(alt_right_press)
	if not battlefield.is_defining_move_order or not battlefield.move_order_fly_through:
		failures.append("Alt + clic droit ne reprend pas l'ordre traversant déplacé depuis Ctrl")
	battlefield.is_defining_move_order = false

	var mouse_screen_position: Vector2 = battlefield.get_viewport().get_mouse_position()
	var world_under_cursor: Vector2 = battlefield._world_position_under_screen(mouse_screen_position, camera.zoom.x, camera.position)
	battlefield._set_camera_zoom(camera.zoom.x * 1.12)
	battlefield._update_camera_zoom(1.0)
	var world_after_zoom: Vector2 = battlefield._world_position_under_screen(mouse_screen_position, camera.zoom.x, camera.position)
	if world_after_zoom.distance_to(world_under_cursor) > 0.01:
		failures.append("le zoom ne conserve pas le point du monde situé sous le curseur")

	battlefield._frame_friendly_units()
	var fleet_bounds := Rect2(battlefield.friendly_units[0].global_position, Vector2.ZERO)
	for unit: TacticalUnit in battlefield.friendly_units:
		fleet_bounds = fleet_bounds.expand(unit.global_position)
	if camera.position.distance_to(fleet_bounds.get_center()) > 0.01:
		failures.append("le cadrage de flotte ne centre pas les unités alliées vivantes")
	battlefield.selected_units.clear()
	battlefield.selected_units.append(battlefield.friendly_units[0])
	battlefield._focus_selected_units()
	if camera.position.distance_to(battlefield.friendly_units[0].global_position) > 0.01:
		failures.append("le retour à la sélection ne centre pas l'unité sélectionnée")

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
