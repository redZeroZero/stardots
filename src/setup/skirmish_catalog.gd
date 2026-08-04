class_name SkirmishCatalog
extends RefCounted

const UNIT_PROFILE: UnitProfile = preload("res://data/balance/default_unit.tres")
const AWACS_PROFILE: UnitProfile = preload("res://data/balance/awacs_unit.tres")
const KINETIC_PDC_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/kinetic_pdc.tres")
const LASER_PDC_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/laser_pdc.tres")
const SHORT_INTERCEPTOR_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/short_interceptor_launcher.tres")
const MEDIUM_MISSILE_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/medium_missile_tubes.tres")
const LONG_MISSILE_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/long_range_missile_cells.tres")
const ANTI_RADIATION_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/anti_radiation_cells.tres")
const RAILGUN_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/medium_railgun.tres")
const RECEIVER_ONLY_DATA_LINK: DataLinkProfile = preload("res://data/data_links/receiver_only_tactical_link.tres")

static var pending_deployment: Array[Dictionary] = []
static var pending_auto_launch: bool = false


static func build_entries() -> Array[Dictionary]:
	return [
		{
			"id": "awacs",
			"code": "EYE",
			"label": "AWACS — veille et relais",
			"profile": AWACS_PROFILE,
		},
		{
			"id": "escort_laser",
			"code": "ESC-L",
			"label": "Escorte laser — défense proche",
			"profile": _make_profile(
				"Escorte laser", "ESCORTEUR", "DÉFENSE LASER",
				[LASER_PDC_SYSTEM, SHORT_INTERCEPTOR_SYSTEM, MEDIUM_MISSILE_SYSTEM], true
			),
		},
		{
			"id": "escort_kinetic",
			"code": "ESC-K",
			"label": "Escorte cinétique — défense proche",
			"profile": _make_profile(
				"Escorte cinétique", "ESCORTEUR", "DÉFENSE CINÉTIQUE",
				[KINETIC_PDC_SYSTEM, SHORT_INTERCEPTOR_SYSTEM, MEDIUM_MISSILE_SYSTEM], true
			),
		},
		{
			"id": "frigate",
			"code": "FRIG",
			"label": "Frégate — missiles moyens",
			"profile": _make_profile(
				"Frégate antinavire", "FRÉGATE", "MISSILES MOYENS",
				[KINETIC_PDC_SYSTEM, MEDIUM_MISSILE_SYSTEM], true
			),
		},
		{
			"id": "railgun",
			"code": "RAIL",
			"label": "Croiseur — railgun axial",
			"profile": _make_profile(
				"Croiseur railgun", "CROISEUR", "RAILGUN AXIAL",
				[KINETIC_PDC_SYSTEM, RAILGUN_SYSTEM], false
			),
		},
		{
			"id": "arsenal",
			"code": "ARS",
			"label": "Porte-missiles — longue portée",
			"profile": _make_profile(
				"Porte-missiles", "PORTE-MISSILES", "CELLULES LONGUE PORTÉE",
				[KINETIC_PDC_SYSTEM, LONG_MISSILE_SYSTEM], false, true
			),
		},
		{
			"id": "anti_radiation",
			"code": "ARM",
			"label": "Frégate — suppression antiradar",
			"profile": _make_profile(
				"Frégate de suppression", "FRÉGATE", "ANTIRAD",
				[KINETIC_PDC_SYSTEM, ANTI_RADIATION_SYSTEM, MEDIUM_MISSILE_SYSTEM], true
			),
		},
	]


static func find_entry(entries: Array[Dictionary], ship_id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if String(entry["id"]) == ship_id:
			return entry
	return {}


static func stage_reload(deployment: Array[Dictionary], auto_launch: bool) -> void:
	pending_deployment = deployment.duplicate(true)
	pending_auto_launch = auto_launch


static func consume_pending_deployment() -> Dictionary:
	var result := {
		"deployment": pending_deployment.duplicate(true),
		"auto_launch": pending_auto_launch,
	}
	pending_deployment.clear()
	pending_auto_launch = false
	return result


static func _make_profile(
	display_name: String,
	classification_label: String,
	role: String,
	systems: Array[WeaponSystemProfile],
	uses_legacy_missile_magazine: bool,
	receiver_only: bool = false
) -> UnitProfile:
	var profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	profile.display_name = display_name
	profile.classification_label = classification_label
	profile.tactical_role = role
	profile.weapon_system_profiles = systems
	if not uses_legacy_missile_magazine:
		profile.missile_capacity = 0
		profile.missile_launcher_count = 0
	if receiver_only:
		profile.sensor_range = 378.0
		profile.active_sensor_range = 1008.0
		profile.active_emission_detection_range = 720.0
		profile.data_link_profile = RECEIVER_ONLY_DATA_LINK
	return profile
