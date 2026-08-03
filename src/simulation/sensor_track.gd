class_name SensorTrack
extends RefCounted

enum State {
	HIDDEN,
	SIGNAL,
	TRACKED,
	IDENTIFIED,
}

enum Channel {
	THERMAL = 1,
	RADIO = 2,
	ACTIVE_RADAR = 4,
	TRIANGULATED = 8,
}

const SIGNAL_CONFIDENCE: float = 0.30
const TRACKED_CONFIDENCE: float = 0.72
const IDENTIFIED_CONFIDENCE: float = 1.0
const SIGNAL_THRESHOLD: float = 0.12
const TRACKED_THRESHOLD: float = 0.55
const IDENTIFIED_THRESHOLD: float = 0.90
const CONFIDENCE_DECAY_PER_SECOND: float = 0.07
const MAXIMUM_UNCERTAINTY: float = 1400.0

var observer_team_id: int
var target: Node2D
var estimated_position: Vector2
var estimated_velocity: Vector2
var uncertainty_radius: float = MAXIMUM_UNCERTAINTY
var confidence: float = 0.0
var observation_floor: float = 0.0
var seconds_since_any_observation: float = INF
var seconds_since_kinematic_observation: float = INF
var assumed_target_acceleration: float = 20.0
var classification_locked: bool = false
var last_observation_channels: int = 0
var bearing_observer_count: int = 0
var triangulation_quality: float = 0.0
var last_observation_source_ids: Array[int] = []


func _init(new_observer_team_id: int, new_target: Node2D, target_acceleration: float) -> void:
	observer_team_id = new_observer_team_id
	target = new_target
	estimated_position = new_target.global_position
	assumed_target_acceleration = maxf(1.0, target_acceleration)


func begin_sensor_pass() -> void:
	observation_floor = 0.0


func observe(
	observed_state: State,
	observed_position: Vector2,
	observed_velocity: Vector2,
	base_uncertainty: float,
	observation_channels: int = 0,
	observer_count: int = 1,
	new_triangulation_quality: float = 0.0,
	observation_source_ids: Array = []
) -> void:
	var observation_confidence: float = _confidence_for_state(observed_state)
	observation_floor = maxf(observation_floor, observation_confidence)
	confidence = maxf(confidence, observation_confidence)
	seconds_since_any_observation = 0.0
	last_observation_channels = observation_channels
	bearing_observer_count = maxi(1, observer_count)
	triangulation_quality = clampf(new_triangulation_quality, 0.0, 1.0)
	last_observation_source_ids.assign(observation_source_ids)
	if observed_state >= State.TRACKED:
		estimated_position = observed_position
		estimated_velocity = observed_velocity
		uncertainty_radius = maxf(0.0, base_uncertainty)
		seconds_since_kinematic_observation = 0.0
	elif confidence <= SIGNAL_CONFIDENCE + 0.001:
		estimated_position = observed_position
		estimated_velocity = Vector2.ZERO
		uncertainty_radius = maxf(1.0, base_uncertainty)
		seconds_since_kinematic_observation = 0.0
	if observed_state == State.IDENTIFIED:
		classification_locked = true


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	seconds_since_any_observation += delta
	seconds_since_kinematic_observation += delta
	confidence = maxf(observation_floor, confidence - CONFIDENCE_DECAY_PER_SECOND * delta)
	estimated_position += estimated_velocity * delta
	var age: float = minf(seconds_since_kinematic_observation, 30.0)
	uncertainty_radius = minf(
		MAXIMUM_UNCERTAINTY,
		uncertainty_radius + assumed_target_acceleration * maxf(0.2, age) * delta
	)


func get_state() -> State:
	if confidence >= IDENTIFIED_THRESHOLD:
		return State.IDENTIFIED
	if confidence >= TRACKED_THRESHOLD:
		return State.TRACKED
	if confidence >= SIGNAL_THRESHOLD:
		return State.SIGNAL
	return State.HIDDEN


func has_fire_control_quality(maximum_uncertainty: float) -> bool:
	return get_state() >= State.TRACKED and uncertainty_radius <= maximum_uncertainty


func _confidence_for_state(state: State) -> float:
	match state:
		State.IDENTIFIED:
			return IDENTIFIED_CONFIDENCE
		State.TRACKED:
			return TRACKED_CONFIDENCE
		State.SIGNAL:
			return SIGNAL_CONFIDENCE
		_:
			return 0.0
