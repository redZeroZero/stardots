class_name TacticalEventLog
extends RefCounted

const MAXIMUM_EVENTS: int = 6

var _events: Array[String] = []
var revision: int = 0


func clear() -> void:
	_events.clear()
	revision += 1


func append_event(tick: int, message: String) -> void:
	var normalized := message.strip_edges()
	if normalized.is_empty():
		return
	var line := "%06d  %s" % [tick, normalized]
	if not _events.is_empty() and _events.back() == line:
		return
	_events.append(line)
	while _events.size() > MAXIMUM_EVENTS:
		_events.pop_front()
	revision += 1


func get_lines() -> Array[String]:
	return _events.duplicate()


func get_text() -> String:
	return "\n".join(_events)
