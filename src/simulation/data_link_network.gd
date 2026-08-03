class_name DataLinkNetwork
extends RefCounted

var units_by_id: Dictionary = {}
var relay_units: Array = []
var transfer_cache: Dictionary = {}
var transmitter_count: int = 0


func rebuild(units: Array) -> void:
	units_by_id.clear()
	relay_units.clear()
	transfer_cache.clear()
	transmitter_count = 0
	for unit in units:
		if not is_instance_valid(unit) or unit.destroyed:
			continue
		var unit_id: int = unit.get_instance_id()
		units_by_id[unit_id] = unit
		if unit.can_transmit_data():
			transmitter_count += 1
		if unit.can_relay_data() and unit.can_receive_data() and unit.can_transmit_data():
			relay_units.append(unit)


func has_transmitters() -> bool:
	return transmitter_count > 0


func can_transfer(source, receiver) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(receiver):
		return false
	var source_id: int = source.get_instance_id()
	var receiver_id: int = receiver.get_instance_id()
	if source_id == receiver_id:
		return true
	if not units_by_id.has(source_id) or not units_by_id.has(receiver_id):
		return false
	if not source.can_transmit_data() or not receiver.can_receive_data():
		return false
	var source_cache: Dictionary = transfer_cache.get(source_id, {})
	if source_cache.has(receiver_id):
		return bool(source_cache[receiver_id])
	var reachable: bool = (
		_has_direct_link(source, receiver)
		or _can_transfer_through_relay(source, receiver)
	)
	source_cache[receiver_id] = reachable
	transfer_cache[source_id] = source_cache
	return reachable


func _can_transfer_through_relay(source, receiver) -> bool:
	if relay_units.is_empty():
		return false
	var visited: Dictionary = {}
	var queue: Array = [source]
	var cursor: int = 0
	while cursor < queue.size():
		var current = queue[cursor]
		cursor += 1
		if current != source and _has_direct_link(current, receiver):
			return true
		for relay in relay_units:
			var relay_id: int = relay.get_instance_id()
			if relay == current or visited.has(relay_id):
				continue
			if _has_direct_link(current, relay):
				visited[relay_id] = true
				queue.append(relay)
	return false


func _has_direct_link(source, receiver) -> bool:
	if not source.can_transmit_data() or not receiver.can_receive_data():
		return false
	if (
		source.tactical_group_id != receiver.tactical_group_id
		and not source.can_bridge_tactical_groups()
		and not receiver.can_bridge_tactical_groups()
	):
		return false
	var maximum_range: float = source.get_data_link_range()
	return source.global_position.distance_squared_to(receiver.global_position) <= maximum_range * maximum_range
