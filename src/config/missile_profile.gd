class_name MissileProfile
extends Resource

enum SeekerMode {
	STANDARD,
	ANTI_RADIATION,
}

@export_category("Identité")
@export var display_name: String = "Missile antinavire moyen"

@export_category("Cinématique et guidage")
@export var seeker_mode: SeekerMode = SeekerMode.STANDARD
@export var launch_speed: float = 45.0
@export var cruise_speed: float = 120.0
@export var cruise_acceleration: float = 55.0
@export var cruise_turn_rate_degrees: float = 55.0
@export var terminal_seeker_range: float = 105.0
@export var terminal_speed: float = 250.0
@export var terminal_acceleration: float = 180.0
@export var terminal_turn_rate_degrees: float = 150.0
@export var maximum_lifetime: float = 10.0

@export_category("Autodirecteur antirayonnement")
@export var radiation_seeker_range: float = 0.0
@export var minimum_radiation_signature: float = 0.1

@export_category("Charge militaire")
@export var warhead_arming_distance: float = 55.0
@export var proximity_fuze_range: float = 28.0
@export var fragment_radius: float = 72.0
@export var maximum_damage: float = 85.0

@export_category("Interception")
@export var maximum_integrity: float = 45.0
@export var intercepted_fragment_radius: float = 36.0
@export var intercepted_maximum_damage: float = 20.0

@export_category("Affichage")
@export var explosion_duration: float = 0.32
