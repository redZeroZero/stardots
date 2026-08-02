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
		_draw_friendly_symbol(_world_to_map(unit.global_position), unit.rotation)

	var enemy_units: Array = tactical_root.get("enemy_units")
	for unit in enemy_units:
		if not is_instance_valid(unit) or unit.destroyed or unit.intel_state == TacticalUnit.IntelState.HIDDEN:
			continue
		var contact_position: Vector2 = unit.global_position
		if unit.intel_state < TacticalUnit.IntelState.IDENTIFIED:
			contact_position += unit.contact_offset
		_draw_contact_symbol(_world_to_map(contact_position), unit.intel_state, unit.rotation)

	var missiles_layer: Node2D = tactical_root.get("missiles_layer")
	for missile in missiles_layer.get_children():
		if not is_instance_valid(missile) or not missile.is_interceptable():
			continue
		_draw_missile_symbol(
			_world_to_map(missile.global_position),
			missile.velocity.normalized(),
			missile.team_id != 0
		)

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


func _draw_friendly_symbol(center: Vector2, heading: float) -> void:
	var forward := Vector2.UP.rotated(heading)
	var side := forward.rotated(PI * 0.5)
	var points := PackedVector2Array([
		center + forward * 4.5,
		center - forward * 3.0 + side * 3.2,
		center - forward * 3.0 - side * 3.2,
	])
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0.01, 0.02, 0.035, 0.95), 3.5)
	draw_polyline(points + PackedVector2Array([points[0]]), Color("59d8ff"), 1.6)


func _draw_contact_symbol(center: Vector2, intel_state: int, heading: float) -> void:
	var halo := Color(0.01, 0.02, 0.035, 0.95)
	if intel_state == TacticalUnit.IntelState.SIGNAL:
		draw_arc(center, 4.0, -PI * 0.35, PI * 1.35, 12, halo, 3.5)
		draw_arc(center, 4.0, -PI * 0.35, PI * 1.35, 12, Color("ffbd48"), 1.6)
		draw_line(center + Vector2(-2.0, 0.0), center + Vector2(2.0, 0.0), Color("ffbd48"), 1.2)
		return
	if intel_state == TacticalUnit.IntelState.TRACKED:
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -4.0), center + Vector2(4.0, 0.0),
			center + Vector2(0.0, 4.0), center + Vector2(-4.0, 0.0),
		])
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), halo, 3.5)
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color("ff9f43"), 1.6)
		return
	var forward := Vector2.UP.rotated(heading)
	var side := forward.rotated(PI * 0.5)
	var triangle := PackedVector2Array([
		center + forward * 4.5,
		center - forward * 3.0 + side * 3.5,
		center - forward * 3.0 - side * 3.5,
	])
	draw_colored_polygon(PackedVector2Array([
		center + (triangle[0] - center) * 1.35,
		center + (triangle[1] - center) * 1.35,
		center + (triangle[2] - center) * 1.35,
	]), halo)
	draw_colored_polygon(triangle, Color("ff5d6c"))


func _draw_missile_symbol(center: Vector2, direction: Vector2, hostile: bool) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var missile_color := Color("ff784f") if hostile else Color("64ddff")
	var start: Vector2 = center - direction * 3.0
	var end: Vector2 = center + direction * (4.5 if hostile else 3.5)
	draw_line(start, end, Color(0.01, 0.02, 0.035, 0.95), 3.5)
	draw_line(start, end, missile_color, 1.8)
