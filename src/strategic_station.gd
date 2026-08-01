class_name StrategicStation
extends Node2D

var team_id: int = -1
var capture_value: float = 0.0
var capture_radius: float = 86.0
var capture_time: float = 8.0
var sensor_range: float = 520.0


func configure(rules: MatchRules) -> void:
	capture_radius = rules.capture_radius
	capture_time = rules.capture_time
	sensor_range = rules.relay_sensor_range
	queue_redraw()


func update_capture(team_zero_present: bool, team_one_present: bool, delta: float) -> void:
	if team_zero_present == team_one_present:
		return

	var direction: float = 1.0 if team_zero_present else -1.0
	capture_value = clampf(capture_value + direction * delta / capture_time, -1.0, 1.0)

	if capture_value >= 1.0:
		team_id = 0
	elif capture_value <= -1.0:
		team_id = 1
	elif team_id == 0 and capture_value <= 0.0:
		team_id = -1
	elif team_id == 1 and capture_value >= 0.0:
		team_id = -1

	queue_redraw()


func _draw() -> void:
	var owner_color := Color("8b96a8")
	if team_id == 0:
		owner_color = Color("59d8ff")
	elif team_id == 1:
		owner_color = Color("ff5d6c")

	draw_circle(Vector2.ZERO, 28.0, Color(0.04, 0.08, 0.13, 0.95))
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 48, owner_color, 3.0)
	draw_line(Vector2(-15.0, 0.0), Vector2(15.0, 0.0), owner_color, 3.0)
	draw_line(Vector2(0.0, -15.0), Vector2(0.0, 15.0), owner_color, 3.0)
	draw_arc(Vector2.ZERO, capture_radius, 0.0, TAU, 72, Color(owner_color, 0.22), 1.0)

	var capture_color := Color("59d8ff") if capture_value >= 0.0 else Color("ff5d6c")
	var capture_angle: float = absf(capture_value) * TAU
	if capture_angle > 0.01:
		draw_arc(Vector2.ZERO, 35.0, -PI * 0.5, -PI * 0.5 + capture_angle, 48, capture_color, 4.0)

	if team_id >= 0:
		draw_arc(Vector2.ZERO, sensor_range, 0.0, TAU, 120, Color(owner_color, 0.10), 1.0)
