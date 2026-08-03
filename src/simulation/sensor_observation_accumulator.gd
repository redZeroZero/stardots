class_name SensorObservationAccumulator
extends RefCounted

var target: TacticalUnit
var best_active_ratio_squared: float = INF
var best_passive_ratio_squared: float = INF
var channels: int = 0
var passive_observer_count: int = 0
var triangulation_quality: float = 0.0
var source_ids: Array[int] = []

var _first_bearing: Vector2 = Vector2.ZERO


func _init(new_target: TacticalUnit) -> void:
	target = new_target


func add_observation(
	source: TacticalUnit,
	active_ratio_squared: float,
	passive_ratio_squared: float,
	observation_channels: int
) -> void:
	best_active_ratio_squared = minf(best_active_ratio_squared, active_ratio_squared)
	best_passive_ratio_squared = minf(best_passive_ratio_squared, passive_ratio_squared)
	channels |= observation_channels
	var source_id: int = source.get_instance_id()
	if source_id not in source_ids:
		source_ids.append(source_id)
	if passive_ratio_squared > 1.0:
		return
	var bearing: Vector2 = source.global_position.direction_to(target.global_position)
	if passive_observer_count == 0:
		_first_bearing = bearing
	elif triangulation_quality < 0.999:
		triangulation_quality = maxf(
			triangulation_quality,
			clampf(absf(_first_bearing.cross(bearing)) * 2.0, 0.0, 1.0)
		)
	passive_observer_count += 1
