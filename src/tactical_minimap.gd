class_name TacticalMinimap
extends Control

var tactical_root: Node
var world_rect: Rect2 = Rect2(-4096.0, -4096.0, 8192.0, 8192.0)
var camera_drag_button: MouseButton = MOUSE_BUTTON_NONE


func bind(root: Node, map_world_rect: Rect2) -> void:
	tactical_root = root
	world_rect = map_world_rect
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			camera_drag_button = event.button_index
			_move_camera_to_map_position(event.position)
		else:
			camera_drag_button = MOUSE_BUTTON_NONE
		accept_event()
	elif event is InputEventMouseMotion and camera_drag_button != MOUSE_BUTTON_NONE:
		_move_camera_to_map_position(event.position)
		accept_event()


func _move_camera_to_map_position(map_position: Vector2) -> void:
	if tactical_root == null:
		return
	var normalized := Vector2(
		clampf(map_position.x / size.x, 0.0, 1.0),
		clampf(map_position.y / size.y, 0.0, 1.0)
	)
	var world_position := world_rect.position + normalized * world_rect.size
	var camera: Camera2D = tactical_root.get("tactical_camera")
	camera.position = world_position
	tactical_root.call("_clamp_camera_to_world")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.055, 0.095, 0.96), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.30, 0.72, 0.92, 0.72), false, 1.5)
	if tactical_root == null:
		return

	var station = tactical_root.get("objective_station")
	if station != null:
		draw_circle(_world_to_map(station.global_position), 3.0, Color("d3dbe8"))

	var friendly_units: Array = tactical_root.get("friendly_units")
	for unit in friendly_units:
		if not is_instance_valid(unit) or unit.destroyed or not unit.selected:
			continue
		var center := _world_to_map(unit.global_position)
		draw_arc(center, _world_radius_to_map(unit.sensor_range), 0.0, TAU, 64, Color(0.35, 0.85, 1.0, 0.42), 1.0)
		if unit.sensor_mode == TacticalUnit.SensorMode.ACTIVE:
			draw_arc(center, _world_radius_to_map(unit.active_sensor_range), 0.0, TAU, 64, Color(1.0, 0.42, 0.88, 0.52), 1.0)
		if unit.unit_profile.provides_fire_control:
			draw_arc(center, _world_radius_to_map(unit.unit_profile.fire_control_share_range), 0.0, TAU, 64, Color(0.45, 1.0, 0.62, 0.58), 1.0)
		if unit.unit_profile.missile_launch_range > 0.0:
			draw_arc(center, _world_radius_to_map(unit.unit_profile.missile_launch_range), 0.0, TAU, 64, Color(1.0, 0.72, 0.30, 0.52), 1.0)
	for unit in friendly_units:
		if not is_instance_valid(unit) or unit.destroyed:
			continue
		draw_circle(_world_to_map(unit.global_position), 3.2, Color("59d8ff"))

	var enemy_units: Array = tactical_root.get("enemy_units")
	for unit in enemy_units:
		if not is_instance_valid(unit) or unit.destroyed or unit.intel_state == TacticalUnit.IntelState.HIDDEN:
			continue
		var contact_position: Vector2 = unit.global_position
		var contact_color := Color("ffbd48")
		var radius: float = 2.5
		if unit.intel_state == TacticalUnit.IntelState.SIGNAL:
			contact_position += unit.contact_offset
		elif unit.intel_state == TacticalUnit.IntelState.TRACKED:
			contact_color = Color("ff9f43")
			radius = 3.0
		else:
			contact_color = Color("ff5d6c")
			radius = 3.2
		draw_circle(_world_to_map(contact_position), radius, contact_color)

	var camera: Camera2D = tactical_root.get("tactical_camera")
	var visible_world_size: Vector2 = get_viewport_rect().size / camera.zoom
	var camera_world_rect := Rect2(camera.position - visible_world_size * 0.5, visible_world_size)
	var camera_map_rect := Rect2(
		_world_to_map(camera_world_rect.position),
		camera_world_rect.size / world_rect.size * size
	)
	draw_rect(camera_map_rect, Color(0.75, 0.94, 1.0, 0.85), false, 1.2)


func _world_to_map(world_position: Vector2) -> Vector2:
	var normalized: Vector2 = (world_position - world_rect.position) / world_rect.size
	return normalized * size


func _world_radius_to_map(world_radius: float) -> float:
	return world_radius / world_rect.size.x * size.x
