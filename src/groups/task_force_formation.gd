class_name TaskForceFormation
extends RefCounted


static func calculate_slots(
	task_force: TaskForce,
	anchor: Vector2,
	heading: float,
	profile: TaskForceFormationProfile
) -> Dictionary:
	if task_force == null or profile == null:
		return {}
	var integrated: Array[TacticalUnit] = task_force.get_members_with_status(
		TaskForce.PhysicalStatus.INTEGRATED
	)
	var support: Array[TacticalUnit] = task_force.get_members_with_status(
		TaskForce.PhysicalStatus.SUPPORT
	)
	return calculate_slots_for_members(
		task_force, integrated, support, anchor, heading, profile
	)


static func calculate_slots_for_members(
	task_force: TaskForce,
	integrated: Array[TacticalUnit],
	support: Array[TacticalUnit],
	anchor: Vector2,
	heading: float,
	profile: TaskForceFormationProfile
) -> Dictionary:
	var slots: Dictionary = {}
	if task_force == null or profile == null:
		return slots
	var forward := Vector2.UP.rotated(heading)
	var right := Vector2.RIGHT.rotated(heading)
	var unit_spacing: float = profile.get_unit_spacing(task_force.formation_spacing)
	if task_force.formation_shape == TaskForce.FormationShape.LINE:
		_append_centered_line_slots(slots, integrated, anchor, right, unit_spacing)
	else:
		_append_swarm_slots(slots, integrated, anchor, forward, unit_spacing)
	var support_center: Vector2 = anchor - forward * profile.get_support_distance(
		task_force.formation_spacing
	)
	_append_centered_line_slots(slots, support, support_center, right, unit_spacing)
	return slots


static func _append_centered_line_slots(
	slots: Dictionary,
	units: Array[TacticalUnit],
	center: Vector2,
	axis: Vector2,
	spacing: float
) -> void:
	var middle_index: float = (float(units.size()) - 1.0) * 0.5
	for index: int in units.size():
		slots[units[index]] = center + axis * (float(index) - middle_index) * spacing


static func _append_swarm_slots(
	slots: Dictionary,
	units: Array[TacticalUnit],
	center: Vector2,
	forward: Vector2,
	spacing: float
) -> void:
	if units.is_empty():
		return
	var ring_start: int = 0
	if units.size() >= 7:
		slots[units[0]] = center
		ring_start = 1
	var ring_count: int = units.size() - ring_start
	if ring_count == 1:
		slots[units[ring_start]] = center
		return
	var radius: float = maxf(
		spacing,
		spacing / maxf(2.0 * sin(PI / float(ring_count)), 0.001)
	)
	var angle_step: float = TAU / float(ring_count)
	for ring_index: int in ring_count:
		var direction: Vector2 = forward.rotated(angle_step * float(ring_index))
		slots[units[ring_start + ring_index]] = center + direction * radius
