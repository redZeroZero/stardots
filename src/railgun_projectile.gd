class_name RailgunProjectile
extends Node2D

var team_id: int = 0
var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var hit_radius: float = 5.0
var lifetime_remaining: float = 0.0
var previous_position: Vector2
var visual_zoom: float = 1.0


func launch(
	origin: Vector2,
	aim_point: Vector2,
	launcher_team_id: int,
	speed: float,
	maximum_range: float,
	projectile_damage: float
) -> void:
	global_position = origin
	previous_position = origin
	team_id = launcher_team_id
	damage = projectile_damage
	var direction: Vector2 = origin.direction_to(aim_point)
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	velocity = direction * speed
	lifetime_remaining = maximum_range / maxf(speed, 0.001)
	rotation = direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	previous_position = global_position
	global_position += velocity * delta
	lifetime_remaining -= delta
	for candidate in get_tree().get_nodes_in_group("tactical_units"):
		if not is_instance_valid(candidate) or candidate.team_id == team_id or candidate.destroyed:
			continue
		var closest_point := Geometry2D.get_closest_point_to_segment(
			candidate.global_position,
			previous_position,
			global_position
		)
		if candidate.global_position.distance_to(closest_point) <= hit_radius:
			candidate.apply_fragment_damage(damage)
			queue_free()
			return
	if lifetime_remaining <= 0.0:
		queue_free()


func set_visual_zoom(value: float) -> void:
	visual_zoom = maxf(value, 0.001)
	queue_redraw()


func _draw() -> void:
	if TacticalPresentation.detail_level(visual_zoom) == TacticalPresentation.DetailLevel.STRATEGIC:
		return
	var stroke: float = TacticalPresentation.stroke_width(2.2, visual_zoom)
	draw_line(Vector2(-15.0, 0.0), Vector2(2.0, 0.0), Color(0.70, 0.90, 1.0, 0.45), stroke)
	draw_circle(Vector2.ZERO, TacticalPresentation.compensated_radius(2.0, 2.5, visual_zoom), Color("d8f4ff"))
