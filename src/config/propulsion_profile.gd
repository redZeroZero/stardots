class_name PropulsionProfile
extends Resource

enum PropulsionDoctrine {
	FLIP_AND_BURN,
	HOLD_ATTITUDE,
	HYBRID,
}

@export_category("Identité")
@export var display_name: String = "Propulsion vectorielle"

@export_category("Performances")
@export var tactical_speed_limit: float = 95.0
@export var drive_acceleration: float = 48.0
@export_range(0.0, 1.0, 0.05) var forward_thrust_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.05) var retrograde_thrust_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.05) var lateral_thrust_multiplier: float = 1.0
@export var maximum_angular_speed_degrees: float = 100.0
@export var angular_acceleration_degrees: float = 180.0

@export_category("Doctrine")
@export var doctrine: PropulsionDoctrine = PropulsionDoctrine.HOLD_ATTITUDE
@export_range(0.1, 1.0, 0.05) var hybrid_flip_threshold: float = 0.65
@export_range(0.1, 1.0, 0.05) var hybrid_turn_speed_ratio: float = 0.65
