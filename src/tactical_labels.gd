class_name TacticalLabels
extends Node2D

const LABEL_FONT_SIZE_PX: int = 10
const LABEL_PADDING_PX: float = 2.0
const MAXIMUM_HOSTILE_LABELS: int = 96

var tactical_root


func bind(root: Node2D) -> void:
	tactical_root = root
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if tactical_root == null:
		return
	var camera: Camera2D = tactical_root.tactical_camera
	var zoom_value: float = camera.zoom.x
	var candidates: Array[Dictionary] = []
	for unit: TacticalUnit in tactical_root.selected_units:
		if is_instance_valid(unit) and not unit.destroyed:
			candidates.append({
				"unit": unit,
				"text": unit.callsign,
				"anchor": unit.global_position,
				"alpha": 1.0,
				"color": Color(0.88, 0.96, 1.0),
				"required": true,
			})
	var strategic_alpha: float = TacticalPresentation.strategic_detail_alpha(zoom_value)
	var hostile_label_count: int = 0
	for priority_state: int in [
		TacticalUnit.IntelState.IDENTIFIED,
		TacticalUnit.IntelState.TRACKED,
		TacticalUnit.IntelState.SIGNAL,
	]:
		for unit: TacticalUnit in tactical_root.enemy_units:
			if hostile_label_count >= MAXIMUM_HOSTILE_LABELS:
				break
			if (
				not is_instance_valid(unit)
				or unit.destroyed
				or unit.intel_state != priority_state
			):
				continue
			var anchor_world: Vector2 = unit.global_position
			if unit.intel_state < TacticalUnit.IntelState.IDENTIFIED:
				anchor_world += unit.contact_offset
			if not get_viewport_rect().grow(32.0).has_point(_world_to_screen(anchor_world, camera)):
				continue
			candidates.append({
				"unit": unit,
				"text": unit.get_contact_label(),
				"anchor": anchor_world,
				"alpha": maxf(0.72, strategic_alpha),
				"color": Color("ffbd48"),
				"required": false,
			})
			hostile_label_count += 1

	var occupied: Array[Rect2] = []
	for candidate: Dictionary in candidates:
		var unit: TacticalUnit = candidate["unit"]
		var label_text: String = candidate["text"]
		var anchor_screen: Vector2 = _world_to_screen(candidate["anchor"], camera)
		if not get_viewport_rect().grow(32.0).has_point(anchor_screen):
			continue
		var text_size: Vector2 = ThemeDB.fallback_font.get_string_size(
			label_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			LABEL_FONT_SIZE_PX
		)
		var box_size := text_size + Vector2.ONE * LABEL_PADDING_PX * 2.0
		var label_rect: Rect2 = TacticalPresentation.available_label_rect(anchor_screen, box_size, occupied)
		if label_rect.size == Vector2.ZERO:
			if not candidate["required"]:
				continue
			label_rect = Rect2(anchor_screen + Vector2(8.0, 6.0 + occupied.size() * (box_size.y + 4.0)), box_size)
		occupied.append(label_rect)
		_draw_screen_label(
			label_text,
			label_rect,
			float(candidate["alpha"]),
			candidate["color"],
			camera
		)


func _draw_screen_label(
	text: String,
	screen_rect: Rect2,
	alpha: float,
	text_color: Color,
	camera: Camera2D
) -> void:
	var zoom_value: float = camera.zoom.x
	var world_rect := Rect2(
		_screen_to_world(screen_rect.position, camera),
		screen_rect.size / zoom_value
	)
	draw_rect(world_rect, Color(0.015, 0.025, 0.04, 0.78 * alpha), true)
	var font_size_world: int = maxi(8, roundi(float(LABEL_FONT_SIZE_PX) / zoom_value))
	var baseline_screen := screen_rect.position + Vector2(
		LABEL_PADDING_PX,
		LABEL_PADDING_PX + ThemeDB.fallback_font.get_ascent(LABEL_FONT_SIZE_PX)
	)
	draw_string(
		ThemeDB.fallback_font,
		_screen_to_world(baseline_screen, camera),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size_world,
		Color(text_color, 0.92 * alpha)
	)


func _world_to_screen(world_position: Vector2, camera: Camera2D) -> Vector2:
	return get_viewport_rect().size * 0.5 + (world_position - camera.position) * camera.zoom


func _screen_to_world(screen_position: Vector2, camera: Camera2D) -> Vector2:
	return camera.position + (screen_position - get_viewport_rect().size * 0.5) / camera.zoom
