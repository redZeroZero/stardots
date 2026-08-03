class_name SensorObservation
extends RefCounted

var source: TacticalUnit
var target: TacticalUnit
var active_ratio_squared: float
var passive_ratio_squared: float
var channels: int
var observer_position: Vector2


func _init(
	new_source: TacticalUnit,
	new_target: TacticalUnit,
	new_active_ratio_squared: float,
	new_passive_ratio_squared: float,
	new_channels: int
) -> void:
	source = new_source
	target = new_target
	active_ratio_squared = new_active_ratio_squared
	passive_ratio_squared = new_passive_ratio_squared
	channels = new_channels
	observer_position = new_source.global_position
