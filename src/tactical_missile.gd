class_name TacticalMissile
extends Node2D

signal impacted(target: Node2D)
signal detonated(world_position: Vector2, fragment_radius: float, maximum_damage: float, intercepted: bool, missile_team_id: int)
signal finished(missile: TacticalMissile)

var target: Node2D
var team_id: int = 0
var profile: MissileProfile
var velocity: Vector2 = Vector2.ZERO
var last_known_position: Vector2
var integrity: float = 0.0
var lifetime: float = 0.0
var burst_time: float = 0.0
var guidance_lost: bool = false
var terminal_guidance: bool = false
var exploding: bool = false
var active_fragment_radius: float = 0.0
var external_guidance_available: bool = true
var visual_zoom: float = 1.0
var cruise_lane_offset: Vector2 = Vector2.ZERO
var distance_travelled: float = 0.0
var radiation_source_available: bool = false


func launch(
	origin: Vector2,
	new_target: Node2D,
	launcher_team_id: int,
	missile_profile: MissileProfile,
	initial_guidance_position: Vector2 = Vector2(INF, INF)
) -> void:
	global_position = origin
	target = new_target
	team_id = launcher_team_id
	profile = missile_profile
	add_to_group("active_missiles")
	integrity = profile.maximum_integrity
	active_fragment_radius = profile.fragment_radius
	last_known_position = (
		initial_guidance_position
		if initial_guidance_position.is_finite()
		else target.global_position
	)
	distance_travelled = 0.0
	_refresh_radiation_lock()
	var launch_direction: Vector2 = global_position.direction_to(last_known_position)
	velocity = launch_direction * profile.launch_speed
	rotation = launch_direction.angle() + PI * 0.5
	queue_redraw()


func set_cruise_lane_offset(offset: Vector2) -> void:
	cruise_lane_offset = offset


func _physics_process(delta: float) -> void:
	if exploding:
		burst_time += delta
		queue_redraw()
		if burst_time >= profile.explosion_duration:
			finished.emit(self)
			queue_free()
		return

	lifetime += delta
	if lifetime >= profile.maximum_lifetime:
		_finish_without_impact()
		return

	var target_is_valid: bool = is_instance_valid(target)
	if is_anti_radiation():
		_refresh_radiation_lock()
		guidance_lost = not radiation_source_available
	elif target_is_valid and external_guidance_available:
		guidance_lost = false
	else:
		guidance_lost = true

	var target_navigation_available: bool = (
		target_is_valid
		and (radiation_source_available if is_anti_radiation() else true)
	)
	var distance_to_target: float = (
		global_position.distance_to(target.global_position)
		if target_navigation_available
		else global_position.distance_to(last_known_position)
	)
	terminal_guidance = (
		target_navigation_available
		and distance_to_target <= profile.terminal_seeker_range + cruise_lane_offset.length()
	)
	var aim_point: Vector2 = last_known_position
	if terminal_guidance:
		aim_point = target.global_position
	elif is_anti_radiation() and radiation_source_available:
		aim_point = target.global_position + cruise_lane_offset
	elif not guidance_lost:
		aim_point += cruise_lane_offset
	var desired_direction := global_position.direction_to(aim_point)
	var current_direction := velocity.normalized() if velocity.length() > 0.01 else desired_direction
	var turn_rate_degrees: float = profile.terminal_turn_rate_degrees if terminal_guidance else profile.cruise_turn_rate_degrees
	var maximum_turn: float = deg_to_rad(turn_rate_degrees) * delta
	var direction_angle: float = rotate_toward(current_direction.angle(), desired_direction.angle(), maximum_turn)
	var direction := Vector2.from_angle(direction_angle)
	var target_speed: float = profile.terminal_speed if terminal_guidance else profile.cruise_speed
	var acceleration: float = profile.terminal_acceleration if terminal_guidance else profile.cruise_acceleration
	var new_speed: float = move_toward(velocity.length(), target_speed, acceleration * delta)
	velocity = direction * new_speed
	var movement: Vector2 = velocity * delta
	global_position += movement
	distance_travelled += movement.length()
	rotation = direction.angle() + PI * 0.5

	if (
		target_is_valid
		and distance_travelled >= profile.warhead_arming_distance
		and global_position.distance_to(target.global_position) <= profile.proximity_fuze_range
	):
		_detonate(false, true)
	elif global_position.distance_to(last_known_position) <= 3.0 and guidance_lost:
		_detonate(false)

	queue_redraw()


func is_interceptable() -> bool:
	return not exploding and integrity > 0.0


func is_anti_radiation() -> bool:
	return profile != null and profile.seeker_mode == MissileProfile.SeekerMode.ANTI_RADIATION


func has_radiation_lock() -> bool:
	return is_anti_radiation() and radiation_source_available


func is_warhead_armed() -> bool:
	return distance_travelled >= profile.warhead_arming_distance


func set_external_guidance(
	available: bool,
	guidance_position: Vector2 = Vector2(INF, INF)
) -> void:
	external_guidance_available = available
	if available and guidance_position.is_finite():
		last_known_position = guidance_position


func set_visual_zoom(value: float) -> void:
	var clamped_value: float = maxf(value, 0.001)
	if is_equal_approx(visual_zoom, clamped_value):
		return
	visual_zoom = clamped_value
	queue_redraw()


func _refresh_radiation_lock() -> void:
	radiation_source_available = false
	if not is_anti_radiation() or not is_instance_valid(target):
		return
	if not target.has_method("get_electromagnetic_signature"):
		return
	var electromagnetic_signature: float = float(target.get_electromagnetic_signature())
	if electromagnetic_signature < profile.minimum_radiation_signature:
		return
	var effective_range: float = profile.radiation_seeker_range * sqrt(electromagnetic_signature)
	if global_position.distance_squared_to(target.global_position) > effective_range * effective_range:
		return
	radiation_source_available = true
	last_known_position = target.global_position


func apply_point_defense_damage(amount: float) -> void:
	if not is_interceptable():
		return
	integrity -= amount
	if integrity <= 0.0:
		_detonate(true)


func _detonate(intercepted: bool, register_impact: bool = false) -> void:
	if exploding:
		return
	exploding = true
	active_fragment_radius = profile.intercepted_fragment_radius if intercepted else profile.fragment_radius
	var damage: float = profile.intercepted_maximum_damage if intercepted else profile.maximum_damage
	detonated.emit(global_position, active_fragment_radius, damage, intercepted, team_id)
	if register_impact and is_instance_valid(target):
		impacted.emit(target)
	queue_redraw()


func _finish_without_impact() -> void:
	finished.emit(self)
	queue_free()


func _draw() -> void:
	if exploding:
		var progress: float = burst_time / profile.explosion_duration
		draw_circle(
			Vector2.ZERO,
			lerpf(4.0, active_fragment_radius, progress),
			Color(1.0, 0.55, 0.20, (1.0 - progress) * 0.55)
		)
		return

	var guided_color := Color("64ddff") if team_id == 0 else Color("ff5d6c")
	var terminal_color := Color("b9ff66") if team_id == 0 else Color("ff9d4d")
	if is_anti_radiation():
		guided_color = Color("e66cff") if team_id == 0 else Color("ff4fbd")
		terminal_color = Color("fff06a")
	var missile_color := Color("ffbd48") if guidance_lost else guided_color
	if terminal_guidance:
		missile_color = terminal_color
	var detail_level := TacticalPresentation.detail_level(visual_zoom)
	var minimum_length_px: float = TacticalPresentation.MINIMUM_MISSILE_LENGTH_PX
	if team_id != 0 and detail_level != TacticalPresentation.DetailLevel.CLOSE:
		minimum_length_px = 7.0
	var body_length: float = maxf(12.0, TacticalPresentation.world_size_for_screen_pixels(minimum_length_px, visual_zoom))
	var body_half_width: float = maxf(4.0, TacticalPresentation.world_size_for_screen_pixels(2.0, visual_zoom))
	var trail_start: float = body_length
	var trail_end: float = body_length + maxf(13.0, TacticalPresentation.world_size_for_screen_pixels(5.0, visual_zoom))
	var stroke: float = TacticalPresentation.stroke_width(2.0, visual_zoom)
	var halo_stroke: float = stroke + TacticalPresentation.world_size_for_screen_pixels(2.0, visual_zoom)
	var halo_color := Color(0.015, 0.025, 0.04, 0.9)
	var missile_shape := PackedVector2Array([
		Vector2(0.0, -body_length * 0.58),
		Vector2(body_half_width, body_length * 0.42),
		Vector2(-body_half_width, body_length * 0.42),
	])
	draw_line(Vector2(0.0, trail_start), Vector2(0.0, trail_end), halo_color, halo_stroke)
	draw_line(Vector2(0.0, trail_start), Vector2(0.0, trail_end), Color(missile_color, 0.42), stroke)
	draw_colored_polygon(PackedVector2Array([
		missile_shape[0] * 1.28,
		missile_shape[1] * 1.28,
		missile_shape[2] * 1.28,
	]), halo_color)
	draw_colored_polygon(missile_shape, missile_color)
