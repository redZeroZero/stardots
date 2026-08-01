class_name TacticalUnit
extends Node2D

enum IntelState {
	HIDDEN,
	SIGNAL,
	TRACKED,
	IDENTIFIED,
}

enum SensorMode {
	PASSIVE,
	ACTIVE,
}

enum ThermalMode {
	SILENT,
	NORMAL,
	COMBAT,
}

const BODY_RADIUS: float = 9.0
const SELECTION_RADIUS: float = 15.0

var callsign: String = "UNIT"
var team_id: int = 0
var unit_profile: UnitProfile
var move_speed: float = 95.0
var maximum_acceleration: float = 38.0
var maximum_angular_speed: float = deg_to_rad(100.0)
var angular_acceleration: float = deg_to_rad(180.0)
var arrival_radius: float = 5.0
var station_keeping_speed: float = 8.0
var preferred_turn_radius: float = 90.0
var turn_anticipation: float = 0.75
var sensor_range: float = 420.0
var active_sensor_range: float = 560.0
var active_emission_detection_range: float = 720.0
var active_sensor_heat_per_second: float = 4.0
var sensor_mode: SensorMode = SensorMode.PASSIVE
var heat_capacity: float = 100.0
var heat: float = 20.0
var passive_cooling_per_second: float = 2.5
var silent_cooling_multiplier: float = 0.20
var combat_cooling_multiplier: float = 2.0
var silent_radiator_signature: float = 0.05
var normal_radiator_signature: float = 0.15
var combat_radiator_signature: float = 0.45
var thermal_mode: ThermalMode = ThermalMode.NORMAL
var baseline_thermal_signature: float = 0.70
var stored_heat_signature_multiplier: float = 0.60
var engine_signature_multiplier: float = 0.80
var engine_signature_activity: float = 0.0
var propulsion_heat_per_second: float = 6.0
var missile_launch_heat: float = 8.0
var missile_loading_heat_per_second: float = 1.5
var point_defense_heat_per_shot: float = 0.6
var weapon_overheat_threshold: float = 0.95
var automatic_thermal_control: bool = true
var stationary_speed_threshold: float = 2.0
var combat_mode_hold_time: float = 6.0
var combat_alert_remaining: float = 0.0
var point_defense_range: float = 115.0
var point_defense_ammunition_capacity: int = 80
var point_defense_ammunition: int = 80
var point_defense_fire_interval: float = 0.14
var point_defense_cooldown_remaining: float = 0.0
var point_defense_projectile_speed: float = 330.0
var point_defense_projectile_lifetime: float = 0.5
var point_defense_projectile_damage: float = 9.0
var point_defense_projectile_hit_radius: float = 4.0
var point_defense_dispersion_degrees: float = 2.8
var maximum_hull: float = 100.0
var hull: float = 100.0
var weapon_cooldown: float = 0.5
var weapon_cooldown_remaining: float = 0.0
var missile_capacity: int = 6
var missiles_remaining: int = 6
var missile_reserve: int = 4
var missile_launcher_count: int = 2
var missile_loader_count: int = 1
var missile_loading_time: float = 4.0
var launcher_loaded: Array[bool] = []
var launcher_loading_remaining: Array[float] = []
var move_target: Vector2
var navigation_route: Array[NavigationWaypoint] = []
var active_leg_origin: Vector2
var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var has_move_target: bool = false
var is_orienting_to_final_heading: bool = false
var final_heading: float = 0.0
var selected: bool = false
var intel_state: IntelState = IntelState.IDENTIFIED
var contact_offset: Vector2 = Vector2.ZERO
var impact_flash_remaining: float = 0.0
var defense_fire_remaining: float = 0.0
var defense_target_position: Vector2 = Vector2.ZERO
var destroyed: bool = false
var is_returning_to_theater: bool = false


func configure(new_callsign: String, new_team_id: int, start_position: Vector2, profile: UnitProfile) -> void:
	callsign = new_callsign
	team_id = new_team_id
	unit_profile = profile
	position = start_position
	move_target = start_position
	move_speed = profile.tactical_speed_limit
	maximum_acceleration = minf(profile.drive_acceleration, profile.crew_safe_acceleration) if profile.crewed else profile.drive_acceleration
	maximum_angular_speed = deg_to_rad(profile.maximum_angular_speed_degrees)
	angular_acceleration = deg_to_rad(profile.angular_acceleration_degrees)
	arrival_radius = profile.arrival_radius
	station_keeping_speed = profile.station_keeping_speed
	preferred_turn_radius = profile.preferred_turn_radius
	turn_anticipation = profile.turn_anticipation
	sensor_range = profile.sensor_range
	active_sensor_range = profile.active_sensor_range
	active_emission_detection_range = profile.active_emission_detection_range
	active_sensor_heat_per_second = profile.active_sensor_heat_per_second
	heat_capacity = profile.heat_capacity
	heat = clampf(profile.initial_heat, 0.0, heat_capacity)
	passive_cooling_per_second = profile.passive_cooling_per_second
	silent_cooling_multiplier = profile.silent_cooling_multiplier
	combat_cooling_multiplier = profile.combat_cooling_multiplier
	silent_radiator_signature = profile.silent_radiator_signature
	normal_radiator_signature = profile.normal_radiator_signature
	combat_radiator_signature = profile.combat_radiator_signature
	baseline_thermal_signature = profile.baseline_thermal_signature
	stored_heat_signature_multiplier = profile.stored_heat_signature_multiplier
	engine_signature_multiplier = profile.engine_signature_multiplier
	propulsion_heat_per_second = profile.propulsion_heat_per_second
	missile_launch_heat = profile.missile_launch_heat
	missile_loading_heat_per_second = profile.missile_loading_heat_per_second
	point_defense_heat_per_shot = profile.point_defense_heat_per_shot
	weapon_overheat_threshold = profile.weapon_overheat_threshold
	automatic_thermal_control = profile.automatic_thermal_control
	stationary_speed_threshold = profile.stationary_speed_threshold
	combat_mode_hold_time = profile.combat_mode_hold_time
	combat_alert_remaining = 0.0
	is_returning_to_theater = false
	point_defense_range = profile.point_defense_range
	point_defense_ammunition_capacity = profile.point_defense_ammunition_capacity
	point_defense_ammunition = point_defense_ammunition_capacity
	point_defense_fire_interval = profile.point_defense_fire_interval
	point_defense_projectile_speed = profile.point_defense_projectile_speed
	point_defense_projectile_lifetime = profile.point_defense_projectile_lifetime
	point_defense_projectile_damage = profile.point_defense_projectile_damage
	point_defense_projectile_hit_radius = profile.point_defense_projectile_hit_radius
	point_defense_dispersion_degrees = profile.point_defense_dispersion_degrees
	maximum_hull = profile.maximum_hull
	hull = maximum_hull
	missile_capacity = profile.missile_capacity
	missiles_remaining = missile_capacity
	missile_launcher_count = maxi(0, profile.missile_launcher_count)
	missile_loader_count = maxi(0, profile.missile_loader_count)
	missile_loading_time = maxf(0.01, profile.missile_loading_time)
	weapon_cooldown = maxf(0.0, profile.missile_launch_interval)
	launcher_loaded.clear()
	launcher_loading_remaining.clear()
	var initially_loaded: int = mini(missile_capacity, missile_launcher_count)
	missile_reserve = missile_capacity - initially_loaded
	for launcher_index: int in missile_launcher_count:
		launcher_loaded.append(launcher_index < initially_loaded)
		launcher_loading_remaining.append(0.0)
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_move_target(target: Vector2) -> void:
	set_navigation_order(target)


func cut_engines() -> void:
	navigation_route.clear()
	has_move_target = false
	is_orienting_to_final_heading = false
	queue_redraw()


func toggle_sensor_mode() -> void:
	sensor_mode = SensorMode.ACTIVE if sensor_mode == SensorMode.PASSIVE else SensorMode.PASSIVE
	queue_redraw()


func get_sensor_mode_name() -> String:
	return "ACTIF" if sensor_mode == SensorMode.ACTIVE else "PASSIF"


func cycle_thermal_mode() -> void:
	thermal_mode = (int(thermal_mode) + 1) % 3
	queue_redraw()


func get_thermal_mode_name() -> String:
	if thermal_mode == ThermalMode.SILENT:
		return "SILENCIEUX"
	if thermal_mode == ThermalMode.COMBAT:
		return "COMBAT"
	return "NORMAL"


func set_navigation_order(
	target: Vector2,
	fly_through: bool = false,
	append: bool = false,
	requested_final_heading: float = 0.0,
	has_requested_final_heading: bool = false
) -> void:
	var route_was_active: bool = has_move_target and not navigation_route.is_empty()
	if not append:
		if has_move_target and navigation_route.size() == 1 and move_target.distance_to(target) <= 0.5:
			return
		navigation_route.clear()
		active_leg_origin = global_position
	else:
		# Une route continue traverse ses points intermédiaires ; seul le dernier
		# waypoint reste un ordre d'arrêt. Le cap d'un point intermédiaire est
		# toujours imposé par le segment qui le suit.
		if not navigation_route.is_empty():
			var previous_waypoint: NavigationWaypoint = navigation_route[-1]
			previous_waypoint.passage_mode = NavigationWaypoint.PassageMode.FLY_THROUGH
			var outgoing_direction: Vector2 = previous_waypoint.position.direction_to(target)
			if outgoing_direction != Vector2.ZERO:
				previous_waypoint.final_heading = outgoing_direction.angle() + PI * 0.5
				previous_waypoint.has_final_heading = true

	var route_origin: Vector2 = navigation_route[-1].position if not navigation_route.is_empty() else global_position
	var approach_direction: Vector2 = route_origin.direction_to(target)
	var heading: float = requested_final_heading
	var heading_is_defined: bool = has_requested_final_heading
	if not fly_through and not heading_is_defined and approach_direction != Vector2.ZERO:
		heading = approach_direction.angle() + PI * 0.5
		heading_is_defined = true
	var mode := NavigationWaypoint.PassageMode.FLY_THROUGH if fly_through else NavigationWaypoint.PassageMode.HOLD
	navigation_route.append(NavigationWaypoint.new(target, mode, heading, heading_is_defined))
	is_orienting_to_final_heading = false
	_recalculate_route_plan()
	if not append or not route_was_active:
		active_leg_origin = global_position
		_activate_current_waypoint()
	queue_redraw()


func _activate_current_waypoint() -> void:
	if navigation_route.is_empty():
		has_move_target = false
		return
	move_target = navigation_route[0].position
	has_move_target = true


func _recalculate_route_plan() -> void:
	for index: int in navigation_route.size():
		var waypoint: NavigationWaypoint = navigation_route[index]
		if waypoint.passage_mode == NavigationWaypoint.PassageMode.HOLD:
			waypoint.planned_speed = 0.0
			continue
		if index >= navigation_route.size() - 1:
			waypoint.planned_speed = move_speed
			continue
		var leg_origin: Vector2 = active_leg_origin if index == 0 else navigation_route[index - 1].position
		var incoming_direction: Vector2 = leg_origin.direction_to(waypoint.position)
		var outgoing_direction: Vector2 = waypoint.position.direction_to(navigation_route[index + 1].position)
		var turn_angle: float = acos(clampf(incoming_direction.dot(outgoing_direction), -1.0, 1.0))
		var turn_cost: float = tan(minf(turn_angle * 0.5, PI * 0.499))
		waypoint.planned_speed = move_speed if turn_cost <= 0.001 else minf(
			move_speed,
			sqrt(maximum_acceleration * preferred_turn_radius / turn_cost)
		)

	# La passe arrière garantit qu'un segment est assez long pour atteindre la
	# vitesse imposée au point suivant avec l'accélération disponible.
	for index: int in range(navigation_route.size() - 2, -1, -1):
		var waypoint: NavigationWaypoint = navigation_route[index]
		var next_waypoint: NavigationWaypoint = navigation_route[index + 1]
		var segment_length: float = waypoint.position.distance_to(next_waypoint.position)
		var reachable_speed: float = sqrt(next_waypoint.planned_speed * next_waypoint.planned_speed + 2.0 * maximum_acceleration * segment_length)
		waypoint.planned_speed = minf(waypoint.planned_speed, reachable_speed)


func set_intel_state(value: IntelState, uncertainty_offset: Vector2 = Vector2.ZERO) -> void:
	if intel_state == value and contact_offset == uncertainty_offset:
		return
	intel_state = value
	contact_offset = uncertainty_offset
	queue_redraw()


func contains_world_point(world_point: Vector2) -> bool:
	return not destroyed and global_position.distance_to(world_point) <= SELECTION_RADIUS


func is_targetable_contact() -> bool:
	return not destroyed and team_id != 0 and intel_state >= IntelState.TRACKED


func has_guidance_track() -> bool:
	return not destroyed and intel_state >= IntelState.TRACKED


func can_launch_weapon() -> bool:
	return not destroyed and not is_weapons_overheated() and weapon_cooldown_remaining <= 0.0 and get_ready_launcher_count() > 0


func mark_weapon_launched() -> void:
	if not can_launch_weapon():
		return
	for launcher_index: int in missile_launcher_count:
		if launcher_loaded[launcher_index]:
			launcher_loaded[launcher_index] = false
			break
	missiles_remaining -= 1
	weapon_cooldown_remaining = weapon_cooldown
	trigger_combat_thermal_mode()
	_add_heat(missile_launch_heat)
	_start_available_launcher_loads()
	queue_redraw()


func get_ready_launcher_count() -> int:
	var ready_count: int = 0
	for loaded: bool in launcher_loaded:
		if loaded:
			ready_count += 1
	return ready_count


func get_loading_launcher_count() -> int:
	var loading_count: int = 0
	for remaining: float in launcher_loading_remaining:
		if remaining > 0.0:
			loading_count += 1
	return loading_count


func _start_available_launcher_loads() -> void:
	var active_loaders: int = get_loading_launcher_count()
	if active_loaders >= missile_loader_count or missile_reserve <= 0:
		return
	for launcher_index: int in missile_launcher_count:
		if active_loaders >= missile_loader_count or missile_reserve <= 0:
			break
		if launcher_loaded[launcher_index] or launcher_loading_remaining[launcher_index] > 0.0:
			continue
		missile_reserve -= 1
		launcher_loading_remaining[launcher_index] = missile_loading_time
		active_loaders += 1


func _update_launcher_loading(delta: float) -> void:
	var changed: bool = false
	if get_loading_launcher_count() > 0:
		_add_heat(missile_loading_heat_per_second * delta)
	for launcher_index: int in missile_launcher_count:
		if launcher_loading_remaining[launcher_index] <= 0.0:
			continue
		launcher_loading_remaining[launcher_index] = maxf(0.0, launcher_loading_remaining[launcher_index] - delta)
		changed = true
		if launcher_loading_remaining[launcher_index] <= 0.0:
			launcher_loaded[launcher_index] = true
	_start_available_launcher_loads()
	if changed:
		queue_redraw()


func _add_heat(amount: float) -> void:
	heat = clampf(heat + maxf(0.0, amount), 0.0, heat_capacity)
	queue_redraw()


func _update_thermal_state(delta: float) -> void:
	if sensor_mode == SensorMode.ACTIVE:
		heat = minf(heat_capacity, heat + active_sensor_heat_per_second * delta)
	var cooling_multiplier: float = 1.0
	if thermal_mode == ThermalMode.SILENT:
		cooling_multiplier = silent_cooling_multiplier
	elif thermal_mode == ThermalMode.COMBAT:
		cooling_multiplier = combat_cooling_multiplier
	heat = maxf(0.0, heat - passive_cooling_per_second * cooling_multiplier * delta)
	engine_signature_activity = maxf(0.0, engine_signature_activity - delta * 0.8)
	if heat >= heat_capacity * 0.99:
		sensor_mode = SensorMode.PASSIVE
	queue_redraw()


func trigger_combat_thermal_mode(duration: float = -1.0) -> void:
	var alert_duration: float = combat_mode_hold_time if duration < 0.0 else duration
	combat_alert_remaining = maxf(combat_alert_remaining, alert_duration)
	if automatic_thermal_control:
		thermal_mode = ThermalMode.COMBAT
	queue_redraw()


func _update_automatic_thermal_mode(delta: float) -> void:
	if not automatic_thermal_control:
		return
	combat_alert_remaining = maxf(0.0, combat_alert_remaining - delta)
	if combat_alert_remaining > 0.0:
		thermal_mode = ThermalMode.COMBAT
	elif has_move_target or velocity.length() > stationary_speed_threshold:
		thermal_mode = ThermalMode.NORMAL
	else:
		thermal_mode = ThermalMode.SILENT


func get_heat_ratio() -> float:
	return heat / heat_capacity if heat_capacity > 0.0 else 0.0


func get_thermal_signature() -> float:
	var radiator_signature: float = normal_radiator_signature
	if thermal_mode == ThermalMode.SILENT:
		radiator_signature = silent_radiator_signature
	elif thermal_mode == ThermalMode.COMBAT:
		radiator_signature = combat_radiator_signature
	return maxf(0.1, baseline_thermal_signature + get_heat_ratio() * stored_heat_signature_multiplier + engine_signature_activity * engine_signature_multiplier + radiator_signature)


func is_weapons_overheated() -> bool:
	return get_heat_ratio() >= weapon_overheat_threshold


func apply_fragment_damage(amount: float) -> void:
	if destroyed or amount <= 0.0:
		return
	hull = maxf(0.0, hull - amount)
	trigger_combat_thermal_mode()
	impact_flash_remaining = 0.35
	if hull <= 0.0:
		destroyed = true
		has_move_target = false
		navigation_route.clear()
		is_orienting_to_final_heading = false
		selected = false
	queue_redraw()


func can_fire_point_defense() -> bool:
	return not destroyed and not is_weapons_overheated() and point_defense_ammunition > 0 and point_defense_cooldown_remaining <= 0.0


func mark_point_defense_fired(aim_point: Vector2) -> void:
	if not can_fire_point_defense():
		return
	point_defense_ammunition -= 1
	point_defense_cooldown_remaining = point_defense_fire_interval
	trigger_combat_thermal_mode()
	_add_heat(point_defense_heat_per_shot)
	defense_target_position = aim_point
	defense_fire_remaining = 0.07
	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_automatic_thermal_mode(delta)
	_update_thermal_state(delta)
	if impact_flash_remaining > 0.0:
		impact_flash_remaining = maxf(0.0, impact_flash_remaining - delta)
		queue_redraw()
	if defense_fire_remaining > 0.0:
		defense_fire_remaining = maxf(0.0, defense_fire_remaining - delta)
		queue_redraw()
	if weapon_cooldown_remaining > 0.0:
		weapon_cooldown_remaining = maxf(0.0, weapon_cooldown_remaining - delta)
		queue_redraw()
	_update_launcher_loading(delta)
	if point_defense_cooldown_remaining > 0.0:
		point_defense_cooldown_remaining = maxf(0.0, point_defense_cooldown_remaining - delta)

	if destroyed:
		return

	if has_move_target:
		_update_inertial_movement(delta)
	elif is_orienting_to_final_heading:
		_update_final_orientation(delta)
	else:
		if absf(angular_velocity) > 0.001:
			angular_velocity = move_toward(angular_velocity, 0.0, angular_acceleration * delta)
			rotation += angular_velocity * delta
		# Sans ordre actif, aucune force ne supprime la vélocité acquise.
		global_position += velocity * delta
	queue_redraw()


func _update_inertial_movement(delta: float) -> void:
	var offset_to_target: Vector2 = move_target - global_position
	var distance_to_target: float = offset_to_target.length()
	var current_waypoint: NavigationWaypoint = navigation_route[0]
	var incoming_direction: Vector2 = active_leg_origin.direction_to(move_target)
	var passed_waypoint: bool = (
		incoming_direction != Vector2.ZERO
		and (global_position - move_target).dot(incoming_direction) >= 0.0
	)
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.FLY_THROUGH and (distance_to_target <= arrival_radius or passed_waypoint):
		var passed_position: Vector2 = current_waypoint.position
		navigation_route.pop_front()
		active_leg_origin = passed_position
		_activate_current_waypoint()
		return
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.HOLD and distance_to_target <= arrival_radius and velocity.length() <= station_keeping_speed:
		global_position = move_target
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		navigation_route.pop_front()
		has_move_target = false
		if current_waypoint.has_final_heading:
			final_heading = current_waypoint.final_heading
			is_orienting_to_final_heading = true
		else:
			_activate_current_waypoint()
		return

	# Le calculateur vise dès maintenant la vitesse prévue au waypoint, au lieu
	# d'attendre de l'avoir dépassé pour traiter le segment suivant.
	var allowed_speed: float = minf(
		move_speed,
		sqrt(current_waypoint.planned_speed * current_waypoint.planned_speed + 2.0 * maximum_acceleration * distance_to_target)
	)
	var desired_speed: float = allowed_speed
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.HOLD:
		var arrival_speed: float = distance_to_target * 0.35
		desired_speed = minf(allowed_speed, arrival_speed)
	var desired_velocity := offset_to_target.normalized() * desired_speed if distance_to_target > 0.001 else Vector2.ZERO
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.FLY_THROUGH and navigation_route.size() > 1:
		var outgoing_direction: Vector2 = current_waypoint.position.direction_to(navigation_route[1].position)
		var exit_velocity: Vector2 = outgoing_direction * current_waypoint.planned_speed
		var required_velocity_change: float = desired_velocity.distance_to(exit_velocity)
		var maneuver_time: float = required_velocity_change / maximum_acceleration
		var anticipation_distance: float = maxf(arrival_radius * 2.0, velocity.length() * maneuver_time * turn_anticipation)
		var transition: float = clampf(1.0 - distance_to_target / anticipation_distance, 0.0, 1.0)
		desired_velocity = desired_velocity.lerp(exit_velocity, smoothstep(0.0, 1.0, transition))
	var velocity_error: Vector2 = desired_velocity - velocity
	var forward := Vector2.UP.rotated(rotation)
	var desired_thrust_direction := velocity_error.normalized() if velocity_error.length() > 0.01 else forward
	var desired_rotation: float = desired_thrust_direction.angle() + PI * 0.5
	var angle_error: float = wrapf(desired_rotation - rotation, -PI, PI)

	# La coque accélère et freine aussi sa rotation, au lieu de pivoter instantanément.
	var desired_angular_speed: float = minf(
		maximum_angular_speed,
		sqrt(2.0 * angular_acceleration * absf(angle_error))
	) * signf(angle_error)
	angular_velocity = move_toward(angular_velocity, desired_angular_speed, angular_acceleration * delta)
	rotation += angular_velocity * delta

	# La poussée principale diminue fortement lorsque la coque est mal alignée.
	var alignment: float = maxf(0.0, cos(angle_error))
	var available_acceleration: float = maximum_acceleration * alignment
	var requested_acceleration: float = velocity_error.length() / maxf(delta, 0.0001)
	var applied_acceleration: float = minf(available_acceleration, requested_acceleration)
	velocity += Vector2.UP.rotated(rotation) * applied_acceleration * delta
	var thrust_ratio: float = applied_acceleration / maximum_acceleration if maximum_acceleration > 0.0 else 0.0
	if thrust_ratio > 0.01:
		_add_heat(propulsion_heat_per_second * thrust_ratio * delta)
		engine_signature_activity = maxf(engine_signature_activity, thrust_ratio)
	if velocity.length() > move_speed:
		velocity = velocity.normalized() * move_speed
	global_position += velocity * delta


func _update_final_orientation(delta: float) -> void:
	var angle_error: float = wrapf(final_heading - rotation, -PI, PI)
	if absf(angle_error) <= deg_to_rad(0.5) and absf(angular_velocity) <= deg_to_rad(1.0):
		rotation = final_heading
		angular_velocity = 0.0
		is_orienting_to_final_heading = false
		_activate_current_waypoint()
		return
	var desired_angular_speed: float = minf(
		maximum_angular_speed,
		sqrt(2.0 * angular_acceleration * absf(angle_error))
	) * signf(angle_error)
	angular_velocity = move_toward(angular_velocity, desired_angular_speed, angular_acceleration * delta)
	rotation += angular_velocity * delta


func _draw() -> void:
	var unit_color := Color("59d8ff") if team_id == 0 else Color("ff5d6c")

	if team_id != 0 and intel_state == IntelState.HIDDEN:
		return
	if destroyed:
		draw_circle(Vector2.ZERO, 13.0, Color(0.25, 0.28, 0.32, 0.8))
		draw_line(Vector2(-9.0, -9.0), Vector2(9.0, 9.0), Color("ff704d"), 3.0)
		draw_line(Vector2(9.0, -9.0), Vector2(-9.0, 9.0), Color("ff704d"), 3.0)
		_draw_impact_flash()
		return
	if team_id != 0 and intel_state == IntelState.SIGNAL:
		draw_circle(contact_offset, 13.0, Color(1.0, 0.74, 0.28, 0.12))
		draw_arc(contact_offset, 13.0, 0.0, TAU, 24, Color("ffbd48"), 2.0)
		draw_line(contact_offset + Vector2(-5.0, 0.0), contact_offset + Vector2(5.0, 0.0), Color("ffbd48"), 1.0)
		return
	if team_id != 0 and intel_state == IntelState.TRACKED:
		var tracked_shape := PackedVector2Array([
			Vector2(0.0, -11.0), Vector2(11.0, 0.0),
			Vector2(0.0, 11.0), Vector2(-11.0, 0.0),
		])
		draw_polyline(tracked_shape + PackedVector2Array([tracked_shape[0]]), Color("ff9f43"), 2.0)
		_draw_impact_flash()
		return

	var forward := Vector2(0.0, -BODY_RADIUS - 4.0)
	var left := Vector2(-BODY_RADIUS, BODY_RADIUS)
	var right := Vector2(BODY_RADIUS, BODY_RADIUS)

	draw_colored_polygon(PackedVector2Array([forward, right, left]), unit_color)
	draw_circle(Vector2.ZERO, 3.0, Color("eafaff"))
	_draw_launcher_status()

	if selected:
		draw_arc(Vector2.ZERO, SELECTION_RADIUS, 0.0, TAU, 32, Color("9bf0ff"), 2.0)
		draw_arc(Vector2.ZERO, sensor_range, 0.0, TAU, 96, Color(0.35, 0.85, 1.0, 0.18), 1.0)
		if sensor_mode == SensorMode.ACTIVE:
			draw_arc(Vector2.ZERO, active_sensor_range, 0.0, TAU, 112, Color(1.0, 0.42, 0.88, 0.28), 1.5)
		if unit_profile.provides_fire_control:
			draw_arc(Vector2.ZERO, unit_profile.fire_control_share_range, 0.0, TAU, 112, Color(0.45, 1.0, 0.62, 0.30), 1.5)
		if unit_profile.missile_launch_range > 0.0:
			draw_arc(Vector2.ZERO, unit_profile.missile_launch_range, 0.0, TAU, 96, Color(1.0, 0.72, 0.30, 0.28), 1.5)
		draw_arc(Vector2.ZERO, point_defense_range, 0.0, TAU, 64, Color(1.0, 0.45, 0.30, 0.30), 1.0)
		var local_velocity_tip := to_local(global_position + velocity * 0.55)
		draw_line(Vector2.ZERO, local_velocity_tip, Color(0.55, 1.0, 0.72, 0.75), 2.0)
		_draw_navigation_route()
	elif has_move_target:
		draw_line(Vector2.ZERO, to_local(move_target), Color(0.35, 0.85, 1.0, 0.32), 1.0)
	if defense_fire_remaining > 0.0:
		draw_line(Vector2.ZERO, to_local(defense_target_position), Color("ffec8b"), 2.0)
	_draw_health_bar()
	_draw_impact_flash()


func _draw_launcher_status() -> void:
	if missile_launcher_count <= 0:
		if unit_profile.provides_fire_control:
			draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 20, Color("8dffaf"), 1.5)
			draw_line(Vector2(-10.0, 5.0), Vector2(10.0, 5.0), Color("8dffaf"), 1.5)
		return
	var spacing: float = 11.0
	var row_width: float = float(missile_launcher_count - 1) * spacing
	for launcher_index: int in missile_launcher_count:
		var marker_position := Vector2(float(launcher_index) * spacing - row_width * 0.5, -21.0)
		draw_circle(marker_position, 4.0, Color(0.04, 0.07, 0.10, 0.95))
		if launcher_loaded[launcher_index]:
			var ready_color := Color("7dff8a") if weapon_cooldown_remaining <= 0.0 else Color("579b68")
			draw_circle(marker_position, 2.5, ready_color)
			draw_arc(marker_position, 4.0, 0.0, TAU, 18, ready_color, 1.4)
		elif launcher_loading_remaining[launcher_index] > 0.0:
			var progress: float = 1.0 - launcher_loading_remaining[launcher_index] / missile_loading_time
			draw_arc(marker_position, 4.0, 0.0, TAU, 18, Color("ffbd48"), 1.0)
			draw_arc(marker_position, 4.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 18, Color("ffe28a"), 2.2)
		else:
			draw_arc(marker_position, 4.0, 0.0, TAU, 18, Color("a63d4a"), 1.4)


func _draw_navigation_route() -> void:
	if navigation_route.is_empty():
		return
	var route_points := PackedVector2Array([Vector2.ZERO])
	for waypoint: NavigationWaypoint in navigation_route:
		route_points.append(to_local(waypoint.position))
	draw_polyline(route_points, Color(0.35, 0.85, 1.0, 0.48), 1.5)
	for waypoint: NavigationWaypoint in navigation_route:
		var local_point := to_local(waypoint.position)
		var waypoint_color := Color("8dffaf") if waypoint.passage_mode == NavigationWaypoint.PassageMode.FLY_THROUGH else Color("9bf0ff")
		draw_circle(local_point, 4.0, Color(waypoint_color, 0.22))
		draw_arc(local_point, 4.0, 0.0, TAU, 16, waypoint_color, 1.5)
		if waypoint.has_final_heading:
			var heading_tip := to_local(waypoint.position + Vector2.UP.rotated(waypoint.final_heading) * 24.0)
			draw_line(local_point, heading_tip, waypoint_color, 2.0)


func _draw_impact_flash() -> void:
	if impact_flash_remaining <= 0.0:
		return
	var intensity: float = impact_flash_remaining / 0.35
	draw_circle(Vector2.ZERO, 22.0 * intensity, Color(1.0, 0.45, 0.18, intensity))


func _draw_health_bar() -> void:
	var ratio: float = hull / maximum_hull
	draw_rect(Rect2(-14.0, 18.0, 28.0, 3.0), Color(0.08, 0.10, 0.13, 0.9))
	draw_rect(Rect2(-14.0, 18.0, 28.0 * ratio, 3.0), Color("7dff8a" if ratio > 0.4 else "ff704d"))
	var heat_ratio: float = get_heat_ratio()
	var heat_color := Color("69d9ff").lerp(Color("ff5d3d"), heat_ratio)
	draw_rect(Rect2(-14.0, 23.0, 28.0, 2.5), Color(0.08, 0.10, 0.13, 0.9))
	draw_rect(Rect2(-14.0, 23.0, 28.0 * heat_ratio, 2.5), heat_color)
