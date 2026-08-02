class_name WeaponMountProfile
extends Resource

enum ArcPreset {
	FORWARD,
	PORT_BROADSIDE,
	STARBOARD_BROADSIDE,
	REAR,
	TURRET,
	CUSTOM,
}

@export_category("Identité")
@export var display_name: String = "Emplacement avant"
@export var arc_preset: ArcPreset = ArcPreset.FORWARD

@export_category("Secteur relatif à la proue")
@export_range(-180.0, 180.0, 1.0) var arc_center_degrees: float = 0.0
@export_range(1.0, 360.0, 1.0) var arc_width_degrees: float = 60.0
@export var rotates_with_hull: bool = true
@export var traversable: bool = false
@export_range(0.0, 360.0, 1.0) var traverse_rate_degrees: float = 0.0
@export_range(0.5, 30.0, 0.5) var firing_tolerance_degrees: float = 4.0


func covers_relative_bearing(relative_bearing_radians: float) -> bool:
	if arc_width_degrees >= 359.9:
		return true
	var center: float = deg_to_rad(arc_center_degrees)
	return absf(wrapf(relative_bearing_radians - center, -PI, PI)) <= deg_to_rad(arc_width_degrees) * 0.5
