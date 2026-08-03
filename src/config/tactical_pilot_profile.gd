class_name TacticalPilotProfile
extends Resource

@export_category("Doctrine")
@export var display_name: String = "Doctrine standard"
@export var fire_control_target_bonus: float = 0.0
@export var railgun_target_bonus: float = 0.0
@export_range(0.0, 0.8, 0.05) var retreat_hull_ratio: float = 0.0
@export var flank_offset: float = 0.0
@export var keep_fire_control_radar_active: bool = true

@export_category("Économie des missiles")
@export_range(1.0, 2.0, 0.05) var missile_damage_margin: float = 1.20
@export_range(0.0, 0.75, 0.05) var missile_reserve_ratio: float = 0.0
@export var allow_total_saturation: bool = true

@export_category("Choix d'armement")
@export var prefer_railgun: bool = true
@export_range(0.0, 1.0, 0.05) var fixed_cell_saturation_ratio: float = 0.50

@export_category("Positionnement")
@export_range(0.1, 0.95, 0.05) var preferred_range_ratio: float = 0.72
@export_range(0.01, 0.30, 0.01) var range_band_ratio: float = 0.08
@export var minimum_range_band: float = 35.0
