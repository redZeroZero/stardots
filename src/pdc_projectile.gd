class_name PdcProjectile
extends Node2D

var team_id: int = 0
var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var hit_radius: float = 3.0
var lifetime_remaining: float = 0.0
var previous_position: Vector2


func launch(
	origin: Vector2,
	aim_point: Vector2,
	launcher_team_id: int,
	speed: float,
	lifetime: float,
	projectile_damage: float,
	projectile_hit_radius: float,
	dispersion_degrees: float
) -> void:
	global_position = origin
	previous_position = origin
	team_id = launcher_team_id
	damage = projectile_damage
	hit_radius = projectile_hit_radius
	lifetime_remaining = lifetime
	var direction: Vector2 = origin.direction_to(aim_point)
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	direction = direction.rotated(deg_to_rad(randf_range(-dispersion_degrees, dispersion_degrees)))
	velocity = direction * speed
	rotation = direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	previous_position = global_position
	global_position += velocity * delta
	lifetime_remaining -= delta

	for candidate in get_tree().get_nodes_in_group("active_missiles"):
		if not is_instance_valid(candidate) or candidate.team_id == team_id or not candidate.is_interceptable():
			continue
		var closest_point := Geometry2D.get_closest_point_to_segment(candidate.global_position, previous_position, global_position)
		if candidate.global_position.distance_to(closest_point) <= hit_radius:
			candidate.apply_point_defense_damage(damage)
			queue_free()
			return

	if lifetime_remaining <= 0.0:
		queue_free()


func _draw() -> void:
	draw_line(Vector2(-8.0, 0.0), Vector2(3.0, 0.0), Color(1.0, 0.83, 0.30, 0.32), 2.0)
	draw_circle(Vector2.ZERO, 1.8, Color("ffe28a"))
