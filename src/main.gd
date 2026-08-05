extends Node2D

const TacticalUnitScene := preload("res://src/tactical_unit.gd")
const TacticalMissileScene := preload("res://src/tactical_missile.gd")
const PdcProjectileScene := preload("res://src/pdc_projectile.gd")
const RailgunProjectileScene := preload("res://src/railgun_projectile.gd")
const StrategicStationScene := preload("res://src/strategic_station.gd")
const TacticalPilotLogic := preload("res://src/ai/tactical_pilot.gd")
const SensorTrackLogic := preload("res://src/simulation/sensor_track.gd")
const DataLinkNetworkLogic := preload("res://src/simulation/data_link_network.gd")
const FireMissionLogic := preload("res://src/orders/fire_mission.gd")
const SkirmishCatalogLogic := preload("res://src/setup/skirmish_catalog.gd")
const UNIT_PROFILE: UnitProfile = preload("res://data/balance/default_unit.tres")
const AWACS_PROFILE: UnitProfile = preload("res://data/balance/awacs_unit.tres")
const MISSILE_PROFILE: MissileProfile = preload("res://data/balance/default_missile.tres")
const MAIN_DRIVE_PROFILE: PropulsionProfile = preload("res://data/propulsion/main_drive.tres")
const VECTOR_DRIVE_PROFILE: PropulsionProfile = preload("res://data/propulsion/vector_drive.tres")
const HYBRID_DRIVE_PROFILE: PropulsionProfile = preload("res://data/propulsion/hybrid_drive.tres")
const KINETIC_PDC_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/kinetic_pdc.tres")
const LASER_PDC_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/laser_pdc.tres")
const SHORT_INTERCEPTOR_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/short_interceptor_launcher.tres")
const MEDIUM_MISSILE_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/medium_missile_tubes.tres")
const LONG_MISSILE_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/long_range_missile_cells.tres")
const ANTI_RADIATION_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/anti_radiation_cells.tres")
const RAILGUN_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/medium_railgun.tres")
const STANDARD_DATA_LINK: DataLinkProfile = preload("res://data/data_links/standard_tactical_link.tres")
const RECEIVER_ONLY_DATA_LINK: DataLinkProfile = preload("res://data/data_links/receiver_only_tactical_link.tres")
const DEFAULT_TACTICAL_PILOT_PROFILE := preload("res://data/ai/default_tactical_pilot.tres")
const BLUE_FLEET_DOCTRINE: TacticalPilotProfile = preload("res://data/ai/blue_network_missiles.tres")
const RED_FLEET_DOCTRINE: TacticalPilotProfile = preload("res://data/ai/red_silent_raiders.tres")
const MATCH_RULES: MatchRules = preload("res://data/balance/match_rules.tres")
const TASK_FORCE_FORMATION_PROFILE: TaskForceFormationProfile = preload(
	"res://data/balance/default_task_force_formation.tres"
)
const CAMERA_SPEED: float = 620.0
const EDGE_SCROLL_MARGIN: float = 18.0
const ATTACK_ZONE_RADIUS: float = 180.0
const ATTACK_ZONE_DISPLAY_DURATION: float = 1.6
const SENSOR_UPDATE_INTERVAL: float = 0.20
const FIRE_CONTROL_MAXIMUM_UNCERTAINTY: float = 45.0
const MISSILE_SWARM_SPACING: float = 52.0
const PDC_SPATIAL_CELL_SIZE: float = 160.0
const THEATER_RETURN_MARGIN: float = 180.0
const RED_LINK_CYCLE_TICKS: int = 160
const RED_LINK_BURST_START_TICK: int = 80
const RED_LINK_BURST_DURATION_TICKS: int = 24
const MIN_ZOOM: float = 0.10
const MAX_ZOOM: float = 2.2
const WORLD_RECT := Rect2(-6144.0, -6144.0, 12288.0, 12288.0)
const BACKGROUND_COLOR := Color("07101f")
const GRID_COLOR := Color(0.18, 0.32, 0.46, 0.22)
const WORLD_BORDER_COLOR := Color(0.45, 0.86, 1.0, 0.72)
const WORLD_EDGE_FILL := Color(0.20, 0.58, 0.78, 0.08)
const SELECTION_FILL := Color(0.25, 0.82, 1.0, 0.10)
const SELECTION_BORDER := Color(0.40, 0.88, 1.0, 0.85)
const DUEL_SANDBOX: bool = true

enum OffensiveWeaponSelection {
	AUTO,
	MISSILES,
	RAILGUN,
	ANTI_RADIATION,
}

enum FireDoctrine {
	ECONOMY,
	SALVO,
	SATURATION,
}

var simulation_clock := SimulationClock.new()
var friendly_units: Array[TacticalUnitScene] = []
var enemy_units: Array[TacticalUnitScene] = []
var selected_units: Array[TacticalUnitScene] = []
var is_selecting: bool = false
var selection_start: Vector2
var selection_end: Vector2
var is_defining_move_order: bool = false
var is_panning_camera: bool = false
var move_order_start: Vector2
var move_order_end: Vector2
var move_order_append: bool = false
var move_order_fly_through: bool = false
var attack_command_armed: bool = false
var active_fire_missions: Array[FireMission] = []
var last_attack_feedback: String = ""
var offensive_weapon_selection: OffensiveWeaponSelection = OffensiveWeaponSelection.AUTO
var fire_doctrine: FireDoctrine = FireDoctrine.SALVO
var confirmed_impacts: int = 0
var missiles_launched: Array[int] = [0, 0]
var missile_impacts: Array[int] = [0, 0]
var missile_interceptions: Array[int] = [0, 0]
var ai_decision_remaining: float = 1.8
var enemy_tactical_pilot = TacticalPilotLogic.new(DEFAULT_TACTICAL_PILOT_PROFILE)
var blue_fleet_pilot = TacticalPilotLogic.new(BLUE_FLEET_DOCTRINE)
var red_fleet_pilot = TacticalPilotLogic.new(RED_FLEET_DOCTRINE)
var enemy_tactical_pilot_enabled: bool = true
var sensor_update_remaining: float = SENSOR_UPDATE_INTERVAL
var sensor_tracks_by_team: Array[Dictionary] = [{}, {}]
var contact_designation_counters: Array[int] = [0, 0]
var tactical_groups_by_team: Array[Dictionary] = [{}, {}]
var data_link_networks_by_team: Array = [DataLinkNetworkLogic.new(), DataLinkNetworkLogic.new()]
var closest_local_target_indices_by_team: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var closest_local_target_distances_by_team: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
var objective_station: StrategicStationScene
var team_hold_time: Array[float] = [0.0, 0.0]
var match_over: bool = false
var propulsion_demo: bool = OS.get_cmdline_user_args().has("--propulsion-demo")
var weapons_demo: bool = OS.get_cmdline_user_args().has("--weapons-demo")
var ai_demo: bool = OS.get_cmdline_user_args().has("--ai-demo")
var sensor_demo: bool = OS.get_cmdline_user_args().has("--sensor-demo")
var thermal_demo: bool = OS.get_cmdline_user_args().has("--thermal-demo")
var radiation_demo: bool = OS.get_cmdline_user_args().has("--radiation-demo")
var network_demo: bool = OS.get_cmdline_user_args().has("--network-demo")
var fleet_battle_demo: bool = OS.get_cmdline_user_args().has("--fleet-battle-demo")
var task_force_demo: bool = (
	OS.get_cmdline_user_args().has("--task-force-demo")
	or OS.get_cmdline_args().has("--task-force-demo")
)
var fleet_battle_seed: int = 0
var fleet_battle_rng := RandomNumberGenerator.new()
var range_debug_enabled: bool = OS.get_cmdline_user_args().has("--debug-ranges")
var benchmark_empty_scenario: bool = false
var skirmish_setup_enabled: bool = false
var deployment_mode: bool = false
var skirmish_battle_active: bool = false
var skirmish_free_test_active: bool = false
var skirmish_catalog_entries: Array[Dictionary] = []
var skirmish_deployment_snapshot: Array[Dictionary] = []
var deployment_dragged_unit: TacticalUnitScene
var deployment_callsign_counters: Dictionary = {}
var target_camera_zoom: float = 0.42
var zoom_anchor_world: Vector2 = Vector2.ZERO
var zoom_anchor_screen: Vector2 = Vector2.ZERO
var zoom_transition_active: bool = false
var task_force_demo_force: TaskForce
var task_force_demo_motion: TaskForceMotion
var task_force_demo_scout: TacticalUnitScene

@onready var units_layer: Node2D = $Units
@onready var missiles_layer: Node2D = $Missiles
@onready var pdc_projectiles_layer: Node2D = $PdcProjectiles
@onready var stations_layer: Node2D = $Stations
@onready var tactical_camera: Camera2D = $TacticalCamera
@onready var status_label: Label = %StatusLabel
@onready var intel_label: Label = %IntelLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var telemetry_label: Label = %TelemetryLabel
@onready var selection_details_label: Label = %SelectionDetailsLabel
@onready var cut_engines_button: Button = %CutEnginesButton
@onready var attack_mode_button: Button = %AttackModeButton
@onready var weapon_select_button: Button = %WeaponSelectButton
@onready var fire_doctrine_button: Button = %FireDoctrineButton
@onready var sensor_mode_button: Button = %SensorModeButton
@onready var thermal_mode_button: Button = %ThermalModeButton
@onready var restart_button: Button = %RestartButton
@onready var info_button: Button = %InfoButton
@onready var secondary_info: PanelContainer = %SecondaryInfo
@onready var victory_label: Label = %VictoryLabel
@onready var tactical_minimap: TacticalMinimap = %TacticalMinimap
@onready var tactical_overlay: TacticalOverlay = $TacticalOverlay
@onready var tactical_labels: TacticalLabels = $TacticalLabels
@onready var skirmish_setup_panel: SkirmishSetupPanel = %SkirmishSetupPanel
@onready var top_margin: MarginContainer = $Interface/TopMargin
@onready var selection_dock: MarginContainer = $Interface/SelectionDock
@onready var restart_margin: MarginContainer = $Interface/RestartMargin
@onready var edit_setup_margin: MarginContainer = %EditSetupMargin
@onready var edit_setup_button: Button = %EditSetupButton


func _ready() -> void:
	_configure_fleet_battle_seed()
	get_viewport().size_changed.connect(queue_redraw)
	restart_button.pressed.connect(_restart_match)
	info_button.pressed.connect(_toggle_secondary_info)
	cut_engines_button.pressed.connect(_cut_selected_engines)
	attack_mode_button.pressed.connect(_toggle_attack_command)
	weapon_select_button.pressed.connect(_cycle_offensive_weapon_selection)
	fire_doctrine_button.pressed.connect(_cycle_fire_doctrine)
	sensor_mode_button.pressed.connect(_toggle_selected_sensors)
	skirmish_setup_panel.rotate_requested.connect(_rotate_deployment_selection)
	skirmish_setup_panel.delete_requested.connect(_delete_deployment_selection)
	skirmish_setup_panel.clear_requested.connect(_clear_deployment)
	skirmish_setup_panel.launch_requested.connect(_launch_skirmish)
	edit_setup_button.pressed.connect(_edit_skirmish_setup)
	tactical_minimap.bind(self, WORLD_RECT)
	tactical_overlay.bind(self)
	tactical_labels.bind(self)
	skirmish_setup_enabled = skirmish_setup_enabled or _should_start_skirmish_setup()
	if skirmish_setup_enabled:
		_begin_skirmish_setup()
	else:
		_spawn_demo_units()
		if propulsion_demo or weapons_demo or sensor_demo or thermal_demo or radiation_demo or network_demo or task_force_demo:
			for unit: TacticalUnitScene in friendly_units:
				selected_units.append(unit)
				unit.set_selected(true)
			if sensor_demo or thermal_demo:
				tactical_camera.position = Vector2(250.0, 360.0)
				tactical_camera.zoom = Vector2.ONE * 0.50
				target_camera_zoom = 0.50
			elif radiation_demo or network_demo or task_force_demo:
				_frame_units(friendly_units + enemy_units)
			else:
				_frame_friendly_units()
	_apply_visual_zoom()
	_refresh_range_visualization()
	if ai_demo:
		_frame_units(friendly_units + enemy_units)
	if fleet_battle_demo:
		_frame_units(friendly_units + enemy_units)
		_update_fleet_battle_header()
	elif network_demo:
		objective_label.text = "SCÉNARIO: RÉSEAU — COMPARER RX-01 ET ISOLÉ-01"
	elif radiation_demo:
		objective_label.text = "SCÉNARIO: CHASSE AUX ÉMETTEURS — ARME ANTIRAD, A PUIS CLIC"
	elif weapons_demo:
		objective_label.text = "SCÉNARIO: ARMEMENTS ET ARCS — A PUIS CLIC SUR UNE CIBLE"
	elif ai_demo:
		objective_label.text = "SCÉNARIO: PILOTE TACTIQUE IA — PORTÉE, CAP ET ARCS"
	elif sensor_demo:
		objective_label.text = "SCÉNARIO: BLIPS FIXES — CLIC DROIT POUR APPROCHER, A PUIS CLIC POUR TIRER"
	elif thermal_demo:
		_update_thermal_demo_header()
	elif propulsion_demo:
		objective_label.text = "SCÉNARIO: COMPARATIF PROPULSION — F POUR CADRER"
	elif task_force_demo:
		_update_task_force_demo_header()
	elif skirmish_setup_enabled:
		objective_label.text = "ESCARMOUCHE LIBRE"
	elif DUEL_SANDBOX:
		objective_label.text = "SCÉNARIO: VEILLE DÉPORTÉE"
	else:
		_spawn_objective_station()
	_update_status()
	_update_fire_control_buttons()
	queue_redraw()


func _configure_fleet_battle_seed() -> void:
	if not fleet_battle_demo:
		return
	if fleet_battle_seed == 0:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--fleet-seed="):
				var seed_text: String = argument.trim_prefix("--fleet-seed=")
				if seed_text.is_valid_int():
					fleet_battle_seed = seed_text.to_int()
	if fleet_battle_seed == 0:
		fleet_battle_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
	fleet_battle_rng.seed = fleet_battle_seed


func _update_fleet_battle_header() -> void:
	if not fleet_battle_demo:
		return
	var relay_state := "TRANSMISSION" if _red_link_window_open() else "SILENCE"
	objective_label.text = "12 BLEUS VS 10 RAIDERS  •  RELAIS %s  •  GRAINE %d" % [
		relay_state,
		fleet_battle_seed,
	]


func _red_link_window_open() -> bool:
	var cycle_tick: int = simulation_clock.tick_index % RED_LINK_CYCLE_TICKS
	return (
		cycle_tick >= RED_LINK_BURST_START_TICK
		and cycle_tick < RED_LINK_BURST_START_TICK + RED_LINK_BURST_DURATION_TICKS
	)


func _should_start_skirmish_setup() -> bool:
	return (
		DisplayServer.get_name() != "headless"
		and not benchmark_empty_scenario
		and not (
			propulsion_demo
			or weapons_demo
			or ai_demo
			or sensor_demo
			or thermal_demo
			or radiation_demo
			or network_demo
			or fleet_battle_demo
			or task_force_demo
		)
	)


func _begin_skirmish_setup() -> void:
	deployment_mode = true
	skirmish_battle_active = false
	skirmish_catalog_entries = SkirmishCatalogLogic.build_entries()
	skirmish_setup_panel.configure(skirmish_catalog_entries)
	skirmish_setup_panel.visible = true
	top_margin.visible = false
	selection_dock.visible = false
	restart_margin.visible = false
	edit_setup_margin.visible = false
	victory_label.visible = false
	units_layer.process_mode = Node.PROCESS_MODE_DISABLED
	missiles_layer.process_mode = Node.PROCESS_MODE_DISABLED
	pdc_projectiles_layer.process_mode = Node.PROCESS_MODE_DISABLED
	stations_layer.process_mode = Node.PROCESS_MODE_DISABLED
	tactical_camera.position = WORLD_RECT.get_center()
	_update_deployment_panel()
	var pending: Dictionary = SkirmishCatalogLogic.consume_pending_deployment()
	_restore_skirmish_deployment(pending["deployment"])
	if not friendly_units.is_empty() or not enemy_units.is_empty():
		_frame_units(friendly_units + enemy_units)
	if bool(pending["auto_launch"]):
		_launch_skirmish()


func _restore_skirmish_deployment(deployment: Array) -> void:
	for placement: Dictionary in deployment:
		_spawn_skirmish_unit(
			String(placement["ship_id"]),
			int(placement["team_id"]),
			Vector2(placement["position"]),
			float(placement["rotation"]),
			int(placement.get("group_id", 0))
		)


func _spawn_skirmish_unit(
	ship_id: String,
	team_id: int,
	world_position: Vector2,
	heading: float = INF,
	group_id: int = -1
) -> TacticalUnitScene:
	if not deployment_mode:
		return null
	var entry: Dictionary = SkirmishCatalogLogic.find_entry(skirmish_catalog_entries, ship_id)
	if entry.is_empty():
		return null
	var safe_position: Vector2 = world_position.clamp(
		WORLD_RECT.position + Vector2.ONE * 24.0,
		WORLD_RECT.end - Vector2.ONE * 24.0
	)
	var callsign: String = _next_skirmish_callsign(team_id, entry)
	var unit: TacticalUnitScene = _spawn_unit(callsign, team_id, safe_position, entry["profile"])
	unit.tactical_group_id = (
		skirmish_setup_panel.get_selected_group_id()
		if group_id < 0
		else group_id
	)
	unit.set_meta("skirmish_ship_id", ship_id)
	unit.rotation = heading if is_finite(heading) else (PI * 0.5 if team_id == 0 else -PI * 0.5)
	unit.set_intel_state(TacticalUnitScene.IntelState.IDENTIFIED)
	_select_deployment_unit(unit)
	_update_deployment_panel()
	return unit


func _next_skirmish_callsign(team_id: int, entry: Dictionary) -> String:
	var counter_key := "%d:%s" % [team_id, String(entry["id"])]
	var next_index: int = int(deployment_callsign_counters.get(counter_key, 0)) + 1
	deployment_callsign_counters[counter_key] = next_index
	return "%s-%s-%02d" % ["B" if team_id == 0 else "R", String(entry["code"]), next_index]


func _select_deployment_unit(unit: TacticalUnitScene) -> void:
	_clear_selection()
	if unit != null and is_instance_valid(unit):
		selected_units.append(unit)
		unit.set_selected(true)
	skirmish_setup_panel.set_has_selection(not selected_units.is_empty())
	queue_redraw()


func _rotate_deployment_selection(direction: int) -> void:
	if not deployment_mode:
		return
	for unit: TacticalUnitScene in selected_units:
		unit.rotation = wrapf(unit.rotation + deg_to_rad(15.0) * float(direction), -PI, PI)
		unit.queue_redraw()
	queue_redraw()


func _delete_deployment_selection() -> void:
	if not deployment_mode:
		return
	var removed_units: Array[TacticalUnitScene] = selected_units.duplicate()
	_clear_selection()
	for unit: TacticalUnitScene in removed_units:
		friendly_units.erase(unit)
		enemy_units.erase(unit)
		unit.queue_free()
	deployment_dragged_unit = null
	_reindex_skirmish_rosters()
	_update_deployment_panel()


func _clear_deployment() -> void:
	if not deployment_mode:
		return
	_clear_selection()
	for unit: TacticalUnitScene in friendly_units + enemy_units:
		unit.queue_free()
	friendly_units.clear()
	enemy_units.clear()
	deployment_callsign_counters.clear()
	deployment_dragged_unit = null
	_update_deployment_panel()


func _reindex_skirmish_rosters() -> void:
	for index: int in friendly_units.size():
		friendly_units[index].team_roster_index = index
	for index: int in enemy_units.size():
		enemy_units[index].team_roster_index = index


func _update_deployment_panel() -> void:
	if not is_instance_valid(skirmish_setup_panel):
		return
	skirmish_setup_panel.update_counts(friendly_units.size(), enemy_units.size())
	skirmish_setup_panel.set_has_selection(not selected_units.is_empty())


func _capture_skirmish_deployment() -> Array[Dictionary]:
	var deployment: Array[Dictionary] = []
	for unit: TacticalUnitScene in friendly_units + enemy_units:
		deployment.append({
			"ship_id": String(unit.get_meta("skirmish_ship_id", "frigate")),
			"team_id": unit.team_id,
			"position": unit.global_position,
			"rotation": unit.rotation,
			"group_id": unit.tactical_group_id,
		})
	return deployment


func _launch_skirmish() -> bool:
	if not deployment_mode or friendly_units.is_empty():
		return false
	skirmish_deployment_snapshot = _capture_skirmish_deployment()
	deployment_mode = false
	skirmish_battle_active = true
	skirmish_free_test_active = enemy_units.is_empty()
	deployment_dragged_unit = null
	_clear_selection()
	for friendly: TacticalUnitScene in friendly_units:
		friendly.set_intel_state(TacticalUnitScene.IntelState.IDENTIFIED)
	for enemy: TacticalUnitScene in enemy_units:
		enemy.set_intel_state(TacticalUnitScene.IntelState.HIDDEN)
	units_layer.process_mode = Node.PROCESS_MODE_INHERIT
	missiles_layer.process_mode = Node.PROCESS_MODE_INHERIT
	pdc_projectiles_layer.process_mode = Node.PROCESS_MODE_INHERIT
	stations_layer.process_mode = Node.PROCESS_MODE_INHERIT
	simulation_clock.paused = false
	skirmish_setup_panel.visible = false
	top_margin.visible = true
	selection_dock.visible = true
	restart_margin.visible = true
	edit_setup_margin.visible = true
	objective_label.text = (
		"TEST LIBRE — SIMULATION SANS ADVERSAIRE"
		if skirmish_free_test_active
		else "ESCARMOUCHE — BLEU JOUEUR VS ROUGE IA"
	)
	_update_sensor_picture()
	_update_status()
	_frame_units(friendly_units + enemy_units)
	return true


func _restart_match() -> void:
	if skirmish_battle_active:
		SkirmishCatalogLogic.stage_reload(skirmish_deployment_snapshot, true)
	get_tree().reload_current_scene()


func _edit_skirmish_setup() -> void:
	if not skirmish_battle_active:
		return
	SkirmishCatalogLogic.stage_reload(skirmish_deployment_snapshot, false)
	get_tree().reload_current_scene()


func _toggle_secondary_info() -> void:
	secondary_info.visible = not secondary_info.visible
	info_button.text = "MASQUER [I]" if secondary_info.visible else "INFOS [I]"


func _cut_selected_engines() -> void:
	if match_over:
		return
	for unit: TacticalUnitScene in selected_units:
		unit.cut_engines()
	_update_status()


func _toggle_attack_command() -> void:
	if attack_command_armed:
		_cancel_attack_command()
	else:
		_arm_attack_command()


func _arm_attack_command() -> void:
	if match_over or selected_units.is_empty():
		return
	attack_command_armed = true
	attack_mode_button.text = "ANNULER [ÉCHAP]"
	queue_redraw()


func _cancel_attack_command() -> void:
	attack_command_armed = false
	attack_mode_button.text = "ATTAQUE [A]"
	queue_redraw()


func _cancel_selected_fire_missions() -> void:
	if selected_units.is_empty():
		return
	var removed_assignment: bool = false
	for mission: FireMission in active_fire_missions:
		var previous_count: int = mission.assigned_units.size()
		mission.remove_units(selected_units)
		removed_assignment = removed_assignment or mission.assigned_units.size() != previous_count
	active_fire_missions = active_fire_missions.filter(
		func(mission): return not mission.assigned_units.is_empty()
	)
	if removed_assignment:
		last_attack_feedback = "MISSION DE FEU ANNULÉE"
		_update_status()
	queue_redraw()


func _update_fire_mission_displays(delta: float) -> void:
	var changed: bool = false
	for mission: FireMission in active_fire_missions:
		if mission.state != FireMission.State.FIRED:
			continue
		mission.completion_display_remaining = maxf(
			0.0,
			mission.completion_display_remaining - delta
		)
		changed = true
	active_fire_missions = active_fire_missions.filter(
		func(mission): return (
			mission.state != FireMission.State.FIRED
			or mission.completion_display_remaining > 0.0
		)
	)
	if changed:
		queue_redraw()


func _toggle_selected_sensors() -> void:
	if match_over:
		return
	for unit: TacticalUnitScene in selected_units:
		unit.toggle_sensor_mode()
	_update_sensor_picture()
	_update_status()


func _cycle_offensive_weapon_selection() -> void:
	offensive_weapon_selection = (int(offensive_weapon_selection) + 1) % OffensiveWeaponSelection.size()
	_update_fire_control_buttons()
	tactical_overlay.invalidate_engagement_envelope()


func _cycle_fire_doctrine() -> void:
	fire_doctrine = (int(fire_doctrine) + 1) % FireDoctrine.size()
	_update_fire_control_buttons()


func _update_fire_control_buttons() -> void:
	var weapon_name := "AUTO"
	if offensive_weapon_selection == OffensiveWeaponSelection.MISSILES:
		weapon_name = "MISSILES"
	elif offensive_weapon_selection == OffensiveWeaponSelection.RAILGUN:
		weapon_name = "RAILGUN"
	elif offensive_weapon_selection == OffensiveWeaponSelection.ANTI_RADIATION:
		weapon_name = "ANTIRAD"
	var doctrine_name := "ÉCONOMIE"
	if fire_doctrine == FireDoctrine.SALVO:
		doctrine_name = "SALVE"
	elif fire_doctrine == FireDoctrine.SATURATION:
		doctrine_name = "SATURATION"
	weapon_select_button.text = "ARME: %s [W]" % weapon_name
	fire_doctrine_button.text = "FEU: %s [D]" % doctrine_name


func _process(delta: float) -> void:
	if not deployment_mode:
		_update_fire_mission_displays(delta)
	_update_camera_zoom(delta)
	_update_camera(delta)


func _physics_process(delta: float) -> void:
	if deployment_mode:
		return
	var processed_ticks: int = simulation_clock.advance(delta)
	if processed_ticks <= 0 or match_over:
		return
	if task_force_demo_motion != null:
		task_force_demo_motion.update(delta)
		queue_redraw()
	_update_objective(delta)
	if match_over:
		return
	_advance_sensor_tracks(delta)
	_update_sensor_picture_if_due(delta)
	_update_ai(delta)
	_update_theater_bounds()
	_update_missile_guidance()
	_update_point_defense(delta)
	_update_status()
	_update_fleet_battle_victory()


func _unhandled_input(event: InputEvent) -> void:
	if deployment_mode:
		_handle_deployment_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if task_force_demo and _handle_task_force_demo_key_event(event):
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_X:
			_cut_selected_engines()
		elif event.keycode == KEY_A:
			_arm_attack_command()
		elif event.keycode == KEY_S:
			_toggle_selected_sensors()
		elif event.keycode == KEY_W:
			_cycle_offensive_weapon_selection()
		elif event.keycode == KEY_D:
			_cycle_fire_doctrine()
		elif event.keycode == KEY_I:
			_toggle_secondary_info()
		elif event.keycode == KEY_V:
			_toggle_range_debug()
		elif event.keycode == KEY_F:
			_frame_friendly_units()
		elif event.keycode == KEY_C:
			_focus_selected_units()
		elif event.keycode == KEY_ESCAPE:
			if attack_command_armed:
				_cancel_attack_command()
			else:
				_cancel_selected_fire_missions()
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if is_panning_camera:
			_pan_camera_by_screen_delta(event.relative)
			get_viewport().set_input_as_handled()
		elif is_selecting:
			selection_end = get_global_mouse_position()
			queue_redraw()
		elif is_defining_move_order:
			move_order_end = get_global_mouse_position()
			queue_redraw()


func _handle_deployment_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_rotate_deployment_selection(-1)
		elif event.keycode == KEY_E:
			_rotate_deployment_selection(1)
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_delete_deployment_selection()
		elif event.keycode == KEY_F:
			_frame_units(friendly_units + enemy_units)
		elif event.keycode == KEY_ESCAPE:
			_select_deployment_unit(null)
		return
	if event is InputEventMouseMotion:
		if is_panning_camera:
			_pan_camera_by_screen_delta(event.relative)
			get_viewport().set_input_as_handled()
		elif deployment_dragged_unit != null and is_instance_valid(deployment_dragged_unit):
			deployment_dragged_unit.global_position = get_global_mouse_position().clamp(
				WORLD_RECT.position + Vector2.ONE * 24.0,
				WORLD_RECT.end - Vector2.ONE * 24.0
			)
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			var clicked_unit: TacticalUnitScene = _find_deployment_unit(get_global_mouse_position())
			if clicked_unit != null:
				_select_deployment_unit(clicked_unit)
				deployment_dragged_unit = clicked_unit
			else:
				_spawn_skirmish_unit(
					skirmish_setup_panel.get_selected_ship_id(),
					skirmish_setup_panel.get_selected_team(),
					get_global_mouse_position(),
					INF,
					skirmish_setup_panel.get_selected_group_id()
				)
		else:
			deployment_dragged_unit = null
		get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		is_panning_camera = mouse_button.pressed
		get_viewport().set_input_as_handled()
	elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
		_set_camera_zoom(target_camera_zoom * 1.12)
	elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
		_set_camera_zoom(target_camera_zoom / 1.12)


func _find_deployment_unit(world_position: Vector2) -> TacticalUnitScene:
	var units: Array = friendly_units + enemy_units
	for index: int in range(units.size() - 1, -1, -1):
		var unit: TacticalUnitScene = units[index]
		if is_instance_valid(unit) and unit.contains_world_point(world_position):
			return unit
	return null


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if attack_command_armed:
				_issue_attack_zone(get_global_mouse_position())
				_cancel_attack_command()
				get_viewport().set_input_as_handled()
				return
			is_selecting = true
			selection_start = get_global_mouse_position()
			selection_end = selection_start
		else:
			if not is_selecting:
				return
			selection_end = get_global_mouse_position()
			_finish_selection(
				Input.is_key_pressed(KEY_SHIFT),
				Input.is_key_pressed(KEY_CTRL)
			)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_cancel_attack_command()
			if event.ctrl_pressed or selected_units.is_empty():
				is_panning_camera = true
				get_viewport().set_input_as_handled()
				return
			is_defining_move_order = true
			move_order_start = get_global_mouse_position()
			move_order_end = move_order_start
			move_order_append = event.shift_pressed
			move_order_fly_through = event.alt_pressed
		else:
			if is_panning_camera:
				is_panning_camera = false
				get_viewport().set_input_as_handled()
				return
			move_order_end = get_global_mouse_position()
			_finish_move_order()
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_set_camera_zoom(target_camera_zoom * 1.12)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_set_camera_zoom(target_camera_zoom / 1.12)


func _update_camera(delta: float) -> void:
	if is_panning_camera:
		_clamp_camera_to_world()
		return
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if get_window().has_focus() and get_viewport().gui_get_hovered_control() == null:
		direction += _get_edge_scroll_direction(get_viewport().get_mouse_position(), get_viewport_rect().size)
	if direction.length() > 1.0:
		direction = direction.normalized()
	if direction != Vector2.ZERO:
		tactical_camera.position += direction * CAMERA_SPEED * delta / tactical_camera.zoom.x
	_clamp_camera_to_world()


func _pan_camera_by_screen_delta(screen_delta: Vector2) -> void:
	tactical_camera.position -= screen_delta / tactical_camera.zoom
	_clamp_camera_to_world()


func _get_edge_scroll_direction(mouse_position: Vector2, viewport_size: Vector2) -> Vector2:
	if mouse_position.x < 0.0 or mouse_position.y < 0.0 or mouse_position.x > viewport_size.x or mouse_position.y > viewport_size.y:
		return Vector2.ZERO
	var direction := Vector2.ZERO
	if mouse_position.x <= EDGE_SCROLL_MARGIN:
		direction.x -= 1.0
	elif mouse_position.x >= viewport_size.x - EDGE_SCROLL_MARGIN:
		direction.x += 1.0
	if mouse_position.y <= EDGE_SCROLL_MARGIN:
		direction.y -= 1.0
	elif mouse_position.y >= viewport_size.y - EDGE_SCROLL_MARGIN:
		direction.y += 1.0
	return direction


func _set_camera_zoom(value: float) -> void:
	zoom_anchor_screen = get_viewport().get_mouse_position()
	zoom_anchor_world = _world_position_under_screen(
		zoom_anchor_screen,
		tactical_camera.zoom.x,
		tactical_camera.position
	)
	target_camera_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	zoom_transition_active = not is_equal_approx(tactical_camera.zoom.x, target_camera_zoom)
	if not zoom_transition_active:
		return


func _update_camera_zoom(delta: float) -> void:
	if not zoom_transition_active:
		return
	var next_zoom: float = lerpf(tactical_camera.zoom.x, target_camera_zoom, minf(1.0, delta * 14.0))
	if absf(next_zoom - target_camera_zoom) <= 0.001:
		next_zoom = target_camera_zoom
		zoom_transition_active = false
	tactical_camera.zoom = Vector2.ONE * next_zoom
	var screen_offset: Vector2 = zoom_anchor_screen - get_viewport_rect().size * 0.5
	tactical_camera.position = zoom_anchor_world - screen_offset / next_zoom
	_clamp_camera_to_world()
	_apply_visual_zoom()


func _world_position_under_screen(screen_position: Vector2, zoom_value: float, camera_position: Vector2) -> Vector2:
	var screen_offset: Vector2 = screen_position - get_viewport_rect().size * 0.5
	return camera_position + screen_offset / maxf(zoom_value, 0.001)


func _apply_visual_zoom() -> void:
	var zoom_value: float = tactical_camera.zoom.x
	for unit: TacticalUnitScene in friendly_units + enemy_units:
		if is_instance_valid(unit):
			unit.set_visual_zoom(zoom_value)
	for missile in missiles_layer.get_children():
		if is_instance_valid(missile) and missile.has_method("set_visual_zoom"):
			missile.set_visual_zoom(zoom_value)
	for projectile in pdc_projectiles_layer.get_children():
		if is_instance_valid(projectile) and projectile.has_method("set_visual_zoom"):
			projectile.set_visual_zoom(zoom_value)
	queue_redraw()


func _frame_friendly_units() -> void:
	_frame_units(friendly_units.filter(func(unit): return is_instance_valid(unit) and not unit.destroyed))


func _focus_selected_units() -> void:
	_frame_units(selected_units.filter(func(unit): return is_instance_valid(unit) and not unit.destroyed))


func _frame_units(units: Array) -> void:
	if units.is_empty():
		return
	var bounds := Rect2(units[0].global_position, Vector2.ZERO)
	for unit in units:
		bounds = bounds.expand(unit.global_position)
	var padding := Vector2(240.0, 180.0)
	var framed_size: Vector2 = bounds.size + padding * 2.0
	var viewport_size: Vector2 = get_viewport_rect().size
	var fitted_zoom: float = minf(
		viewport_size.x / maxf(framed_size.x, 1.0),
		viewport_size.y / maxf(framed_size.y, 1.0)
	)
	tactical_camera.position = bounds.get_center()
	target_camera_zoom = clampf(fitted_zoom, MIN_ZOOM, MAX_ZOOM)
	tactical_camera.zoom = Vector2.ONE * target_camera_zoom
	zoom_transition_active = false
	_clamp_camera_to_world()
	_apply_visual_zoom()


func _clamp_camera_to_world() -> void:
	var half_view: Vector2 = get_viewport_rect().size / tactical_camera.zoom * 0.5
	var minimum_position: Vector2 = WORLD_RECT.position + half_view
	var maximum_position: Vector2 = WORLD_RECT.end - half_view
	if minimum_position.x > maximum_position.x:
		tactical_camera.position.x = WORLD_RECT.get_center().x
	else:
		tactical_camera.position.x = clampf(tactical_camera.position.x, minimum_position.x, maximum_position.x)
	if minimum_position.y > maximum_position.y:
		tactical_camera.position.y = WORLD_RECT.get_center().y
	else:
		tactical_camera.position.y = clampf(tactical_camera.position.y, minimum_position.y, maximum_position.y)


func _spawn_demo_units() -> void:
	if benchmark_empty_scenario:
		_update_sensor_picture()
		return
	if weapons_demo:
		_spawn_weapons_demo_units()
	elif fleet_battle_demo:
		_spawn_fleet_battle_demo_units()
	elif radiation_demo:
		_spawn_radiation_demo_units()
	elif network_demo:
		_spawn_network_demo_units()
	elif ai_demo:
		_spawn_ai_demo_units()
	elif sensor_demo:
		_spawn_sensor_demo_units()
	elif thermal_demo:
		_spawn_thermal_demo_units()
	elif task_force_demo:
		_spawn_task_force_demo_units()
	elif propulsion_demo:
		_spawn_propulsion_demo_units()
	elif DUEL_SANDBOX:
		_spawn_unit("EYE-01", 0, Vector2(-1200, 360), AWACS_PROFILE)
		_spawn_unit("A-01", 0, Vector2(-920, 270), UNIT_PROFILE)
		_spawn_unit("A-02", 0, Vector2(-920, 450), UNIT_PROFILE)
		_spawn_unit("BANDIT-01", 1, Vector2(1450, 240), UNIT_PROFILE)
		_spawn_unit("BANDIT-02", 1, Vector2(1520, 360), UNIT_PROFILE)
		_spawn_unit("BANDIT-03", 1, Vector2(1450, 480), UNIT_PROFILE)
	else:
		var friendly_positions := [
			Vector2(470, 300), Vector2(520, 330), Vector2(570, 300),
			Vector2(470, 390), Vector2(520, 420), Vector2(570, 390),
		]
		var enemy_positions := [
			Vector2(760, 280), Vector2(880, 360), Vector2(990, 260), Vector2(1120, 430),
		]
		for index: int in friendly_positions.size():
			_spawn_unit("A-%02d" % (index + 1), 0, friendly_positions[index], UNIT_PROFILE)
		for index: int in enemy_positions.size():
			_spawn_unit("B-%02d" % (index + 1), 1, enemy_positions[index], UNIT_PROFILE)

	_update_sensor_picture()


func _spawn_task_force_demo_units() -> void:
	print("Démo Task Force active : 8 bâtiments, clic membre = sélection TF, Ctrl+clic = micro.")
	task_force_demo_force = TaskForce.new(0, 0)
	var flip_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	flip_profile.display_name = "Frégate à moteur principal"
	flip_profile.tactical_role = "FLIP-AND-BURN"
	flip_profile.propulsion_profile = MAIN_DRIVE_PROFILE
	var hybrid_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	hybrid_profile.display_name = "Éclaireur à propulsion mixte"
	hybrid_profile.tactical_role = "HYBRIDE"
	hybrid_profile.propulsion_profile = HYBRID_DRIVE_PROFILE
	var entries: Array[Dictionary] = [
		{"callsign": "TF-FLIP-01", "profile": flip_profile, "status": TaskForce.PhysicalStatus.INTEGRATED},
		{"callsign": "TF-FLIP-02", "profile": flip_profile, "status": TaskForce.PhysicalStatus.INTEGRATED},
		{"callsign": "TF-FLIP-03", "profile": flip_profile, "status": TaskForce.PhysicalStatus.INTEGRATED},
		{"callsign": "TF-VECTOR-01", "profile": UNIT_PROFILE, "status": TaskForce.PhysicalStatus.INTEGRATED},
		{"callsign": "TF-VECTOR-02", "profile": UNIT_PROFILE, "status": TaskForce.PhysicalStatus.INTEGRATED},
		{"callsign": "TF-VECTOR-03", "profile": UNIT_PROFILE, "status": TaskForce.PhysicalStatus.INTEGRATED},
		{"callsign": "TF-ÉCLAIREUR", "profile": hybrid_profile, "status": TaskForce.PhysicalStatus.INTEGRATED},
		{"callsign": "TF-AWACS", "profile": AWACS_PROFILE, "status": TaskForce.PhysicalStatus.SUPPORT},
	]
	for entry: Dictionary in entries:
		var unit: TacticalUnitScene = _spawn_unit(
			entry["callsign"],
			0,
			Vector2.ZERO,
			entry["profile"]
		)
		task_force_demo_force.add_member(unit, entry["status"])
		if unit.callsign == "TF-ÉCLAIREUR":
			task_force_demo_scout = unit
	var initial_anchor := Vector2(-1600.0, 360.0)
	var initial_heading: float = PI * 0.5
	task_force_demo_motion = TaskForceMotion.new()
	task_force_demo_motion.configure(
		task_force_demo_force,
		TASK_FORCE_FORMATION_PROFILE,
		initial_anchor,
		initial_heading
	)
	var initial_slots: Dictionary = task_force_demo_motion.calculate_current_slots()
	for unit: TacticalUnitScene in initial_slots:
		unit.global_position = initial_slots[unit]
		unit.rotation = initial_heading
		unit.velocity = Vector2.ZERO
		unit.cut_engines()
	task_force_demo_motion.request_formation_refresh()
	task_force_demo_motion.update(0.0)


func _spawn_propulsion_demo_units() -> void:
	var flip_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	flip_profile.display_name = "Démonstrateur moteur principal"
	flip_profile.tactical_role = "FLIP-AND-BURN"
	flip_profile.propulsion_profile = MAIN_DRIVE_PROFILE

	var hold_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	hold_profile.display_name = "Démonstrateur poussée vectorielle"
	hold_profile.tactical_role = "CAP MAINTENU"
	hold_profile.propulsion_profile = VECTOR_DRIVE_PROFILE

	var hybrid_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	hybrid_profile.display_name = "Démonstrateur propulsion mixte"
	hybrid_profile.tactical_role = "HYBRIDE"
	hybrid_profile.propulsion_profile = HYBRID_DRIVE_PROFILE

	var demonstrations: Array[Dictionary] = [
		{"callsign": "FLIP-01", "position": Vector2(-1200.0, 160.0), "profile": flip_profile},
		{"callsign": "CAP-01", "position": Vector2(-1200.0, 360.0), "profile": hold_profile},
		{"callsign": "HYBRID-01", "position": Vector2(-1200.0, 560.0), "profile": hybrid_profile},
	]
	for demonstration: Dictionary in demonstrations:
		var start_position: Vector2 = demonstration["position"]
		var unit: TacticalUnitScene = _spawn_unit(
			demonstration["callsign"],
			0,
			start_position,
			demonstration["profile"]
		)
		unit.set_navigation_order(Vector2(1200.0, start_position.y))


func _spawn_weapons_demo_units() -> void:
	var guard_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	guard_profile.display_name = "Escorte de défense rapprochée"
	guard_profile.tactical_role = "DÉFENSE"
	guard_profile.weapon_system_profiles = [KINETIC_PDC_SYSTEM, LASER_PDC_SYSTEM, SHORT_INTERCEPTOR_SYSTEM]
	guard_profile.missile_capacity = 0
	guard_profile.missile_launcher_count = 0

	var frigate_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	frigate_profile.display_name = "Frégate antinavire"
	frigate_profile.tactical_role = "MISSILES MOYENS"
	frigate_profile.weapon_system_profiles = [KINETIC_PDC_SYSTEM, MEDIUM_MISSILE_SYSTEM]

	var railgun_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	railgun_profile.display_name = "Canon axial"
	railgun_profile.tactical_role = "RAILGUN"
	railgun_profile.weapon_system_profiles = [KINETIC_PDC_SYSTEM, RAILGUN_SYSTEM]
	railgun_profile.missile_capacity = 0
	railgun_profile.missile_launcher_count = 0

	var arsenal_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	arsenal_profile.display_name = "Porte-missiles à cellules fixes"
	arsenal_profile.tactical_role = "ARSENAL"
	arsenal_profile.weapon_system_profiles = [KINETIC_PDC_SYSTEM, LONG_MISSILE_SYSTEM]
	arsenal_profile.missile_capacity = 0
	arsenal_profile.missile_launcher_count = 0
	_configure_receiver_only_arsenal(arsenal_profile)

	var friendly_profiles: Array[UnitProfile] = [guard_profile, frigate_profile, railgun_profile, arsenal_profile]
	for index: int in friendly_profiles.size():
		var friendly: TacticalUnitScene = _spawn_unit(
			["GUARD-01", "FRIG-01", "RAIL-01", "ARSENAL-01"][index],
			0,
			Vector2(-900.0, 120.0 + float(index) * 180.0),
			friendly_profiles[index]
		)
		friendly.rotation = PI * 0.5
	var awacs: TacticalUnitScene = _spawn_unit(
		"EYE-TEST",
		0,
		Vector2(-1120.0, 390.0),
		AWACS_PROFILE
	)
	awacs.rotation = PI * 0.5

	var target_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	target_profile.display_name = "Cible d'essai"
	target_profile.tactical_role = "PLASTRON"
	target_profile.missile_capacity = 0
	target_profile.missile_launcher_count = 0
	target_profile.point_defense_ammunition_capacity = 0
	target_profile.weapon_system_profiles = []
	var target_positions: Array[Vector2] = [
		Vector2(-280.0, 300.0),
		Vector2(-220.0, 360.0),
		Vector2(-280.0, 420.0),
		Vector2(-220.0, 480.0),
	]
	for index: int in 4:
		var target: TacticalUnitScene = _spawn_unit(
			"TARGET-%02d" % (index + 1),
			1,
			target_positions[index],
			target_profile
		)
		target.invulnerable = true
		target.fixed_in_place = true
		target.set_intel_state(TacticalUnitScene.IntelState.IDENTIFIED)

	var incoming := TacticalMissileScene.new() as TacticalMissileScene
	missiles_layer.add_child(incoming)
	incoming.impacted.connect(_on_missile_impacted.bind(1))
	incoming.detonated.connect(_on_missile_detonated)
	incoming.finished.connect(_on_missile_finished)
	incoming.launch(Vector2(-480.0, 120.0), friendly_units[0], 1, MISSILE_PROFILE)
	incoming.set_visual_zoom(tactical_camera.zoom.x)


func _spawn_fleet_battle_demo_units() -> void:
	var laser_escort := _make_fleet_battle_profile(
		"Escorte laser", "ESCORTEUR", "DÉFENSE LASER",
		[LASER_PDC_SYSTEM, SHORT_INTERCEPTOR_SYSTEM, MEDIUM_MISSILE_SYSTEM], true
	)
	var kinetic_escort := _make_fleet_battle_profile(
		"Escorte cinétique", "ESCORTEUR", "DÉFENSE CINÉTIQUE",
		[KINETIC_PDC_SYSTEM, SHORT_INTERCEPTOR_SYSTEM, MEDIUM_MISSILE_SYSTEM], true
	)
	var frigate := _make_fleet_battle_profile(
		"Frégate antinavire", "FRÉGATE", "MISSILES MOYENS",
		[KINETIC_PDC_SYSTEM, MEDIUM_MISSILE_SYSTEM], true
	)
	var railgun := _make_fleet_battle_profile(
		"Croiseur railgun", "CROISEUR", "RAILGUN AXIAL",
		[KINETIC_PDC_SYSTEM, RAILGUN_SYSTEM], false
	)
	var arsenal := _make_fleet_battle_profile(
		"Porte-missiles", "PORTE-MISSILES", "CELLULES LONGUE PORTÉE",
		[KINETIC_PDC_SYSTEM, LONG_MISSILE_SYSTEM], false, true
	)
	var anti_radiation := _make_fleet_battle_profile(
		"Frégate de suppression", "FRÉGATE", "ANTIRAD",
		[KINETIC_PDC_SYSTEM, ANTI_RADIATION_SYSTEM, MEDIUM_MISSILE_SYSTEM], true
	)
	var passive_relay: UnitProfile = AWACS_PROFILE.duplicate(true)
	passive_relay.display_name = "Relais passif"
	passive_relay.classification_label = "RELAIS"
	passive_relay.tactical_role = "RELAIS SILENCIEUX"
	var blue_entries: Array[Dictionary] = [
		{"suffix": "EYE", "profile": AWACS_PROFILE, "offset": Vector2(-430.0, 0.0), "active": true},
		{"suffix": "ESC-L1", "profile": laser_escort, "offset": Vector2(-100.0, -390.0)},
		{"suffix": "ESC-L2", "profile": laser_escort, "offset": Vector2(-100.0, 390.0)},
		{"suffix": "ESC-K1", "profile": kinetic_escort, "offset": Vector2(-60.0, -260.0)},
		{"suffix": "ESC-K2", "profile": kinetic_escort, "offset": Vector2(-60.0, 260.0)},
		{"suffix": "FRIG-1", "profile": frigate, "offset": Vector2(100.0, -230.0)},
		{"suffix": "FRIG-2", "profile": frigate, "offset": Vector2(160.0, 0.0)},
		{"suffix": "FRIG-3", "profile": frigate, "offset": Vector2(100.0, 230.0)},
		{"suffix": "ARS-1", "profile": arsenal, "offset": Vector2(-260.0, -150.0)},
		{"suffix": "ARS-2", "profile": arsenal, "offset": Vector2(-260.0, 150.0)},
		{"suffix": "ARM-1", "profile": anti_radiation, "offset": Vector2(20.0, -110.0)},
		{"suffix": "ARM-2", "profile": anti_radiation, "offset": Vector2(20.0, 110.0)},
	]
	var red_entries: Array[Dictionary] = [
		{"suffix": "RELAIS", "profile": passive_relay, "offset": Vector2(390.0, 0.0)},
		{"suffix": "RAIL-1", "profile": railgun, "offset": Vector2(-210.0, -340.0)},
		{"suffix": "RAIL-2", "profile": railgun, "offset": Vector2(-260.0, 0.0)},
		{"suffix": "RAIL-3", "profile": railgun, "offset": Vector2(-210.0, 340.0)},
		{"suffix": "FRIG-1", "profile": frigate, "offset": Vector2(-40.0, -190.0)},
		{"suffix": "FRIG-2", "profile": frigate, "offset": Vector2(-40.0, 190.0)},
		{"suffix": "ESC-L", "profile": laser_escort, "offset": Vector2(130.0, -280.0)},
		{"suffix": "ESC-K", "profile": kinetic_escort, "offset": Vector2(130.0, 280.0)},
		{"suffix": "ARM-1", "profile": anti_radiation, "offset": Vector2(20.0, -100.0)},
		{"suffix": "ARM-2", "profile": anti_radiation, "offset": Vector2(20.0, 100.0)},
	]
	_spawn_fleet_formation(0, Vector2(-1320.0, 360.0), blue_entries)
	_spawn_fleet_formation(1, Vector2(1320.0, 360.0), red_entries)


func _spawn_fleet_formation(
	team_id: int,
	base_position: Vector2,
	entries: Array[Dictionary]
) -> void:
	for entry: Dictionary in entries:
		var jitter := Vector2(
			fleet_battle_rng.randf_range(-55.0, 55.0),
			fleet_battle_rng.randf_range(-45.0, 45.0)
		)
		var unit: TacticalUnitScene = _spawn_unit(
			("B-" if team_id == 0 else "R-") + String(entry.suffix),
			team_id,
			base_position + Vector2(entry.offset) + jitter,
			entry.profile
		)
		unit.rotation = PI * 0.5 if team_id == 0 else -PI * 0.5
		unit.sensor_mode = (
			TacticalUnitScene.SensorMode.ACTIVE
			if bool(entry.get("active", false))
			else TacticalUnitScene.SensorMode.PASSIVE
		)


func _make_fleet_battle_profile(
	display_name: String,
	classification_label: String,
	role: String,
	systems: Array[WeaponSystemProfile],
	uses_legacy_missile_magazine: bool,
	receiver_only_arsenal: bool = false
) -> UnitProfile:
	var profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	profile.display_name = display_name
	profile.classification_label = classification_label
	profile.tactical_role = role
	profile.weapon_system_profiles = systems
	if not uses_legacy_missile_magazine:
		profile.missile_capacity = 0
		profile.missile_launcher_count = 0
	if receiver_only_arsenal:
		_configure_receiver_only_arsenal(profile)
	return profile


func _configure_receiver_only_arsenal(profile: UnitProfile) -> void:
	profile.sensor_range = 378.0
	profile.active_sensor_range = 1008.0
	profile.active_emission_detection_range = 720.0
	profile.data_link_profile = RECEIVER_ONLY_DATA_LINK


func _spawn_radiation_demo_units() -> void:
	var hunter_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	hunter_profile.display_name = "Frégate de suppression électronique"
	hunter_profile.tactical_role = "CHASSEUR D'ÉMETTEURS"
	hunter_profile.weapon_system_profiles = [KINETIC_PDC_SYSTEM, ANTI_RADIATION_SYSTEM]
	hunter_profile.active_emission_detection_range = 2200.0
	hunter_profile.missile_capacity = 0
	hunter_profile.missile_launcher_count = 0
	var hunter: TacticalUnitScene = _spawn_unit(
		"ARM-01",
		0,
		Vector2(-700.0, 360.0),
		hunter_profile
	)
	hunter.rotation = PI * 0.5
	hunter.sensor_mode = TacticalUnitScene.SensorMode.PASSIVE

	var emitter_profile: UnitProfile = AWACS_PROFILE.duplicate(true)
	emitter_profile.display_name = "Émetteur de calibration"
	emitter_profile.tactical_role = "RADAR ACTIF"
	emitter_profile.weapon_system_profiles = []
	emitter_profile.point_defense_ammunition_capacity = 0
	emitter_profile.missile_capacity = 0
	emitter_profile.missile_launcher_count = 0
	var emitter: TacticalUnitScene = _spawn_unit(
		"EYE-CIBLE",
		1,
		Vector2(700.0, 360.0),
		emitter_profile
	)
	emitter.sensor_mode = TacticalUnitScene.SensorMode.ACTIVE
	emitter.fixed_in_place = true
	emitter.invulnerable = true


func _spawn_network_demo_units() -> void:
	var transmitter_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	transmitter_profile.display_name = "Capteur avec émission de données"
	transmitter_profile.tactical_role = "CAPTEUR TX"
	transmitter_profile.weapon_system_profiles = []
	transmitter_profile.missile_capacity = 0
	transmitter_profile.missile_launcher_count = 0
	transmitter_profile.data_link_profile = STANDARD_DATA_LINK.duplicate(true)
	transmitter_profile.data_link_profile.can_transmit = true
	var transmitter: TacticalUnitScene = _spawn_unit(
		"TX-01", 0, Vector2(-1200.0, 260.0), transmitter_profile
	)
	transmitter.sensor_mode = TacticalUnitScene.SensorMode.ACTIVE

	var relay: TacticalUnitScene = _spawn_unit(
		"RELAIS-01", 0, Vector2(-200.0, 360.0), AWACS_PROFILE
	)
	relay.sensor_mode = TacticalUnitScene.SensorMode.PASSIVE

	var receiver_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	receiver_profile.display_name = "Bâtiment récepteur de pistes"
	receiver_profile.tactical_role = "RÉCEPTEUR"
	receiver_profile.weapon_system_profiles = []
	receiver_profile.missile_capacity = 0
	receiver_profile.missile_launcher_count = 0
	receiver_profile.sensor_range = 100.0
	receiver_profile.active_sensor_range = 130.0
	receiver_profile.data_link_profile = RECEIVER_ONLY_DATA_LINK
	_spawn_unit("RX-01", 0, Vector2(1200.0, 260.0), receiver_profile)

	var isolated_profile: UnitProfile = receiver_profile.duplicate(true)
	isolated_profile.display_name = "Bâtiment sans liaison"
	isolated_profile.tactical_role = "ISOLÉ"
	isolated_profile.data_link_profile = null
	_spawn_unit("ISOLÉ-01", 0, Vector2(1200.0, 500.0), isolated_profile)

	var target_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	target_profile.display_name = "Contact réseau"
	target_profile.tactical_role = "CIBLE FIXE"
	target_profile.weapon_system_profiles = []
	target_profile.missile_capacity = 0
	target_profile.missile_launcher_count = 0
	target_profile.point_defense_ammunition_capacity = 0
	target_profile.data_link_profile = null
	var target: TacticalUnitScene = _spawn_unit(
		"CONTACT-RÉSEAU", 1, Vector2(-800.0, 360.0), target_profile
	)
	target.fixed_in_place = true
	target.invulnerable = true


func _spawn_ai_demo_units() -> void:
	var frigate_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	frigate_profile.display_name = "Frégate de test joueur"
	frigate_profile.tactical_role = "MISSILES MOYENS"
	frigate_profile.weapon_system_profiles = [KINETIC_PDC_SYSTEM, MEDIUM_MISSILE_SYSTEM]
	var frigate: TacticalUnitScene = _spawn_unit("FRIG-BLEU", 0, Vector2(-280.0, 280.0), frigate_profile)
	frigate.invulnerable = true
	frigate.rotation = PI * 0.5

	var friendly_railgun_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	friendly_railgun_profile.display_name = "Railgun de test joueur"
	friendly_railgun_profile.tactical_role = "RAILGUN AXIAL"
	friendly_railgun_profile.weapon_system_profiles = [KINETIC_PDC_SYSTEM, RAILGUN_SYSTEM]
	friendly_railgun_profile.missile_capacity = 0
	friendly_railgun_profile.missile_launcher_count = 0
	var friendly_railgun: TacticalUnitScene = _spawn_unit(
		"RAIL-BLEU",
		0,
		Vector2(-280.0, 460.0),
		friendly_railgun_profile
	)
	friendly_railgun.invulnerable = true
	friendly_railgun.rotation = PI * 0.5

	var friendly_awacs: TacticalUnitScene = _spawn_unit("EYE-BLEU", 0, Vector2(-520.0, 370.0), AWACS_PROFILE)
	friendly_awacs.invulnerable = true
	friendly_awacs.sensor_mode = TacticalUnitScene.SensorMode.ACTIVE

	var railgun_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	railgun_profile.display_name = "Chasseur cinétique IA"
	railgun_profile.tactical_role = "RAILGUN AXIAL"
	railgun_profile.weapon_system_profiles = [KINETIC_PDC_SYSTEM, RAILGUN_SYSTEM]
	railgun_profile.missile_capacity = 0
	railgun_profile.missile_launcher_count = 0
	var railgun_ship: TacticalUnitScene = _spawn_unit("RAIL-AI", 1, Vector2(420.0, 260.0), railgun_profile)
	railgun_ship.rotation = 0.0

	var arsenal_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	arsenal_profile.display_name = "Porte-missiles IA"
	arsenal_profile.tactical_role = "CELLULES LONGUE PORTÉE"
	arsenal_profile.weapon_system_profiles = [KINETIC_PDC_SYSTEM, LONG_MISSILE_SYSTEM]
	arsenal_profile.missile_capacity = 0
	arsenal_profile.missile_launcher_count = 0
	_configure_receiver_only_arsenal(arsenal_profile)
	var arsenal_ship: TacticalUnitScene = _spawn_unit("ARSENAL-AI", 1, Vector2(1300.0, 460.0), arsenal_profile)
	arsenal_ship.rotation = 0.0

	var awacs: TacticalUnitScene = _spawn_unit("EYE-AI", 1, Vector2(820.0, 360.0), AWACS_PROFILE)
	awacs.sensor_mode = TacticalUnitScene.SensorMode.ACTIVE


func _spawn_sensor_demo_units() -> void:
	var sensor_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	sensor_profile.display_name = "Plateforme de veille"
	sensor_profile.classification_label = "CAPTEUR"
	sensor_profile.tactical_role = "CAPTEUR ACTIF"
	sensor_profile.weapon_system_profiles = []
	sensor_profile.missile_capacity = 0
	sensor_profile.missile_launcher_count = 0
	sensor_profile.point_defense_ammunition_capacity = 0
	var sensor: TacticalUnitScene = _spawn_unit("SENSOR-01", 0, Vector2(-600.0, 360.0), sensor_profile)
	sensor.sensor_mode = TacticalUnitScene.SensorMode.ACTIVE
	sensor.invulnerable = true

	var shooter_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	shooter_profile.display_name = "Frégate de tir de calibration"
	shooter_profile.classification_label = "FRÉGATE"
	shooter_profile.tactical_role = "MISSILES MOYENS"
	var shooter: TacticalUnitScene = _spawn_unit("TIREUR-01", 0, Vector2(-520.0, 470.0), shooter_profile)
	shooter.sensor_mode = TacticalUnitScene.SensorMode.PASSIVE
	shooter.invulnerable = true

	var target_center: Vector2 = sensor.global_position + Vector2(
		sensor.active_sensor_range * 0.82,
		0.0
	)
	var target_specs: Array[Dictionary] = [
		{"callsign": "CONTACT-A", "position": target_center + Vector2(-40.0, -150.0), "class": "FRÉGATE"},
		{"callsign": "CONTACT-B", "position": target_center + Vector2(0.0, -50.0), "class": "ESCORTEUR"},
		{"callsign": "CONTACT-C", "position": target_center + Vector2(0.0, 50.0), "class": "CROISEUR"},
		{"callsign": "CONTACT-D", "position": target_center + Vector2(-40.0, 150.0), "class": "PORTE-MISSILES"},
	]
	for spec: Dictionary in target_specs:
		var target_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
		target_profile.display_name = "Plastron fixe de calibration"
		target_profile.classification_label = spec["class"]
		target_profile.tactical_role = "PLASTRON FIXE"
		target_profile.weapon_system_profiles = []
		target_profile.missile_capacity = 0
		target_profile.missile_launcher_count = 0
		target_profile.point_defense_ammunition_capacity = 0
		var target: TacticalUnitScene = _spawn_unit(
			spec["callsign"],
			1,
			spec["position"],
			target_profile
		)
		target.invulnerable = true
		target.fixed_in_place = true
		target.rotation = -PI * 0.5


func _spawn_thermal_demo_units() -> void:
	var sensor_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
	sensor_profile.display_name = "Veilleur thermique de calibration"
	sensor_profile.classification_label = "CAPTEUR"
	sensor_profile.tactical_role = "VEILLE PASSIVE"
	sensor_profile.weapon_system_profiles = []
	sensor_profile.missile_capacity = 0
	sensor_profile.missile_launcher_count = 0
	sensor_profile.point_defense_ammunition_capacity = 0
	var sensor: TacticalUnitScene = _spawn_unit(
		"VEILLE-IR",
		0,
		Vector2(-600.0, 360.0),
		sensor_profile
	)
	sensor.sensor_mode = TacticalUnitScene.SensorMode.ACTIVE
	sensor.invulnerable = true

	var target_specs: Array[Dictionary] = [
		{"callsign": "CIBLE-FROIDE", "position": Vector2(140.0, 260.0), "heat": 0.0, "class": "COQUE FROIDE"},
		{"callsign": "CIBLE-CHAUDE", "position": Vector2(140.0, 460.0), "heat": 100.0, "class": "COQUE CHAUDE"},
	]
	for spec: Dictionary in target_specs:
		var target_profile: UnitProfile = UNIT_PROFILE.duplicate(true)
		target_profile.display_name = "Cible thermique étalonnée"
		target_profile.classification_label = spec["class"]
		target_profile.tactical_role = "CALIBRATION IR"
		target_profile.weapon_system_profiles = []
		target_profile.missile_capacity = 0
		target_profile.missile_launcher_count = 0
		target_profile.point_defense_ammunition_capacity = 0
		target_profile.data_link_profile = null
		target_profile.initial_heat = spec["heat"]
		var target: TacticalUnitScene = _spawn_unit(
			spec["callsign"],
			1,
			spec["position"],
			target_profile
		)
		target.invulnerable = true
		target.fixed_in_place = true
		target.rotation = -PI * 0.5
		if target.callsign == "CIBLE-CHAUDE":
			target.thermal_mode = TacticalUnitScene.ThermalMode.COMBAT


func _spawn_unit(callsign: String, team_id: int, start_position: Vector2, profile: UnitProfile) -> TacticalUnitScene:
	var unit := TacticalUnitScene.new() as TacticalUnitScene
	unit.configure(callsign, team_id, start_position, profile)
	unit.team_roster_index = friendly_units.size() if team_id == 0 else enemy_units.size()
	unit.set_visual_zoom(tactical_camera.zoom.x)
	if team_id != 0:
		unit.set_intel_state(TacticalUnitScene.IntelState.HIDDEN)
	units_layer.add_child(unit)
	if team_id == 0:
		friendly_units.append(unit)
	else:
		enemy_units.append(unit)
	return unit


func _spawn_objective_station() -> void:
	objective_station = StrategicStationScene.new() as StrategicStationScene
	objective_station.configure(MATCH_RULES)
	objective_station.position = Vector2(740.0, 610.0)
	stations_layer.add_child(objective_station)


func _update_objective(delta: float) -> void:
	if match_over:
		return
	if objective_station == null:
		return
	var team_zero_present := _team_present_in_capture_zone(friendly_units)
	var team_one_present := _team_present_in_capture_zone(enemy_units)
	objective_station.update_capture(team_zero_present, team_one_present, delta)

	if objective_station.team_id == 0:
		team_hold_time[0] += delta
		team_hold_time[1] = 0.0
	elif objective_station.team_id == 1:
		team_hold_time[1] += delta
		team_hold_time[0] = 0.0
	else:
		team_hold_time[0] = 0.0
		team_hold_time[1] = 0.0

	var owner_text := "NEUTRE"
	if objective_station.team_id == 0:
		owner_text = "BLEU"
	elif objective_station.team_id == 1:
		owner_text = "ROUGE"
	var hold_time: float = team_hold_time[maxi(0, objective_station.team_id)] if objective_station.team_id >= 0 else 0.0
	objective_label.text = "RELAIS: %s  •  CONTRÔLE %.1f/%.0f s" % [owner_text, hold_time, MATCH_RULES.victory_hold_time]

	if not match_over and objective_station.team_id >= 0 and hold_time >= MATCH_RULES.victory_hold_time:
		_end_match(objective_station.team_id)


func _team_present_in_capture_zone(units: Array[TacticalUnitScene]) -> bool:
	for unit: TacticalUnitScene in units:
		if not unit.destroyed and unit.global_position.distance_to(objective_station.global_position) <= objective_station.capture_radius:
			return true
	return false


func _update_theater_bounds() -> void:
	var safe_rect: Rect2 = WORLD_RECT.grow(-THEATER_RETURN_MARGIN)
	var units: Array = friendly_units + enemy_units
	for unit: TacticalUnitScene in units:
		if not is_instance_valid(unit) or unit.destroyed:
			continue
		if not WORLD_RECT.has_point(unit.global_position):
			if not unit.is_returning_to_theater or not unit.has_move_target:
				var safe_maximum: Vector2 = safe_rect.end - Vector2.ONE
				var return_point := Vector2(
					clampf(unit.global_position.x, safe_rect.position.x, safe_maximum.x),
					clampf(unit.global_position.y, safe_rect.position.y, safe_maximum.y)
				)
				unit.is_returning_to_theater = true
				unit.set_navigation_order(return_point)
		elif unit.is_returning_to_theater and safe_rect.has_point(unit.global_position) and not unit.has_move_target:
			unit.is_returning_to_theater = false


func _end_match(winning_team: int) -> void:
	match_over = true
	simulation_clock.paused = true
	units_layer.process_mode = Node.PROCESS_MODE_DISABLED
	missiles_layer.process_mode = Node.PROCESS_MODE_DISABLED
	pdc_projectiles_layer.process_mode = Node.PROCESS_MODE_DISABLED
	stations_layer.process_mode = Node.PROCESS_MODE_DISABLED
	_cancel_attack_command()
	victory_label.text = "VICTOIRE BLEUE" if winning_team == 0 else "VICTOIRE ROUGE"
	victory_label.visible = true


func _update_fleet_battle_victory() -> void:
	if skirmish_free_test_active:
		return
	if (not fleet_battle_demo and not skirmish_battle_active) or match_over:
		return
	var blue_alive: bool = friendly_units.any(func(unit): return not unit.destroyed)
	var red_alive: bool = enemy_units.any(func(unit): return not unit.destroyed)
	if blue_alive and red_alive:
		return
	if blue_alive:
		_end_match(0)
	elif red_alive:
		_end_match(1)
	else:
		match_over = true
		simulation_clock.paused = true
		units_layer.process_mode = Node.PROCESS_MODE_DISABLED
		missiles_layer.process_mode = Node.PROCESS_MODE_DISABLED
		pdc_projectiles_layer.process_mode = Node.PROCESS_MODE_DISABLED
		stations_layer.process_mode = Node.PROCESS_MODE_DISABLED
		_cancel_attack_command()
		victory_label.text = "DESTRUCTION MUTUELLE"
		victory_label.visible = true


func _update_sensor_picture() -> void:
	_rebuild_data_link_networks()
	_update_automatic_radio_emissions()
	_begin_sensor_pass()
	var refresh_local_ai_targets: bool = ai_decision_remaining <= SENSOR_UPDATE_INTERVAL + 0.001
	_prepare_local_detection_cache(refresh_local_ai_targets)
	var friendly_buffers := SensorPassBuffers.new(friendly_units.size())
	var enemy_buffers := SensorPassBuffers.new(enemy_units.size())
	for friendly_index: int in friendly_units.size():
		friendly_buffers.capture_target(friendly_index, friendly_units[friendly_index])
	for enemy_index: int in enemy_units.size():
		enemy_buffers.capture_target(enemy_index, enemy_units[enemy_index])
	friendly_buffers.capture_search_radii(friendly_units, enemy_buffers)
	enemy_buffers.capture_search_radii(enemy_units, friendly_buffers)
	_collect_group_local_sensor_observations(
		friendly_buffers,
		enemy_buffers,
		refresh_local_ai_targets
	)

	if objective_station != null and objective_station.team_id == 0:
		for enemy_index: int in enemy_units.size():
			var enemy: TacticalUnitScene = enemy_units[enemy_index]
			if enemy.destroyed:
				continue
			var station_range: float = objective_station.sensor_range * enemy_buffers.signatures[enemy_index]
			var station_ratio_squared: float = objective_station.global_position.distance_squared_to(enemy.global_position) / maxf(
				station_range * station_range,
				0.0001
			)
			if station_ratio_squared < enemy_buffers.best_active[enemy_index]:
				enemy_buffers.best_active[enemy_index] = station_ratio_squared
				enemy_buffers.best_sources[enemy_index] = 0

	if tactical_groups_by_team[0].size() <= 1:
		for enemy_index: int in enemy_units.size():
			_record_sensor_observation(
				0, enemy_units[enemy_index], enemy_buffers.best_active[enemy_index],
				enemy_buffers.best_passive[enemy_index], enemy_buffers.observer_counts[enemy_index],
				enemy_buffers.triangulation_quality[enemy_index], enemy_buffers.channels[enemy_index],
				_observation_source_ids(enemy_buffers.best_sources[enemy_index])
			)
	if tactical_groups_by_team[1].size() <= 1:
		for friendly_index: int in friendly_units.size():
			_record_sensor_observation(
				1, friendly_units[friendly_index], friendly_buffers.best_active[friendly_index],
				friendly_buffers.best_passive[friendly_index], friendly_buffers.observer_counts[friendly_index],
				friendly_buffers.triangulation_quality[friendly_index], friendly_buffers.channels[friendly_index],
				_observation_source_ids(friendly_buffers.best_sources[friendly_index])
			)
	_update_group_track_pictures(0, enemy_buffers.group_observations)
	_update_group_track_pictures(1, friendly_buffers.group_observations)
	_update_command_picture_from_groups(0)
	_update_command_picture_from_groups(1)
	_sync_player_sensor_picture()
	_update_fire_missions()


func _collect_group_local_sensor_observations(
	friendly_buffers: SensorPassBuffers,
	enemy_buffers: SensorPassBuffers,
	refresh_local_ai_targets: bool
) -> void:
	var friendly_groups: Dictionary = tactical_groups_by_team[0]
	var enemy_groups: Dictionary = tactical_groups_by_team[1]
	var friendly_network_sharing: bool = data_link_networks_by_team[0].has_transmitters()
	var enemy_network_sharing: bool = data_link_networks_by_team[1].has_transmitters()
	var friendly_group_pictures: bool = friendly_groups.size() > 1
	var enemy_group_pictures: bool = enemy_groups.size() > 1
	for friendly_group: TacticalGroup in friendly_groups.values():
		var friendly_bounds: Rect2 = _get_tactical_group_bounds(friendly_group)
		var friendly_search_radius: float = _get_group_sensor_search_radius(
			friendly_group,
			friendly_buffers
		)
		for enemy_group: TacticalGroup in enemy_groups.values():
			var enemy_bounds: Rect2 = _get_tactical_group_bounds(enemy_group)
			var enemy_search_radius: float = _get_group_sensor_search_radius(
				enemy_group,
				enemy_buffers
			)
			if (
				not friendly_bounds.grow(friendly_search_radius).intersects(enemy_bounds)
				and not enemy_bounds.grow(enemy_search_radius).intersects(friendly_bounds)
			):
				continue
			_collect_sensor_group_pair(
				friendly_group,
				enemy_group,
				friendly_buffers,
				enemy_buffers,
				friendly_network_sharing,
				enemy_network_sharing,
				friendly_group_pictures,
				enemy_group_pictures,
				refresh_local_ai_targets
			)


func _collect_sensor_group_pair(
	friendly_group: TacticalGroup,
	enemy_group: TacticalGroup,
	friendly_buffers: SensorPassBuffers,
	enemy_buffers: SensorPassBuffers,
	friendly_network_sharing: bool,
	enemy_network_sharing: bool,
	friendly_group_pictures: bool,
	enemy_group_pictures: bool,
	refresh_local_ai_targets: bool
) -> void:
	var friendly_signatures := friendly_buffers.signatures
	var friendly_emissions := friendly_buffers.emissions
	var friendly_passive_ranges := friendly_buffers.passive_ranges_squared
	var friendly_active_ranges := friendly_buffers.active_ranges_squared
	var friendly_radio_ranges := friendly_buffers.radio_ranges_squared
	var friendly_search_radii := friendly_buffers.search_radii
	var friendly_best_active := friendly_buffers.best_active
	var friendly_best_passive := friendly_buffers.best_passive
	var friendly_best_source_ratios := friendly_buffers.best_source_ratios
	var friendly_best_sources := friendly_buffers.best_sources
	var friendly_channels := friendly_buffers.channels
	var enemy_signatures := enemy_buffers.signatures
	var enemy_emissions := enemy_buffers.emissions
	var enemy_passive_ranges := enemy_buffers.passive_ranges_squared
	var enemy_active_ranges := enemy_buffers.active_ranges_squared
	var enemy_radio_ranges := enemy_buffers.radio_ranges_squared
	var enemy_search_radii := enemy_buffers.search_radii
	var enemy_best_active := enemy_buffers.best_active
	var enemy_best_passive := enemy_buffers.best_passive
	var enemy_best_source_ratios := enemy_buffers.best_source_ratios
	var enemy_best_sources := enemy_buffers.best_sources
	var enemy_channels := enemy_buffers.channels
	for friendly: TacticalUnitScene in friendly_group.members:
		var friendly_index: int = friendly.team_roster_index
		var friendly_search_radius: float = friendly_search_radii[friendly_index]
		for enemy: TacticalUnitScene in enemy_group.members:
			var enemy_index: int = enemy.team_roster_index
			var enemy_search_radius: float = enemy_search_radii[enemy_index]
			var distance_squared: float = friendly.global_position.distance_squared_to(enemy.global_position)
			if (
				distance_squared > friendly_search_radius * friendly_search_radius
				and distance_squared > enemy_search_radius * enemy_search_radius
			):
				continue

			var enemy_signature: float = enemy_signatures[enemy_index]
			var friendly_thermal: float = distance_squared / maxf(
				friendly_passive_ranges[friendly_index]
					* enemy_signature * enemy_signature,
				0.0001
			)
			var friendly_radio: float = INF
			if enemy_emissions[enemy_index] > 0.0:
				friendly_radio = distance_squared / maxf(
					friendly_radio_ranges[friendly_index] * enemy_emissions[enemy_index],
					0.0001
				)
			var friendly_passive: float = minf(friendly_thermal, friendly_radio)
			enemy_best_passive[enemy_index] = minf(
				enemy_best_passive[enemy_index], friendly_passive
			)
			var friendly_active: float = INF
			if friendly_active_ranges[friendly_index] > 0.0:
				friendly_active = distance_squared / friendly_active_ranges[friendly_index]
				enemy_best_active[enemy_index] = minf(
					enemy_best_active[enemy_index], friendly_active
				)
			var friendly_detection: float = minf(friendly_active, friendly_passive)
			if friendly_network_sharing and friendly_detection < enemy_best_source_ratios[enemy_index]:
				enemy_best_source_ratios[enemy_index] = friendly_detection
				enemy_best_sources[enemy_index] = friendly.get_instance_id()
			if (
				refresh_local_ai_targets
				and friendly_detection <= 0.68 * 0.68
				and distance_squared < closest_local_target_distances_by_team[0][friendly_index]
			):
				closest_local_target_distances_by_team[0][friendly_index] = distance_squared
				closest_local_target_indices_by_team[0][friendly_index] = enemy_index
			if friendly_thermal <= 1.0:
				enemy_channels[enemy_index] |= SensorTrackLogic.Channel.THERMAL
			if friendly_radio <= 1.0:
				enemy_channels[enemy_index] |= SensorTrackLogic.Channel.RADIO
			if friendly_passive <= 1.0:
				_register_triangulation_observer(
					enemy.global_position, friendly.global_position, enemy_index,
					enemy_buffers.observer_counts, enemy_buffers.triangulation_quality,
					enemy_buffers.first_observer_directions
				)
			if friendly_group_pictures and friendly_detection <= 1.0:
				_append_group_observation(
					enemy_buffers.group_observations, friendly, enemy,
					friendly_active, friendly_passive, friendly_thermal, friendly_radio
				)

			var friendly_signature: float = friendly_signatures[friendly_index]
			var enemy_thermal: float = distance_squared / maxf(
				enemy_passive_ranges[enemy_index]
					* friendly_signature * friendly_signature,
				0.0001
			)
			var enemy_radio: float = INF
			if friendly_emissions[friendly_index] > 0.0:
				enemy_radio = distance_squared / maxf(
					enemy_radio_ranges[enemy_index] * friendly_emissions[friendly_index],
					0.0001
				)
			var enemy_passive: float = minf(enemy_thermal, enemy_radio)
			friendly_best_passive[friendly_index] = minf(
				friendly_best_passive[friendly_index], enemy_passive
			)
			var enemy_active: float = INF
			if enemy_active_ranges[enemy_index] > 0.0:
				enemy_active = distance_squared / enemy_active_ranges[enemy_index]
				friendly_best_active[friendly_index] = minf(
					friendly_best_active[friendly_index], enemy_active
				)
			var enemy_detection: float = minf(enemy_active, enemy_passive)
			if enemy_network_sharing and enemy_detection < friendly_best_source_ratios[friendly_index]:
				friendly_best_source_ratios[friendly_index] = enemy_detection
				friendly_best_sources[friendly_index] = enemy.get_instance_id()
			if (
				refresh_local_ai_targets
				and enemy_detection <= 0.68 * 0.68
				and distance_squared < closest_local_target_distances_by_team[1][enemy_index]
			):
				closest_local_target_distances_by_team[1][enemy_index] = distance_squared
				closest_local_target_indices_by_team[1][enemy_index] = friendly_index
			if enemy_thermal <= 1.0:
				friendly_channels[friendly_index] |= SensorTrackLogic.Channel.THERMAL
			if enemy_radio <= 1.0:
				friendly_channels[friendly_index] |= SensorTrackLogic.Channel.RADIO
			if enemy_passive <= 1.0:
				_register_triangulation_observer(
					friendly.global_position, enemy.global_position, friendly_index,
					friendly_buffers.observer_counts, friendly_buffers.triangulation_quality,
					friendly_buffers.first_observer_directions
				)
			if enemy_group_pictures and enemy_detection <= 1.0:
				_append_group_observation(
					friendly_buffers.group_observations, enemy, friendly,
					enemy_active, enemy_passive, enemy_thermal, enemy_radio
				)
	friendly_buffers.best_active = friendly_best_active
	friendly_buffers.best_passive = friendly_best_passive
	friendly_buffers.best_source_ratios = friendly_best_source_ratios
	friendly_buffers.best_sources = friendly_best_sources
	friendly_buffers.channels = friendly_channels
	enemy_buffers.best_active = enemy_best_active
	enemy_buffers.best_passive = enemy_best_passive
	enemy_buffers.best_source_ratios = enemy_best_source_ratios
	enemy_buffers.best_sources = enemy_best_sources
	enemy_buffers.channels = enemy_channels


func _get_tactical_group_bounds(group: TacticalGroup) -> Rect2:
	if group.members.is_empty():
		return Rect2()
	var bounds := Rect2(group.members[0].global_position, Vector2.ZERO)
	for index: int in range(1, group.members.size()):
		bounds = bounds.expand(group.members[index].global_position)
	return bounds.grow(1.0)


func _get_group_sensor_search_radius(
	group: TacticalGroup,
	observer_buffers: SensorPassBuffers
) -> float:
	var maximum_radius: float = 0.0
	for member: TacticalUnitScene in group.members:
		maximum_radius = maxf(
			maximum_radius,
			observer_buffers.search_radii[member.team_roster_index]
		)
	return maximum_radius


func _get_sensor_search_radius(
	observer: TacticalUnitScene,
	target_buffers: SensorPassBuffers
) -> float:
	var radius: float = maxf(
		observer.sensor_range * target_buffers.maximum_signature,
		observer.active_emission_detection_range * sqrt(target_buffers.maximum_emission)
	)
	if observer.sensor_mode == TacticalUnitScene.SensorMode.ACTIVE:
		radius = maxf(radius, observer.active_sensor_range)
	return radius


func _rebuild_data_link_networks() -> void:
	_rebuild_tactical_groups()
	data_link_networks_by_team[0].rebuild(friendly_units)
	data_link_networks_by_team[1].rebuild(enemy_units)


func _rebuild_tactical_groups() -> void:
	for team_id: int in 2:
		var previous_groups: Dictionary = tactical_groups_by_team[team_id]
		var rebuilt_groups: Dictionary = {}
		var units: Array[TacticalUnitScene] = friendly_units if team_id == 0 else enemy_units
		for unit: TacticalUnitScene in units:
			if unit.destroyed:
				continue
			var group_id: int = unit.tactical_group_id
			var group: TacticalGroup = previous_groups.get(group_id)
			if group == null:
				group = TacticalGroup.new(group_id, team_id)
			else:
				group.members.clear()
			rebuilt_groups[group_id] = group
		for unit: TacticalUnitScene in units:
			if unit.destroyed:
				continue
			var group: TacticalGroup = rebuilt_groups[unit.tactical_group_id]
			group.add_member(unit)
		tactical_groups_by_team[team_id] = rebuilt_groups


func _append_group_observation(
	store: Dictionary,
	source: TacticalUnitScene,
	target: TacticalUnitScene,
	active_ratio_squared: float,
	passive_ratio_squared: float,
	thermal_ratio_squared: float,
	radio_ratio_squared: float
) -> void:
	var channels: int = 0
	if thermal_ratio_squared <= 1.0:
		channels |= SensorTrackLogic.Channel.THERMAL
	if radio_ratio_squared <= 1.0:
		channels |= SensorTrackLogic.Channel.RADIO
	if active_ratio_squared <= 1.0:
		channels |= SensorTrackLogic.Channel.ACTIVE_RADAR
	var group_id: int = source.tactical_group_id
	if not store.has(group_id):
		store[group_id] = {}
	var group_accumulators: Dictionary = store[group_id]
	var target_id: int = target.get_instance_id()
	var accumulator: SensorObservationAccumulator = group_accumulators.get(target_id)
	if accumulator == null:
		accumulator = SensorObservationAccumulator.new(target)
		group_accumulators[target_id] = accumulator
	accumulator.add_observation(
		source,
		active_ratio_squared,
		passive_ratio_squared,
		channels
	)


func _update_group_track_pictures(team_id: int, observations_by_target: Dictionary) -> void:
	if tactical_groups_by_team[team_id].size() <= 1:
		return
	for group: TacticalGroup in tactical_groups_by_team[team_id].values():
		var group_accumulators: Dictionary = observations_by_target.get(group.group_id, {})
		for accumulator: SensorObservationAccumulator in group_accumulators.values():
			group.track_picture.observe_accumulator(accumulator)
	_share_group_track_reports(team_id)


func _update_command_picture_from_groups(team_id: int) -> void:
	var groups: Dictionary = tactical_groups_by_team[team_id]
	if groups.size() <= 1:
		return
	var best_tracks_by_target: Dictionary = {}
	for group: TacticalGroup in groups.values():
		for target_id: int in group.track_picture.tracks:
			var group_track: SensorTrack = group.track_picture.tracks[target_id]
			if group_track.observation_floor <= 0.0:
				continue
			var current_best: SensorTrack = best_tracks_by_target.get(target_id)
			if (
				current_best == null
				or group_track.confidence > current_best.confidence
				or (
					is_equal_approx(group_track.confidence, current_best.confidence)
					and group_track.uncertainty_radius < current_best.uncertainty_radius
				)
			):
				best_tracks_by_target[target_id] = group_track
	for group_track: SensorTrack in best_tracks_by_target.values():
		var command_track = _get_or_create_sensor_track(team_id, group_track.target)
		command_track.observe(
			group_track.get_state(),
			group_track.estimated_position,
			group_track.estimated_velocity,
			group_track.uncertainty_radius,
			group_track.last_observation_channels,
			group_track.bearing_observer_count,
			group_track.triangulation_quality,
			group_track.last_observation_source_ids,
			group_track.classification_state,
			group_track.classification_label
		)


func _share_group_track_reports(team_id: int) -> void:
	var groups: Dictionary = tactical_groups_by_team[team_id]
	var routes: Dictionary = _build_group_report_routes(team_id, groups)
	if routes.is_empty():
		return
	var reports_by_group: Dictionary = {}
	for source_group: TacticalGroup in groups.values():
		reports_by_group[source_group.group_id] = (
			source_group.track_picture.create_reports(source_group.group_id)
		)
	for source_group: TacticalGroup in groups.values():
		var reports: Array = reports_by_group[source_group.group_id]
		if reports.is_empty():
			continue
		var destination_ids: Array = routes.get(source_group.group_id, [])
		for destination_id: int in destination_ids:
			var destination_group: TacticalGroup = groups.get(destination_id)
			if destination_group == null:
				continue
			for report: TrackReport in reports:
				var target = instance_from_id(report.target_id)
				if is_instance_valid(target) and target is TacticalUnit:
					destination_group.track_picture.ingest_report(report, target)


func _build_group_report_routes(team_id: int, groups: Dictionary) -> Dictionary:
	var allies: Array[TacticalUnitScene] = friendly_units if team_id == 0 else enemy_units
	var bridges: Array[TacticalUnitScene] = []
	for unit: TacticalUnitScene in allies:
		if not unit.destroyed and unit.can_bridge_tactical_groups():
			bridges.append(unit)
	if bridges.is_empty():
		return {}

	var inbound_by_bridge: Dictionary = {}
	var outbound_by_bridge: Dictionary = {}
	for bridge: TacticalUnitScene in bridges:
		var inbound: Dictionary = {}
		var outbound: Dictionary = {}
		for group: TacticalGroup in groups.values():
			var can_reach_bridge: bool = group.group_id == bridge.tactical_group_id
			var bridge_can_reach: bool = can_reach_bridge
			for member: TacticalUnitScene in group.members:
				if not can_reach_bridge and _data_link_can_transfer_now(member, bridge):
					can_reach_bridge = true
				if not bridge_can_reach and _data_link_can_transfer_now(bridge, member):
					bridge_can_reach = true
				if can_reach_bridge and bridge_can_reach:
					break
			inbound[group.group_id] = can_reach_bridge
			outbound[group.group_id] = bridge_can_reach
		inbound_by_bridge[bridge.get_instance_id()] = inbound
		outbound_by_bridge[bridge.get_instance_id()] = outbound

	var routes: Dictionary = {}
	for source_group: TacticalGroup in groups.values():
		var destinations: Array[int] = []
		for destination_group: TacticalGroup in groups.values():
			if destination_group == source_group:
				continue
			for bridge: TacticalUnitScene in bridges:
				var bridge_id: int = bridge.get_instance_id()
				var inbound: Dictionary = inbound_by_bridge[bridge_id]
				var outbound: Dictionary = outbound_by_bridge[bridge_id]
				if bool(inbound[source_group.group_id]) and bool(outbound[destination_group.group_id]):
					destinations.append(destination_group.group_id)
					break
		if not destinations.is_empty():
			routes[source_group.group_id] = destinations
	return routes


func _prepare_local_detection_cache(refresh_local_ai_targets: bool) -> void:
	if not refresh_local_ai_targets:
		return
	closest_local_target_indices_by_team[0].resize(friendly_units.size())
	closest_local_target_indices_by_team[0].fill(-1)
	closest_local_target_indices_by_team[1].resize(enemy_units.size())
	closest_local_target_indices_by_team[1].fill(-1)
	closest_local_target_distances_by_team[0].resize(friendly_units.size())
	closest_local_target_distances_by_team[0].fill(INF)
	closest_local_target_distances_by_team[1].resize(enemy_units.size())
	closest_local_target_distances_by_team[1].fill(INF)


func _infinite_float_array(size: int) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	values.resize(size)
	values.fill(INF)
	return values


func _observation_source_ids(source_id: int) -> Array[int]:
	var source_ids: Array[int] = []
	if source_id >= 0:
		source_ids.append(source_id)
	return source_ids


func _register_triangulation_observer(
	target_position: Vector2,
	observer_position: Vector2,
	target_index: int,
	observer_counts: Array[int],
	triangulation_quality: Array[float],
	first_observer_positions: Array[Vector2]
) -> void:
	if observer_counts[target_index] == 0:
		first_observer_positions[target_index] = observer_position.direction_to(target_position)
	elif triangulation_quality[target_index] < 0.999:
		var first_direction: Vector2 = first_observer_positions[target_index]
		var new_direction: Vector2 = observer_position.direction_to(target_position)
		var crossing_angle_quality: float = clampf(absf(first_direction.cross(new_direction)) * 2.0, 0.0, 1.0)
		triangulation_quality[target_index] = maxf(
			triangulation_quality[target_index],
			crossing_angle_quality
		)
	observer_counts[target_index] += 1


func _update_automatic_radio_emissions() -> void:
	for unit: TacticalUnitScene in friendly_units + enemy_units:
		unit.set_datalink_emission_mode(TacticalUnitScene.DatalinkEmissionMode.SILENT)
	for team_id: int in 2:
		var allies: Array[TacticalUnitScene] = friendly_units if team_id == 0 else enemy_units
		if not data_link_networks_by_team[team_id].has_transmitters():
			continue
		var team_tracks: Dictionary = sensor_tracks_by_team[team_id]
		var track_source_ids: Dictionary = {}
		var fire_control_source_ids: Dictionary = {}
		var global_track_available: bool = false
		var global_fire_control_available: bool = false
		for track in team_tracks.values():
			var track_state: int = track.get_state()
			if track_state < SensorTrackLogic.State.SIGNAL:
				continue
			for source_id: int in track.last_observation_source_ids:
				if source_id == 0:
					global_track_available = true
					global_fire_control_available = (
						global_fire_control_available
						or track.has_fire_control_quality(FIRE_CONTROL_MAXIMUM_UNCERTAINTY)
					)
					continue
				track_source_ids[source_id] = true
				if track.has_fire_control_quality(FIRE_CONTROL_MAXIMUM_UNCERTAINTY):
					fire_control_source_ids[source_id] = true
		for provider: TacticalUnitScene in allies:
			if provider.destroyed or not provider.can_transmit_data():
				continue
			if (
				fleet_battle_demo
				and provider.team_id == 1
				and provider.callsign == "R-RELAIS"
				and not _red_link_window_open()
			):
				continue
			var link_peers: Array[TacticalUnitScene] = allies
			if not provider.can_bridge_tactical_groups():
				var provider_group: TacticalGroup = tactical_groups_by_team[team_id].get(
					provider.tactical_group_id
				)
				link_peers = [] if provider_group == null else provider_group.members
			if not _provider_has_linked_ally(provider, link_peers):
				continue
			var provider_id: int = provider.get_instance_id()
			var has_shared_track: bool = global_track_available or track_source_ids.has(provider_id)
			var has_fire_control_track: bool = (
				global_fire_control_available or fire_control_source_ids.has(provider_id)
			)
			if provider.can_relay_data() and not has_shared_track:
				for source_id: int in track_source_ids:
					var source = instance_from_id(source_id)
					if (
						is_instance_valid(source)
						and source is TacticalUnit
						and data_link_networks_by_team[team_id].can_transfer(source, provider)
					):
						has_shared_track = true
						if fire_control_source_ids.has(source_id):
							has_fire_control_track = true
							break
			if provider.provides_fire_control_data() and has_fire_control_track and _provider_has_linked_armed_ally(provider, link_peers):
				provider.set_datalink_emission_mode(TacticalUnitScene.DatalinkEmissionMode.FIRE_CONTROL)
			elif has_shared_track:
				provider.set_datalink_emission_mode(TacticalUnitScene.DatalinkEmissionMode.TRACK_SHARING)


func _provider_has_linked_ally(provider: TacticalUnitScene, allies: Array[TacticalUnitScene]) -> bool:
	for ally: TacticalUnitScene in allies:
		if ally != provider and not ally.destroyed and data_link_networks_by_team[provider.team_id].can_transfer(provider, ally):
			return true
	return false


func _provider_has_linked_armed_ally(provider: TacticalUnitScene, allies: Array[TacticalUnitScene]) -> bool:
	for ally: TacticalUnitScene in allies:
		if ally == provider or ally.destroyed:
			continue
		if not data_link_networks_by_team[provider.team_id].can_transfer(provider, ally):
			continue
		if (
			ally.get_weapon_system(WeaponSystemProfile.Family.RAILGUN) != null
			or ally.get_weapon_system(WeaponSystemProfile.Family.MISSILE, WeaponSystemProfile.TacticalRole.ANTI_SHIP) != null
		):
			return true
	return false


func _begin_sensor_pass() -> void:
	for team_tracks: Dictionary in sensor_tracks_by_team:
		for track in team_tracks.values():
			track.begin_sensor_pass()
	for groups: Dictionary in tactical_groups_by_team:
		for group: TacticalGroup in groups.values():
			group.track_picture.begin_sensor_pass()


func _record_sensor_observation(
	observer_team_id: int,
	target: TacticalUnitScene,
	best_active_ratio_squared: float,
	best_passive_ratio_squared: float,
	observer_count: int,
	triangulation_quality: float,
	observation_channels: int,
	observation_source_ids: Array
) -> void:
	if target.destroyed:
		return
	var observed_state: int = SensorTrackLogic.State.HIDDEN
	var base_uncertainty: float = SensorTrackLogic.MAXIMUM_UNCERTAINTY
	var observed_position: Vector2 = target.global_position
	var observed_velocity: Vector2 = target.velocity
	if best_active_ratio_squared <= 0.36 * 0.36:
		observed_state = SensorTrackLogic.State.IDENTIFIED
		base_uncertainty = 2.0
		observation_channels |= SensorTrackLogic.Channel.ACTIVE_RADAR
	elif best_active_ratio_squared <= 0.68 * 0.68:
		observed_state = SensorTrackLogic.State.TRACKED
		base_uncertainty = 14.0
		observation_channels |= SensorTrackLogic.Channel.ACTIVE_RADAR
	elif best_active_ratio_squared <= 1.0:
		observed_state = SensorTrackLogic.State.SIGNAL
		base_uncertainty = 90.0
		observation_channels |= SensorTrackLogic.Channel.ACTIVE_RADAR

	var passive_state: int = SensorTrackLogic.State.HIDDEN
	var passive_uncertainty: float = SensorTrackLogic.MAXIMUM_UNCERTAINTY
	var triangulated: bool = observer_count >= 2 and triangulation_quality >= 0.08
	if bool(observation_channels & SensorTrackLogic.Channel.THERMAL):
		passive_state = SensorTrackLogic.State.IDENTIFIED
		passive_uncertainty = 2.0
	elif best_passive_ratio_squared <= 0.68 * 0.68:
		passive_state = SensorTrackLogic.State.TRACKED
		passive_uncertainty = 20.0
	elif best_passive_ratio_squared <= 1.0 and triangulated:
		passive_state = SensorTrackLogic.State.TRACKED
		passive_uncertainty = lerpf(55.0, 18.0, triangulation_quality)
	elif best_passive_ratio_squared <= 1.0:
		passive_state = SensorTrackLogic.State.SIGNAL
		passive_uncertainty = 90.0
	if passive_state > observed_state:
		observed_state = passive_state
		base_uncertainty = passive_uncertainty
	elif passive_state == observed_state:
		base_uncertainty = minf(base_uncertainty, passive_uncertainty)
	if triangulated and passive_state >= SensorTrackLogic.State.TRACKED:
		observation_channels |= SensorTrackLogic.Channel.TRIANGULATED

	if observed_state == SensorTrackLogic.State.SIGNAL:
		var phase: float = deg_to_rad(float(abs(target.callsign.hash()) % 360))
		observed_position += Vector2.from_angle(phase) * base_uncertainty * 0.45
		observed_velocity = Vector2.ZERO
	if observed_state == SensorTrackLogic.State.HIDDEN:
		return
	var observed_classification: int = SensorTrackLogic.classification_for_observation(
		observed_state,
		observation_channels
	)
	var track = _get_or_create_sensor_track(observer_team_id, target)
	track.observe(
		observed_state,
		observed_position,
		observed_velocity,
		base_uncertainty,
		observation_channels,
		observer_count,
		triangulation_quality,
		observation_source_ids,
		observed_classification,
		target.unit_profile.classification_label
	)


func _advance_sensor_tracks(delta: float) -> void:
	for team_tracks: Dictionary in sensor_tracks_by_team:
		var expired_keys: Array[int] = []
		for target_id: int in team_tracks:
			var track = team_tracks[target_id]
			if not is_instance_valid(track.target) or track.target.destroyed:
				expired_keys.append(target_id)
				continue
			track.advance(delta)
			if track.get_state() == SensorTrackLogic.State.HIDDEN and track.seconds_since_any_observation > 2.0:
				expired_keys.append(target_id)
		for target_id: int in expired_keys:
			team_tracks.erase(target_id)
	for groups: Dictionary in tactical_groups_by_team:
		for group: TacticalGroup in groups.values():
			group.track_picture.advance(delta)
	_sync_player_sensor_picture()


func _get_or_create_sensor_track(observer_team_id: int, target: TacticalUnitScene):
	var team_tracks: Dictionary = sensor_tracks_by_team[observer_team_id]
	var target_id: int = target.get_instance_id()
	if not team_tracks.has(target_id):
		var track = SensorTrackLogic.new(
			observer_team_id,
			target,
			target.maximum_acceleration
		)
		contact_designation_counters[observer_team_id] += 1
		track.designation = "BANDIT-%02d" % contact_designation_counters[observer_team_id]
		team_tracks[target_id] = track
	return team_tracks[target_id]


func _get_sensor_track(observer_team_id: int, target: TacticalUnitScene):
	return sensor_tracks_by_team[observer_team_id].get(target.get_instance_id())


func _get_group_sensor_track(observer_team_id: int, group_id: int, target: TacticalUnitScene):
	var groups: Dictionary = tactical_groups_by_team[observer_team_id]
	if groups.size() <= 1:
		return _get_sensor_track(observer_team_id, target)
	var group: TacticalGroup = groups.get(group_id)
	return null if group == null else group.track_picture.get_track(target)


func _get_unit_sensor_track(unit: TacticalUnitScene, target: TacticalUnitScene):
	if unit == null:
		return null
	return _get_group_sensor_track(unit.team_id, unit.tactical_group_id, target)


func _count_accessible_tracks(unit: TacticalUnitScene) -> int:
	var count: int = 0
	var tracks: Dictionary = sensor_tracks_by_team[unit.team_id]
	var uses_group_picture: bool = tactical_groups_by_team[unit.team_id].size() > 1
	if uses_group_picture:
		var group: TacticalGroup = tactical_groups_by_team[unit.team_id].get(unit.tactical_group_id)
		tracks = {} if group == null else group.track_picture.tracks
	for track in tracks.values():
		if (
			track.get_state() >= SensorTrackLogic.State.SIGNAL
			and (uses_group_picture or _unit_can_access_track(unit, track))
		):
			count += 1
	return count


func _unit_can_access_track(unit: TacticalUnitScene, track) -> bool:
	if unit == null or track == null or unit.destroyed:
		return false
	var unit_id: int = unit.get_instance_id()
	var can_access: bool = false
	for source_id: int in track.last_observation_source_ids:
		if source_id == 0 or source_id == unit_id:
			can_access = true
			break
		var source = instance_from_id(source_id)
		if (
			is_instance_valid(source)
			and source is TacticalUnit
			and source.team_id == unit.team_id
			and _data_link_can_transfer_now(source, unit)
		):
			can_access = true
			break
	if (
		not can_access
		and is_instance_valid(track.target)
		and _local_detection_ratio_squared(unit, track.target) <= 1.0
	):
		can_access = true
	return can_access


func _data_link_can_transfer_now(source: TacticalUnitScene, receiver: TacticalUnitScene) -> bool:
	if (
		fleet_battle_demo
		and source.team_id == 1
		and source.callsign == "R-RELAIS"
		and not _red_link_window_open()
	):
		return false
	return data_link_networks_by_team[source.team_id].can_transfer(source, receiver)


func _local_detection_ratio_squared(unit: TacticalUnitScene, target: TacticalUnitScene) -> float:
	return _sensor_range_ratio_squared(unit, target)


func _sync_player_sensor_picture() -> void:
	var signal_count: int = 0
	var tracked_count: int = 0
	var estimated_type_count: int = 0
	var confirmed_type_count: int = 0
	var radio_count: int = 0
	var triangulated_count: int = 0
	for enemy: TacticalUnitScene in enemy_units:
		if enemy.destroyed:
			continue
		var track = _get_sensor_track(0, enemy)
		var new_state: int = SensorTrackLogic.State.HIDDEN if track == null else track.get_state()
		if new_state >= SensorTrackLogic.State.TRACKED:
			tracked_count += 1
		elif new_state == SensorTrackLogic.State.SIGNAL:
			signal_count += 1
		if track != null and track.classification_state == SensorTrackLogic.Classification.ESTIMATED:
			estimated_type_count += 1
		elif track != null and track.classification_state == SensorTrackLogic.Classification.CONFIRMED:
			confirmed_type_count += 1
		if track == null:
			enemy.set_sensor_contact(TacticalUnitScene.IntelState.HIDDEN, enemy.global_position, 0.0)
		else:
			enemy.set_sensor_contact(
				new_state,
				track.estimated_position,
				track.uncertainty_radius,
				track.designation,
				track.classification_state,
				track.classification_label
			)
			if bool(track.last_observation_channels & SensorTrackLogic.Channel.RADIO):
				radio_count += 1
			if bool(track.last_observation_channels & SensorTrackLogic.Channel.TRIANGULATED):
				triangulated_count += 1

	intel_label.text = "RENSEIGNEMENT: %d CONTACT  •  %d PISTE  //  TYPE %d?  •  %d CONF.  //  TRI %d  •  EM %d" % [
		signal_count,
		tracked_count,
		estimated_type_count,
		confirmed_type_count,
		triangulated_count,
		radio_count,
	]


func _update_sensor_picture_if_due(delta: float) -> void:
	sensor_update_remaining -= delta
	if sensor_update_remaining > 0.0:
		return
	sensor_update_remaining += SENSOR_UPDATE_INTERVAL
	_update_sensor_picture()


func _finish_selection(add_to_selection: bool, individual_selection: bool = false) -> void:
	is_selecting = false
	if not add_to_selection:
		_clear_selection()

	var selection_rect := Rect2(selection_start, selection_end - selection_start).abs()
	var is_click := selection_start.distance_to(selection_end) < 6.0
	if task_force_demo and not individual_selection and task_force_demo_force != null:
		var selected_task_force_member: TacticalUnitScene = null
		for unit: TacticalUnitScene in task_force_demo_force.members:
			var member_is_selected := (
				unit.contains_world_point(selection_end)
				if is_click
				else selection_rect.has_point(unit.global_position)
			)
			if member_is_selected:
				selected_task_force_member = unit
				break
		if selected_task_force_member != null:
			for member: TacticalUnitScene in task_force_demo_force.members:
				if member not in selected_units and not member.destroyed:
					selected_units.append(member)
					member.set_selected(true)
			_refresh_range_visualization()
			_update_status()
			queue_redraw()
			return

	for unit: TacticalUnitScene in friendly_units:
		var should_select := unit.contains_world_point(selection_end) if is_click else selection_rect.has_point(unit.global_position)
		if should_select and unit not in selected_units:
			selected_units.append(unit)
			unit.set_selected(true)

	_refresh_range_visualization()
	_update_status()
	queue_redraw()


func _clear_selection() -> void:
	for unit: TacticalUnitScene in selected_units:
		unit.set_selected(false)
	selected_units.clear()
	tactical_overlay.invalidate_engagement_envelope()


func _toggle_range_debug() -> void:
	range_debug_enabled = not range_debug_enabled
	_refresh_range_visualization()
	last_attack_feedback = "PORTÉES DÉTAILLÉES" if range_debug_enabled else "ENVELOPPE D'ENGAGEMENT"
	_update_status()


func _refresh_range_visualization() -> void:
	var show_technical_detail: bool = selected_units.size() == 1 or range_debug_enabled
	for unit: TacticalUnitScene in selected_units:
		if is_instance_valid(unit):
			unit.set_range_visualization(show_technical_detail, show_technical_detail)
	tactical_overlay.invalidate_engagement_envelope()


func get_engagement_group_id(unit: TacticalUnitScene) -> int:
	var provider = _get_connected_fire_control_provider(unit)
	return provider.get_instance_id() if is_instance_valid(provider) else unit.get_instance_id()


func unit_contributes_sensor_to_group(unit: TacticalUnitScene, group_id: int) -> bool:
	var group_provider = instance_from_id(group_id)
	if not is_instance_valid(group_provider) or group_provider == unit:
		return true
	return _data_link_can_transfer_now(unit, group_provider)


func is_weapon_system_selected_for_overlay(system: WeaponSystemProfile) -> bool:
	if system == null:
		return offensive_weapon_selection in [
			OffensiveWeaponSelection.AUTO,
			OffensiveWeaponSelection.MISSILES,
		]
	match offensive_weapon_selection:
		OffensiveWeaponSelection.MISSILES:
			return (
				system.family == WeaponSystemProfile.Family.MISSILE
				and system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_SHIP
			)
		OffensiveWeaponSelection.RAILGUN:
			return system.family == WeaponSystemProfile.Family.RAILGUN
		OffensiveWeaponSelection.ANTI_RADIATION:
			return system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_RADIATION
	return (
		system.family == WeaponSystemProfile.Family.RAILGUN
		or (
			system.family == WeaponSystemProfile.Family.MISSILE
			and system.tactical_role in [
				WeaponSystemProfile.TacticalRole.ANTI_SHIP,
				WeaponSystemProfile.TacticalRole.ANTI_RADIATION,
			]
		)
	)


func selected_group_has_fire_control_solution(target: TacticalUnitScene) -> bool:
	for launcher: TacticalUnitScene in selected_units:
		if not is_instance_valid(launcher) or launcher.destroyed:
			continue
		var has_selected_weapon: bool = false
		for system: WeaponSystemProfile in launcher.weapon_system_profiles:
			if not is_weapon_system_selected_for_overlay(system):
				continue
			if (
				system.feed_type == WeaponSystemProfile.FeedType.ENERGY
				or launcher.get_weapon_system_ammunition(system) > 0
			):
				has_selected_weapon = true
				break
		if not has_selected_weapon:
			continue
		if (
			offensive_weapon_selection == OffensiveWeaponSelection.ANTI_RADIATION
			and _has_current_radio_bearing(launcher.team_id, target, launcher)
		):
			return true
		if _launcher_has_fire_control_solution(launcher, target):
			return true
	return false


func _finish_move_order() -> void:
	if not is_defining_move_order:
		return
	is_defining_move_order = false
	var drag_vector: Vector2 = move_order_end - move_order_start
	var has_final_heading: bool = drag_vector.length() >= 12.0 and not move_order_fly_through
	var requested_heading: float = drag_vector.angle() + PI * 0.5 if has_final_heading else 0.0
	_issue_move_order(move_order_start, move_order_fly_through, move_order_append, requested_heading, has_final_heading)
	queue_redraw()


func _issue_move_order(
	target: Vector2,
	fly_through: bool = false,
	append: bool = false,
	requested_final_heading: float = 0.0,
	has_final_heading: bool = false
) -> void:
	if selected_units.is_empty():
		return
	if task_force_demo_motion != null and task_force_demo_force != null:
		if selected_units.size() == 1 and selected_units[0] in task_force_demo_force.members:
			task_force_demo_motion.detach_member(selected_units[0])
		else:
			task_force_demo_motion.issue_navigation_order(
				target,
				fly_through,
				append,
				requested_final_heading,
				has_final_heading
			)
			_update_task_force_demo_header()
			return

	var columns: int = ceili(sqrt(float(selected_units.size())))
	var rows: int = ceili(float(selected_units.size()) / float(columns))
	var spacing: float = 32.0
	for index: int in selected_units.size():
		var row: int = index / columns
		var column: int = index % columns
		var units_in_row: int = mini(columns, selected_units.size() - row * columns)
		var offset := Vector2(
			(float(column) - float(units_in_row - 1) * 0.5) * spacing,
			(float(row) - float(rows - 1) * 0.5) * spacing
		)
		selected_units[index].set_navigation_order(
			target + offset,
			fly_through,
			append,
			requested_final_heading,
			has_final_heading
		)


func _issue_attack_zone(zone_center: Vector2) -> int:
	if selected_units.is_empty():
		return 0
	_replace_fire_mission_assignments(selected_units)
	var mission := FireMissionLogic.new() as FireMission
	mission.configure(
		zone_center,
		ATTACK_ZONE_RADIUS,
		selected_units,
		int(offensive_weapon_selection),
		int(fire_doctrine)
	)
	active_fire_missions.append(mission)
	var shots_fired: int = _evaluate_fire_mission(mission)
	last_attack_feedback = mission.status_text
	_update_status()
	queue_redraw()
	return shots_fired


func _replace_fire_mission_assignments(units: Array) -> void:
	for mission: FireMission in active_fire_missions:
		mission.remove_units(units)
	active_fire_missions = active_fire_missions.filter(
		func(mission): return not mission.assigned_units.is_empty()
	)


func _update_fire_missions() -> void:
	var status_changed: bool = false
	for mission: FireMission in active_fire_missions:
		mission.prune_units()
		if mission.assigned_units.is_empty() or mission.state == FireMission.State.FIRED:
			continue
		var previous_state: int = mission.state
		var previous_status: String = mission.status_text
		_evaluate_fire_mission(mission)
		if (
			(previous_state != mission.state or previous_status != mission.status_text)
			and mission.assigned_units.any(func(unit): return unit in selected_units)
		):
			last_attack_feedback = mission.status_text
			status_changed = true
	active_fire_missions = active_fire_missions.filter(
		func(mission): return not mission.assigned_units.is_empty()
	)
	if status_changed:
		_update_status()
	queue_redraw()


func _evaluate_fire_mission(mission: FireMission) -> int:
	var candidates: Array[TacticalUnitScene] = []
	for enemy: TacticalUnitScene in enemy_units:
		if (
			enemy.is_targetable_contact()
			and _get_contact_position(0, enemy).distance_to(mission.center) <= mission.radius
		):
			candidates.append(enemy)
	candidates.sort_custom(func(first: TacticalUnitScene, second: TacticalUnitScene):
		return _get_contact_position(0, first).distance_squared_to(mission.center) < _get_contact_position(0, second).distance_squared_to(mission.center)
	)
	if candidates.is_empty():
		mission.mark_waiting("ATTENTE CONTACT")
		return 0
	var shots_fired: int = 0
	var missile_allocation: Dictionary = {"cursor": 0}
	for launcher: TacticalUnitScene in mission.assigned_units:
		var launcher_shots: int = _fire_selected_offensive_weapons(
			launcher,
			candidates,
			missile_allocation,
			mission.weapon_selection,
			mission.fire_doctrine
		)
		shots_fired += launcher_shots
		if mission.fire_doctrine == FireDoctrine.ECONOMY and shots_fired > 0:
			break
	if shots_fired > 0:
		mission.mark_fired(shots_fired, ATTACK_ZONE_DISPLAY_DURATION)
	else:
		mission.mark_blocked(_get_attack_block_reason(
			candidates[0], mission.assigned_units, mission.weapon_selection
		))
	return shots_fired


func _fire_selected_offensive_weapons(
	launcher: TacticalUnitScene,
	targets: Array[TacticalUnitScene],
	missile_allocation: Dictionary,
	weapon_selection: int = offensive_weapon_selection,
	doctrine: int = fire_doctrine
) -> int:
	var allow_missiles: bool = weapon_selection in [
		OffensiveWeaponSelection.AUTO,
		OffensiveWeaponSelection.MISSILES,
	]
	var allow_railgun: bool = weapon_selection in [
		OffensiveWeaponSelection.AUTO,
		OffensiveWeaponSelection.RAILGUN,
	]
	var allow_anti_radiation: bool = weapon_selection in [
		OffensiveWeaponSelection.AUTO,
		OffensiveWeaponSelection.ANTI_RADIATION,
	]
	var saturation: bool = doctrine == FireDoctrine.SATURATION
	var shots: int = 0
	if saturation:
		if allow_railgun:
			for target: TacticalUnitScene in targets:
				if _fire_railgun(launcher, target):
					shots += 1
					break
		if allow_anti_radiation:
			shots += _launch_anti_radiation_salvo(launcher, targets, true, missile_allocation)
		if allow_missiles:
			shots += _launch_missile_salvo(launcher, targets, true, missile_allocation)
		return shots
	# En AUTO, le railgun économise les missiles lorsqu'il possède une solution.
	if allow_railgun:
		for target: TacticalUnitScene in targets:
			if _fire_railgun(launcher, target):
				return 1
	if allow_anti_radiation:
		var radiation_shots: int = _launch_anti_radiation_salvo(
			launcher,
			targets,
			false,
			missile_allocation
		)
		if radiation_shots > 0:
			return radiation_shots
	if allow_missiles:
		return _launch_missile_salvo(launcher, targets, false, missile_allocation)
	return 0


func _get_attack_block_reason(
	target: TacticalUnitScene,
	launchers: Array,
	weapon_selection: int
) -> String:
	var found_weapon: bool = false
	var found_in_range: bool = false
	var found_in_arc: bool = false
	var found_radio_bearing: bool = false
	var found_fire_control: bool = false
	for launcher: TacticalUnitScene in launchers:
		for system: WeaponSystemProfile in launcher.weapon_system_profiles:
			if (
				weapon_selection == OffensiveWeaponSelection.MISSILES
				and system.tactical_role != WeaponSystemProfile.TacticalRole.ANTI_SHIP
			):
				continue
			if weapon_selection == OffensiveWeaponSelection.RAILGUN and system.family != WeaponSystemProfile.Family.RAILGUN:
				continue
			if weapon_selection == OffensiveWeaponSelection.ANTI_RADIATION and system.tactical_role != WeaponSystemProfile.TacticalRole.ANTI_RADIATION:
				continue
			if system.family != WeaponSystemProfile.Family.RAILGUN and not (
				system.family == WeaponSystemProfile.Family.MISSILE
				and system.tactical_role in [
					WeaponSystemProfile.TacticalRole.ANTI_SHIP,
					WeaponSystemProfile.TacticalRole.ANTI_RADIATION,
				]
			):
				continue
			found_weapon = true
			if (
				system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_RADIATION
				and not _has_current_radio_bearing(launcher.team_id, target, launcher)
			):
				continue
			if system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_RADIATION:
				found_radio_bearing = true
			var target_position: Vector2 = _get_contact_position(launcher.team_id, target, launcher)
			var distance: float = launcher.global_position.distance_to(target_position)
			if not system.is_in_range(distance):
				continue
			found_in_range = true
			if not launcher.is_position_in_mount_arc(system.mount_profile, target_position):
				continue
			found_in_arc = true
			if (
				system.tactical_role != WeaponSystemProfile.TacticalRole.ANTI_RADIATION
				and not _launcher_has_fire_control_solution(launcher, target)
			):
				continue
			found_fire_control = true
	if not found_weapon:
		if weapon_selection == OffensiveWeaponSelection.ANTI_RADIATION:
			return "ATTENTE: AUCUNE ARME ANTIRAD"
		return "ATTENTE: AUCUNE ARME COMPATIBLE"
	if weapon_selection == OffensiveWeaponSelection.ANTI_RADIATION and not found_radio_bearing:
		return "ATTENTE: ÉMISSION RADIO"
	if not found_in_range:
		return "ATTENTE: PORTÉE"
	if not found_in_arc:
		return "ATTENTE: ARC"
	if not found_fire_control:
		return "ATTENTE: PISTE OU LIAISON"
	return "ATTENTE: RECHARGE, POINTAGE OU CHALEUR"


func _launch_anti_radiation_salvo(
	launcher: TacticalUnitScene,
	targets: Array[TacticalUnitScene],
	saturation: bool,
	allocation: Dictionary
) -> int:
	var system: WeaponSystemProfile = launcher.get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_RADIATION
	)
	if system == null or system.missile_profile == null:
		return 0
	var eligible_targets: Array[TacticalUnitScene] = []
	var start_index: int = int(allocation.get("radiation_cursor", 0))
	for offset: int in targets.size():
		var target: TacticalUnitScene = targets[(start_index + offset) % targets.size()]
		var target_position: Vector2 = _get_contact_position(launcher.team_id, target, launcher)
		if target.destroyed or not _has_current_radio_bearing(launcher.team_id, target, launcher):
			continue
		if not launcher.can_fire_weapon_system(system, target_position):
			continue
		eligible_targets.append(target)
	if eligible_targets.is_empty():
		return 0
	var requested_count: int = system.launcher_count if saturation else 1
	var first_target_position: Vector2 = _get_contact_position(
		launcher.team_id,
		eligible_targets[0],
		launcher
	)
	var launched_count: int = launcher.consume_weapon_system_salvo(
		system,
		first_target_position,
		requested_count
	)
	for launch_index: int in launched_count:
		var assigned_target: TacticalUnitScene = eligible_targets[launch_index % eligible_targets.size()]
		var assigned_position: Vector2 = _get_contact_position(
			launcher.team_id,
			assigned_target,
			launcher
		)
		var lane_slot: float = float(launch_index) - float(launched_count - 1) * 0.5
		var lane_direction: Vector2 = launcher.global_position.direction_to(assigned_position).rotated(PI * 0.5)
		var missile := TacticalMissileScene.new() as TacticalMissileScene
		missiles_layer.add_child(missile)
		missile.impacted.connect(_on_missile_impacted.bind(launcher.team_id))
		missile.detonated.connect(_on_missile_detonated)
		missile.finished.connect(_on_missile_finished)
		missile.launch(
			launcher.global_position + lane_direction * lane_slot * 3.0,
			assigned_target,
			launcher.team_id,
			system.missile_profile,
			assigned_position
		)
		missile.set_meta("guidance_group_id", launcher.tactical_group_id)
		missile.set_cruise_lane_offset(lane_direction * lane_slot * MISSILE_SWARM_SPACING)
		missile.set_visual_zoom(tactical_camera.zoom.x)
	allocation["radiation_cursor"] = start_index + launched_count
	missiles_launched[launcher.team_id] += launched_count
	_update_status()
	return launched_count


func _has_current_radio_bearing(
	observer_team_id: int,
	target: TacticalUnitScene,
	consumer: TacticalUnitScene = null
) -> bool:
	var track = (
		_get_sensor_track(observer_team_id, target)
		if consumer == null
		else _get_unit_sensor_track(consumer, target)
	)
	return (
		track != null
		and track.get_state() >= SensorTrackLogic.State.SIGNAL
		and track.seconds_since_any_observation <= SENSOR_UPDATE_INTERVAL * 2.0
		and bool(track.last_observation_channels & SensorTrackLogic.Channel.RADIO)
	)


func _fire_railgun(launcher: TacticalUnitScene, target: TacticalUnitScene) -> bool:
	var system: WeaponSystemProfile = launcher.get_weapon_system(
		WeaponSystemProfile.Family.RAILGUN,
		WeaponSystemProfile.TacticalRole.KINETIC_STRIKE
	)
	var target_position: Vector2 = _get_contact_position(launcher.team_id, target, launcher)
	if not launcher.can_fire_weapon_system(system, target_position):
		return false
	if not _launcher_has_fire_control_solution(launcher, target):
		return false
	var aim_point: Vector2 = _calculate_intercept_point(
		launcher.global_position,
		target_position,
		_get_contact_velocity(launcher.team_id, target, launcher),
		system.projectile_speed
	)
	var projectile := RailgunProjectileScene.new() as RailgunProjectile
	pdc_projectiles_layer.add_child(projectile)
	projectile.launch(
		launcher.global_position,
		aim_point,
		launcher.team_id,
		system.projectile_speed,
		system.maximum_range,
		system.damage
	)
	projectile.set_visual_zoom(tactical_camera.zoom.x)
	launcher.mark_weapon_system_fired(system, target.global_position)
	return true


func _launch_missile(launcher: TacticalUnitScene, target: TacticalUnitScene) -> bool:
	return _launch_missile_burst(launcher, target, false) > 0


func _launch_missile_burst(
	launcher: TacticalUnitScene,
	target: TacticalUnitScene,
	saturation: bool,
	requested_count_override: int = -1
) -> int:
	var targets: Array[TacticalUnitScene] = [target]
	return _launch_missile_salvo(
		launcher,
		targets,
		saturation,
		{"cursor": 0},
		requested_count_override
	)


func _launch_missile_salvo(
	launcher: TacticalUnitScene,
	targets: Array[TacticalUnitScene],
	saturation: bool,
	allocation: Dictionary,
	requested_count_override: int = -1
) -> int:
	var eligible_targets: Array[TacticalUnitScene] = []
	var start_index: int = int(allocation.get("cursor", 0))
	for offset: int in targets.size():
		var target: TacticalUnitScene = targets[(start_index + offset) % targets.size()]
		var target_position: Vector2 = _get_contact_position(launcher.team_id, target, launcher)
		if target.destroyed or not launcher.can_launch_weapon_at(target_position):
			continue
		if not _launcher_has_fire_control_solution(launcher, target) or not _is_target_in_missile_range(launcher, target):
			continue
		eligible_targets.append(target)
	if eligible_targets.is_empty():
		return 0
	var requested_count: int = launcher.get_anti_ship_burst_capacity() if saturation else 1
	if requested_count_override >= 0:
		requested_count = mini(launcher.get_anti_ship_burst_capacity(), requested_count_override)
	if requested_count <= 0:
		return 0
	var missile_profile: MissileProfile = launcher.get_anti_ship_missile_profile()
	var first_target_position: Vector2 = _get_contact_position(
		launcher.team_id,
		eligible_targets[0],
		launcher
	)
	var launched_count: int = launcher.consume_anti_ship_missiles(first_target_position, requested_count)
	for launch_index: int in launched_count:
		var assigned_target: TacticalUnitScene = eligible_targets[launch_index % eligible_targets.size()]
		var assigned_position: Vector2 = _get_contact_position(
			launcher.team_id,
			assigned_target,
			launcher
		)
		var lane_slot: float = float(launch_index) - float(launched_count - 1) * 0.5
		var lane_direction: Vector2 = launcher.global_position.direction_to(assigned_position).rotated(PI * 0.5)
		var lane_offset: Vector2 = lane_direction * lane_slot * MISSILE_SWARM_SPACING
		var missile := TacticalMissileScene.new() as TacticalMissileScene
		missiles_layer.add_child(missile)
		missile.impacted.connect(_on_missile_impacted.bind(launcher.team_id))
		missile.detonated.connect(_on_missile_detonated)
		missile.finished.connect(_on_missile_finished)
		var launch_offset: Vector2 = lane_direction * lane_slot * 3.0
		missile.launch(
			launcher.global_position + launch_offset,
			assigned_target,
			launcher.team_id,
			missile_profile if missile_profile != null else MISSILE_PROFILE,
			assigned_position
		)
		missile.set_meta("guidance_group_id", launcher.tactical_group_id)
		missile.set_cruise_lane_offset(lane_offset)
		missile.set_visual_zoom(tactical_camera.zoom.x)
	allocation["cursor"] = start_index + launched_count
	missiles_launched[launcher.team_id] += launched_count
	_update_status()
	return launched_count


func _update_ai(delta: float) -> void:
	if weapons_demo or sensor_demo or thermal_demo:
		return
	ai_decision_remaining -= delta
	if ai_decision_remaining > 0.0:
		return
	ai_decision_remaining = MATCH_RULES.ai_decision_interval
	if fleet_battle_demo:
		_update_fleet_tactical_ai(friendly_units, enemy_units, BLUE_FLEET_DOCTRINE, blue_fleet_pilot)
		_update_fleet_tactical_ai(enemy_units, friendly_units, RED_FLEET_DOCTRINE, red_fleet_pilot)
		return
	if skirmish_battle_active:
		_update_skirmish_ai()
		return

	for launcher: TacticalUnitScene in enemy_units:
		var target = _find_closest_tracked_target(launcher, friendly_units)
		if DUEL_SANDBOX:
			if launcher.get_heat_ratio() >= 0.80:
				launcher.sensor_mode = TacticalUnitScene.SensorMode.PASSIVE
			elif target == null:
				launcher.sensor_mode = TacticalUnitScene.SensorMode.ACTIVE
		if objective_station != null and objective_station.team_id != 1 and launcher.global_position.distance_to(objective_station.global_position) > objective_station.capture_radius * 0.7:
			var formation_offset := Vector2(float(enemy_units.find(launcher) - 1) * 32.0, 0.0)
			launcher.set_move_target(objective_station.global_position + formation_offset)
		elif enemy_tactical_pilot_enabled and target != null:
			_execute_tactical_plan(launcher, target)
		elif DUEL_SANDBOX and target == null:
			var bandit_index: int = enemy_units.find(launcher)
			var approach_offset := Vector2(0.0, float(bandit_index - 1) * 90.0)
			launcher.set_move_target(Vector2(-250.0, 360.0) + approach_offset)


func _update_skirmish_ai() -> void:
	var search_point: Vector2 = _get_alive_fleet_center(friendly_units)
	for launcher: TacticalUnitScene in enemy_units:
		if launcher.destroyed:
			continue
		var target = _find_closest_tracked_target(launcher, friendly_units)
		if launcher.get_heat_ratio() >= 0.80:
			launcher.sensor_mode = TacticalUnitScene.SensorMode.PASSIVE
		elif target == null:
			launcher.sensor_mode = TacticalUnitScene.SensorMode.ACTIVE
		if target != null:
			_execute_tactical_plan(launcher, target, red_fleet_pilot, RED_FLEET_DOCTRINE)
		elif not launcher.has_move_target and launcher.global_position.distance_to(search_point) > 240.0:
			var slot_offset := Vector2(0.0, float(enemy_units.find(launcher)) * 42.0)
			launcher.set_navigation_order(search_point + slot_offset)


func _get_alive_fleet_center(units: Array[TacticalUnitScene]) -> Vector2:
	var center := Vector2.ZERO
	var alive_count: int = 0
	for unit: TacticalUnitScene in units:
		if unit.destroyed:
			continue
		center += unit.global_position
		alive_count += 1
	return center / float(alive_count) if alive_count > 0 else WORLD_RECT.get_center()


func _update_fleet_tactical_ai(
	launchers: Array[TacticalUnitScene],
	targets: Array[TacticalUnitScene],
	doctrine: TacticalPilotProfile,
	pilot
) -> void:
	for launcher: TacticalUnitScene in launchers:
		if launcher.destroyed:
			continue
		var target = _find_fleet_priority_target(launcher, targets, doctrine)
		if launcher.get_heat_ratio() >= 0.80:
			launcher.sensor_mode = TacticalUnitScene.SensorMode.PASSIVE
		elif (
			target == null
			and launcher.provides_fire_control_data()
			and doctrine.keep_fire_control_radar_active
		):
			launcher.sensor_mode = TacticalUnitScene.SensorMode.ACTIVE
		if target == null:
			if launcher.team_id == 1:
				_apply_red_precontact_plan(launcher)
			continue
		if (
			launcher.team_id == 1
			and launcher.callsign == "R-RAIL-2"
			and missiles_launched[1] == 0
		):
			launcher.cut_engines()
			continue
		if launcher.hull / maxf(launcher.maximum_hull, 0.001) <= doctrine.retreat_hull_ratio:
			var retreat_direction: Vector2 = target.global_position.direction_to(launcher.global_position)
			if retreat_direction == Vector2.ZERO:
				retreat_direction = Vector2.LEFT if launcher.team_id == 0 else Vector2.RIGHT
			launcher.sensor_mode = TacticalUnitScene.SensorMode.PASSIVE
			launcher.set_navigation_order(launcher.global_position + retreat_direction * 900.0)
			continue
		if _try_ai_anti_radiation_attack(launcher, targets, doctrine):
			continue
		if doctrine.flank_offset > 0.0 and not launcher.provides_fire_control_data():
			var target_distance: float = launcher.global_position.distance_to(target.global_position)
			if target_distance > 1100.0:
				var outward: Vector2 = target.global_position.direction_to(launcher.global_position)
				if outward == Vector2.ZERO:
					outward = Vector2.RIGHT
				var flank_sign: float = _get_red_assault_flank(launcher)
				if flank_sign == 0.0:
					_execute_tactical_plan(launcher, target, pilot, doctrine)
					continue
				var staging_point: Vector2 = (
					target.global_position
					+ outward * 720.0
					+ outward.rotated(PI * 0.5) * doctrine.flank_offset * flank_sign
					+ outward * _get_red_assault_slot_offset(launcher)
				)
				launcher.set_navigation_order(staging_point)
				continue
		_execute_tactical_plan(launcher, target, pilot, doctrine)


func _apply_red_precontact_plan(unit: TacticalUnitScene) -> void:
	if unit.callsign in ["R-RELAIS", "R-RAIL-2"]:
		unit.cut_engines()
		return
	var flank_sign: float = _get_red_assault_flank(unit)
	if flank_sign == 0.0:
		return
	var approach_point := Vector2(
		350.0 + _get_red_assault_slot_offset(unit),
		360.0 + flank_sign * 430.0
	)
	if not unit.has_move_target or unit.move_target.distance_to(approach_point) > 2.0:
		unit.set_navigation_order(approach_point)


func _get_red_assault_flank(unit: TacticalUnitScene) -> float:
	if unit.callsign in ["R-RAIL-1", "R-FRIG-1", "R-ESC-L", "R-ARM-1"]:
		return -1.0
	if unit.callsign in ["R-RAIL-3", "R-FRIG-2", "R-ESC-K", "R-ARM-2"]:
		return 1.0
	return 0.0


func _get_red_assault_slot_offset(unit: TacticalUnitScene) -> float:
	if unit.callsign.contains("ARM"):
		return 135.0
	if unit.callsign.contains("ESC"):
		return 95.0
	if unit.callsign.contains("FRIG"):
		return 55.0
	return 0.0


func _find_fleet_priority_target(
	launcher: TacticalUnitScene,
	targets: Array[TacticalUnitScene],
	doctrine: TacticalPilotProfile
):
	var fallback = _find_closest_tracked_target(launcher, targets)
	if fallback == null:
		return null
	var best_target: TacticalUnitScene = fallback
	var best_score: float = INF
	var anti_ship_system: WeaponSystemProfile = launcher.get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_SHIP
	)
	var preferred_railgun: WeaponSystemProfile = launcher.get_weapon_system(
		WeaponSystemProfile.Family.RAILGUN,
		WeaponSystemProfile.TacticalRole.KINETIC_STRIKE
	)
	for candidate: TacticalUnitScene in targets:
		if candidate.destroyed or not _launcher_has_fire_control_solution(launcher, candidate):
			continue
		if (
			anti_ship_system != null
			and (preferred_railgun == null or not doctrine.prefer_railgun)
			and _get_unreserved_missile_damage_need(launcher.team_id, candidate, doctrine) <= 0.0
		):
			continue
		var score: float = launcher.global_position.distance_to(candidate.global_position)
		if candidate.provides_fire_control_data():
			score -= doctrine.fire_control_target_bonus
		if candidate.get_weapon_system(WeaponSystemProfile.Family.RAILGUN) != null:
			score -= doctrine.railgun_target_bonus
		var stable_variation: int = absi(
			("%s:%s:%d" % [launcher.callsign, candidate.callsign, fleet_battle_seed]).hash()
		) % 181
		score += float(stable_variation)
		if score < best_score:
			best_score = score
			best_target = candidate
	return best_target


func _try_ai_anti_radiation_attack(
	launcher: TacticalUnitScene,
	targets: Array[TacticalUnitScene],
	doctrine: TacticalPilotProfile
) -> bool:
	var system: WeaponSystemProfile = launcher.get_weapon_system(
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.TacticalRole.ANTI_RADIATION
	)
	if system == null:
		return false
	var best_target: TacticalUnitScene = null
	var best_score: float = INF
	for candidate: TacticalUnitScene in targets:
		if candidate.destroyed or not _has_current_radio_bearing(launcher.team_id, candidate, launcher):
			continue
		var distance: float = launcher.global_position.distance_to(candidate.global_position)
		var score: float = distance - (system.maximum_range if candidate.provides_fire_control_data() else 0.0)
		if score < best_score:
			best_score = score
			best_target = candidate
	if best_target == null:
		return false
	if _get_ai_missile_shot_count(launcher, best_target, system, doctrine) <= 0:
		return false
	return _launch_anti_radiation_salvo(launcher, [best_target], false, {}) > 0


func _execute_tactical_plan(
	launcher: TacticalUnitScene,
	target: TacticalUnitScene,
	pilot = enemy_tactical_pilot,
	doctrine: TacticalPilotProfile = null
) -> void:
	var plan: Dictionary = pilot.plan_engagement(launcher, target)
	if plan.is_empty():
		return
	if bool(plan["maneuver_required"]):
		var maneuver_point: Vector2 = plan["maneuver_point"]
		var desired_heading: float = float(plan["desired_heading"])
		var same_active_order: bool = (
			launcher.has_move_target
			and launcher.move_target.distance_to(maneuver_point) <= 2.0
		)
		var already_orienting: bool = (
			launcher.is_orienting_to_final_heading
			and absf(angle_difference(launcher.final_heading, desired_heading)) <= deg_to_rad(1.0)
		)
		if not same_active_order and not already_orienting:
			launcher.set_navigation_order(maneuver_point, false, false, desired_heading, true)
	if not bool(plan["should_fire"]):
		return
	var system: WeaponSystemProfile = plan["system"]
	if system.family == WeaponSystemProfile.Family.RAILGUN:
		_fire_railgun(launcher, target)
	elif system.family == WeaponSystemProfile.Family.MISSILE:
		if bool(plan["saturation"]):
			_launch_missile_burst(launcher, target, true)
		elif doctrine == null:
			_launch_missile_burst(launcher, target, false)
		else:
			var requested_count: int = _get_ai_missile_shot_count(
				launcher,
				target,
				system,
				doctrine
			)
			if requested_count > 0:
				_launch_missile_burst(launcher, target, false, requested_count)


func _get_ai_missile_shot_count(
	launcher: TacticalUnitScene,
	target: TacticalUnitScene,
	system: WeaponSystemProfile,
	doctrine: TacticalPilotProfile
) -> int:
	if system == null or system.missile_profile == null:
		return 0
	var damage_need: float = _get_unreserved_missile_damage_need(
		launcher.team_id,
		target,
		doctrine
	)
	if damage_need <= 0.0:
		return 0
	var survival_probability: float = _estimate_missile_survival_probability(target)
	var expected_damage: float = maxf(1.0, system.missile_profile.maximum_damage * survival_probability)
	var required_count: int = ceili(damage_need / expected_damage)
	var ready_count: int = launcher.get_anti_ship_burst_capacity()
	var remaining_count: int = launcher.missiles_remaining
	var initial_capacity: int = launcher.missile_capacity
	if system.feed_type == WeaponSystemProfile.FeedType.FIXED_CELLS:
		remaining_count = launcher.get_weapon_system_ammunition(system)
		initial_capacity = system.ammunition_capacity
		ready_count = mini(system.launcher_count, remaining_count)
	var protected_reserve: int = ceili(float(initial_capacity) * doctrine.missile_reserve_ratio)
	var expendable_count: int = maxi(0, remaining_count - protected_reserve)
	return mini(required_count, mini(ready_count, expendable_count))


func _get_unreserved_missile_damage_need(
	attacking_team_id: int,
	target: TacticalUnitScene,
	doctrine: TacticalPilotProfile
) -> float:
	var required_damage: float = target.hull * doctrine.missile_damage_margin
	return maxf(0.0, required_damage - _get_reserved_missile_damage(attacking_team_id, target))


func _get_reserved_missile_damage(attacking_team_id: int, target: TacticalUnitScene) -> float:
	var survival_probability: float = _estimate_missile_survival_probability(target)
	var reserved_damage: float = 0.0
	for missile: TacticalMissileScene in missiles_layer.get_children():
		if (
			missile.team_id != attacking_team_id
			or missile.target != target
			or not missile.is_interceptable()
			or missile.profile == null
		):
			continue
		reserved_damage += missile.profile.maximum_damage * survival_probability
	return reserved_damage


func _estimate_missile_survival_probability(target: TacticalUnitScene) -> float:
	var defenders: Array[TacticalUnitScene] = friendly_units if target.team_id == 0 else enemy_units
	var survival_probability: float = 0.86
	for defender: TacticalUnitScene in defenders:
		if defender.destroyed or defender.global_position.distance_to(target.global_position) > 280.0:
			continue
		for system: WeaponSystemProfile in defender.weapon_system_profiles:
			if system.tactical_role == WeaponSystemProfile.TacticalRole.INTERCEPTOR:
				survival_probability -= 0.12
			elif system.family == WeaponSystemProfile.Family.LASER_PDC:
				survival_probability -= 0.10
			elif (
				system.family == WeaponSystemProfile.Family.KINETIC_PDC
				and defender.point_defense_ammunition > 0
			):
				survival_probability -= 0.07
	return clampf(survival_probability, 0.28, 0.90)


func _find_closest_tracked_target(launcher: TacticalUnitScene, candidates: Array[TacticalUnitScene]):
	if (
		launcher.team_roster_index >= 0
		and launcher.team_roster_index < closest_local_target_indices_by_team[launcher.team_id].size()
	):
		var cached_target_index: int = closest_local_target_indices_by_team[launcher.team_id][launcher.team_roster_index]
		if cached_target_index >= 0 and cached_target_index < candidates.size():
			var cached_target: TacticalUnitScene = candidates[cached_target_index]
			if not cached_target.destroyed:
				return cached_target
	var closest_target = null
	var closest_distance: float = INF
	var fire_control_providers: Array[TacticalUnitScene] = _get_fire_control_providers(launcher.team_id)
	for candidate: TacticalUnitScene in candidates:
		if candidate.destroyed or launcher.destroyed or launcher.team_id == candidate.team_id:
			continue
		var track = _get_unit_sensor_track(launcher, candidate)
		if track != null and track.get_state() < SensorTrackLogic.State.TRACKED:
			continue
		if track == null and (
			_sensor_range_ratio_squared(launcher, candidate) > 0.68 * 0.68
			and not _providers_have_fire_control_solution(launcher, candidate, fire_control_providers)
		):
			continue
		var contact_position: Vector2 = candidate.global_position if track == null else track.estimated_position
		var distance: float = launcher.global_position.distance_to(contact_position)
		if distance < closest_distance:
			closest_target = candidate
			closest_distance = distance
	return closest_target


func _launcher_has_fire_control_solution(launcher: TacticalUnitScene, target: TacticalUnitScene) -> bool:
	if launcher.destroyed or target.destroyed or launcher.team_id == target.team_id:
		return false
	var track = _get_unit_sensor_track(launcher, target)
	if _sensor_range_ratio_squared(launcher, target) <= 0.68 * 0.68:
		return true
	if _providers_have_fire_control_solution(
		launcher,
		target,
		_get_fire_control_providers(launcher.team_id)
	):
		return true
	return (
		track != null
		and track.has_fire_control_quality(FIRE_CONTROL_MAXIMUM_UNCERTAINTY)
	)


func _get_contact_position(
	observer_team_id: int,
	target: TacticalUnitScene,
	consumer: TacticalUnitScene = null
) -> Vector2:
	var track = (
		_get_sensor_track(observer_team_id, target)
		if consumer == null
		else _get_unit_sensor_track(consumer, target)
	)
	return target.global_position if track == null else track.estimated_position


func _get_contact_velocity(
	observer_team_id: int,
	target: TacticalUnitScene,
	consumer: TacticalUnitScene = null
) -> Vector2:
	var track = (
		_get_sensor_track(observer_team_id, target)
		if consumer == null
		else _get_unit_sensor_track(consumer, target)
	)
	return target.velocity if track == null else track.estimated_velocity


func _get_fire_control_providers(team_id: int) -> Array[TacticalUnitScene]:
	var providers: Array[TacticalUnitScene] = []
	var allies: Array[TacticalUnitScene] = friendly_units if team_id == 0 else enemy_units
	for provider: TacticalUnitScene in allies:
		if not provider.destroyed and provider.provides_fire_control_data():
			providers.append(provider)
	return providers


func _providers_have_fire_control_solution(
	launcher: TacticalUnitScene,
	target: TacticalUnitScene,
	providers: Array[TacticalUnitScene]
) -> bool:
	for provider: TacticalUnitScene in providers:
		if provider == launcher:
			continue
		if not _data_link_can_transfer_now(provider, launcher):
			continue
		var provider_track = _get_unit_sensor_track(provider, target)
		if (
			_sensor_range_ratio_squared(provider, target) <= 0.68 * 0.68
			or (
				provider_track != null
				and provider_track.has_fire_control_quality(FIRE_CONTROL_MAXIMUM_UNCERTAINTY)
			)
		):
			return true
	return false


func _is_target_in_missile_range(launcher: TacticalUnitScene, target: TacticalUnitScene) -> bool:
	return (
		launcher.get_anti_ship_missile_range() > 0.0
		and launcher.global_position.distance_to(
			_get_contact_position(launcher.team_id, target, launcher)
		) <= launcher.get_anti_ship_missile_range()
	)


func _get_connected_fire_control_provider(unit: TacticalUnitScene):
	var allies: Array[TacticalUnitScene] = friendly_units if unit.team_id == 0 else enemy_units
	for provider: TacticalUnitScene in allies:
		if provider.destroyed or not provider.provides_fire_control_data():
			continue
		if _data_link_can_transfer_now(provider, unit):
			return provider
	return null


func _update_missile_guidance() -> void:
	for missile in missiles_layer.get_children():
		if not missile.is_interceptable() or not is_instance_valid(missile.target):
			continue
		if missile.target is TacticalUnit:
			missile.target.trigger_combat_thermal_mode()
			if missile.is_anti_radiation():
				# L'autodirecteur passif ne reçoit pas la position réelle via le réseau :
				# il poursuit l'émission ou continue vers son dernier relèvement.
				continue
			var guidance_group_id: int = int(missile.get_meta("guidance_group_id", 0))
			var guidance_track = _get_group_sensor_track(
				missile.team_id,
				guidance_group_id,
				missile.target
			)
			var guidance_available: bool = (
				guidance_track != null
				and guidance_track.get_state() >= SensorTrackLogic.State.TRACKED
			)
			var guidance_position: Vector2 = (
				missile.target.global_position
				if guidance_track == null
				else guidance_track.estimated_position
			)
			missile.set_external_guidance(guidance_available, guidance_position)
		elif missile.target is TacticalMissile:
			# Un intercepteur possède sa propre piste locale sur le missile poursuivi.
			missile.set_external_guidance(true)


func _team_has_track(observer_team_id: int, target: TacticalUnitScene) -> bool:
	if target.destroyed:
		return false
	var fused_track = _get_sensor_track(observer_team_id, target)
	if fused_track != null:
		return fused_track.get_state() >= SensorTrackLogic.State.TRACKED
	if observer_team_id == 0 and target.team_id != 0:
		return target.intel_state >= TacticalUnitScene.IntelState.TRACKED

	var sensors: Array[TacticalUnitScene] = friendly_units if observer_team_id == 0 else enemy_units
	for sensor: TacticalUnitScene in sensors:
		if sensor.destroyed:
			continue
		if _sensor_range_ratio_squared(sensor, target) <= 0.68 * 0.68:
			return true
	if objective_station != null and objective_station.team_id == observer_team_id:
		if (
			objective_station.global_position.distance_to(target.global_position)
			<= objective_station.sensor_range * target.get_passive_detection_signature() * 0.68
		):
			return true
	return false


func _sensor_range_ratio(sensor: TacticalUnitScene, target: TacticalUnitScene) -> float:
	return sqrt(_sensor_range_ratio_squared(sensor, target))


func _sensor_range_ratio_squared(
	sensor: TacticalUnitScene,
	target: TacticalUnitScene,
	target_thermal_signature: float = -1.0
) -> float:
	var distance_squared: float = sensor.global_position.distance_squared_to(target.global_position)
	var thermal_signature: float = (
		target_thermal_signature
		if target_thermal_signature >= 0.0
		else target.get_passive_detection_signature()
	)
	return _sensor_range_ratio_squared_at_distance(
		sensor,
		target,
		thermal_signature,
		distance_squared
	)


func _sensor_range_ratio_squared_at_distance(
	sensor: TacticalUnitScene,
	target: TacticalUnitScene,
	target_thermal_signature: float,
	distance_squared: float
) -> float:
	return minf(
		_active_radar_ratio_squared_at_distance(sensor, distance_squared),
		minf(
			_thermal_ratio_squared_at_distance(sensor, target_thermal_signature, distance_squared),
			_radio_ratio_squared_at_distance(sensor, target, distance_squared)
		)
	)


func _thermal_ratio_squared_at_distance(
	sensor: TacticalUnitScene,
	target_thermal_signature: float,
	distance_squared: float
) -> float:
	var passive_range: float = sensor.sensor_range * target_thermal_signature
	return distance_squared / maxf(passive_range * passive_range, 0.0001)


func _active_radar_ratio_squared_at_distance(
	sensor: TacticalUnitScene,
	distance_squared: float
) -> float:
	if sensor.sensor_mode != TacticalUnitScene.SensorMode.ACTIVE:
		return INF
	return distance_squared / maxf(sensor.active_sensor_range * sensor.active_sensor_range, 0.0001)


func _radio_ratio_squared_at_distance(
	sensor: TacticalUnitScene,
	target: TacticalUnitScene,
	distance_squared: float
) -> float:
	var electromagnetic_signature: float = target.get_electromagnetic_signature()
	if electromagnetic_signature <= 0.0:
		return INF
	var emission_detection_range: float = (
		sensor.active_emission_detection_range * sqrt(electromagnetic_signature)
	)
	return distance_squared / maxf(emission_detection_range * emission_detection_range, 0.0001)


func _update_point_defense(delta: float) -> void:
	var _unused_delta := delta
	var missiles := missiles_layer.get_children()
	if missiles.is_empty():
		return
	_update_missile_interceptors(missiles)
	var missile_grid: Dictionary = {}
	for missile in missiles:
		if not is_instance_valid(missile) or not missile.is_interceptable():
			continue
		var cell := Vector2i(
			floori(missile.global_position.x / PDC_SPATIAL_CELL_SIZE),
			floori(missile.global_position.y / PDC_SPATIAL_CELL_SIZE)
		)
		if not missile_grid.has(cell):
			missile_grid[cell] = []
		missile_grid[cell].append(missile)

	var defenders: Array = friendly_units + enemy_units
	for defender in defenders:
		if not is_instance_valid(defender) or defender.destroyed:
			continue
		var nearest_missile = null
		var nearest_distance_squared: float = INF
		var defense_range: float = maxf(defender.point_defense_range, 150.0)
		var defense_range_squared: float = defense_range * defense_range
		var defender_cell := Vector2i(
			floori(defender.global_position.x / PDC_SPATIAL_CELL_SIZE),
			floori(defender.global_position.y / PDC_SPATIAL_CELL_SIZE)
		)
		var cell_radius: int = ceili(defense_range / PDC_SPATIAL_CELL_SIZE)
		for cell_x: int in range(defender_cell.x - cell_radius, defender_cell.x + cell_radius + 1):
			for cell_y: int in range(defender_cell.y - cell_radius, defender_cell.y + cell_radius + 1):
				var cell := Vector2i(cell_x, cell_y)
				if not missile_grid.has(cell):
					continue
				for missile in missile_grid[cell]:
					if missile.team_id == defender.team_id:
						continue
					var distance_squared: float = defender.global_position.distance_squared_to(missile.global_position)
					if distance_squared <= defense_range_squared and distance_squared < nearest_distance_squared:
						nearest_missile = missile
						nearest_distance_squared = distance_squared
		if nearest_missile != null:
			var laser_system: WeaponSystemProfile = defender.get_weapon_system(WeaponSystemProfile.Family.LASER_PDC)
			if defender.can_fire_weapon_system(laser_system, nearest_missile.global_position):
				nearest_missile.apply_point_defense_damage(laser_system.damage)
				defender.mark_weapon_system_fired(laser_system, nearest_missile.global_position)
			if nearest_missile.is_interceptable() and defender.can_fire_point_defense_at(nearest_missile.global_position):
				_fire_point_defense_burst(defender, nearest_missile)


func _update_missile_interceptors(missiles: Array) -> void:
	var defenders: Array = friendly_units + enemy_units
	for defender: TacticalUnitScene in defenders:
		if not is_instance_valid(defender) or defender.destroyed:
			continue
		var system: WeaponSystemProfile = defender.get_weapon_system(
			WeaponSystemProfile.Family.MISSILE,
			WeaponSystemProfile.TacticalRole.INTERCEPTOR
		)
		if system == null:
			continue
		var nearest_missile: TacticalMissile = null
		var nearest_distance: float = INF
		for candidate in missiles:
			if not is_instance_valid(candidate) or not candidate.is_interceptable() or candidate.team_id == defender.team_id:
				continue
			var distance: float = defender.global_position.distance_to(candidate.global_position)
			if distance < nearest_distance and defender.can_fire_weapon_system(system, candidate.global_position):
				nearest_missile = candidate
				nearest_distance = distance
		if nearest_missile == null:
			continue
		var interceptor := TacticalMissileScene.new() as TacticalMissileScene
		missiles_layer.add_child(interceptor)
		interceptor.impacted.connect(_on_missile_impacted.bind(defender.team_id))
		interceptor.detonated.connect(_on_missile_detonated)
		interceptor.finished.connect(_on_missile_finished)
		interceptor.launch(defender.global_position, nearest_missile, defender.team_id, system.missile_profile)
		interceptor.set_visual_zoom(tactical_camera.zoom.x)
		defender.mark_weapon_system_fired(system, nearest_missile.global_position)
		missiles_launched[defender.team_id] += 1


func _fire_point_defense_burst(defender: TacticalUnitScene, missile: TacticalMissileScene) -> void:
	var aim_point: Vector2 = _calculate_intercept_point(
		defender.global_position,
		missile.global_position,
		missile.velocity,
		defender.point_defense_projectile_speed
	)
	var projectile := PdcProjectileScene.new() as PdcProjectileScene
	pdc_projectiles_layer.add_child(projectile)
	projectile.launch(
		defender.global_position,
		aim_point,
		defender.team_id,
		defender.point_defense_projectile_speed,
		defender.point_defense_projectile_lifetime,
		defender.point_defense_projectile_damage,
		defender.point_defense_projectile_hit_radius,
		defender.point_defense_dispersion_degrees
	)
	projectile.set_visual_zoom(tactical_camera.zoom.x)
	defender.mark_point_defense_fired(aim_point)


func _calculate_intercept_point(origin: Vector2, target_position: Vector2, target_velocity: Vector2, projectile_speed: float) -> Vector2:
	var relative_position: Vector2 = target_position - origin
	var a: float = target_velocity.length_squared() - projectile_speed * projectile_speed
	var b: float = 2.0 * relative_position.dot(target_velocity)
	var c: float = relative_position.length_squared()
	var intercept_time: float = 0.0
	if absf(a) < 0.0001:
		if absf(b) > 0.0001:
			intercept_time = maxf(0.0, -c / b)
	else:
		var discriminant: float = b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var root: float = sqrt(discriminant)
			var first_time: float = (-b - root) / (2.0 * a)
			var second_time: float = (-b + root) / (2.0 * a)
			if first_time > 0.0 and second_time > 0.0:
				intercept_time = minf(first_time, second_time)
			else:
				intercept_time = maxf(first_time, second_time)
	if intercept_time <= 0.0:
		return target_position
	return target_position + target_velocity * intercept_time


func _on_missile_detonated(world_position: Vector2, fragment_radius: float, maximum_damage: float, intercepted: bool, missile_team_id: int) -> void:
	if intercepted:
		missile_interceptions[1 - missile_team_id] += 1
	var units: Array = friendly_units + enemy_units
	for unit in units:
		if not is_instance_valid(unit) or unit.destroyed:
			continue
		var distance: float = unit.global_position.distance_to(world_position)
		if distance > fragment_radius:
			continue
		var falloff: float = 1.0 - distance / fragment_radius
		unit.apply_fragment_damage(maximum_damage * falloff)
	for missile in missiles_layer.get_children():
		if not is_instance_valid(missile) or missile.team_id == missile_team_id or not missile.is_interceptable():
			continue
		var missile_distance: float = missile.global_position.distance_to(world_position)
		if missile_distance <= fragment_radius:
			var missile_falloff: float = 1.0 - missile_distance / fragment_radius
			missile.apply_point_defense_damage(maximum_damage * missile_falloff)
	var previous_selection_size: int = selected_units.size()
	selected_units = selected_units.filter(func(unit): return is_instance_valid(unit) and not unit.destroyed)
	if selected_units.size() != previous_selection_size:
		_refresh_range_visualization()


func _on_missile_impacted(_target: Node2D, missile_team_id: int) -> void:
	confirmed_impacts += 1
	missile_impacts[missile_team_id] += 1
	_update_status()


func _on_missile_finished(_missile: TacticalMissileScene) -> void:
	_update_status()


func _update_status() -> void:
	_update_fleet_battle_header()
	var friendly_missiles: int = 0
	var hostile_missiles: int = 0
	for missile in missiles_layer.get_children():
		if missile.team_id == 0:
			friendly_missiles += 1
		else:
			hostile_missiles += 1
	status_label.text = "TICK %06d  //  SÉLECTION %02d  //  MISSILES %02d/%02d  //  IMPACTS %02d" % [
		simulation_clock.tick_index,
		selected_units.size(),
		friendly_missiles,
		hostile_missiles,
		confirmed_impacts,
	]
	var selected_mission_status: String = _get_selected_fire_mission_status()
	if not selected_mission_status.is_empty():
		status_label.text += "  //  %s" % selected_mission_status
	elif not last_attack_feedback.is_empty():
		status_label.text += "  //  %s" % last_attack_feedback
	var blue_alive: int = friendly_units.filter(func(unit): return not unit.destroyed).size()
	var red_alive: int = enemy_units.filter(func(unit): return not unit.destroyed).size()
	var blue_ammunition: int = 0
	var red_ammunition: int = 0
	for unit: TacticalUnitScene in friendly_units:
		blue_ammunition += unit.missiles_remaining
	for unit: TacticalUnitScene in enemy_units:
		red_ammunition += unit.missiles_remaining
	telemetry_label.text = "BLEU %d/%d  MUN %d  TIRS %d  TOUCHÉS %d  INTERCEPT. %d\nROUGE %d/%d  MUN %d  TIRS %d  TOUCHÉS %d  INTERCEPT. %d" % [
		blue_alive, friendly_units.size(), blue_ammunition, missiles_launched[0], missile_impacts[0], missile_interceptions[0],
		red_alive, enemy_units.size(), red_ammunition, missiles_launched[1], missile_impacts[1], missile_interceptions[1],
	]
	_update_selection_details()
	if thermal_demo:
		_update_thermal_demo_header()
	elif task_force_demo:
		_update_task_force_demo_header()


func _update_thermal_demo_header() -> void:
	if friendly_units.is_empty():
		return
	var cold_target: TacticalUnitScene
	var hot_target: TacticalUnitScene
	for target: TacticalUnitScene in enemy_units:
		if target.callsign == "CIBLE-FROIDE":
			cold_target = target
		elif target.callsign == "CIBLE-CHAUDE":
			hot_target = target
	if cold_target == null or hot_target == null:
		return
	var sensor: TacticalUnitScene = friendly_units[0]
	var cold_signature: float = cold_target.get_passive_detection_signature()
	var hot_signature: float = hot_target.get_passive_detection_signature()
	objective_label.text = (
		"THERMIQUE — S: ACTIF/PASSIF  •  FROID IR %.2f → %.0f  •  CHAUD IR %.2f → %.0f  •  CAPTEUR %s"
		% [
			cold_signature,
			sensor.sensor_range * cold_signature,
			hot_signature,
			sensor.sensor_range * hot_signature,
			sensor.get_sensor_mode_name(),
		]
	)


func _get_selected_fire_mission_status() -> String:
	var selected_missions: Array[FireMission] = []
	for mission: FireMission in active_fire_missions:
		if mission.assigned_units.any(func(unit): return unit in selected_units):
			selected_missions.append(mission)
	if selected_missions.is_empty():
		return ""
	if selected_missions.size() == 1:
		return "MISSION: %s" % selected_missions[0].status_text
	return "MISSIONS: %d ACTIVES" % selected_missions.size()


func _update_selection_details() -> void:
	_update_system_control_labels()
	if selected_units.is_empty():
		selection_details_label.text = "SÉLECTION: AUCUNE UNITÉ"
		return
	if selected_units.size() == 1:
		var unit: TacticalUnitScene = selected_units[0]
		var reload_text := "PRÊT" if unit.can_launch_weapon() else "%.1f s" % unit.weapon_cooldown_remaining
		var crew_text := "HABITÉ" if unit.unit_profile.crewed else "AUTONOME"
		var propulsion_name := "PROFIL INTÉGRÉ"
		if unit.unit_profile.propulsion_profile != null:
			propulsion_name = unit.unit_profile.propulsion_profile.display_name.to_upper()
		var network_text: String = "GT %d • %s • PISTES %d" % [
			unit.tactical_group_id + 1,
			unit.get_data_link_role_name(),
			_count_accessible_tracks(unit),
		]
		var fire_control_provider = _get_connected_fire_control_provider(unit)
		if fire_control_provider == unit:
			network_text += " • CONDUITE %.0f" % unit.get_data_link_range()
		elif fire_control_provider != null:
			network_text += " • VIA %s" % fire_control_provider.callsign
		var route_text := "ROUTE —"
		if unit.is_returning_to_theater:
			route_text = "HORS SECTEUR • RETOUR AUTO"
		elif not unit.navigation_route.is_empty():
			route_text = "ROUTE %d  •  V.PROCH %.0f" % [
				unit.navigation_route.size(), unit.navigation_route[0].planned_speed,
			]
		selection_details_label.text = "%s  //  %s  //  %s  //  %s  •  COQUE %.0f/%.0f\nVIT %.0f/%.0f  •  ACC %.0f  •  ROT %.0f°/s  •  PROP. %s [%s]  •  PHASE %s  •  %s\nCAPT. %s %.0f  •  %s  •  EM %.2f [%s]  •  THERM. %s  •  CHALEUR %.0f/%.0f  •  IR %.2f\nPDC %.0f  MUN %d/%d  •  TIR %.0f  •  TUBES %d/%d  CHARGE %d  •  MISSILES %d/%d  (%s)\nARMES: %s" % [
			unit.callsign, unit.unit_profile.tactical_role, unit.unit_profile.display_name, crew_text,
			unit.hull, unit.maximum_hull,
			unit.velocity.length(), unit.move_speed, unit.maximum_acceleration,
			rad_to_deg(unit.maximum_angular_speed), propulsion_name, unit.get_propulsion_doctrine_name(), unit.get_maneuver_phase_name(), route_text,
			unit.get_sensor_mode_name(), unit.sensor_range,
			network_text,
			unit.get_electromagnetic_signature(), unit.get_electromagnetic_emission_name(),
			unit.get_thermal_mode_name(), unit.heat, unit.heat_capacity, unit.get_thermal_signature(),
			unit.point_defense_range, unit.point_defense_ammunition, unit.point_defense_ammunition_capacity,
			unit.unit_profile.missile_launch_range,
			unit.get_ready_launcher_count(), unit.missile_launcher_count,
			unit.get_loading_launcher_count(), unit.missiles_remaining, unit.missile_capacity, reload_text,
			unit.get_weapon_system_summary(),
		]
		return

	var total_hull: float = 0.0
	var total_maximum_hull: float = 0.0
	var launchers_ready: int = 0
	var launchers_loading: int = 0
	var missiles_available: int = 0
	var missile_capacity: int = 0
	var pdc_ammunition: int = 0
	var pdc_capacity: int = 0
	for unit: TacticalUnitScene in selected_units:
		total_hull += unit.hull
		total_maximum_hull += unit.maximum_hull
		missiles_available += unit.missiles_remaining
		missile_capacity += unit.missile_capacity
		pdc_ammunition += unit.point_defense_ammunition
		pdc_capacity += unit.point_defense_ammunition_capacity
		launchers_ready += unit.get_ready_launcher_count()
		launchers_loading += unit.get_loading_launcher_count()
	selection_details_label.text = "GROUPE: %d UNITÉS\nCOQUE %.0f/%.0f  •  TUBES PRÊTS %d  •  CHARGEMENT %d\nMISSILES %d/%d  •  MUNITIONS PDC %d/%d" % [
		selected_units.size(), total_hull, total_maximum_hull,
		launchers_ready, launchers_loading, missiles_available, missile_capacity,
		pdc_ammunition, pdc_capacity,
	]


func _update_system_control_labels() -> void:
	var disabled: bool = selected_units.is_empty()
	cut_engines_button.disabled = disabled
	attack_mode_button.disabled = disabled
	sensor_mode_button.disabled = disabled
	thermal_mode_button.disabled = true
	if disabled:
		attack_mode_button.text = "ATTAQUE [A]"
		sensor_mode_button.text = "CAPTEUR: — [S]"
		thermal_mode_button.text = "THERMIQUE: AUTO"
		return
	var first_unit: TacticalUnitScene = selected_units[0]
	var sensor_text: String = first_unit.get_sensor_mode_name()
	var thermal_text: String = first_unit.get_thermal_mode_name()
	for unit: TacticalUnitScene in selected_units:
		if unit.sensor_mode != first_unit.sensor_mode:
			sensor_text = "MIXTE"
		if unit.thermal_mode != first_unit.thermal_mode:
			thermal_text = "MIXTE"
	sensor_mode_button.text = "CAPTEUR: %s [S]" % sensor_text
	thermal_mode_button.text = "THERMIQUE AUTO: %s" % thermal_text


func _handle_task_force_demo_key(keycode: int) -> bool:
	if task_force_demo_force == null or task_force_demo_motion == null:
		return false
	if keycode == KEY_1 or keycode == KEY_KP_1:
		_set_task_force_demo_formation(TaskForce.FormationShape.LINE, TaskForce.FormationSpacing.TIGHT)
	elif keycode == KEY_2 or keycode == KEY_KP_2:
		_set_task_force_demo_formation(TaskForce.FormationShape.LINE, TaskForce.FormationSpacing.LOOSE)
	elif keycode == KEY_3 or keycode == KEY_KP_3:
		_set_task_force_demo_formation(TaskForce.FormationShape.SWARM, TaskForce.FormationSpacing.TIGHT)
	elif keycode == KEY_4 or keycode == KEY_KP_4:
		_set_task_force_demo_formation(TaskForce.FormationShape.SWARM, TaskForce.FormationSpacing.LOOSE)
	elif keycode == KEY_T:
		if task_force_demo_scout == null:
			return false
		if task_force_demo_force.get_member_status(task_force_demo_scout) == TaskForce.PhysicalStatus.DETACHED:
			task_force_demo_motion.rejoin_member(task_force_demo_scout)
		else:
			task_force_demo_motion.detach_member(task_force_demo_scout)
	elif keycode == KEY_R:
		var rejoined_any: bool = false
		for unit: TacticalUnitScene in task_force_demo_force.members:
			if task_force_demo_force.get_member_status(unit) == TaskForce.PhysicalStatus.DETACHED:
				rejoined_any = task_force_demo_motion.rejoin_member(unit) or rejoined_any
		if not rejoined_any:
			return false
	else:
		return false
	_update_task_force_demo_header()
	queue_redraw()
	return true


func _handle_task_force_demo_key_event(event: InputEventKey) -> bool:
	if _handle_task_force_demo_key(event.keycode):
		return true
	return (
		event.physical_keycode != event.keycode
		and _handle_task_force_demo_key(event.physical_keycode)
	)


func _set_task_force_demo_formation(
	shape: TaskForce.FormationShape,
	spacing: TaskForce.FormationSpacing
) -> void:
	task_force_demo_force.set_formation(shape, spacing)
	task_force_demo_motion.request_formation_refresh()


func _update_task_force_demo_header() -> void:
	if task_force_demo_force == null or task_force_demo_motion == null:
		return
	var shape_name := (
		"LIGNE"
		if task_force_demo_force.formation_shape == TaskForce.FormationShape.LINE
		else "ESSAIM"
	)
	var spacing_name := (
		"SERRÉ"
		if task_force_demo_force.formation_spacing == TaskForce.FormationSpacing.TIGHT
		else "LÂCHE"
	)
	var scout_name := "INTÉGRÉ"
	if (
		task_force_demo_scout != null
		and task_force_demo_force.get_member_status(task_force_demo_scout)
		== TaskForce.PhysicalStatus.DETACHED
	):
		scout_name = "DÉTACHÉ"
	objective_label.text = (
		"TF %s/%s  •  COHÉSION %.0f  •  ÉCLAIREUR %s  •  CLIC TF  •  CTRL+CLIC MICRO  •  1–4 FORMATION  •  T/R STATUT  •  CLIC DROIT DÉPLACE"
		% [shape_name, spacing_name, task_force_demo_motion.get_cohesion_error(), scout_name]
	)


func _draw_task_force_demo_slots() -> void:
	if not task_force_demo or task_force_demo_motion == null:
		return
	var zoom_value: float = tactical_camera.zoom.x
	var slots: Dictionary = task_force_demo_motion.calculate_current_slots()
	var line_width: float = TacticalPresentation.stroke_width(1.0, zoom_value)
	var slot_radius: float = TacticalPresentation.world_size_for_screen_pixels(3.0, zoom_value)
	var route_width: float = TacticalPresentation.stroke_width(1.5, zoom_value)
	var route_points := PackedVector2Array([task_force_demo_motion.anchor_position])
	for waypoint: NavigationWaypoint in task_force_demo_motion.navigation_route:
		route_points.append(waypoint.position)
	if route_points.size() > 1:
		draw_polyline(route_points, Color(0.35, 0.85, 1.0, 0.72), route_width)
	var waypoint_radius: float = TacticalPresentation.compensated_radius(
		4.0,
		TacticalPresentation.MINIMUM_WAYPOINT_DIAMETER_PX,
		zoom_value
	)
	for waypoint_index: int in task_force_demo_motion.navigation_route.size():
		var waypoint: NavigationWaypoint = task_force_demo_motion.navigation_route[waypoint_index]
		var waypoint_color := (
			Color("8dffaf")
			if waypoint.passage_mode == NavigationWaypoint.PassageMode.FLY_THROUGH
			else Color("d7fbff")
		)
		draw_circle(waypoint.position, waypoint_radius, Color(waypoint_color, 0.22))
		draw_arc(
			waypoint.position,
			waypoint_radius,
			0.0,
			TAU,
			TacticalPresentation.circle_segments(waypoint_radius, zoom_value),
			waypoint_color,
			route_width
		)
		if waypoint.has_final_heading:
			_draw_task_force_heading_vector(
				waypoint.position,
				waypoint.final_heading,
				waypoint_color,
				route_width,
				zoom_value
			)
	for unit: TacticalUnitScene in slots:
		var slot: Vector2 = slots[unit]
		var color := Color(0.35, 0.92, 1.0, 0.42)
		if task_force_demo_force.get_member_status(unit) == TaskForce.PhysicalStatus.SUPPORT:
			color = Color(0.75, 0.48, 1.0, 0.52)
		draw_line(unit.global_position, slot, color, line_width)
		draw_circle(slot, slot_radius, color, false, line_width)
	var anchor_radius: float = TacticalPresentation.world_size_for_screen_pixels(5.0, zoom_value)
	draw_circle(
		task_force_demo_motion.anchor_position,
		anchor_radius,
		Color(0.95, 0.85, 0.30, 0.85),
		false,
		line_width
	)


func _draw_task_force_heading_vector(
	origin: Vector2,
	heading: float,
	color: Color,
	stroke: float,
	zoom_value: float
) -> void:
	var heading_length: float = maxf(
		24.0,
		TacticalPresentation.world_size_for_screen_pixels(14.0, zoom_value)
	)
	var heading_direction: Vector2 = Vector2.UP.rotated(heading)
	var heading_tip: Vector2 = origin + heading_direction * heading_length
	draw_line(origin, heading_tip, color, stroke)
	var arrow_size: float = TacticalPresentation.world_size_for_screen_pixels(4.0, zoom_value)
	var arrow_base: Vector2 = heading_tip - heading_direction * arrow_size * 1.8
	draw_line(
		heading_tip,
		arrow_base + heading_direction.rotated(PI * 0.5) * arrow_size,
		color,
		stroke
	)
	draw_line(
		heading_tip,
		arrow_base - heading_direction.rotated(PI * 0.5) * arrow_size,
		color,
		stroke
	)


func _draw() -> void:
	draw_rect(WORLD_RECT, BACKGROUND_COLOR)
	var zoom_value: float = tactical_camera.zoom.x
	_draw_grid(TacticalPresentation.STRATEGIC_GRID_SPACING, TacticalPresentation.grid_alpha(TacticalPresentation.STRATEGIC_GRID_SPACING, zoom_value))
	_draw_grid(TacticalPresentation.TACTICAL_GRID_SPACING, TacticalPresentation.grid_alpha(TacticalPresentation.TACTICAL_GRID_SPACING, zoom_value))
	_draw_grid(TacticalPresentation.CLOSE_GRID_SPACING, TacticalPresentation.grid_alpha(TacticalPresentation.CLOSE_GRID_SPACING, zoom_value))

	var edge_width: float = 32.0
	draw_rect(Rect2(WORLD_RECT.position, Vector2(WORLD_RECT.size.x, edge_width)), WORLD_EDGE_FILL)
	draw_rect(Rect2(Vector2(WORLD_RECT.position.x, WORLD_RECT.end.y - edge_width), Vector2(WORLD_RECT.size.x, edge_width)), WORLD_EDGE_FILL)
	draw_rect(Rect2(WORLD_RECT.position, Vector2(edge_width, WORLD_RECT.size.y)), WORLD_EDGE_FILL)
	draw_rect(Rect2(Vector2(WORLD_RECT.end.x - edge_width, WORLD_RECT.position.y), Vector2(edge_width, WORLD_RECT.size.y)), WORLD_EDGE_FILL)
	draw_rect(WORLD_RECT, WORLD_BORDER_COLOR, false, TacticalPresentation.stroke_width(4.0, zoom_value))
	_draw_task_force_demo_slots()


func _draw_grid(spacing: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var grid_color := Color(GRID_COLOR, GRID_COLOR.a * alpha)
	var grid_stroke: float = TacticalPresentation.stroke_width(1.0, tactical_camera.zoom.x)
	var x: float = WORLD_RECT.position.x
	while x <= WORLD_RECT.end.x:
		draw_line(Vector2(x, WORLD_RECT.position.y), Vector2(x, WORLD_RECT.end.y), grid_color, grid_stroke)
		x += spacing
	var y: float = WORLD_RECT.position.y
	while y <= WORLD_RECT.end.y:
		draw_line(Vector2(WORLD_RECT.position.x, y), Vector2(WORLD_RECT.end.x, y), grid_color, grid_stroke)
		y += spacing
