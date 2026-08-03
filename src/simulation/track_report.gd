class_name TrackReport
extends RefCounted

var target_id: int
var estimated_position: Vector2
var estimated_velocity: Vector2
var uncertainty_radius: float
var confidence: float
var source_group_id: int
var source_ids: Array[int] = []
var channels: int


static func from_track(track: SensorTrack, group_id: int) -> TrackReport:
	var report := TrackReport.new()
	report.target_id = track.target.get_instance_id()
	report.estimated_position = track.estimated_position
	report.estimated_velocity = track.estimated_velocity
	report.uncertainty_radius = track.uncertainty_radius
	report.confidence = track.confidence
	report.source_group_id = group_id
	report.source_ids.assign(track.last_observation_source_ids)
	report.channels = track.last_observation_channels
	return report
