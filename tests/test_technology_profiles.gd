extends SceneTree

const PROPULSION_PATHS: Array[String] = [
	"res://data/propulsion/main_drive.tres",
	"res://data/propulsion/vector_drive.tres",
	"res://data/propulsion/hybrid_drive.tres",
	"res://data/propulsion/awacs_vector_drive.tres",
]
const MOUNT_PATHS: Array[String] = [
	"res://data/weapon_mounts/forward_fixed.tres",
	"res://data/weapon_mounts/port_broadside.tres",
	"res://data/weapon_mounts/starboard_broadside.tres",
	"res://data/weapon_mounts/rear_fixed.tres",
	"res://data/weapon_mounts/turret.tres",
]
const WEAPON_PATHS: Array[String] = [
	"res://data/weapons/kinetic_pdc.tres",
	"res://data/weapons/laser_pdc.tres",
	"res://data/weapons/short_interceptor_launcher.tres",
	"res://data/weapons/medium_missile_tubes.tres",
	"res://data/weapons/medium_missile_cells.tres",
	"res://data/weapons/long_range_missile_cells.tres",
	"res://data/weapons/anti_radiation_cells.tres",
	"res://data/weapons/medium_railgun.tres",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	for path: String in PROPULSION_PATHS:
		var propulsion: PropulsionProfile = load(path)
		if propulsion == null or propulsion.display_name.is_empty():
			failures.append("profil de propulsion invalide : %s" % path)
		elif propulsion.forward_thrust_multiplier <= 0.0:
			failures.append("profil sans poussée principale : %s" % path)

	var default_unit: UnitProfile = load("res://data/balance/default_unit.tres")
	var awacs_unit: UnitProfile = load("res://data/balance/awacs_unit.tres")
	if default_unit.propulsion_profile == null or awacs_unit.propulsion_profile == null:
		failures.append("les profils d'unité principaux n'utilisent pas les ressources de propulsion")

	var forward_mount: WeaponMountProfile = load(MOUNT_PATHS[0])
	var port_mount: WeaponMountProfile = load(MOUNT_PATHS[1])
	var starboard_mount: WeaponMountProfile = load(MOUNT_PATHS[2])
	var rear_mount: WeaponMountProfile = load(MOUNT_PATHS[3])
	var turret_mount: WeaponMountProfile = load(MOUNT_PATHS[4])
	if not forward_mount.covers_relative_bearing(0.0) or forward_mount.covers_relative_bearing(PI):
		failures.append("le profil avant ne couvre pas uniquement la proue")
	if not port_mount.covers_relative_bearing(-PI * 0.5):
		failures.append("la bordée bâbord ne couvre pas bâbord")
	if not starboard_mount.covers_relative_bearing(PI * 0.5):
		failures.append("la bordée tribord ne couvre pas tribord")
	if not rear_mount.covers_relative_bearing(PI):
		failures.append("le profil arrière ne couvre pas la poupe")
	if not turret_mount.covers_relative_bearing(2.7):
		failures.append("la tourelle ne couvre pas 360 degrés")
	for path: String in WEAPON_PATHS:
		var weapon: WeaponSystemProfile = load(path)
		if weapon == null or weapon.mount_profile == null:
			failures.append("système d'arme sans montage : %s" % path)
		elif weapon.maximum_range <= weapon.minimum_range:
			failures.append("plage d'engagement invalide : %s" % path)

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Profils technologiques validés : 4 propulsions, 5 montages et 8 systèmes d'arme.")
	quit(0)
