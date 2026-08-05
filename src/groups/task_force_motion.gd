class_name TaskForceMotion
extends RefCounted

var task_force: TaskForce
var formation_profile: TaskForceFormationProfile
var anchor_position: Vector2
var anchor_velocity: Vector2 = Vector2.ZERO
var anchor_heading: float = 0.0
var target_position: Vector2
var final_heading: float = 0.0
var has_final_heading: bool = false
var has_move_order: bool = false
var is_orienting_to_final_heading: bool = false
var anchor_angular_velocity: float = 0.0
var navigation_route: Array[NavigationWaypoint] = []
var _active_leg_origin: Vector2
var _force_slot_refresh: bool = true
var _last_slots: Dictionary = {}
var _status_before_detachment_by_instance_id: Dictionary = {}


func configure(
	new_task_force: TaskForce,
	new_formation_profile: TaskForceFormationProfile,
	initial_anchor: Vector2,
	initial_heading: float = 0.0
) -> void:
	task_force = new_task_force
	formation_profile = new_formation_profile
	anchor_position = initial_anchor
	target_position = initial_anchor
	anchor_heading = initial_heading
	anchor_velocity = Vector2.ZERO
	anchor_angular_velocity = 0.0
	navigation_route.clear()
	_active_leg_origin = initial_anchor
	has_move_order = false
	is_orienting_to_final_heading = false
	_force_slot_refresh = true
	_last_slots.clear()
	_status_before_detachment_by_instance_id.clear()
	_refresh_member_orders()


func issue_move_order(
	new_target_position: Vector2,
	requested_final_heading: float = 0.0,
	requested_heading_is_defined: bool = false
) -> void:
	issue_navigation_order(
		new_target_position,
		false,
		false,
		requested_final_heading,
		requested_heading_is_defined
	)


func issue_navigation_order(
	new_target_position: Vector2,
	fly_through: bool = false,
	append: bool = false,
	requested_final_heading: float = 0.0,
	requested_heading_is_defined: bool = false
) -> void:
	if not append or navigation_route.is_empty():
		if not append:
			navigation_route.clear()
		_active_leg_origin = anchor_position
	else:
		var previous_waypoint: NavigationWaypoint = navigation_route[-1]
		previous_waypoint.passage_mode = NavigationWaypoint.PassageMode.FLY_THROUGH
		var outgoing_direction: Vector2 = previous_waypoint.position.direction_to(
			new_target_position
		)
		if outgoing_direction != Vector2.ZERO:
			previous_waypoint.final_heading = outgoing_direction.angle() + PI * 0.5
			previous_waypoint.has_final_heading = true
	var passage_mode := (
		NavigationWaypoint.PassageMode.FLY_THROUGH
		if fly_through
		else NavigationWaypoint.PassageMode.HOLD
	)
	navigation_route.append(NavigationWaypoint.new(
		new_target_position,
		passage_mode,
		requested_final_heading,
		requested_heading_is_defined
	))
	if navigation_route.size() == 1:
		_activate_current_waypoint()
	is_orienting_to_final_heading = false
	_force_slot_refresh = true


func set_member_status(unit: TacticalUnit, physical_status: TaskForce.PhysicalStatus) -> bool:
	if task_force == null:
		return false
	var previous_status: int = task_force.get_member_status(unit)
	if previous_status < 0 or not task_force.set_member_status(unit, physical_status):
		return false
	if physical_status == TaskForce.PhysicalStatus.DETACHED:
		if previous_status != TaskForce.PhysicalStatus.DETACHED:
			_status_before_detachment_by_instance_id[unit.get_instance_id()] = previous_status
		unit.cut_engines()
		unit.show_navigation_route = true
	else:
		_status_before_detachment_by_instance_id.erase(unit.get_instance_id())
		unit.show_navigation_route = false
	_last_slots.erase(unit)
	_force_slot_refresh = true
	return true


func detach_member(unit: TacticalUnit) -> bool:
	return set_member_status(unit, TaskForce.PhysicalStatus.DETACHED)


func rejoin_member(unit: TacticalUnit) -> bool:
	if task_force == null or task_force.get_member_status(unit) != TaskForce.PhysicalStatus.DETACHED:
		return false
	var restored_status: int = int(_status_before_detachment_by_instance_id.get(
		unit.get_instance_id(),
		TaskForce.PhysicalStatus.INTEGRATED
	))
	return set_member_status(unit, restored_status)


func request_formation_refresh() -> void:
	_force_slot_refresh = true


func update(delta: float) -> void:
	if task_force == null or formation_profile == null:
		return
	task_force.remove_invalid_members()
	if not task_force.can_persist():
		has_move_order = false
		anchor_velocity = Vector2.ZERO
		_last_slots.clear()
		return
	var previous_heading: float = anchor_heading
	if has_move_order:
		_advance_anchor(delta)
	elif is_orienting_to_final_heading:
		_advance_final_orientation(delta)
	elif anchor_velocity != Vector2.ZERO:
		anchor_position += anchor_velocity * delta
		anchor_heading = rotate_toward(
			anchor_heading,
			anchor_velocity.angle() + PI * 0.5,
			_get_slowest_member_angular_speed() * delta
		)
	anchor_angular_velocity = (
		angle_difference(previous_heading, anchor_heading) / delta
		if delta > 0.0
		else 0.0
	)
	_refresh_member_orders()


func calculate_current_slots() -> Dictionary:
	return TaskForceFormation.calculate_slots(
		task_force,
		anchor_position,
		anchor_heading,
		formation_profile
	)


func get_cohesion_error() -> float:
	var maximum_error: float = 0.0
	var slots: Dictionary = calculate_current_slots()
	for unit: TacticalUnit in slots:
		if is_instance_valid(unit) and not unit.destroyed:
			maximum_error = maxf(maximum_error, unit.global_position.distance_to(slots[unit]))
	return maximum_error


func _advance_anchor(delta: float) -> void:
	var offset: Vector2 = target_position - anchor_position
	var distance: float = offset.length()
	var current_waypoint: NavigationWaypoint = navigation_route[0]
	var incoming_direction: Vector2 = _active_leg_origin.direction_to(target_position)
	var passed_waypoint: bool = (
		incoming_direction != Vector2.ZERO
		and (anchor_position - target_position).dot(incoming_direction) >= 0.0
	)
	if (
		current_waypoint.passage_mode == NavigationWaypoint.PassageMode.FLY_THROUGH
		and (distance <= formation_profile.anchor_arrival_radius or passed_waypoint)
	):
		var passed_position: Vector2 = current_waypoint.position
		navigation_route.pop_front()
		_active_leg_origin = passed_position
		if navigation_route.is_empty():
			has_move_order = false
		else:
			_activate_current_waypoint()
		_force_slot_refresh = true
		return
	var maximum_acceleration: float = _get_slowest_member_acceleration()
	var maximum_speed: float = _get_slowest_member_speed() * _get_cohesion_speed_ratio()
	var desired_speed: float = maximum_speed
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.HOLD:
		var braking_speed: float = sqrt(maxf(0.0, 2.0 * maximum_acceleration * distance))
		desired_speed = minf(maximum_speed, braking_speed)
	var desired_velocity: Vector2 = offset.normalized() * desired_speed if distance > 0.001 else Vector2.ZERO
	anchor_velocity = anchor_velocity.move_toward(
		desired_velocity,
		maximum_acceleration * delta
	)
	anchor_position += anchor_velocity * delta
	if anchor_velocity.length() > 0.1:
		var travel_heading: float = anchor_velocity.angle() + PI * 0.5
		anchor_heading = rotate_toward(
			anchor_heading,
			travel_heading,
			_get_slowest_member_angular_speed() * delta
		)
	if (
		current_waypoint.passage_mode == NavigationWaypoint.PassageMode.HOLD
		and distance <= formation_profile.anchor_arrival_radius
		and anchor_velocity.length() <= formation_profile.anchor_stop_speed
	):
		anchor_position = target_position
		anchor_velocity = Vector2.ZERO
		navigation_route.pop_front()
		has_move_order = not navigation_route.is_empty()
		is_orienting_to_final_heading = has_final_heading
		if has_move_order:
			_active_leg_origin = anchor_position
			_activate_current_waypoint()
		_force_slot_refresh = true


func _advance_final_orientation(delta: float) -> void:
	anchor_heading = rotate_toward(
		anchor_heading,
		final_heading,
		_get_slowest_member_angular_speed() * delta
	)
	_force_slot_refresh = true
	if absf(angle_difference(anchor_heading, final_heading)) <= 0.01:
		anchor_heading = final_heading
		is_orienting_to_final_heading = false


func _refresh_member_orders() -> void:
	var slots: Dictionary = calculate_current_slots()
	for tracked_unit: Variant in _last_slots.keys():
		if not slots.has(tracked_unit):
			_last_slots.erase(tracked_unit)
	for unit: TacticalUnit in slots:
		if not is_instance_valid(unit) or unit.destroyed:
			continue
		var slot: Vector2 = slots[unit]
		var previous_slot: Vector2 = _last_slots.get(unit, Vector2(INF, INF))
		var member_is_settled: bool = _member_is_settled(unit, slot)
		if not member_is_settled:
			unit.show_navigation_route = false
			var slot_offset: Vector2 = slot - anchor_position
			var rotational_velocity := Vector2(-slot_offset.y, slot_offset.x) * anchor_angular_velocity
			unit.set_formation_target(slot, anchor_velocity + rotational_velocity)
			_last_slots[unit] = slot
		elif (
			_force_slot_refresh
			or unit.formation_guidance_active
			or not previous_slot.is_finite()
			or previous_slot.distance_to(slot) >= formation_profile.slot_refresh_distance
		):
			unit.show_navigation_route = false
			unit.set_navigation_order(
				slot,
				false,
				false,
				anchor_heading,
				true
			)
			_last_slots[unit] = slot
	_force_slot_refresh = false


func _member_is_settled(unit: TacticalUnit, slot: Vector2) -> bool:
	if has_move_order or is_orienting_to_final_heading or anchor_velocity != Vector2.ZERO:
		return false
	return (
		unit.global_position.distance_to(slot) <= formation_profile.anchor_arrival_radius
		and unit.velocity.length() <= formation_profile.anchor_stop_speed
	)


func _get_cohesion_speed_ratio() -> float:
	var spacing: float = formation_profile.get_unit_spacing(task_force.formation_spacing)
	var full_speed_error: float = spacing * formation_profile.cohesion_full_speed_distance_multiplier
	var minimum_speed_error: float = spacing * formation_profile.cohesion_minimum_speed_distance_multiplier
	var transition: float = inverse_lerp(full_speed_error, minimum_speed_error, get_cohesion_error())
	return lerpf(1.0, formation_profile.minimum_cohesion_speed_ratio, clampf(transition, 0.0, 1.0))


func _get_slowest_member_speed() -> float:
	var slowest_speed: float = INF
	for unit: TacticalUnit in _get_commanded_members():
		slowest_speed = minf(slowest_speed, unit.move_speed)
	return 0.0 if is_inf(slowest_speed) else slowest_speed


func _get_slowest_member_acceleration() -> float:
	var slowest_acceleration: float = INF
	for unit: TacticalUnit in _get_commanded_members():
		slowest_acceleration = minf(slowest_acceleration, unit.maximum_acceleration)
	return 0.0 if is_inf(slowest_acceleration) else slowest_acceleration


func _get_slowest_member_angular_speed() -> float:
	var slowest_angular_speed: float = INF
	for unit: TacticalUnit in _get_commanded_members():
		slowest_angular_speed = minf(slowest_angular_speed, unit.maximum_angular_speed)
	return 0.0 if is_inf(slowest_angular_speed) else slowest_angular_speed


func _get_commanded_members() -> Array[TacticalUnit]:
	var commanded_members: Array[TacticalUnit] = []
	for unit: TacticalUnit in task_force.members:
		if task_force.get_member_status(unit) != TaskForce.PhysicalStatus.DETACHED:
			commanded_members.append(unit)
	return commanded_members


func _activate_current_waypoint() -> void:
	if navigation_route.is_empty():
		has_move_order = false
		return
	var waypoint: NavigationWaypoint = navigation_route[0]
	target_position = waypoint.position
	final_heading = waypoint.final_heading
	has_final_heading = waypoint.has_final_heading
	has_move_order = true
