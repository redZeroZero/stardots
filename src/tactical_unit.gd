class_name TacticalUnit
extends Node2D

enum IntelState {
	HIDDEN,
	SIGNAL,
	TRACKED,
	IDENTIFIED,
}

enum ClassificationState {
	UNKNOWN,
	ESTIMATED,
	CONFIRMED,
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

enum DatalinkEmissionMode {
	SILENT,
	TRACK_SHARING,
	FIRE_CONTROL,
}

const BODY_RADIUS: float = 9.0
const SELECTION_RADIUS: float = 15.0
const IDENTIFIED_SYMBOL_EXTENT_MULTIPLIER: float = 1.45
const ATTITUDE_CORRECTION_DEADZONE: float = 1.0

var callsign: String = "UNIT"
var team_id: int = 0
var team_roster_index: int = -1
var tactical_group_id: int = 0
var unit_profile: UnitProfile
var weapon_system_profiles: Array[WeaponSystemProfile] = []
var weapon_system_ammunition: Dictionary = {}
var weapon_system_cooldowns: Dictionary = {}
var weapon_turret_angles: Dictionary = {}
var weapon_turret_aim_points: Dictionary = {}
var move_speed: float = 95.0
var maximum_acceleration: float = 38.0
var propulsion_doctrine: UnitProfile.PropulsionDoctrine = UnitProfile.PropulsionDoctrine.HOLD_ATTITUDE
var forward_thrust_multiplier: float = 1.0
var retrograde_thrust_multiplier: float = 1.0
var lateral_thrust_multiplier: float = 1.0
var hybrid_flip_threshold: float = 0.65
var hybrid_turn_speed_ratio: float = 0.65
var maximum_angular_speed: float = deg_to_rad(100.0)
var angular_acceleration: float = deg_to_rad(180.0)
var arrival_radius: float = 5.0
var station_keeping_speed: float = 8.0
var preferred_turn_radius: float = 90.0
var turn_anticipation: float = 0.75
var sensor_range: float = 378.0
var active_sensor_range: float = 1008.0
var active_emission_detection_range: float = 720.0
var active_sensor_heat_per_second: float = 3.0
var minimum_passive_signature: float = 1.0
var sensor_mode: SensorMode = SensorMode.PASSIVE
var datalink_emission_mode: DatalinkEmissionMode = DatalinkEmissionMode.SILENT
var heat_capacity: float = 100.0
var heat: float = 20.0
var passive_cooling_per_second: float = 2.5
var silent_cooling_multiplier: float = 0.20
var combat_cooling_multiplier: float = 2.0
var silent_radiator_signature: float = 0.05
var normal_radiator_signature: float = 0.15
var combat_radiator_signature: float = 0.45
var thermal_mode: ThermalMode = ThermalMode.NORMAL
var baseline_thermal_signature: float = 0.60
var stored_heat_signature_multiplier: float = 1.25
var engine_signature_multiplier: float = 0.50
var maximum_thermal_signature: float = 2.50
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
var active_leg_plan: NavigationLegPlan
var maneuver_phase: NavigationLegPlan.Phase = NavigationLegPlan.Phase.CRUISE
var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var has_move_target: bool = false
var is_orienting_to_final_heading: bool = false
var final_heading: float = 0.0
var selected: bool = false
var show_support_ranges: bool = true
var show_individual_weapon_ranges: bool = false
var show_navigation_route: bool = true
var intel_state: IntelState = IntelState.IDENTIFIED
var contact_uncertainty_radius: float = 0.0
var contact_offset: Vector2 = Vector2.ZERO
var contact_pulse_elapsed: float = 0.0
var contact_designation: String = ""
var contact_classification_state: ClassificationState = ClassificationState.UNKNOWN
var contact_classification_label: String = ""
var impact_flash_remaining: float = 0.0
var defense_fire_remaining: float = 0.0
var defense_target_position: Vector2 = Vector2.ZERO
var destroyed: bool = false
var invulnerable: bool = false
var fixed_in_place: bool = false
var is_returning_to_theater: bool = false
var visual_zoom: float = 1.0
var hybrid_flip_active: bool = false
var formation_guidance_active: bool = false
var formation_target_position: Vector2 = Vector2.ZERO
var formation_target_velocity: Vector2 = Vector2.ZERO


func configure(new_callsign: String, new_team_id: int, start_position: Vector2, profile: UnitProfile) -> void:
	callsign = new_callsign
	team_id = new_team_id
	unit_profile = profile
	weapon_system_profiles = profile.weapon_system_profiles.duplicate()
	weapon_system_ammunition.clear()
	weapon_system_cooldowns.clear()
	weapon_turret_angles.clear()
	weapon_turret_aim_points.clear()
	for system: WeaponSystemProfile in weapon_system_profiles:
		weapon_system_ammunition[system] = maxi(0, system.ammunition_capacity)
		weapon_system_cooldowns[system] = 0.0
		if system.mount_profile != null and system.mount_profile.traversable:
			weapon_turret_angles[system] = deg_to_rad(system.mount_profile.arc_center_degrees)
	add_to_group("tactical_units")
	position = start_position
	move_target = start_position
	var propulsion: PropulsionProfile = profile.propulsion_profile
	var drive_acceleration: float = propulsion.drive_acceleration if propulsion != null else profile.drive_acceleration
	move_speed = propulsion.tactical_speed_limit if propulsion != null else profile.tactical_speed_limit
	maximum_acceleration = minf(drive_acceleration, profile.crew_safe_acceleration) if profile.crewed else drive_acceleration
	propulsion_doctrine = propulsion.doctrine if propulsion != null else profile.propulsion_doctrine
	forward_thrust_multiplier = propulsion.forward_thrust_multiplier if propulsion != null else profile.forward_thrust_multiplier
	retrograde_thrust_multiplier = propulsion.retrograde_thrust_multiplier if propulsion != null else profile.retrograde_thrust_multiplier
	lateral_thrust_multiplier = propulsion.lateral_thrust_multiplier if propulsion != null else profile.lateral_thrust_multiplier
	hybrid_flip_threshold = propulsion.hybrid_flip_threshold if propulsion != null else profile.hybrid_flip_threshold
	hybrid_turn_speed_ratio = propulsion.hybrid_turn_speed_ratio if propulsion != null else profile.hybrid_turn_speed_ratio
	hybrid_flip_active = false
	maximum_angular_speed = deg_to_rad(propulsion.maximum_angular_speed_degrees if propulsion != null else profile.maximum_angular_speed_degrees)
	angular_acceleration = deg_to_rad(propulsion.angular_acceleration_degrees if propulsion != null else profile.angular_acceleration_degrees)
	arrival_radius = profile.arrival_radius
	station_keeping_speed = profile.station_keeping_speed
	preferred_turn_radius = profile.preferred_turn_radius
	turn_anticipation = profile.turn_anticipation
	sensor_range = profile.sensor_range
	active_sensor_range = profile.active_sensor_range
	active_emission_detection_range = profile.active_emission_detection_range
	active_sensor_heat_per_second = profile.active_sensor_heat_per_second
	minimum_passive_signature = profile.minimum_passive_signature
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
	maximum_thermal_signature = profile.maximum_thermal_signature
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


func set_range_visualization(show_support: bool, show_weapons: bool) -> void:
	if show_support_ranges == show_support and show_individual_weapon_ranges == show_weapons:
		return
	show_support_ranges = show_support
	show_individual_weapon_ranges = show_weapons
	queue_redraw()


func set_visual_zoom(value: float) -> void:
	var clamped_value: float = maxf(value, 0.001)
	if is_equal_approx(visual_zoom, clamped_value):
		return
	visual_zoom = clamped_value
	queue_redraw()


func set_move_target(target: Vector2) -> void:
	set_navigation_order(target)


func cut_engines() -> void:
	navigation_route.clear()
	has_move_target = false
	is_orienting_to_final_heading = false
	hybrid_flip_active = false
	formation_guidance_active = false
	queue_redraw()


func set_formation_target(target_position: Vector2, target_velocity: Vector2) -> void:
	formation_target_position = target_position
	formation_target_velocity = target_velocity.limit_length(move_speed)
	formation_guidance_active = true
	navigation_route.clear()
	has_move_target = false
	is_orienting_to_final_heading = false
	queue_redraw()


func clear_formation_target() -> void:
	formation_guidance_active = false
	hybrid_flip_active = false


func toggle_sensor_mode() -> void:
	sensor_mode = SensorMode.ACTIVE if sensor_mode == SensorMode.PASSIVE else SensorMode.PASSIVE
	queue_redraw()


func get_sensor_mode_name() -> String:
	return "ACTIF" if sensor_mode == SensorMode.ACTIVE else "PASSIF"


func set_datalink_emission_mode(value: DatalinkEmissionMode) -> void:
	datalink_emission_mode = value


func can_receive_data() -> bool:
	return unit_profile.data_link_profile != null and unit_profile.data_link_profile.can_receive


func can_transmit_data() -> bool:
	return unit_profile.data_link_profile != null and unit_profile.data_link_profile.can_transmit


func can_relay_data() -> bool:
	return unit_profile.data_link_profile != null and unit_profile.data_link_profile.can_relay


func can_bridge_tactical_groups() -> bool:
	return (
		unit_profile.data_link_profile != null
		and unit_profile.data_link_profile.can_bridge_groups
	)


func provides_fire_control_data() -> bool:
	return (
		unit_profile.data_link_profile != null
		and unit_profile.data_link_profile.provides_fire_control
	)


func get_data_link_range() -> float:
	return (
		maxf(0.0, unit_profile.data_link_profile.transmission_range)
		if unit_profile.data_link_profile != null
		else 0.0
	)


func get_data_link_role_name() -> String:
	if unit_profile.data_link_profile == null:
		return "ISOLÉ"
	if provides_fire_control_data() and can_relay_data():
		return "RELAIS + CONDUITE"
	if can_relay_data():
		return "RELAIS"
	if can_receive_data() and can_transmit_data():
		return "TRANSCEIVER"
	if can_receive_data():
		return "RÉCEPTEUR"
	if can_transmit_data():
		return "ÉMETTEUR"
	return "ISOLÉ"


func get_electromagnetic_signature() -> float:
	var radar_emission: float = (
		unit_profile.active_radar_emission_strength
		if sensor_mode == SensorMode.ACTIVE
		else 0.0
	)
	var link_emission: float = 0.0
	var link_profile: DataLinkProfile = unit_profile.data_link_profile
	if link_profile != null and datalink_emission_mode == DatalinkEmissionMode.TRACK_SHARING:
		link_emission = link_profile.track_emission_strength
	elif link_profile != null and datalink_emission_mode == DatalinkEmissionMode.FIRE_CONTROL:
		link_emission = link_profile.fire_control_emission_strength
	return maxf(radar_emission, link_emission)


func get_electromagnetic_emission_name() -> String:
	if sensor_mode == SensorMode.ACTIVE and datalink_emission_mode == DatalinkEmissionMode.FIRE_CONTROL:
		return "RADAR + CONDUITE"
	if sensor_mode == SensorMode.ACTIVE:
		return "RADAR ACTIF"
	if datalink_emission_mode == DatalinkEmissionMode.FIRE_CONTROL:
		return "CONDUITE DE TIR"
	if datalink_emission_mode == DatalinkEmissionMode.TRACK_SHARING:
		return "PARTAGE PISTES"
	return "SILENCE RADIO"


func get_propulsion_doctrine_name() -> String:
	match propulsion_doctrine:
		UnitProfile.PropulsionDoctrine.FLIP_AND_BURN:
			return "FLIP-AND-BURN"
		UnitProfile.PropulsionDoctrine.HYBRID:
			return "HYBRIDE"
		_:
			return "CAP MAINTENU"


func get_maneuver_phase_name() -> String:
	if not has_move_target:
		return "CAP FINAL" if is_orienting_to_final_heading else "INERTIE"
	match maneuver_phase:
		NavigationLegPlan.Phase.ACCELERATE:
			return "ACCÉLÉRATION"
		NavigationLegPlan.Phase.RETRO_BRAKE:
			return "RÉTROFREINAGE"
		NavigationLegPlan.Phase.TURN:
			return "RETOURNEMENT"
		NavigationLegPlan.Phase.BRAKE:
			return "FREINAGE"
		_:
			return "CROISIÈRE"


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
	formation_guidance_active = false
	var route_was_active: bool = has_move_target and not navigation_route.is_empty()
	if not append:
		if has_move_target and navigation_route.size() == 1 and move_target.distance_to(target) <= 0.5:
			var current_waypoint: NavigationWaypoint = navigation_route[0]
			var same_heading: bool = (
				current_waypoint.has_final_heading == has_requested_final_heading
				and (
					not has_requested_final_heading
					or absf(angle_difference(
						current_waypoint.final_heading,
						requested_final_heading
					)) <= 0.001
				)
			)
			if same_heading:
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
	hybrid_flip_active = false
	_recalculate_route_plan()
	if not append or not route_was_active:
		active_leg_origin = global_position
		_activate_current_waypoint()
	queue_redraw()


func _activate_current_waypoint() -> void:
	if navigation_route.is_empty():
		has_move_target = false
		active_leg_plan = null
		return
	move_target = navigation_route[0].position
	has_move_target = true
	_refresh_active_leg_plan()


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
	if has_move_target:
		_refresh_active_leg_plan()


func _refresh_active_leg_plan() -> void:
	if navigation_route.is_empty():
		active_leg_plan = null
		return
	var waypoint: NavigationWaypoint = navigation_route[0]
	var travel_direction: Vector2 = active_leg_origin.direction_to(waypoint.position)
	var start_speed: float = maxf(0.0, velocity.dot(travel_direction)) if travel_direction != Vector2.ZERO else velocity.length()
	var flip_required: bool = false
	if waypoint.passage_mode == NavigationWaypoint.PassageMode.HOLD:
		flip_required = propulsion_doctrine == UnitProfile.PropulsionDoctrine.FLIP_AND_BURN
		if propulsion_doctrine == UnitProfile.PropulsionDoctrine.HYBRID:
			flip_required = retrograde_thrust_multiplier < hybrid_flip_threshold
	var braking_multiplier: float = forward_thrust_multiplier if flip_required else retrograde_thrust_multiplier
	if waypoint.passage_mode == NavigationWaypoint.PassageMode.FLY_THROUGH:
		braking_multiplier = maxf(forward_thrust_multiplier, maxf(retrograde_thrust_multiplier, lateral_thrust_multiplier))
	var flip_duration: float = NavigationLegPlan.half_turn_duration(maximum_angular_speed, angular_acceleration) if flip_required else 0.0
	var pre_turn_braking_acceleration: float = 0.0
	var turn_speed_ratio: float = 1.0
	if flip_required and propulsion_doctrine == UnitProfile.PropulsionDoctrine.HYBRID:
		pre_turn_braking_acceleration = maximum_acceleration * maxf(0.05, retrograde_thrust_multiplier)
		turn_speed_ratio = hybrid_turn_speed_ratio
	active_leg_plan = NavigationLegPlan.calculate(
		active_leg_origin.distance_to(waypoint.position),
		start_speed,
		move_speed,
		waypoint.planned_speed,
		maximum_acceleration * maxf(0.05, forward_thrust_multiplier),
		maximum_acceleration * maxf(0.05, braking_multiplier),
		flip_duration,
		flip_required,
		pre_turn_braking_acceleration,
		turn_speed_ratio
	)
	maneuver_phase = active_leg_plan.phase(active_leg_plan.distance, start_speed)


func set_intel_state(value: IntelState, uncertainty_offset: Vector2 = Vector2.ZERO) -> void:
	if intel_state == value and contact_offset == uncertainty_offset:
		return
	if value == IntelState.SIGNAL and intel_state != IntelState.SIGNAL:
		contact_pulse_elapsed = 0.0
	intel_state = value
	contact_offset = uncertainty_offset
	queue_redraw()


func set_sensor_contact(
	value: IntelState,
	estimated_position: Vector2,
	uncertainty_radius: float,
	designation: String = "",
	classification_state: ClassificationState = ClassificationState.UNKNOWN,
	classification_label: String = ""
) -> void:
	var offset: Vector2 = estimated_position - global_position
	if (
		intel_state == value
		and contact_offset.distance_to(offset) <= 0.01
		and is_equal_approx(contact_uncertainty_radius, uncertainty_radius)
		and contact_designation == designation
		and contact_classification_state == classification_state
		and contact_classification_label == classification_label
	):
		return
	if value == IntelState.SIGNAL and intel_state != IntelState.SIGNAL:
		contact_pulse_elapsed = 0.0
	intel_state = value
	contact_offset = offset
	contact_uncertainty_radius = maxf(0.0, uncertainty_radius)
	contact_designation = designation
	contact_classification_state = classification_state
	contact_classification_label = classification_label
	queue_redraw()


func get_contact_label() -> String:
	var designation: String = contact_designation if not contact_designation.is_empty() else "BANDIT"
	if (
		contact_classification_state == ClassificationState.UNKNOWN
		or contact_classification_label.is_empty()
	):
		return designation
	if contact_classification_state == ClassificationState.ESTIMATED:
		return "%s — %s ?" % [designation, contact_classification_label]
	return "%s — %s" % [designation, contact_classification_label]


func contains_world_point(world_point: Vector2) -> bool:
	var click_radius: float = TacticalPresentation.compensated_radius(
		SELECTION_RADIUS,
		TacticalPresentation.MINIMUM_CLICK_RADIUS_PX * 2.0,
		visual_zoom
	)
	return not destroyed and global_position.distance_to(world_point) <= click_radius


func is_targetable_contact() -> bool:
	return not destroyed and team_id != 0 and intel_state >= IntelState.TRACKED


func has_guidance_track() -> bool:
	return not destroyed and intel_state >= IntelState.TRACKED


func can_launch_weapon() -> bool:
	return not destroyed and not is_weapons_overheated() and weapon_cooldown_remaining <= 0.0 and get_ready_launcher_count() > 0


func can_launch_weapon_at(target_position: Vector2) -> bool:
	var system: WeaponSystemProfile = get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_SHIP
	)
	if system == null and not weapon_system_profiles.is_empty():
		return false
	if system != null and system.feed_type == WeaponSystemProfile.FeedType.FIXED_CELLS:
		return can_fire_weapon_system(system, target_position)
	return can_launch_weapon() and can_weapon_system_engage(system, target_position)


func mark_anti_ship_missile_launched(target_position: Vector2) -> void:
	consume_anti_ship_missiles(target_position, 1)


func get_anti_ship_burst_capacity() -> int:
	var system: WeaponSystemProfile = get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_SHIP
	)
	if system != null and system.feed_type == WeaponSystemProfile.FeedType.FIXED_CELLS:
		return mini(system.launcher_count, get_weapon_system_ammunition(system))
	return get_ready_launcher_count()


func consume_anti_ship_missiles(target_position: Vector2, requested_count: int) -> int:
	var system: WeaponSystemProfile = get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_SHIP
	)
	var count: int = mini(maxi(0, requested_count), get_anti_ship_burst_capacity())
	if count <= 0:
		return 0
	if system != null and system.feed_type == WeaponSystemProfile.FeedType.FIXED_CELLS:
		weapon_system_ammunition[system] = get_weapon_system_ammunition(system) - count
		weapon_system_cooldowns[system] = maxf(0.0, system.fire_interval)
		trigger_combat_thermal_mode()
		_add_heat(system.heat_per_shot * float(count))
		defense_target_position = target_position
		defense_fire_remaining = 0.10
		queue_redraw()
		return count
	var consumed: int = 0
	for launcher_index: int in missile_launcher_count:
		if consumed >= count:
			break
		if launcher_loaded[launcher_index]:
			launcher_loaded[launcher_index] = false
			consumed += 1
	missiles_remaining -= consumed
	weapon_cooldown_remaining = weapon_cooldown
	trigger_combat_thermal_mode()
	_add_heat(missile_launch_heat * float(consumed))
	_start_available_launcher_loads()
	queue_redraw()
	return consumed


func get_weapon_system(family: WeaponSystemProfile.Family, tactical_role: int = -1) -> WeaponSystemProfile:
	for system: WeaponSystemProfile in weapon_system_profiles:
		if system == null or system.family != family:
			continue
		if tactical_role < 0 or system.tactical_role == tactical_role:
			return system
	return null


func can_weapon_system_engage(system: WeaponSystemProfile, target_position: Vector2) -> bool:
	if system == null:
		return true
	var distance: float = global_position.distance_to(target_position)
	return system.is_in_range(distance) and is_position_in_mount_arc(system.mount_profile, target_position)


func can_fire_weapon_system(system: WeaponSystemProfile, target_position: Vector2) -> bool:
	if destroyed or is_weapons_overheated() or system == null:
		return false
	if float(weapon_system_cooldowns.get(system, 0.0)) > 0.0:
		return false
	if system.feed_type != WeaponSystemProfile.FeedType.ENERGY and int(weapon_system_ammunition.get(system, 0)) <= 0:
		return false
	request_weapon_aim(system, target_position)
	return can_weapon_system_engage(system, target_position) and is_weapon_system_aligned(system, target_position)


func request_weapon_aim(system: WeaponSystemProfile, target_position: Vector2) -> void:
	if system == null or system.mount_profile == null or not system.mount_profile.traversable:
		return
	weapon_turret_aim_points[system] = target_position


func is_weapon_system_aligned(system: WeaponSystemProfile, target_position: Vector2) -> bool:
	if system == null or system.mount_profile == null or not system.mount_profile.traversable:
		return true
	var target_direction: Vector2 = global_position.direction_to(target_position)
	if target_direction == Vector2.ZERO:
		return true
	var forward: Vector2 = Vector2.UP.rotated(rotation)
	var target_bearing: float = forward.angle_to(target_direction)
	var turret_bearing: float = float(weapon_turret_angles.get(system, 0.0))
	return absf(wrapf(target_bearing - turret_bearing, -PI, PI)) <= deg_to_rad(system.mount_profile.firing_tolerance_degrees)


func mark_weapon_system_fired(system: WeaponSystemProfile, aim_point: Vector2) -> void:
	if not can_fire_weapon_system(system, aim_point):
		return
	if system.feed_type != WeaponSystemProfile.FeedType.ENERGY:
		weapon_system_ammunition[system] = int(weapon_system_ammunition.get(system, 0)) - 1
	weapon_system_cooldowns[system] = maxf(0.0, system.fire_interval)
	trigger_combat_thermal_mode()
	_add_heat(system.heat_per_shot)
	defense_target_position = aim_point
	defense_fire_remaining = 0.10
	queue_redraw()


func consume_weapon_system_salvo(
	system: WeaponSystemProfile,
	aim_point: Vector2,
	requested_count: int
) -> int:
	if not can_fire_weapon_system(system, aim_point):
		return 0
	var available: int = get_weapon_system_ammunition(system)
	var consumed: int = mini(maxi(0, requested_count), mini(system.launcher_count, available))
	if consumed <= 0:
		return 0
	weapon_system_ammunition[system] = available - consumed
	weapon_system_cooldowns[system] = maxf(0.0, system.fire_interval)
	trigger_combat_thermal_mode()
	_add_heat(system.heat_per_shot * float(consumed))
	defense_target_position = aim_point
	defense_fire_remaining = 0.10
	queue_redraw()
	return consumed


func get_weapon_system_ammunition(system: WeaponSystemProfile) -> int:
	return int(weapon_system_ammunition.get(system, 0))


func get_weapon_system_summary() -> String:
	if weapon_system_profiles.is_empty():
		return "ARMEMENT INTÉGRÉ"
	var entries: PackedStringArray = []
	for system: WeaponSystemProfile in weapon_system_profiles:
		var availability := "ÉNERGIE" if system.feed_type == WeaponSystemProfile.FeedType.ENERGY else "%d/%d" % [
			get_weapon_system_ammunition(system), system.ammunition_capacity,
		]
		if system.mount_profile != null and system.mount_profile.traversable:
			availability += " CAP %.0f°" % rad_to_deg(float(weapon_turret_angles.get(system, 0.0)))
		entries.append("%s %s" % [system.display_name.to_upper(), availability])
	return " • ".join(entries)


func is_position_in_mount_arc(mount: WeaponMountProfile, target_position: Vector2) -> bool:
	if mount == null or mount.arc_width_degrees >= 359.9:
		return true
	var target_direction: Vector2 = global_position.direction_to(target_position)
	if target_direction == Vector2.ZERO:
		return true
	var forward: Vector2 = Vector2.UP.rotated(rotation)
	return mount.covers_relative_bearing(forward.angle_to(target_direction))


func get_anti_ship_missile_profile() -> MissileProfile:
	var system: WeaponSystemProfile = get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_SHIP
	)
	return system.missile_profile if system != null and system.missile_profile != null else null


func get_anti_ship_missile_range() -> float:
	var system: WeaponSystemProfile = get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_SHIP
	)
	if system != null:
		return system.maximum_range
	return 0.0 if not weapon_system_profiles.is_empty() else unit_profile.missile_launch_range


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
	elif (
		sensor_mode == SensorMode.ACTIVE
		or has_move_target
		or velocity.length() > stationary_speed_threshold
	):
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
	return clampf(
		baseline_thermal_signature
		+ get_heat_ratio() * stored_heat_signature_multiplier
		+ engine_signature_activity * engine_signature_multiplier
		+ radiator_signature,
		0.1,
		maximum_thermal_signature
	)


func get_passive_detection_signature() -> float:
	return maxf(minimum_passive_signature, get_thermal_signature())


func is_weapons_overheated() -> bool:
	return get_heat_ratio() >= weapon_overheat_threshold


func apply_fragment_damage(amount: float) -> void:
	if destroyed or amount <= 0.0:
		return
	trigger_combat_thermal_mode()
	impact_flash_remaining = 0.35
	if invulnerable:
		queue_redraw()
		return
	hull = maxf(0.0, hull - amount)
	if hull <= 0.0:
		destroyed = true
		has_move_target = false
		navigation_route.clear()
		is_orienting_to_final_heading = false
		formation_guidance_active = false
		selected = false
	queue_redraw()


func can_fire_point_defense() -> bool:
	return not destroyed and not is_weapons_overheated() and point_defense_ammunition > 0 and point_defense_cooldown_remaining <= 0.0


func can_fire_point_defense_at(target_position: Vector2) -> bool:
	var system: WeaponSystemProfile = get_weapon_system(WeaponSystemProfile.Family.KINETIC_PDC)
	if system == null and not weapon_system_profiles.is_empty():
		return false
	request_weapon_aim(system, target_position)
	return (
		can_fire_point_defense()
		and can_weapon_system_engage(system, target_position)
		and is_weapon_system_aligned(system, target_position)
	)


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
	if intel_state == IntelState.SIGNAL:
		contact_pulse_elapsed = fposmod(
			contact_pulse_elapsed + delta,
			TacticalPresentation.CONTACT_PULSE_PERIOD
		)
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
	for system: WeaponSystemProfile in weapon_system_cooldowns.keys():
		var cooldown: float = float(weapon_system_cooldowns[system])
		if cooldown > 0.0:
			weapon_system_cooldowns[system] = maxf(0.0, cooldown - delta)
	_update_turret_tracking(delta)

	if destroyed:
		formation_guidance_active = false
		return
	if fixed_in_place:
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		has_move_target = false
		navigation_route.clear()
		is_orienting_to_final_heading = false
		formation_guidance_active = false
		if intel_state == IntelState.SIGNAL:
			queue_redraw()
		return

	if formation_guidance_active:
		_update_formation_guidance(delta)
	elif has_move_target:
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


func _update_formation_guidance(delta: float) -> void:
	var offset: Vector2 = formation_target_position - global_position
	var distance: float = offset.length()
	# Une correction proportionnelle amortit l'approche d'un emplacement mobile.
	# Un profil de freinage de waypoint provoquerait ici des flips répétés chaque
	# fois que l'emplacement est rafraîchi.
	var correction_speed: float = minf(move_speed, distance * 0.8)
	var correction_velocity := (
		offset.normalized() * correction_speed
		if distance > 0.001
		else Vector2.ZERO
	)
	var desired_velocity: Vector2 = (
		formation_target_velocity + correction_velocity
	).limit_length(move_speed)
	var velocity_error: Vector2 = desired_velocity - velocity
	var thrust_direction := (
		velocity_error.normalized()
		if velocity_error.length() > 0.01
		else Vector2.ZERO
	)
	var requested_acceleration: float = velocity_error.length() / maxf(delta, 0.0001)
	var route_direction: Vector2 = formation_target_velocity.normalized()
	if route_direction == Vector2.ZERO:
		route_direction = offset.normalized()
	if route_direction == Vector2.ZERO:
		route_direction = Vector2.UP.rotated(rotation)
	var facing_direction: Vector2 = _get_doctrine_facing_direction(
		route_direction,
		thrust_direction,
		velocity_error.length(),
		requested_acceleration
	)
	_rotate_toward_heading(facing_direction.angle() + PI * 0.5, delta)

	var thrust_multiplier: float = _directional_thrust_multiplier(thrust_direction)
	var available_acceleration: float = maximum_acceleration * thrust_multiplier
	var applied_acceleration: float = minf(available_acceleration, requested_acceleration)
	velocity += thrust_direction * applied_acceleration * delta
	var thrust_ratio: float = (
		applied_acceleration / maximum_acceleration
		if maximum_acceleration > 0.0
		else 0.0
	)
	if thrust_ratio > 0.01:
		_add_heat(propulsion_heat_per_second * thrust_ratio * delta)
		engine_signature_activity = maxf(engine_signature_activity, thrust_ratio)
	if velocity.length() > move_speed:
		velocity = velocity.normalized() * move_speed
	global_position += velocity * delta


func _update_turret_tracking(delta: float) -> void:
	for system: WeaponSystemProfile in weapon_turret_angles.keys():
		if not weapon_turret_aim_points.has(system):
			continue
		var aim_point: Vector2 = weapon_turret_aim_points[system]
		var target_direction: Vector2 = global_position.direction_to(aim_point)
		if target_direction == Vector2.ZERO:
			continue
		var forward: Vector2 = Vector2.UP.rotated(rotation)
		var desired_bearing: float = forward.angle_to(target_direction)
		var current_bearing: float = float(weapon_turret_angles[system])
		var maximum_step: float = deg_to_rad(system.mount_profile.traverse_rate_degrees) * delta
		weapon_turret_angles[system] = rotate_toward(current_bearing, desired_bearing, maximum_step)
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

	if active_leg_plan == null:
		_refresh_active_leg_plan()
	maneuver_phase = active_leg_plan.phase(distance_to_target, velocity.length())
	var desired_speed: float = active_leg_plan.cruise_speed
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.HOLD and maneuver_phase == NavigationLegPlan.Phase.RETRO_BRAKE:
		desired_speed = minf(
			active_leg_plan.cruise_speed,
			active_leg_plan.pre_turn_braking_speed_limit(distance_to_target)
		)
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.HOLD and maneuver_phase == NavigationLegPlan.Phase.BRAKE:
		desired_speed = active_leg_plan.braking_speed_limit(distance_to_target)
		var final_approach_speed: float = maxf(active_leg_plan.final_speed, distance_to_target * 0.8)
		desired_speed = minf(desired_speed, final_approach_speed)
	var desired_travel_direction: Vector2 = offset_to_target.normalized() if distance_to_target > 0.001 else Vector2.ZERO
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.FLY_THROUGH and incoming_direction != Vector2.ZERO:
		desired_travel_direction = incoming_direction
	var desired_velocity := desired_travel_direction * desired_speed
	var route_facing_direction: Vector2 = incoming_direction
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.HOLD and maneuver_phase == NavigationLegPlan.Phase.TURN:
		desired_velocity = velocity
		route_facing_direction = -incoming_direction
	elif current_waypoint.passage_mode == NavigationWaypoint.PassageMode.HOLD and active_leg_plan.requires_flip and maneuver_phase == NavigationLegPlan.Phase.BRAKE:
		route_facing_direction = -incoming_direction
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.FLY_THROUGH and navigation_route.size() > 1:
		var outgoing_direction: Vector2 = current_waypoint.position.direction_to(navigation_route[1].position)
		var exit_velocity: Vector2 = outgoing_direction * current_waypoint.planned_speed
		var required_velocity_change: float = desired_velocity.distance_to(exit_velocity)
		var maneuver_time: float = required_velocity_change / maximum_acceleration
		var anticipation_distance: float = maxf(arrival_radius * 2.0, velocity.length() * maneuver_time * turn_anticipation)
		var transition: float = clampf(1.0 - distance_to_target / anticipation_distance, 0.0, 1.0)
		var eased_transition: float = smoothstep(0.0, 1.0, transition)
		desired_velocity = desired_velocity.lerp(exit_velocity, eased_transition)
		route_facing_direction = incoming_direction.lerp(outgoing_direction, eased_transition).normalized()
	var velocity_error: Vector2 = desired_velocity - velocity
	var forward := Vector2.UP.rotated(rotation)
	var thrust_direction: Vector2 = velocity_error.normalized() if velocity_error.length() > 0.01 else Vector2.ZERO
	var requested_acceleration: float = velocity_error.length() / maxf(delta, 0.0001)
	var desired_facing_direction: Vector2 = route_facing_direction
	if desired_facing_direction == Vector2.ZERO:
		desired_facing_direction = desired_velocity.normalized() if desired_velocity != Vector2.ZERO else forward
	if current_waypoint.passage_mode == NavigationWaypoint.PassageMode.FLY_THROUGH:
		desired_facing_direction = _get_doctrine_facing_direction(
			desired_facing_direction,
			thrust_direction,
			velocity_error.length(),
			requested_acceleration
		)
	var desired_rotation: float = desired_facing_direction.angle() + PI * 0.5
	_rotate_toward_heading(desired_rotation, delta)

	var thrust_multiplier: float = _directional_thrust_multiplier(thrust_direction)
	var available_acceleration: float = maximum_acceleration * thrust_multiplier
	var applied_acceleration: float = minf(available_acceleration, requested_acceleration)
	velocity += thrust_direction * applied_acceleration * delta
	var thrust_ratio: float = applied_acceleration / maximum_acceleration if maximum_acceleration > 0.0 else 0.0
	if thrust_ratio > 0.01:
		_add_heat(propulsion_heat_per_second * thrust_ratio * delta)
		engine_signature_activity = maxf(engine_signature_activity, thrust_ratio)
	if velocity.length() > move_speed:
		velocity = velocity.normalized() * move_speed
	global_position += velocity * delta


func _get_doctrine_facing_direction(
	route_direction: Vector2,
	thrust_direction: Vector2,
	velocity_error_length: float,
	requested_acceleration: float
) -> Vector2:
	if thrust_direction == Vector2.ZERO or velocity_error_length <= ATTITUDE_CORRECTION_DEADZONE:
		hybrid_flip_active = false
		return route_direction
	if propulsion_doctrine == UnitProfile.PropulsionDoctrine.FLIP_AND_BURN:
		return thrust_direction
	if propulsion_doctrine == UnitProfile.PropulsionDoctrine.HYBRID:
		var requested_ratio: float = requested_acceleration / maxf(maximum_acceleration, 0.001)
		if hybrid_flip_active:
			if requested_ratio < hybrid_flip_threshold * 0.25:
				hybrid_flip_active = false
		elif requested_ratio >= hybrid_flip_threshold and _directional_thrust_multiplier(thrust_direction) < hybrid_flip_threshold:
			hybrid_flip_active = true
		if hybrid_flip_active:
			return thrust_direction
	return route_direction


func _directional_thrust_multiplier(thrust_direction: Vector2) -> float:
	if thrust_direction == Vector2.ZERO:
		return 0.0
	var forward: Vector2 = Vector2.UP.rotated(rotation)
	var axial_dot: float = forward.dot(thrust_direction)
	var axial_multiplier: float = forward_thrust_multiplier if axial_dot >= 0.0 else retrograde_thrust_multiplier
	var axial_component: float = absf(axial_dot) * axial_multiplier
	var lateral_component: float = absf(forward.cross(thrust_direction)) * lateral_thrust_multiplier
	return clampf(sqrt(axial_component * axial_component + lateral_component * lateral_component), 0.0, 1.0)


func _update_final_orientation(delta: float) -> void:
	if _rotate_toward_heading(final_heading, delta):
		is_orienting_to_final_heading = false
		_activate_current_waypoint()


func _rotate_toward_heading(target_heading: float, delta: float) -> bool:
	var angle_error: float = wrapf(target_heading - rotation, -PI, PI)
	var stopping_step: float = angular_acceleration * delta
	if absf(angle_error) <= deg_to_rad(0.25) and absf(angular_velocity) <= stopping_step:
		rotation = target_heading
		angular_velocity = 0.0
		return true
	var desired_angular_speed: float = minf(
		maximum_angular_speed,
		sqrt(2.0 * angular_acceleration * absf(angle_error))
	) * signf(angle_error)
	angular_velocity = move_toward(angular_velocity, desired_angular_speed, angular_acceleration * delta)
	var rotation_step: float = angular_velocity * delta
	if signf(rotation_step) == signf(angle_error) and absf(rotation_step) >= absf(angle_error):
		rotation = target_heading
		angular_velocity = 0.0
		return true
	rotation += rotation_step
	return false


func _draw() -> void:
	var unit_color := Color("59d8ff") if team_id == 0 else Color("ff5d6c")
	var detail_level := TacticalPresentation.detail_level(visual_zoom)
	var close_alpha: float = TacticalPresentation.close_detail_alpha(visual_zoom)
	var tactical_alpha: float = TacticalPresentation.tactical_detail_alpha(visual_zoom)
	var secondary_alpha: float = 1.0 - TacticalPresentation.strategic_detail_alpha(visual_zoom)
	var symbol_radius: float = TacticalPresentation.compensated_radius(
		BODY_RADIUS,
		TacticalPresentation.MINIMUM_UNIT_DIAMETER_PX,
		visual_zoom
	)
	var important_stroke: float = TacticalPresentation.stroke_width(2.0, visual_zoom)
	var halo_stroke: float = important_stroke + TacticalPresentation.world_size_for_screen_pixels(2.0, visual_zoom)
	var halo_color := Color(0.015, 0.025, 0.04, 0.88)

	if team_id != 0 and intel_state == IntelState.HIDDEN:
		return
	if destroyed:
		var destroyed_radius: float = maxf(13.0, symbol_radius)
		draw_circle(Vector2.ZERO, destroyed_radius, Color(0.25, 0.28, 0.32, 0.8))
		draw_line(Vector2(-destroyed_radius, -destroyed_radius), Vector2(destroyed_radius, destroyed_radius), Color("ff704d"), important_stroke)
		draw_line(Vector2(destroyed_radius, -destroyed_radius), Vector2(-destroyed_radius, destroyed_radius), Color("ff704d"), important_stroke)
		_draw_impact_flash()
		return
	if invulnerable:
		draw_arc(
			Vector2.ZERO,
			symbol_radius * 1.85,
			0.0,
			TAU,
			TacticalPresentation.circle_segments(symbol_radius * 1.85, visual_zoom),
			Color(0.72, 0.82, 0.92, 0.78),
			important_stroke
		)
	if team_id != 0 and intel_state == IntelState.SIGNAL:
		var signal_radius: float = maxf(13.0, symbol_radius)
		var blip_radius: float = maxf(
			signal_radius * 0.18,
			TacticalPresentation.world_size_for_screen_pixels(2.0, visual_zoom)
		)
		var phase_offset: float = float(posmod(callsign.hash(), 997)) / 997.0
		var pulse_phase: float = TacticalPresentation.contact_pulse_phase(
			contact_pulse_elapsed,
			phase_offset
		)
		var pulse_minimum: float = maxf(
			blip_radius * 1.8,
			TacticalPresentation.world_size_for_screen_pixels(4.0, visual_zoom)
		)
		var pulse_maximum: float = maxf(
			pulse_minimum + TacticalPresentation.world_size_for_screen_pixels(6.0, visual_zoom),
			minf(contact_uncertainty_radius, 240.0)
		)
		var pulse_radius: float = TacticalPresentation.contact_pulse_radius(
			pulse_minimum,
			pulse_maximum,
			pulse_phase
		)
		var pulse_alpha: float = TacticalPresentation.contact_pulse_alpha(pulse_phase)
		draw_circle(contact_offset, blip_radius * 1.8, halo_color)
		draw_circle(contact_offset, blip_radius, Color("ffbd48"))
		draw_arc(
			contact_offset,
			pulse_radius,
			0.0,
			TAU,
			TacticalPresentation.circle_segments(pulse_radius, visual_zoom),
			Color(1.0, 0.74, 0.28, 0.86 * pulse_alpha),
			important_stroke
		)
		return
	if team_id != 0 and intel_state == IntelState.TRACKED:
		var tracked_center: Vector2 = contact_offset
		var tracked_shape := PackedVector2Array([
			tracked_center + Vector2(0.0, -symbol_radius), tracked_center + Vector2(symbol_radius, 0.0),
			tracked_center + Vector2(0.0, symbol_radius), tracked_center + Vector2(-symbol_radius, 0.0),
		])
		draw_polyline(tracked_shape + PackedVector2Array([tracked_shape[0]]), halo_color, halo_stroke)
		draw_polyline(tracked_shape + PackedVector2Array([tracked_shape[0]]), Color("ff9f43"), important_stroke)
		_draw_impact_flash()
		return

	var forward := Vector2(0.0, -symbol_radius * IDENTIFIED_SYMBOL_EXTENT_MULTIPLIER)
	var left := Vector2(-symbol_radius, symbol_radius)
	var right := Vector2(symbol_radius, symbol_radius)
	if team_id == 0:
		var simplified_alpha: float = 1.0 - close_alpha
		if simplified_alpha > 0.01:
			draw_polyline(PackedVector2Array([left, forward, right]), Color(halo_color, halo_color.a * simplified_alpha), halo_stroke)
			draw_polyline(PackedVector2Array([left, forward, right]), Color(unit_color, simplified_alpha), important_stroke)
			draw_line(Vector2.ZERO, forward * 0.72, Color(halo_color, halo_color.a * simplified_alpha), halo_stroke)
			draw_line(Vector2.ZERO, forward * 0.72, Color(unit_color, simplified_alpha), important_stroke)
		if close_alpha > 0.01:
			draw_colored_polygon(PackedVector2Array([forward * 1.18, right * 1.18, left * 1.18]), Color(halo_color, halo_color.a * close_alpha))
			draw_colored_polygon(PackedVector2Array([forward, right, left]), Color(unit_color, close_alpha))
			draw_circle(Vector2.ZERO, 3.0, Color(0.92, 0.98, 1.0, close_alpha))
	else:
		draw_colored_polygon(PackedVector2Array([forward * 1.18, right * 1.18, left * 1.18]), halo_color)
		draw_colored_polygon(PackedVector2Array([forward, right, left]), unit_color)
	if close_alpha > 0.01:
		_draw_launcher_status(close_alpha)

	if selected:
		var selection_radius: float = TacticalPresentation.compensated_radius(
			SELECTION_RADIUS,
			TacticalPresentation.MINIMUM_SELECTION_DIAMETER_PX,
			visual_zoom
		)
		var selection_segments: int = TacticalPresentation.circle_segments(selection_radius, visual_zoom)
		draw_arc(Vector2.ZERO, selection_radius, 0.0, TAU, selection_segments, halo_color, halo_stroke)
		draw_arc(Vector2.ZERO, selection_radius, 0.0, TAU, selection_segments, Color("9bf0ff"), important_stroke)
		var range_stroke: float = TacticalPresentation.stroke_width(1.0, visual_zoom)
		var range_alpha_boost: float = 1.35 if detail_level == TacticalPresentation.DetailLevel.STRATEGIC else 1.0
		if show_support_ranges:
			draw_arc(Vector2.ZERO, sensor_range, 0.0, TAU, TacticalPresentation.circle_segments(sensor_range, visual_zoom), Color(0.35, 0.85, 1.0, 0.18 * range_alpha_boost), range_stroke)
			if sensor_mode == SensorMode.ACTIVE:
				draw_arc(Vector2.ZERO, active_sensor_range, 0.0, TAU, TacticalPresentation.circle_segments(active_sensor_range, visual_zoom), Color(1.0, 0.42, 0.88, 0.28 * range_alpha_boost), TacticalPresentation.stroke_width(1.5, visual_zoom))
			if provides_fire_control_data():
				draw_arc(Vector2.ZERO, get_data_link_range(), 0.0, TAU, TacticalPresentation.circle_segments(get_data_link_range(), visual_zoom), Color(0.45, 1.0, 0.62, 0.30 * range_alpha_boost), TacticalPresentation.stroke_width(1.5, visual_zoom))
		if show_individual_weapon_ranges:
			if weapon_system_profiles.is_empty():
				_draw_weapon_range_arc(null, unit_profile.missile_launch_range, Color(1.0, 0.72, 0.30, 0.28 * range_alpha_boost), range_stroke)
				_draw_weapon_range_arc(null, point_defense_range, Color(1.0, 0.45, 0.30, 0.30 * range_alpha_boost), range_stroke)
			else:
				for system: WeaponSystemProfile in weapon_system_profiles:
					_draw_weapon_range_arc(
						system,
						system.maximum_range,
						_weapon_arc_color(system, range_alpha_boost),
						range_stroke
					)
		var local_velocity_tip := to_local(global_position + velocity * 0.55)
		if detail_level == TacticalPresentation.DetailLevel.STRATEGIC and local_velocity_tip.length() > 0.01:
			local_velocity_tip = local_velocity_tip.normalized() * maxf(local_velocity_tip.length(), TacticalPresentation.world_size_for_screen_pixels(12.0, visual_zoom))
		draw_line(Vector2.ZERO, local_velocity_tip, Color(0.55, 1.0, 0.72, 0.75), important_stroke)
		if show_navigation_route:
			_draw_navigation_route()
	elif has_move_target and close_alpha > 0.01:
		draw_line(Vector2.ZERO, to_local(move_target), Color(0.35, 0.85, 1.0, 0.32 * close_alpha), 1.0)
	if defense_fire_remaining > 0.0 and secondary_alpha > 0.01:
		draw_line(Vector2.ZERO, to_local(defense_target_position), Color(1.0, 0.93, 0.55, secondary_alpha), important_stroke)
	if close_alpha > 0.01:
		_draw_health_bar(close_alpha)
	if tactical_alpha > 0.01 and hull < maximum_hull:
		_draw_compact_health(symbol_radius, tactical_alpha)
	if secondary_alpha > 0.01:
		_draw_impact_flash(secondary_alpha)


func _draw_weapon_range_arc(
	system: WeaponSystemProfile,
	fallback_range: float,
	color: Color,
	stroke: float
) -> void:
	var maximum_range: float = system.maximum_range if system != null else fallback_range
	if maximum_range <= 0.0:
		return
	var mount: WeaponMountProfile = system.mount_profile if system != null else null
	var arc_center: float = 0.0
	var arc_width: float = TAU
	if mount != null and mount.arc_width_degrees < 359.9:
		arc_center = -PI * 0.5 + deg_to_rad(mount.arc_center_degrees)
		arc_width = deg_to_rad(mount.arc_width_degrees)
	var start_angle: float = arc_center - arc_width * 0.5
	var end_angle: float = arc_center + arc_width * 0.5
	var segments: int = maxi(4, ceili(float(TacticalPresentation.circle_segments(maximum_range, visual_zoom)) * arc_width / TAU))
	draw_arc(Vector2.ZERO, maximum_range, start_angle, end_angle, segments, color, stroke)
	if arc_width < TAU - 0.01:
		draw_line(Vector2.ZERO, Vector2.from_angle(start_angle) * maximum_range, Color(color, color.a * 0.55), stroke)
		draw_line(Vector2.ZERO, Vector2.from_angle(end_angle) * maximum_range, Color(color, color.a * 0.55), stroke)
	if system != null and system.minimum_range > 0.0:
		draw_arc(Vector2.ZERO, system.minimum_range, start_angle, end_angle, segments, Color(color, color.a * 0.65), stroke)
	if mount != null and mount.traversable:
		var turret_bearing: float = float(weapon_turret_angles.get(system, deg_to_rad(mount.arc_center_degrees)))
		var turret_angle: float = -PI * 0.5 + turret_bearing
		var tolerance: float = deg_to_rad(mount.firing_tolerance_degrees)
		draw_line(
			Vector2.ZERO,
			Vector2.from_angle(turret_angle) * maximum_range,
			Color(color, minf(0.72, color.a * 2.0)),
			stroke * 1.35
		)
		draw_arc(
			Vector2.ZERO,
			maximum_range,
			turret_angle - tolerance,
			turret_angle + tolerance,
			4,
			Color(color, minf(0.9, color.a * 2.4)),
			stroke * 1.5
		)


func _weapon_arc_color(system: WeaponSystemProfile, alpha_boost: float) -> Color:
	match system.family:
		WeaponSystemProfile.Family.KINETIC_PDC:
			return Color(1.0, 0.45, 0.30, 0.30 * alpha_boost)
		WeaponSystemProfile.Family.LASER_PDC:
			return Color(0.35, 0.95, 1.0, 0.32 * alpha_boost)
		WeaponSystemProfile.Family.RAILGUN:
			return Color(0.78, 0.92, 1.0, 0.34 * alpha_boost)
		WeaponSystemProfile.Family.MISSILE:
			if system.tactical_role == WeaponSystemProfile.TacticalRole.INTERCEPTOR:
				return Color(0.55, 1.0, 0.62, 0.30 * alpha_boost)
			if system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_RADIATION:
				return Color(1.0, 0.35, 0.82, 0.32 * alpha_boost)
	return Color(1.0, 0.72, 0.30, 0.28 * alpha_boost)


func _draw_launcher_status(alpha: float = 1.0) -> void:
	if missile_launcher_count <= 0:
		if provides_fire_control_data():
			var awacs_color := Color(0.55, 1.0, 0.69, alpha)
			draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 20, awacs_color, 1.5)
			draw_line(Vector2(-10.0, 5.0), Vector2(10.0, 5.0), awacs_color, 1.5)
		return
	var spacing: float = 11.0
	var row_width: float = float(missile_launcher_count - 1) * spacing
	for launcher_index: int in missile_launcher_count:
		var marker_position := Vector2(float(launcher_index) * spacing - row_width * 0.5, -21.0)
		draw_circle(marker_position, 4.0, Color(0.04, 0.07, 0.10, 0.95 * alpha))
		if launcher_loaded[launcher_index]:
			var ready_color := Color("7dff8a") if weapon_cooldown_remaining <= 0.0 else Color("579b68")
			ready_color.a = alpha
			draw_circle(marker_position, 2.5, ready_color)
			draw_arc(marker_position, 4.0, 0.0, TAU, 18, ready_color, 1.4)
		elif launcher_loading_remaining[launcher_index] > 0.0:
			var progress: float = 1.0 - launcher_loading_remaining[launcher_index] / missile_loading_time
			draw_arc(marker_position, 4.0, 0.0, TAU, 18, Color(1.0, 0.74, 0.28, alpha), 1.0)
			draw_arc(marker_position, 4.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 18, Color(1.0, 0.89, 0.54, alpha), 2.2)
		else:
			draw_arc(marker_position, 4.0, 0.0, TAU, 18, Color(0.65, 0.24, 0.29, alpha), 1.4)


func _draw_navigation_route() -> void:
	if navigation_route.is_empty():
		return
	var route_points := PackedVector2Array([Vector2.ZERO])
	for waypoint: NavigationWaypoint in navigation_route:
		route_points.append(to_local(waypoint.position))
	var route_stroke: float = TacticalPresentation.stroke_width(1.5, visual_zoom)
	draw_polyline(route_points, Color(0.35, 0.85, 1.0, 0.58), route_stroke)
	_draw_flight_plan_markers(route_stroke)
	var waypoint_radius: float = TacticalPresentation.compensated_radius(
		4.0,
		TacticalPresentation.MINIMUM_WAYPOINT_DIAMETER_PX,
		visual_zoom
	)
	for waypoint_index: int in navigation_route.size():
		var waypoint: NavigationWaypoint = navigation_route[waypoint_index]
		var local_point := to_local(waypoint.position)
		var waypoint_color := Color("8dffaf") if waypoint.passage_mode == NavigationWaypoint.PassageMode.FLY_THROUGH else Color("9bf0ff")
		if waypoint_index == navigation_route.size() - 1:
			waypoint_color = Color("d7fbff")
		draw_circle(local_point, waypoint_radius, Color(waypoint_color, 0.22))
		draw_arc(local_point, waypoint_radius, 0.0, TAU, TacticalPresentation.circle_segments(waypoint_radius, visual_zoom), waypoint_color, route_stroke)
		if waypoint.has_final_heading:
			var heading_length: float = maxf(24.0, TacticalPresentation.world_size_for_screen_pixels(14.0, visual_zoom))
			var heading_direction := TacticalPresentation.local_direction_for_world_heading(
				waypoint.final_heading,
				global_rotation
			)
			var heading_tip := local_point + heading_direction * heading_length
			draw_line(local_point, heading_tip, waypoint_color, route_stroke)
			var arrow_size: float = TacticalPresentation.world_size_for_screen_pixels(4.0, visual_zoom)
			var arrow_base := heading_tip - heading_direction * arrow_size * 1.8
			draw_line(heading_tip, arrow_base + heading_direction.rotated(PI * 0.5) * arrow_size, waypoint_color, route_stroke)
			draw_line(heading_tip, arrow_base - heading_direction.rotated(PI * 0.5) * arrow_size, waypoint_color, route_stroke)


func _draw_flight_plan_markers(route_stroke: float) -> void:
	if active_leg_plan == null or navigation_route.is_empty():
		return
	var target_position: Vector2 = navigation_route[0].position
	var leg_direction: Vector2 = active_leg_origin.direction_to(target_position)
	if leg_direction == Vector2.ZERO:
		return
	var marker_size: float = TacticalPresentation.world_size_for_screen_pixels(5.0, visual_zoom)
	var minimum_spacing: float = TacticalPresentation.world_size_for_screen_pixels(11.0, visual_zoom)
	var world_axis_x: Vector2 = Vector2.RIGHT.rotated(-global_rotation)
	var world_axis_y: Vector2 = Vector2.DOWN.rotated(-global_rotation)
	var marker_positions: Array[Vector2] = []

	var acceleration_end: Vector2 = active_leg_origin + leg_direction * active_leg_plan.acceleration_distance
	_draw_phase_marker_if_ahead(
		acceleration_end, Color("7dff8a"), 0, marker_size, minimum_spacing,
		world_axis_x, world_axis_y, marker_positions, route_stroke
	)
	if active_leg_plan.pre_turn_braking_distance > 0.0:
		var retro_braking_position: Vector2 = target_position - leg_direction * active_leg_plan.pre_turn_braking_start_remaining
		_draw_phase_marker_if_ahead(
			retro_braking_position, Color("62e6ff"), 3, marker_size, minimum_spacing,
			world_axis_x, world_axis_y, marker_positions, route_stroke
		)
	if active_leg_plan.requires_flip:
		var flip_position: Vector2 = target_position - leg_direction * active_leg_plan.turn_start_remaining
		_draw_phase_marker_if_ahead(
			flip_position, Color("ff70d7"), 1, marker_size, minimum_spacing,
			world_axis_x, world_axis_y, marker_positions, route_stroke
		)
	var braking_position: Vector2 = target_position - leg_direction * active_leg_plan.braking_distance
	_draw_phase_marker_if_ahead(
		braking_position, Color("ffad5c"), 2, marker_size, minimum_spacing,
		world_axis_x, world_axis_y, marker_positions, route_stroke
	)


func _draw_phase_marker_if_ahead(
	world_position: Vector2,
	color: Color,
	shape: int,
	marker_size: float,
	minimum_spacing: float,
	axis_x: Vector2,
	axis_y: Vector2,
	drawn_positions: Array[Vector2],
	stroke: float
) -> void:
	var route_direction: Vector2 = active_leg_origin.direction_to(navigation_route[0].position)
	if (world_position - global_position).dot(route_direction) <= 0.0:
		return
	for drawn_position: Vector2 in drawn_positions:
		if world_position.distance_to(drawn_position) < minimum_spacing:
			return
	drawn_positions.append(world_position)
	var point: Vector2 = to_local(world_position)
	draw_circle(point, marker_size * 1.35, Color(color, 0.14))
	if shape == 0:
		draw_line(point - axis_x * marker_size, point + axis_x * marker_size, color, stroke)
		draw_line(point - axis_y * marker_size, point + axis_y * marker_size, color, stroke)
	elif shape == 1:
		var diamond := PackedVector2Array([
			point - axis_y * marker_size,
			point + axis_x * marker_size,
			point + axis_y * marker_size,
			point - axis_x * marker_size,
			point - axis_y * marker_size,
		])
		draw_polyline(diamond, color, stroke)
	elif shape == 2:
		var half_size: float = marker_size * 0.72
		var square := PackedVector2Array([
			point - axis_x * half_size - axis_y * half_size,
			point + axis_x * half_size - axis_y * half_size,
			point + axis_x * half_size + axis_y * half_size,
			point - axis_x * half_size + axis_y * half_size,
			point - axis_x * half_size - axis_y * half_size,
		])
		draw_polyline(square, color, stroke)
	else:
		var triangle := PackedVector2Array([
			point - axis_y * marker_size,
			point + axis_x * marker_size * 0.85 + axis_y * marker_size * 0.70,
			point - axis_x * marker_size * 0.85 + axis_y * marker_size * 0.70,
			point - axis_y * marker_size,
		])
		draw_polyline(triangle, color, stroke)


func _draw_compact_health(symbol_radius: float, alpha: float = 1.0) -> void:
	var ratio: float = hull / maximum_hull
	var width: float = maxf(symbol_radius * 2.0, TacticalPresentation.world_size_for_screen_pixels(10.0, visual_zoom))
	var height: float = TacticalPresentation.world_size_for_screen_pixels(2.0, visual_zoom)
	var top_left := Vector2(-width * 0.5, symbol_radius + height * 1.5)
	draw_rect(Rect2(top_left, Vector2(width, height)), Color(0.08, 0.10, 0.13, 0.9 * alpha))
	var health_color := Color("7dff8a" if ratio > 0.4 else "ff704d")
	health_color.a = alpha
	draw_rect(Rect2(top_left, Vector2(width * ratio, height)), health_color)


func _draw_impact_flash(alpha: float = 1.0) -> void:
	if impact_flash_remaining <= 0.0:
		return
	var intensity: float = impact_flash_remaining / 0.35
	draw_circle(Vector2.ZERO, 22.0 * intensity, Color(1.0, 0.45, 0.18, intensity * alpha))


func _draw_health_bar(alpha: float = 1.0) -> void:
	var ratio: float = hull / maximum_hull
	draw_rect(Rect2(-14.0, 18.0, 28.0, 3.0), Color(0.08, 0.10, 0.13, 0.9 * alpha))
	var hull_color := Color("7dff8a" if ratio > 0.4 else "ff704d")
	hull_color.a = alpha
	draw_rect(Rect2(-14.0, 18.0, 28.0 * ratio, 3.0), hull_color)
	var heat_ratio: float = get_heat_ratio()
	var heat_color := Color("69d9ff").lerp(Color("ff5d3d"), heat_ratio)
	draw_rect(Rect2(-14.0, 23.0, 28.0, 2.5), Color(0.08, 0.10, 0.13, 0.9 * alpha))
	heat_color.a = alpha
	draw_rect(Rect2(-14.0, 23.0, 28.0 * heat_ratio, 2.5), heat_color)
