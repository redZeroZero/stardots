class_name NavigationLegPlan
extends RefCounted

enum Phase {
	ACCELERATE,
	CRUISE,
	RETRO_BRAKE,
	TURN,
	BRAKE,
}

var distance: float = 0.0
var cruise_speed: float = 0.0
var final_speed: float = 0.0
var acceleration: float = 0.0
var braking_acceleration: float = 0.0
var acceleration_distance: float = 0.0
var pre_turn_braking_acceleration: float = 0.0
var pre_turn_braking_distance: float = 0.0
var pre_turn_braking_start_remaining: float = 0.0
var braking_distance: float = 0.0
var turn_duration: float = 0.0
var turn_speed: float = 0.0
var turn_lead_distance: float = 0.0
var turn_start_remaining: float = 0.0
var requires_flip: bool = false


static func calculate(
	leg_distance: float,
	start_speed: float,
	speed_limit: float,
	waypoint_speed: float,
	available_acceleration: float,
	available_braking_acceleration: float,
	flip_duration: float,
	flip_required: bool,
	available_pre_turn_braking_acceleration: float = 0.0,
	turn_speed_ratio: float = 1.0
) -> NavigationLegPlan:
	var plan := NavigationLegPlan.new()
	plan.distance = maxf(0.0, leg_distance)
	plan.final_speed = maxf(0.0, waypoint_speed)
	plan.acceleration = maxf(0.001, available_acceleration)
	plan.braking_acceleration = maxf(0.001, available_braking_acceleration)
	plan.turn_duration = maxf(0.0, flip_duration) if flip_required else 0.0
	plan.requires_flip = flip_required
	plan.pre_turn_braking_acceleration = maxf(0.0, available_pre_turn_braking_acceleration)
	var clamped_turn_speed_ratio: float = clampf(turn_speed_ratio, 0.1, 1.0)
	var uses_pre_turn_braking: bool = flip_required and plan.pre_turn_braking_acceleration > 0.001 and clamped_turn_speed_ratio < 0.999

	var quadratic_factor: float = 0.5 / plan.acceleration
	if uses_pre_turn_braking:
		quadratic_factor += (1.0 - clamped_turn_speed_ratio * clamped_turn_speed_ratio) / (2.0 * plan.pre_turn_braking_acceleration)
		quadratic_factor += clamped_turn_speed_ratio * clamped_turn_speed_ratio / (2.0 * plan.braking_acceleration)
	else:
		quadratic_factor += 0.5 / plan.braking_acceleration
	var target_distance: float = (
		plan.distance
		+ start_speed * start_speed / (2.0 * plan.acceleration)
		+ plan.final_speed * plan.final_speed / (2.0 * plan.braking_acceleration)
	)
	var effective_turn_duration: float = plan.turn_duration * clamped_turn_speed_ratio if uses_pre_turn_braking else plan.turn_duration
	var discriminant: float = effective_turn_duration * effective_turn_duration + 4.0 * quadratic_factor * target_distance
	var reachable_peak: float = (
		-effective_turn_duration + sqrt(maxf(0.0, discriminant))
	) / (2.0 * quadratic_factor)
	plan.cruise_speed = clampf(reachable_peak, plan.final_speed, maxf(plan.final_speed, speed_limit))
	plan.turn_speed = plan.cruise_speed * clamped_turn_speed_ratio if uses_pre_turn_braking else plan.cruise_speed
	plan.acceleration_distance = maxf(
		0.0,
		(plan.cruise_speed * plan.cruise_speed - start_speed * start_speed) / (2.0 * plan.acceleration)
	)
	plan.braking_distance = maxf(
		0.0,
		(plan.turn_speed * plan.turn_speed - plan.final_speed * plan.final_speed) / (2.0 * plan.braking_acceleration)
	)
	if uses_pre_turn_braking:
		plan.pre_turn_braking_distance = maxf(
			0.0,
			(plan.cruise_speed * plan.cruise_speed - plan.turn_speed * plan.turn_speed)
			/ (2.0 * plan.pre_turn_braking_acceleration)
		)
	plan.turn_lead_distance = plan.turn_speed * plan.turn_duration
	plan.turn_start_remaining = plan.braking_distance + plan.turn_lead_distance
	plan.pre_turn_braking_start_remaining = plan.turn_start_remaining + plan.pre_turn_braking_distance
	return plan


func phase(distance_remaining: float, current_speed: float) -> Phase:
	if distance_remaining <= braking_distance:
		return Phase.BRAKE
	if requires_flip and distance_remaining <= turn_start_remaining:
		return Phase.TURN
	if pre_turn_braking_distance > 0.0 and distance_remaining <= pre_turn_braking_start_remaining:
		return Phase.RETRO_BRAKE
	if current_speed < cruise_speed - 0.5:
		return Phase.ACCELERATE
	return Phase.CRUISE


func braking_speed_limit(distance_remaining: float) -> float:
	return sqrt(maxf(0.0, final_speed * final_speed + 2.0 * braking_acceleration * maxf(0.0, distance_remaining)))


func pre_turn_braking_speed_limit(distance_remaining: float) -> float:
	var distance_before_turn: float = maxf(0.0, distance_remaining - turn_start_remaining)
	return sqrt(maxf(0.0, turn_speed * turn_speed + 2.0 * pre_turn_braking_acceleration * distance_before_turn))


static func half_turn_duration(maximum_angular_speed: float, angular_acceleration: float) -> float:
	var safe_speed: float = maxf(0.001, maximum_angular_speed)
	var safe_acceleration: float = maxf(0.001, angular_acceleration)
	var acceleration_time: float = safe_speed / safe_acceleration
	var acceleration_and_braking_angle: float = safe_speed * safe_speed / safe_acceleration
	if PI <= acceleration_and_braking_angle:
		return 2.0 * sqrt(PI / safe_acceleration)
	return 2.0 * acceleration_time + (PI - acceleration_and_braking_angle) / safe_speed
