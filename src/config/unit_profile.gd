class_name UnitProfile
extends Resource

@export_category("Identité")
@export var display_name: String = "Bâtiment standard"
@export var tactical_role: String = "FRÉGATE"
@export var crewed: bool = true

@export_category("Mobilité")
@export var tactical_speed_limit: float = 95.0
@export var drive_acceleration: float = 48.0
@export var crew_safe_acceleration: float = 38.0
@export var maximum_angular_speed_degrees: float = 100.0
@export var angular_acceleration_degrees: float = 180.0
@export var arrival_radius: float = 5.0
@export var station_keeping_speed: float = 8.0
@export var preferred_turn_radius: float = 90.0
@export_range(0.2, 1.5, 0.05) var turn_anticipation: float = 0.75

@export_category("Capteurs")
@export var sensor_range: float = 420.0
@export var active_sensor_range: float = 560.0
@export var active_emission_detection_range: float = 720.0
@export var active_sensor_heat_per_second: float = 4.0
@export var provides_fire_control: bool = false
@export var fire_control_share_range: float = 0.0

@export_category("Thermique")
@export var heat_capacity: float = 100.0
@export var initial_heat: float = 20.0
@export var passive_cooling_per_second: float = 2.5
@export var silent_cooling_multiplier: float = 0.20
@export var combat_cooling_multiplier: float = 2.0
@export var silent_radiator_signature: float = 0.05
@export var normal_radiator_signature: float = 0.15
@export var combat_radiator_signature: float = 0.45
@export var baseline_thermal_signature: float = 0.70
@export var stored_heat_signature_multiplier: float = 0.60
@export var engine_signature_multiplier: float = 0.80
@export var propulsion_heat_per_second: float = 6.0
@export var missile_launch_heat: float = 8.0
@export var missile_loading_heat_per_second: float = 1.5
@export var point_defense_heat_per_shot: float = 0.6
@export_range(0.5, 1.0, 0.01) var weapon_overheat_threshold: float = 0.95

@export_category("Automatisation thermique")
@export var automatic_thermal_control: bool = true
@export var stationary_speed_threshold: float = 2.0
@export var combat_mode_hold_time: float = 6.0

@export_category("Défense ponctuelle")
@export var point_defense_range: float = 115.0
@export var point_defense_ammunition_capacity: int = 80
@export var point_defense_fire_interval: float = 0.14
@export var point_defense_projectile_speed: float = 330.0
@export var point_defense_projectile_lifetime: float = 0.5
@export var point_defense_projectile_damage: float = 9.0
@export var point_defense_projectile_hit_radius: float = 4.0
@export var point_defense_dispersion_degrees: float = 2.8

@export_category("Survie et armement")
@export var maximum_hull: float = 100.0
@export var missile_launch_range: float = 900.0
@export var missile_capacity: int = 6
@export var missile_launcher_count: int = 2
@export var missile_loader_count: int = 1
@export var missile_loading_time: float = 4.0
@export var missile_launch_interval: float = 0.5
