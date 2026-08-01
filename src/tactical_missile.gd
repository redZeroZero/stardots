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


func launch(origin: Vector2, new_target: Node2D, launcher_team_id: int, missile_profile: MissileProfile) -> void:
	global_position = origin
	target = new_target
	team_id = launcher_team_id
	profile = missile_profile
	add_to_group("active_missiles")
	integrity = profile.maximum_integrity
	active_fragment_radius = profile.fragment_radius
	last_known_position = target.global_position
	var launch_direction: Vector2 = global_position.direction_to(last_known_position)
	velocity = launch_direction * profile.launch_speed
	rotation = launch_direction.angle() + PI * 0.5
	queue_redraw()


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
		_detonate(true)
		return

	var target_is_valid := is_instance_valid(target)
	if target_is_valid and external_guidance_available:
		last_known_position = target.global_position
		guidance_lost = false
	else:
		guidance_lost = true

	terminal_guidance = (
		target_is_valid
		and global_position.distance_to(target.global_position) <= profile.terminal_seeker_range
	)
	var aim_point: Vector2 = target.global_position if terminal_guidance else last_known_position
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
	global_position += velocity * delta
	rotation = direction.angle() + PI * 0.5

	if target_is_valid and global_position.distance_to(target.global_position) <= profile.proximity_fuze_range:
		_detonate(false)
	elif global_position.distance_to(last_known_position) <= 3.0 and guidance_lost:
		_detonate(false)

	queue_redraw()


func is_interceptable() -> bool:
	return not exploding and integrity > 0.0


func set_external_guidance(available: bool) -> void:
	external_guidance_available = available


func apply_point_defense_damage(amount: float) -> void:
	if not is_interceptable():
		return
	integrity -= amount
	if integrity <= 0.0:
		_detonate(true)


func _detonate(intercepted: bool) -> void:
	if exploding:
		return
	exploding = true
	active_fragment_radius = profile.intercepted_fragment_radius if intercepted else profile.fragment_radius
	var damage: float = profile.intercepted_maximum_damage if intercepted else profile.maximum_damage
	detonated.emit(global_position, active_fragment_radius, damage, intercepted, team_id)
	if not intercepted and is_instance_valid(target):
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
	var missile_color := Color("ffbd48") if guidance_lost else guided_color
	if terminal_guidance:
		missile_color = terminal_color
	draw_line(Vector2(0.0, 12.0), Vector2(0.0, 25.0), Color(missile_color, 0.28), 2.0)
	draw_colored_polygon(
		PackedVector2Array([Vector2(0.0, -7.0), Vector2(4.0, 5.0), Vector2(-4.0, 5.0)]),
		missile_color
	)
