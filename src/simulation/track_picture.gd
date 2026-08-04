class_name TrackPicture
extends RefCounted

const FIRE_CONTROL_MAXIMUM_UNCERTAINTY: float = 45.0

var tracks: Dictionary = {}
var observer_team_id: int


func _init(new_observer_team_id: int = -1) -> void:
	observer_team_id = new_observer_team_id


func begin_sensor_pass() -> void:
	for track in tracks.values():
		track.begin_sensor_pass()


func observe_target(target: TacticalUnit, observations: Array[SensorObservation]) -> void:
	if observations.is_empty() or target.destroyed:
		return
	var accumulator := SensorObservationAccumulator.new(target)
	for observation: SensorObservation in observations:
		accumulator.add_observation(
			observation.source,
			observation.active_ratio_squared,
			observation.passive_ratio_squared,
			observation.channels
		)
	observe_accumulator(accumulator)


func observe_accumulator(accumulator: SensorObservationAccumulator) -> void:
	var target: TacticalUnit = accumulator.target
	if target == null or target.destroyed:
		return
	var best_active: float = accumulator.best_active_ratio_squared
	var best_passive: float = accumulator.best_passive_ratio_squared
	var channels: int = accumulator.channels

	var observed_state: int = SensorTrack.State.HIDDEN
	var uncertainty: float = SensorTrack.MAXIMUM_UNCERTAINTY
	if best_active <= 0.36 * 0.36:
		observed_state = SensorTrack.State.IDENTIFIED
		uncertainty = 2.0
		channels |= SensorTrack.Channel.ACTIVE_RADAR
	elif best_active <= 0.68 * 0.68:
		observed_state = SensorTrack.State.TRACKED
		uncertainty = 14.0
		channels |= SensorTrack.Channel.ACTIVE_RADAR
	elif best_active <= 1.0:
		observed_state = SensorTrack.State.SIGNAL
		uncertainty = 90.0
		channels |= SensorTrack.Channel.ACTIVE_RADAR

	var triangulation_quality: float = accumulator.triangulation_quality
	var triangulated: bool = (
		accumulator.passive_observer_count >= 2
		and triangulation_quality >= 0.08
	)
	var passive_state: int = SensorTrack.State.HIDDEN
	var passive_uncertainty: float = SensorTrack.MAXIMUM_UNCERTAINTY
	if bool(channels & SensorTrack.Channel.THERMAL):
		passive_state = SensorTrack.State.IDENTIFIED
		passive_uncertainty = 2.0
	elif best_passive <= 0.68 * 0.68:
		passive_state = SensorTrack.State.TRACKED
		passive_uncertainty = 20.0
	elif best_passive <= 1.0 and triangulated:
		passive_state = SensorTrack.State.TRACKED
		passive_uncertainty = lerpf(55.0, 18.0, triangulation_quality)
	elif best_passive <= 1.0:
		passive_state = SensorTrack.State.SIGNAL
		passive_uncertainty = 90.0
	if passive_state > observed_state:
		observed_state = passive_state
		uncertainty = passive_uncertainty
	elif passive_state == observed_state:
		uncertainty = minf(uncertainty, passive_uncertainty)
	if triangulated and passive_state >= SensorTrack.State.TRACKED:
		channels |= SensorTrack.Channel.TRIANGULATED
	if observed_state == SensorTrack.State.HIDDEN:
		return
	var observed_classification: int = SensorTrack.classification_for_observation(
		observed_state,
		channels
	)

	var observed_position: Vector2 = target.global_position
	var observed_velocity: Vector2 = target.velocity
	if observed_state == SensorTrack.State.SIGNAL:
		var phase: float = deg_to_rad(float(abs(target.callsign.hash()) % 360))
		observed_position += Vector2.from_angle(phase) * uncertainty * 0.45
		observed_velocity = Vector2.ZERO
	var track: SensorTrack = _get_or_create_track(target)
	track.observe(
		observed_state,
		observed_position,
		observed_velocity,
		uncertainty,
		channels,
		accumulator.passive_observer_count,
		triangulation_quality,
		accumulator.source_ids,
		observed_classification,
		target.unit_profile.classification_label
	)


func advance(delta: float) -> void:
	var expired_ids: Array[int] = []
	for target_id: int in tracks:
		var track: SensorTrack = tracks[target_id]
		if not is_instance_valid(track.target) or track.target.destroyed:
			expired_ids.append(target_id)
			continue
		track.advance(delta)
		if track.get_state() == SensorTrack.State.HIDDEN and track.seconds_since_any_observation > 2.0:
			expired_ids.append(target_id)
	for target_id: int in expired_ids:
		tracks.erase(target_id)


func ingest_report(report: TrackReport, target: TacticalUnit) -> void:
	if target == null or target.destroyed:
		return
	var reported_state: int = SensorTrack.State.HIDDEN
	if report.confidence >= SensorTrack.IDENTIFIED_THRESHOLD:
		reported_state = SensorTrack.State.IDENTIFIED
	elif report.confidence >= SensorTrack.TRACKED_THRESHOLD:
		reported_state = SensorTrack.State.TRACKED
	elif report.confidence >= SensorTrack.SIGNAL_THRESHOLD:
		reported_state = SensorTrack.State.SIGNAL
	if reported_state == SensorTrack.State.HIDDEN:
		return
	var track: SensorTrack = _get_or_create_track(target)
	var report_uncertainty: float = report.uncertainty_radius + 8.0
	var reported_confidence: float = report.confidence
	var improves_classification: bool = report.classification_state > track.classification_state
	if reported_confidence < track.observation_floor and not improves_classification:
		return
	if (
		reported_confidence == track.observation_floor
		and report_uncertainty >= track.uncertainty_radius
		and not improves_classification
	):
		return
	track.observe(
		reported_state,
		report.estimated_position,
		report.estimated_velocity,
		report_uncertainty,
		report.channels,
		1,
		0.0,
		report.source_ids,
		report.classification_state,
		report.classification_label
	)


func get_track(target: TacticalUnit):
	return tracks.get(target.get_instance_id())


func create_reports(group_id: int) -> Array[TrackReport]:
	var reports: Array[TrackReport] = []
	for track: SensorTrack in tracks.values():
		if (
			track.get_state() >= SensorTrack.State.SIGNAL
			and track.observation_floor > 0.0
		):
			reports.append(TrackReport.from_track(track, group_id))
	return reports


func _get_or_create_track(target: TacticalUnit) -> SensorTrack:
	var target_id: int = target.get_instance_id()
	if not tracks.has(target_id):
		tracks[target_id] = SensorTrack.new(observer_team_id, target, target.maximum_acceleration)
	return tracks[target_id]
