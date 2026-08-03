class_name FireMission
extends RefCounted

enum State {
	WAITING,
	BLOCKED,
	FIRED,
}

var center: Vector2
var radius: float
var weapon_selection: int
var fire_doctrine: int
var assigned_units: Array = []
var state: State = State.WAITING
var status_text: String = "ATTENTE CONTACT"
var shots_fired: int = 0
var completion_display_remaining: float = 0.0


func configure(
	mission_center: Vector2,
	mission_radius: float,
	units: Array,
	selected_weapon: int,
	selected_doctrine: int
) -> void:
	center = mission_center
	radius = mission_radius
	assigned_units = units.duplicate()
	weapon_selection = selected_weapon
	fire_doctrine = selected_doctrine


func prune_units() -> void:
	assigned_units = assigned_units.filter(
		func(unit): return is_instance_valid(unit) and not unit.destroyed
	)


func remove_units(units: Array) -> void:
	assigned_units = assigned_units.filter(func(unit): return unit not in units)


func mark_waiting(text: String) -> void:
	state = State.WAITING
	status_text = text


func mark_blocked(text: String) -> void:
	state = State.BLOCKED
	status_text = text


func mark_fired(count: int, display_duration: float) -> void:
	state = State.FIRED
	shots_fired = count
	status_text = "SALVE %d TIR(S)" % count
	completion_display_remaining = display_duration
