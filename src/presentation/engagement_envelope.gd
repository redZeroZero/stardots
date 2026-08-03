class_name EngagementEnvelope
extends RefCounted

const EXACT_UNIT_LIMIT: int = 32
const MINIMUM_SEGMENTS: int = 8
const MAXIMUM_SEGMENTS: int = 48
const TARGET_SEGMENT_LENGTH: float = 85.0


func build_weapon_coverage(units: Array, system_filter: Callable) -> Dictionary:
	var valid_units: Array = units.filter(
		func(unit): return is_instance_valid(unit) and not unit.destroyed
	)
	if valid_units.is_empty():
		return _empty_result()
	var sectors: Array[PackedVector2Array] = []
	for unit in valid_units:
		sectors.append_array(_build_unit_weapon_sectors(unit, system_filter))
	return _build_result(valid_units.size(), sectors)


func build_sensor_coverage(units: Array) -> Dictionary:
	var valid_units: Array = units.filter(
		func(unit): return is_instance_valid(unit) and not unit.destroyed
	)
	var sectors: Array[PackedVector2Array] = []
	for unit in valid_units:
		var nominal_range: float = (
			unit.active_sensor_range
			if unit.sensor_mode == TacticalUnit.SensorMode.ACTIVE
			else unit.sensor_range
		)
		if nominal_range > 0.0:
			sectors.append(_build_sector(unit, nominal_range, null))
	return _build_result(valid_units.size(), sectors)


func _build_unit_weapon_sectors(unit, system_filter: Callable) -> Array[PackedVector2Array]:
	var sectors: Array[PackedVector2Array] = []
	if unit.weapon_system_profiles.is_empty():
		if not system_filter.call(null):
			return sectors
		var fallback_range: float = maxf(
			unit.unit_profile.missile_launch_range if unit.missiles_remaining > 0 else 0.0,
			0.0
		)
		if fallback_range > 0.0:
			sectors.append(_build_sector(unit, fallback_range, null))
		return sectors
	for system: WeaponSystemProfile in unit.weapon_system_profiles:
		if system == null or system.maximum_range <= 0.0 or not system_filter.call(system):
			continue
		if (
			system.feed_type != WeaponSystemProfile.FeedType.ENERGY
			and unit.get_weapon_system_ammunition(system) <= 0
		):
			continue
		sectors.append(_build_sector(unit, system.maximum_range, system.mount_profile))
	return sectors


func _build_result(unit_count: int, source_polygons: Array[PackedVector2Array]) -> Dictionary:
	if source_polygons.is_empty():
		return _empty_result()
	var contours: Array[PackedVector2Array]
	if unit_count > EXACT_UNIT_LIMIT:
		contours = [_build_strategic_hull(source_polygons)]
	else:
		contours = _merge_overlapping_polygons(source_polygons)
	return {"sources": source_polygons, "contours": contours}


func _empty_result() -> Dictionary:
	return {"sources": [], "contours": []}


func _build_sector(unit, maximum_range: float, mount: WeaponMountProfile) -> PackedVector2Array:
	var arc_width: float = TAU
	var arc_center: float = -PI * 0.5
	if mount != null and mount.arc_width_degrees < 359.9:
		arc_width = deg_to_rad(mount.arc_width_degrees)
		arc_center += deg_to_rad(mount.arc_center_degrees)
	var segment_count: int = clampi(
		ceili(maximum_range * arc_width / TARGET_SEGMENT_LENGTH),
		MINIMUM_SEGMENTS,
		MAXIMUM_SEGMENTS
	)
	var points := PackedVector2Array()
	var is_full_circle: bool = arc_width >= TAU - 0.01
	if not is_full_circle:
		points.append(unit.global_position)
	var point_count: int = segment_count if is_full_circle else segment_count + 1
	for segment_index: int in point_count:
		var ratio: float = float(segment_index) / float(segment_count)
		var angle: float = unit.rotation + arc_center - arc_width * 0.5 + arc_width * ratio
		points.append(unit.global_position + Vector2.from_angle(angle) * maximum_range)
	return points


func _merge_overlapping_polygons(source_polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var merged: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in source_polygons:
		var pending: PackedVector2Array = polygon
		var index: int = 0
		while index < merged.size():
			if Geometry2D.intersect_polygons(merged[index], pending).is_empty():
				index += 1
				continue
			var union: Array[PackedVector2Array] = Geometry2D.merge_polygons(merged[index], pending)
			if union.size() != 1:
				index += 1
				continue
			pending = union[0]
			merged.remove_at(index)
			index = 0
		merged.append(pending)
	return merged


func _build_strategic_hull(polygons: Array[PackedVector2Array]) -> PackedVector2Array:
	var all_points := PackedVector2Array()
	for polygon: PackedVector2Array in polygons:
		all_points.append_array(polygon)
	return Geometry2D.convex_hull(all_points)
