class_name WeaponSystemProfile
extends Resource

enum Family {
	KINETIC_PDC,
	LASER_PDC,
	MISSILE,
	RAILGUN,
}

enum FeedType {
	MAGAZINE,
	FIXED_CELLS,
	ENERGY,
}

enum TacticalRole {
	POINT_DEFENSE,
	INTERCEPTOR,
	ANTI_SHIP,
	KINETIC_STRIKE,
	ANTI_RADIATION,
}

@export_category("Identité")
@export var display_name: String = "Système d'arme"
@export var family: Family = Family.MISSILE
@export var tactical_role: TacticalRole = TacticalRole.ANTI_SHIP

@export_category("Installation")
@export var mount_profile: WeaponMountProfile
@export var feed_type: FeedType = FeedType.MAGAZINE
@export var launcher_count: int = 1
@export var loader_count: int = 1
@export var ammunition_capacity: int = 1
@export var reload_time: float = 1.0

@export_category("Engagement")
@export var minimum_range: float = 0.0
@export var maximum_range: float = 100.0
@export var fire_interval: float = 1.0
@export var heat_per_shot: float = 0.0
@export var damage: float = 0.0
@export var projectile_speed: float = 0.0
@export var missile_profile: MissileProfile


func is_in_range(distance: float) -> bool:
	return distance >= minimum_range and distance <= maximum_range
