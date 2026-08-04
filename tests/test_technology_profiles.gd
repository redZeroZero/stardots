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
const DATA_LINK_PATHS: Array[String] = [
	"res://data/data_links/standard_tactical_link.tres",
	"res://data/data_links/receiver_only_tactical_link.tres",
	"res://data/data_links/awacs_relay_link.tres",
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
	if default_unit.classification_label != "FRÉGATE" or awacs_unit.classification_label != "AWACS":
		failures.append("les profils principaux n'exposent pas leur classe capteur")
	if (
		not is_equal_approx(default_unit.sensor_range, 630.0)
		or not is_equal_approx(default_unit.active_sensor_range, 1800.0)
		or not is_equal_approx(default_unit.active_emission_detection_range, 1400.0)
	):
		failures.append("la frégate généraliste ne conserve pas son autonomie capteur intermédiaire")
	if not is_equal_approx(default_unit.minimum_passive_signature, 1.0):
		failures.append("une plateforme ordinaire n'a pas de garantie passive nominale")
	if (
		not is_equal_approx(default_unit.active_radar_emission_strength, 2.0)
		or not is_equal_approx(awacs_unit.active_radar_emission_strength, 4.0)
	):
		failures.append("l'allongement radar ne conserve pas une émission active détectable")
	if (
		default_unit.data_link_profile == null
		or not default_unit.data_link_profile.can_receive
		or not default_unit.data_link_profile.can_transmit
		or default_unit.data_link_profile.can_relay
	):
		failures.append("la frégate généraliste n'utilise pas une liaison transceiver sans relais")

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
	for path: String in DATA_LINK_PATHS:
		var data_link: DataLinkProfile = load(path)
		if data_link == null or not (data_link.can_receive or data_link.can_transmit):
			failures.append("profil de liaison sans capacité : %s" % path)
		elif data_link.can_transmit and data_link.transmission_range <= 0.0:
			failures.append("profil émetteur sans portée : %s" % path)

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Profils technologiques validés : 4 propulsions, 3 liaisons, 5 montages et 8 systèmes d'arme.")
	quit(0)
