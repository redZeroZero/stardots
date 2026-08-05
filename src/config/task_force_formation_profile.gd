class_name TaskForceFormationProfile
extends Resource

@export_category("Espacement principal")
@export var tight_unit_spacing: float = 48.0
@export var loose_unit_spacing: float = 120.0

@export_category("Appui")
@export var tight_support_distance: float = 180.0
@export var loose_support_distance: float = 320.0

@export_category("Poursuite élastique")
@export var slot_refresh_distance: float = 8.0
@export var cohesion_full_speed_distance_multiplier: float = 1.5
@export var cohesion_minimum_speed_distance_multiplier: float = 6.0
@export_range(0.1, 1.0, 0.05) var minimum_cohesion_speed_ratio: float = 0.35
@export var anchor_arrival_radius: float = 8.0
@export var anchor_stop_speed: float = 2.0


func get_unit_spacing(spacing: TaskForce.FormationSpacing) -> float:
	return tight_unit_spacing if spacing == TaskForce.FormationSpacing.TIGHT else loose_unit_spacing


func get_support_distance(spacing: TaskForce.FormationSpacing) -> float:
	return (
		tight_support_distance
		if spacing == TaskForce.FormationSpacing.TIGHT
		else loose_support_distance
	)
