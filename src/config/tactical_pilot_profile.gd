class_name TacticalPilotProfile
extends Resource

@export_category("Choix d'armement")
@export var prefer_railgun: bool = true
@export_range(0.0, 1.0, 0.05) var fixed_cell_saturation_ratio: float = 0.50

@export_category("Positionnement")
@export_range(0.1, 0.95, 0.05) var preferred_range_ratio: float = 0.72
@export_range(0.01, 0.30, 0.01) var range_band_ratio: float = 0.08
@export var minimum_range_band: float = 35.0

