class_name TacticalPilot
extends RefCounted

var profile: Resource


func _init(new_profile: Resource) -> void:
	profile = new_profile


func plan_engagement(unit: TacticalUnit, target: TacticalUnit) -> Dictionary:
	if unit == null or target == null or unit.destroyed or target.destroyed:
		return {}
	var system: WeaponSystemProfile = _select_offensive_system(unit)
	if system == null:
		return {}

	var distance: float = unit.global_position.distance_to(target.global_position)
	var usable_span: float = maxf(0.0, system.maximum_range - system.minimum_range)
	var preferred_range: float = system.minimum_range + usable_span * profile.preferred_range_ratio
	var range_band: float = maxf(profile.minimum_range_band, usable_span * profile.range_band_ratio)
	var too_close: bool = distance < maxf(system.minimum_range, preferred_range - range_band)
	var too_far: bool = distance > minf(system.maximum_range, preferred_range + range_band)

	var mount: WeaponMountProfile = system.mount_profile
	var fixed_directional_mount: bool = (
		mount != null
		and mount.arc_width_degrees < 359.9
		and not mount.traversable
	)
	var desired_heading: float = unit.rotation
	var target_direction: Vector2 = unit.global_position.direction_to(target.global_position)
	if fixed_directional_mount and target_direction != Vector2.ZERO:
		var desired_forward: Vector2 = target_direction.rotated(-deg_to_rad(mount.arc_center_degrees))
		desired_heading = desired_forward.angle() + PI * 0.5
	var target_in_arc: bool = unit.is_position_in_mount_arc(mount, target.global_position)
	var must_align_hull: bool = fixed_directional_mount and not target_in_arc

	var maneuver_point: Vector2 = unit.global_position
	if too_close or too_far:
		var outward_direction: Vector2 = target.global_position.direction_to(unit.global_position)
		if outward_direction == Vector2.ZERO:
			outward_direction = Vector2.RIGHT
		maneuver_point = target.global_position + outward_direction * preferred_range

	var saturation: bool = false
	if (
		profile.allow_total_saturation
		and system.family == WeaponSystemProfile.Family.MISSILE
		and system.feed_type == WeaponSystemProfile.FeedType.FIXED_CELLS
	):
		var saturation_floor: int = ceili(float(system.ammunition_capacity) * profile.fixed_cell_saturation_ratio)
		saturation = unit.get_weapon_system_ammunition(system) >= maxi(2, saturation_floor)

	return {
		"system": system,
		"maneuver_required": too_close or too_far or must_align_hull,
		"maneuver_point": maneuver_point,
		"desired_heading": desired_heading,
		"preferred_range": preferred_range,
		"should_fire": system.is_in_range(distance) and target_in_arc,
		"saturation": saturation,
	}


func _select_offensive_system(unit: TacticalUnit) -> WeaponSystemProfile:
	var railgun: WeaponSystemProfile = unit.get_weapon_system(
		WeaponSystemProfile.Family.RAILGUN,
		WeaponSystemProfile.TacticalRole.KINETIC_STRIKE
	)
	var missile: WeaponSystemProfile = unit.get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_SHIP
	)
	if profile.prefer_railgun and _has_ammunition(unit, railgun):
		return railgun
	if _has_ammunition(unit, missile):
		return missile
	if _has_ammunition(unit, railgun):
		return railgun
	return null


func _has_ammunition(unit: TacticalUnit, system: WeaponSystemProfile) -> bool:
	if system == null:
		return false
	if system.feed_type == WeaponSystemProfile.FeedType.ENERGY:
		return true
	if system.family == WeaponSystemProfile.Family.MISSILE and system.feed_type == WeaponSystemProfile.FeedType.MAGAZINE:
		return unit.get_anti_ship_burst_capacity() > 0
	return unit.get_weapon_system_ammunition(system) > 0
