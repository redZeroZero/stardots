class_name TacticalOverlay
extends Node2D

const EngagementEnvelopeLogic := preload("res://src/presentation/engagement_envelope.gd")
const ENVELOPE_REFRESH_INTERVAL: float = 0.20
const PASSIVE_SENSOR_FILL := Color(0.25, 0.82, 1.0, 0.014)
const PASSIVE_SENSOR_BORDER := Color(0.35, 0.85, 1.0, 0.58)
const ACTIVE_SENSOR_FILL := Color(1.0, 0.42, 0.88, 0.010)
const ACTIVE_SENSOR_BORDER := Color(1.0, 0.42, 0.88, 0.62)
const WEAPON_FILL := Color(1.0, 0.55, 0.22, 0.028)
const WEAPON_BORDER := Color(1.0, 0.68, 0.30, 0.72)
const FIRE_CONTROL_COLOR := Color(0.55, 1.0, 0.62, 0.92)

var tactical_root
var engagement_envelope = EngagementEnvelopeLogic.new()
var engagement_groups: Array[Dictionary] = []
var fire_control_target_ids: Dictionary = {}
var envelope_refresh_remaining: float = 0.0
var show_collective_weapon_envelope: bool = true
var show_collective_weapon_fill: bool = false
var show_collective_sensor_fill: bool = false


func bind(root: Node2D) -> void:
	tactical_root = root
	invalidate_engagement_envelope()
	queue_redraw()


func invalidate_engagement_envelope() -> void:
	envelope_refresh_remaining = 0.0


func _process(delta: float) -> void:
	envelope_refresh_remaining -= delta
	if envelope_refresh_remaining <= 0.0:
		envelope_refresh_remaining += ENVELOPE_REFRESH_INTERVAL
		_rebuild_engagement_groups()
	queue_redraw()


func _draw() -> void:
	if tactical_root == null:
		return
	var zoom_value: float = tactical_root.tactical_camera.zoom.x
	_draw_engagement_envelopes(zoom_value)
	_draw_fire_control_markers(zoom_value)
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
	if not tactical_root.active_fire_missions.is_empty():
		_draw_fire_missions(zoom_value)


func _rebuild_engagement_groups() -> void:
	engagement_groups.clear()
	fire_control_target_ids.clear()
	if tactical_root == null or tactical_root.range_debug_enabled:
		return
	for target in tactical_root.enemy_units:
		if (
			is_instance_valid(target)
			and not target.destroyed
			and target.intel_state >= TacticalUnit.IntelState.TRACKED
			and tactical_root.selected_group_has_fire_control_solution(target)
		):
			fire_control_target_ids[target.get_instance_id()] = true
	if tactical_root.selected_units.size() <= 1:
		return
	var units_by_group: Dictionary = {}
	for unit in tactical_root.selected_units:
		if not is_instance_valid(unit) or unit.destroyed:
			continue
		var group_id: int = tactical_root.get_engagement_group_id(unit)
		if not units_by_group.has(group_id):
			units_by_group[group_id] = []
		units_by_group[group_id].append(unit)
	for group_id: int in units_by_group:
		var group_units: Array = units_by_group[group_id]
		var sensor_units: Array = group_units.filter(
			func(unit): return tactical_root.unit_contributes_sensor_to_group(unit, group_id)
		)
		var passive_sensor_coverage: Dictionary = (
			engagement_envelope.build_passive_sensor_coverage(sensor_units)
		)
		var active_sensor_coverage: Dictionary = (
			engagement_envelope.build_active_sensor_coverage(sensor_units)
		)
		var weapon_coverage: Dictionary = engagement_envelope.build_weapon_coverage(
			group_units,
			tactical_root.is_weapon_system_selected_for_overlay
		)
		if (
			not passive_sensor_coverage.contours.is_empty()
			or not active_sensor_coverage.contours.is_empty()
			or not weapon_coverage.contours.is_empty()
		):
			engagement_groups.append({
				"group_id": group_id,
				"passive_sensor": passive_sensor_coverage,
				"active_sensor": active_sensor_coverage,
				"weapon": weapon_coverage,
			})


func _draw_engagement_envelopes(zoom_value: float) -> void:
	var sensor_width: float = TacticalPresentation.stroke_width(1.2, zoom_value)
	var weapon_width: float = TacticalPresentation.stroke_width(1.7, zoom_value)
	for group: Dictionary in engagement_groups:
		_draw_coverage(
			group.active_sensor,
			ACTIVE_SENSOR_FILL,
			ACTIVE_SENSOR_BORDER,
			sensor_width,
			show_collective_sensor_fill
		)
		_draw_coverage(
			group.passive_sensor,
			PASSIVE_SENSOR_FILL,
			PASSIVE_SENSOR_BORDER,
			sensor_width,
			show_collective_sensor_fill
		)
		if show_collective_weapon_envelope:
			_draw_coverage(
				group.weapon,
				WEAPON_FILL,
				WEAPON_BORDER,
				weapon_width,
				show_collective_weapon_fill
			)


func _draw_coverage(
	coverage: Dictionary,
	fill: Color,
	border: Color,
	width: float,
	draw_source_fill: bool = true
) -> void:
	# Les sources sont convexes et sûres à trianguler. Les unions booléennes,
	# parfois concaves, ne servent qu'au contour afin d'éviter les polygones invalides.
	if draw_source_fill:
		for source: PackedVector2Array in coverage.sources:
			if source.size() >= 3:
				draw_colored_polygon(source, fill)
	for contour: PackedVector2Array in coverage.contours:
		if contour.size() < 3:
			continue
		var closed_contour: PackedVector2Array = contour.duplicate()
		closed_contour.append(contour[0])
		draw_polyline(closed_contour, border, width, true)


func _draw_fire_control_markers(zoom_value: float) -> void:
	if tactical_root.selected_units.is_empty() or tactical_root.range_debug_enabled:
		return
	var corner_length: float = TacticalPresentation.world_size_for_screen_pixels(
		TacticalPresentation.FIRE_CONTROL_CORNER_LENGTH_PX,
		zoom_value
	)
	var width: float = TacticalPresentation.stroke_width(1.6, zoom_value)
	for target in tactical_root.enemy_units:
		if (
			not is_instance_valid(target)
			or target.destroyed
			or target.intel_state < TacticalUnit.IntelState.TRACKED
			or not has_fire_control_solution(target)
		):
			continue
		var center: Vector2 = tactical_root._get_contact_position(0, target)
		var extent_multiplier: float = (
			TacticalUnit.IDENTIFIED_SYMBOL_EXTENT_MULTIPLIER
			if target.intel_state == TacticalUnit.IntelState.IDENTIFIED
			else 1.0
		)
		var marker_radius: float = TacticalPresentation.fire_control_marker_radius(
			TacticalUnit.BODY_RADIUS,
			extent_multiplier,
			zoom_value
		)
		for diagonal: Vector2 in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
			var corner: Vector2 = center + diagonal * marker_radius
			draw_line(corner, corner - Vector2(diagonal.x, 0.0) * corner_length, FIRE_CONTROL_COLOR, width)
			draw_line(corner, corner - Vector2(0.0, diagonal.y) * corner_length, FIRE_CONTROL_COLOR, width)


func has_fire_control_solution(target) -> bool:
	return is_instance_valid(target) and fire_control_target_ids.has(target.get_instance_id())


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


func _draw_fire_missions(zoom_value: float) -> void:
	var attack_stroke: float = TacticalPresentation.stroke_width(2.0, zoom_value)
	var cross_radius: float = maxf(12.0, TacticalPresentation.world_size_for_screen_pixels(7.0, zoom_value))
	var font_size: int = maxi(8, roundi(10.0 / zoom_value))
	for mission: FireMission in tactical_root.active_fire_missions:
		var attack_color := Color("9bf0ff")
		var alpha: float = 1.0
		if mission.state == FireMission.State.BLOCKED:
			attack_color = Color("ffbd48")
		elif mission.state == FireMission.State.FIRED:
			attack_color = Color("8dffaf")
			alpha = mission.completion_display_remaining / tactical_root.ATTACK_ZONE_DISPLAY_DURATION
		draw_circle(mission.center, mission.radius, Color(attack_color, 0.035 * alpha))
		draw_arc(
			mission.center,
			mission.radius,
			0.0,
			TAU,
			TacticalPresentation.circle_segments(mission.radius, zoom_value),
			Color(attack_color, 0.82 * alpha),
			attack_stroke
		)
		draw_line(mission.center + Vector2(-cross_radius, 0.0), mission.center + Vector2(cross_radius, 0.0), Color(attack_color, alpha), attack_stroke)
		draw_line(mission.center + Vector2(0.0, -cross_radius), mission.center + Vector2(0.0, cross_radius), Color(attack_color, alpha), attack_stroke)
		draw_string(
			ThemeDB.fallback_font,
			mission.center + Vector2(-mission.radius, mission.radius + 14.0 / zoom_value),
			mission.status_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			mission.radius * 2.0,
			font_size,
			Color(attack_color, 0.92 * alpha)
		)
