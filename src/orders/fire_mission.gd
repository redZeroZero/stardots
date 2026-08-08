class_name FireMission
extends RefCounted

enum State {
	WAITING,
	BLOCKED,
	FIRED,
}

enum BlockReason {
	NONE,
	NO_CONTACT,
	INSUFFICIENT_TRACK,
	OUT_OF_LINK,
	OUT_OF_RANGE,
	OUT_OF_ARC,
	AIMING,
	RELOADING,
	OVERHEATED,
	NO_AMMUNITION,
	NO_COMPATIBLE_WEAPON,
	NO_RADIO_EMISSION,
	FIRE_CONTROL_UNAVAILABLE,
}

var center: Vector2
var radius: float
var weapon_selection: int
var fire_doctrine: int
var assigned_units: Array = []
var state: State = State.WAITING
var block_reason: BlockReason = BlockReason.NONE
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


func mark_waiting(text: String, reason: BlockReason = BlockReason.NO_CONTACT) -> void:
	state = State.WAITING
	block_reason = reason
	status_text = text


func mark_blocked(reason: BlockReason, text: String) -> void:
	state = State.BLOCKED
	block_reason = reason
	status_text = text


func mark_fired(count: int, display_duration: float) -> void:
	state = State.FIRED
	block_reason = BlockReason.NONE
	shots_fired = count
	status_text = "SALVE %d TIR(S)" % count
	completion_display_remaining = display_duration
