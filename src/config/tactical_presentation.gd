class_name TacticalPresentation
extends RefCounted

enum DetailLevel {
	STRATEGIC,
	TACTICAL,
	CLOSE,
}

const STRATEGIC_THRESHOLD: float = 0.28
const CLOSE_THRESHOLD: float = 0.65
const MINIMUM_UNIT_DIAMETER_PX: float = 8.0
const MINIMUM_SELECTION_DIAMETER_PX: float = 14.0
const MINIMUM_MISSILE_LENGTH_PX: float = 5.0
const MINIMUM_WAYPOINT_DIAMETER_PX: float = 6.0
const MINIMUM_CLICK_RADIUS_PX: float = 8.0
const MINIMUM_STROKE_PX: float = 1.0
const MAXIMUM_STROKE_PX: float = 3.0
const CLOSE_GRID_SPACING: float = 64.0
const TACTICAL_GRID_SPACING: float = 256.0
const STRATEGIC_GRID_SPACING: float = 1024.0
const CONTACT_PULSE_PERIOD: float = 1.5
const FIRE_CONTROL_MARKER_PADDING_PX: float = 4.0
const FIRE_CONTROL_CORNER_LENGTH_PX: float = 4.0


static func detail_level(zoom: float) -> DetailLevel:
	if zoom < STRATEGIC_THRESHOLD:
		return DetailLevel.STRATEGIC
	if zoom <= CLOSE_THRESHOLD:
		return DetailLevel.TACTICAL
	return DetailLevel.CLOSE


static func close_detail_alpha(zoom: float) -> float:
	return smoothstep(0.58, 0.72, zoom)


static func strategic_detail_alpha(zoom: float) -> float:
	return 1.0 - smoothstep(0.22, 0.34, zoom)


static func tactical_detail_alpha(zoom: float) -> float:
	return (1.0 - close_detail_alpha(zoom)) * (1.0 - strategic_detail_alpha(zoom))


static func world_size_for_screen_pixels(screen_pixels: float, zoom: float) -> float:
	return screen_pixels / maxf(zoom, 0.001)


static func compensated_radius(base_radius: float, minimum_diameter_px: float, zoom: float) -> float:
	return maxf(base_radius, world_size_for_screen_pixels(minimum_diameter_px * 0.5, zoom))


static func stroke_width(base_world_width: float, zoom: float, minimum_px: float = MINIMUM_STROKE_PX) -> float:
	var safe_zoom: float = maxf(zoom, 0.001)
	return clampf(base_world_width, minimum_px / safe_zoom, MAXIMUM_STROKE_PX / safe_zoom)


static func circle_segments(world_radius: float, zoom: float) -> int:
	var apparent_circumference: float = TAU * world_radius * maxf(zoom, 0.001)
	return clampi(ceili(apparent_circumference / 10.0), 16, 128)


static func contact_pulse_phase(elapsed_seconds: float, phase_offset: float = 0.0) -> float:
	return fposmod(elapsed_seconds / CONTACT_PULSE_PERIOD + phase_offset, 1.0)


static func contact_pulse_radius(minimum_radius: float, maximum_radius: float, phase: float) -> float:
	var safe_phase: float = clampf(phase, 0.0, 1.0)
	return lerpf(minimum_radius, maxf(minimum_radius, maximum_radius), smoothstep(0.0, 1.0, safe_phase))


static func contact_pulse_alpha(phase: float) -> float:
	return 1.0 - smoothstep(0.12, 1.0, clampf(phase, 0.0, 1.0))


static func fire_control_marker_radius(
	base_symbol_radius: float,
	extent_multiplier: float,
	zoom: float
) -> float:
	var symbol_radius: float = compensated_radius(
		base_symbol_radius,
		MINIMUM_UNIT_DIAMETER_PX,
		zoom
	)
	return (
		symbol_radius * maxf(1.0, extent_multiplier)
		+ world_size_for_screen_pixels(FIRE_CONTROL_MARKER_PADDING_PX, zoom)
	)


static func local_direction_for_world_heading(world_heading: float, node_rotation: float) -> Vector2:
	return Vector2.UP.rotated(world_heading - node_rotation)


static func available_label_rect(anchor: Vector2, label_size: Vector2, occupied: Array[Rect2]) -> Rect2:
	var candidates: Array[Vector2] = [
		Vector2(8.0, -label_size.y - 6.0),
		Vector2(8.0, 6.0),
		Vector2(-label_size.x - 8.0, -label_size.y - 6.0),
		Vector2(-label_size.x - 8.0, 6.0),
		Vector2(8.0, -label_size.y * 2.0 - 10.0),
		Vector2(8.0, label_size.y + 10.0),
	]
	for offset: Vector2 in candidates:
		var candidate := Rect2(anchor + offset, label_size)
		var overlaps: bool = false
		for existing: Rect2 in occupied:
			if candidate.grow(2.0).intersects(existing):
				overlaps = true
				break
		if not overlaps:
			return candidate
	return Rect2()


static func grid_alpha(grid_spacing: float, zoom: float) -> float:
	var strategic_fade: float = smoothstep(0.22, 0.34, zoom)
	var close_fade: float = smoothstep(0.55, 0.72, zoom)
	if is_equal_approx(grid_spacing, STRATEGIC_GRID_SPACING):
		return 1.0 - strategic_fade
	if is_equal_approx(grid_spacing, TACTICAL_GRID_SPACING):
		return strategic_fade * (1.0 - close_fade)
	if is_equal_approx(grid_spacing, CLOSE_GRID_SPACING):
		return close_fade
	return 0.0
