class_name SensorPassBuffers
extends RefCounted

var best_active: PackedFloat64Array
var best_passive: PackedFloat64Array
var observer_counts: Array[int] = []
var triangulation_quality: Array[float] = []
var channels: PackedInt32Array
var first_observer_directions: Array[Vector2] = []
var best_sources: PackedInt64Array
var best_source_ratios: PackedFloat64Array
var signatures: PackedFloat64Array
var emissions: PackedFloat64Array
var passive_ranges_squared: PackedFloat64Array
var active_ranges_squared: PackedFloat64Array
var radio_ranges_squared: PackedFloat64Array
var search_radii: PackedFloat64Array
var group_observations: Dictionary = {}
var maximum_signature: float = 0.1
var maximum_emission: float = 0.0


func _init(size: int) -> void:
	best_active = _infinite_float_array(size)
	best_passive = _infinite_float_array(size)
	observer_counts.resize(size)
	observer_counts.fill(0)
	triangulation_quality.resize(size)
	triangulation_quality.fill(0.0)
	channels.resize(size)
	channels.fill(0)
	first_observer_directions.resize(size)
	first_observer_directions.fill(Vector2.ZERO)
	best_sources.resize(size)
	best_sources.fill(-1)
	best_source_ratios = _infinite_float_array(size)
	signatures.resize(size)
	emissions.resize(size)
	passive_ranges_squared.resize(size)
	active_ranges_squared.resize(size)
	radio_ranges_squared.resize(size)
	search_radii.resize(size)


func capture_target(index: int, target: TacticalUnit) -> void:
	var signature: float = target.get_passive_detection_signature()
	var emission: float = target.get_electromagnetic_signature()
	signatures[index] = signature
	emissions[index] = emission
	passive_ranges_squared[index] = target.sensor_range * target.sensor_range
	active_ranges_squared[index] = (
		target.active_sensor_range * target.active_sensor_range
		if target.sensor_mode == TacticalUnit.SensorMode.ACTIVE
		else 0.0
	)
	radio_ranges_squared[index] = (
		target.active_emission_detection_range * target.active_emission_detection_range
	)
	maximum_signature = maxf(maximum_signature, signature)
	maximum_emission = maxf(maximum_emission, emission)


func capture_search_radii(
	observers: Array[TacticalUnit],
	target_buffers: SensorPassBuffers
) -> void:
	var maximum_emission_radius_multiplier: float = sqrt(target_buffers.maximum_emission)
	for index: int in observers.size():
		var observer: TacticalUnit = observers[index]
		var radius: float = maxf(
			observer.sensor_range * target_buffers.maximum_signature,
			observer.active_emission_detection_range * maximum_emission_radius_multiplier
		)
		if observer.sensor_mode == TacticalUnit.SensorMode.ACTIVE:
			radius = maxf(radius, observer.active_sensor_range)
		search_radii[index] = radius


func _infinite_float_array(size: int) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	values.resize(size)
	values.fill(INF)
	return values
