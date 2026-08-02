class_name TacticalOverlay
extends Node2D

var tactical_root


func bind(root: Node2D) -> void:
	tactical_root = root
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if tactical_root == null:
		return
	var zoom_value: float = tactical_root.tactical_camera.zoom.x
	if tactical_root.is_selecting:
		var selection_rect := Rect2(
			tactical_root.selection_start,
			tactical_root.selection_end - tactical_root.selection_start
		).abs()
		draw_rect(selection_rect, tactical_root.SELECTION_FILL, true)
		draw_rect(
			selection_rect,
			tactical_root.SELECTION_BORDER,
			false,
			TacticalPresentation.stroke_width(1.5, zoom_value)
		)
	if tactical_root.is_defining_move_order:
		_draw_move_order(zoom_value)
	if tactical_root.attack_zone_display_remaining > 0.0:
		_draw_attack_zone(zoom_value)


func _draw_move_order(zoom_value: float) -> void:
	var order_color := Color("8dffaf") if tactical_root.move_order_fly_through else Color("9bf0ff")
	var order_radius: float = TacticalPresentation.compensated_radius(7.0, 8.0, zoom_value)
	var order_stroke: float = TacticalPresentation.stroke_width(2.0, zoom_value)
	draw_circle(tactical_root.move_order_start, order_radius, Color(order_color, 0.18))
	draw_arc(
		tactical_root.move_order_start,
		order_radius,
		0.0,
		TAU,
		TacticalPresentation.circle_segments(order_radius, zoom_value),
		order_color,
		order_stroke
	)
	if tactical_root.move_order_end.distance_to(tactical_root.move_order_start) < 12.0 or tactical_root.move_order_fly_through:
		return
	draw_line(tactical_root.move_order_start, tactical_root.move_order_end, order_color, order_stroke)
	var direction: Vector2 = tactical_root.move_order_start.direction_to(tactical_root.move_order_end)
	var arrow_size: float = TacticalPresentation.world_size_for_screen_pixels(4.0, zoom_value)
	var arrow_base: Vector2 = tactical_root.move_order_end - direction * arrow_size * 2.0
	draw_line(tactical_root.move_order_end, arrow_base + direction.rotated(PI * 0.5) * arrow_size, order_color, order_stroke)
	draw_line(tactical_root.move_order_end, arrow_base - direction.rotated(PI * 0.5) * arrow_size, order_color, order_stroke)


func _draw_attack_zone(zoom_value: float) -> void:
	var attack_color := Color("8dffaf") if tactical_root.attack_zone_has_solution else Color("ffbd48")
	var alpha: float = tactical_root.attack_zone_display_remaining / tactical_root.ATTACK_ZONE_DISPLAY_DURATION
	var attack_radius: float = tactical_root.ATTACK_ZONE_RADIUS
	var center: Vector2 = tactical_root.attack_zone_center
	draw_circle(center, attack_radius, Color(attack_color, 0.05 * alpha))
	var attack_stroke: float = TacticalPresentation.stroke_width(2.0, zoom_value)
	draw_arc(
		center,
		attack_radius,
		0.0,
		TAU,
		TacticalPresentation.circle_segments(attack_radius, zoom_value),
		Color(attack_color, 0.85 * alpha),
		attack_stroke
	)
	var cross_radius: float = maxf(12.0, TacticalPresentation.world_size_for_screen_pixels(7.0, zoom_value))
	draw_line(center + Vector2(-cross_radius, 0.0), center + Vector2(cross_radius, 0.0), attack_color, attack_stroke)
	draw_line(center + Vector2(0.0, -cross_radius), center + Vector2(0.0, cross_radius), attack_color, attack_stroke)
