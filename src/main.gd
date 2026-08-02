extends Node2D

const TacticalUnitScene := preload("res://src/tactical_unit.gd")
const TacticalMissileScene := preload("res://src/tactical_missile.gd")
const PdcProjectileScene := preload("res://src/pdc_projectile.gd")
const RailgunProjectileScene := preload("res://src/railgun_projectile.gd")
const StrategicStationScene := preload("res://src/strategic_station.gd")
const TacticalPilotLogic := preload("res://src/ai/tactical_pilot.gd")
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
const RAILGUN_SYSTEM: WeaponSystemProfile = preload("res://data/weapons/medium_railgun.tres")
const DEFAULT_TACTICAL_PILOT_PROFILE := preload("res://data/ai/default_tactical_pilot.tres")
const MATCH_RULES: MatchRules = preload("res://data/balance/match_rules.tres")
const CAMERA_SPEED: float = 620.0
const EDGE_SCROLL_MARGIN: float = 18.0
const ATTACK_ZONE_RADIUS: float = 180.0
const ATTACK_ZONE_DISPLAY_DURATION: float = 1.6
const SENSOR_UPDATE_INTERVAL: float = 0.20
const MISSILE_SWARM_SPACING: float = 52.0
const PDC_SPATIAL_CELL_SIZE: float = 160.0
const THEATER_RETURN_MARGIN: float = 180.0
const MIN_ZOOM: float = 0.15
const MAX_ZOOM: float = 2.2
const WORLD_RECT := Rect2(-4096.0, -4096.0, 8192.0, 8192.0)
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
var attack_zone_center: Vector2
var attack_zone_display_remaining: float = 0.0
var attack_zone_has_solution: bool = false
var last_attack_feedback: String = ""
var offensive_weapon_selection: OffensiveWeaponSelection = OffensiveWeaponSelection.AUTO
var fire_doctrine: FireDoctrine = FireDoctrine.SALVO
var confirmed_impacts: int = 0
var missiles_launched: Array[int] = [0, 0]
var missile_impacts: Array[int] = [0, 0]
var missile_interceptions: Array[int] = [0, 0]
var ai_decision_remaining: float = 1.8
var enemy_tactical_pilot = TacticalPilotLogic.new(DEFAULT_TACTICAL_PILOT_PROFILE)
var enemy_tactical_pilot_enabled: bool = true
var sensor_update_remaining: float = SENSOR_UPDATE_INTERVAL
var objective_station: StrategicStationScene
var team_hold_time: Array[float] = [0.0, 0.0]
var match_over: bool = false
var propulsion_demo: bool = OS.get_cmdline_user_args().has("--propulsion-demo")
var weapons_demo: bool = OS.get_cmdline_user_args().has("--weapons-demo")
var ai_demo: bool = OS.get_cmdline_user_args().has("--ai-demo")
var benchmark_empty_scenario: bool = false
var target_camera_zoom: float = 0.42
var zoom_anchor_world: Vector2 = Vector2.ZERO
var zoom_anchor_screen: Vector2 = Vector2.ZERO
var zoom_transition_active: bool = false

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


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	restart_button.pressed.connect(_restart_match)
	info_button.pressed.connect(_toggle_secondary_info)
	cut_engines_button.pressed.connect(_cut_selected_engines)
	attack_mode_button.pressed.connect(_toggle_attack_command)
	weapon_select_button.pressed.connect(_cycle_offensive_weapon_selection)
	fire_doctrine_button.pressed.connect(_cycle_fire_doctrine)
	sensor_mode_button.pressed.connect(_toggle_selected_sensors)
	tactical_minimap.bind(self, WORLD_RECT)
	tactical_overlay.bind(self)
	tactical_labels.bind(self)
	_spawn_demo_units()
	if propulsion_demo or weapons_demo:
		for unit: TacticalUnitScene in friendly_units:
			selected_units.append(unit)
			unit.set_selected(true)
		_frame_friendly_units()
	_apply_visual_zoom()
	if ai_demo:
		_frame_units(friendly_units + enemy_units)
	if weapons_demo:
		objective_label.text = "SCÉNARIO: ARMEMENTS ET ARCS — A PUIS CLIC SUR UNE CIBLE"
	elif ai_demo:
		objective_label.text = "SCÉNARIO: PILOTE TACTIQUE IA — PORTÉE, CAP ET ARCS"
	elif propulsion_demo:
		objective_label.text = "SCÉNARIO: COMPARATIF PROPULSION — F POUR CADRER"
	elif DUEL_SANDBOX:
		objective_label.text = "SCÉNARIO: VEILLE DÉPORTÉE"
	else:
		_spawn_objective_station()
	_update_status()
	_update_fire_control_buttons()
	queue_redraw()


func _restart_match() -> void:
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


func _cycle_fire_doctrine() -> void:
	fire_doctrine = (int(fire_doctrine) + 1) % FireDoctrine.size()
	_update_fire_control_buttons()


func _update_fire_control_buttons() -> void:
	var weapon_name := "AUTO"
	if offensive_weapon_selection == OffensiveWeaponSelection.MISSILES:
		weapon_name = "MISSILES"
	elif offensive_weapon_selection == OffensiveWeaponSelection.RAILGUN:
		weapon_name = "RAILGUN"
	var doctrine_name := "ÉCONOMIE"
	if fire_doctrine == FireDoctrine.SALVO:
		doctrine_name = "SALVE"
	elif fire_doctrine == FireDoctrine.SATURATION:
		doctrine_name = "SATURATION"
	weapon_select_button.text = "ARME: %s [W]" % weapon_name
	fire_doctrine_button.text = "FEU: %s [D]" % doctrine_name


func _process(delta: float) -> void:
	if attack_zone_display_remaining > 0.0:
		attack_zone_display_remaining = maxf(0.0, attack_zone_display_remaining - delta)
		queue_redraw()
	_update_camera_zoom(delta)
	_update_camera(delta)


func _physics_process(delta: float) -> void:
	var processed_ticks: int = simulation_clock.advance(delta)
	if processed_ticks <= 0 or match_over:
		return
	_update_objective(delta)
	if match_over:
		return
	_update_ai(delta)
	_update_theater_bounds()
	_update_missile_guidance()
	_update_point_defense(delta)
	_update_sensor_picture_if_due(delta)
	_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_X:
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
		elif event.keycode == KEY_F:
			_frame_friendly_units()
		elif event.keycode == KEY_C:
			_focus_selected_units()
		elif event.keycode == KEY_ESCAPE:
			_cancel_attack_command()
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
			_finish_selection(Input.is_key_pressed(KEY_SHIFT))
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_cancel_attack_command()
			if selected_units.is_empty():
				is_panning_camera = true
				get_viewport().set_input_as_handled()
				return
			is_defining_move_order = true
			move_order_start = get_global_mouse_position()
			move_order_end = move_order_start
			move_order_append = event.shift_pressed
			move_order_fly_through = event.ctrl_pressed
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
	elif ai_demo:
		_spawn_ai_demo_units()
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
	var arsenal_ship: TacticalUnitScene = _spawn_unit("ARSENAL-AI", 1, Vector2(1300.0, 460.0), arsenal_profile)
	arsenal_ship.rotation = 0.0

	var awacs: TacticalUnitScene = _spawn_unit("EYE-AI", 1, Vector2(820.0, 360.0), AWACS_PROFILE)
	awacs.sensor_mode = TacticalUnitScene.SensorMode.ACTIVE


func _spawn_unit(callsign: String, team_id: int, start_position: Vector2, profile: UnitProfile) -> TacticalUnitScene:
	var unit := TacticalUnitScene.new() as TacticalUnitScene
	unit.configure(callsign, team_id, start_position, profile)
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


func _update_sensor_picture() -> void:
	var signal_count: int = 0
	var tracked_count: int = 0
	var identified_count: int = 0

	for enemy: TacticalUnitScene in enemy_units:
		if enemy.destroyed:
			continue
		var enemy_thermal_signature: float = enemy.get_thermal_signature()
		var best_range_ratio_squared: float = INF
		for friendly: TacticalUnitScene in friendly_units:
			if friendly.destroyed:
				continue
			best_range_ratio_squared = minf(
				best_range_ratio_squared,
				_sensor_range_ratio_squared(friendly, enemy, enemy_thermal_signature)
			)
		if objective_station != null and objective_station.team_id == 0:
			var station_range: float = objective_station.sensor_range * enemy_thermal_signature
			var station_ratio_squared: float = objective_station.global_position.distance_squared_to(enemy.global_position) / maxf(
				station_range * station_range,
				0.0001
			)
			best_range_ratio_squared = minf(best_range_ratio_squared, station_ratio_squared)

		var new_state: TacticalUnitScene.IntelState = TacticalUnitScene.IntelState.HIDDEN
		var uncertainty := Vector2.ZERO
		if best_range_ratio_squared <= 0.36 * 0.36:
			new_state = TacticalUnitScene.IntelState.IDENTIFIED
			identified_count += 1
		elif best_range_ratio_squared <= 0.68 * 0.68:
			new_state = TacticalUnitScene.IntelState.TRACKED
			tracked_count += 1
		elif best_range_ratio_squared <= 1.0:
			new_state = TacticalUnitScene.IntelState.SIGNAL
			var phase: float = deg_to_rad(float(abs(enemy.callsign.hash()) % 360))
			uncertainty = Vector2.from_angle(phase) * 34.0
			signal_count += 1
		enemy.set_intel_state(new_state, uncertainty)

	intel_label.text = "RENSEIGNEMENT: %d SIGNAL  •  %d PISTE  •  %d IDENTIFIÉ" % [
		signal_count,
		tracked_count,
		identified_count,
	]


func _update_sensor_picture_if_due(delta: float) -> void:
	sensor_update_remaining -= delta
	if sensor_update_remaining > 0.0:
		return
	sensor_update_remaining += SENSOR_UPDATE_INTERVAL
	_update_sensor_picture()


func _finish_selection(add_to_selection: bool) -> void:
	is_selecting = false
	if not add_to_selection:
		_clear_selection()

	var selection_rect := Rect2(selection_start, selection_end - selection_start).abs()
	var is_click := selection_start.distance_to(selection_end) < 6.0

	for unit: TacticalUnitScene in friendly_units:
		var should_select := unit.contains_world_point(selection_end) if is_click else selection_rect.has_point(unit.global_position)
		if should_select and unit not in selected_units:
			selected_units.append(unit)
			unit.set_selected(true)

	_update_status()
	queue_redraw()


func _clear_selection() -> void:
	for unit: TacticalUnitScene in selected_units:
		unit.set_selected(false)
	selected_units.clear()


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
	attack_zone_center = zone_center
	attack_zone_display_remaining = ATTACK_ZONE_DISPLAY_DURATION
	var candidates: Array[TacticalUnitScene] = []
	for enemy: TacticalUnitScene in enemy_units:
		if enemy.is_targetable_contact() and enemy.global_position.distance_to(zone_center) <= ATTACK_ZONE_RADIUS:
			candidates.append(enemy)
	candidates.sort_custom(func(first: TacticalUnitScene, second: TacticalUnitScene):
		return first.global_position.distance_squared_to(zone_center) < second.global_position.distance_squared_to(zone_center)
	)
	var shots_fired: int = 0
	var missile_allocation: Dictionary = {"cursor": 0}
	for launcher: TacticalUnitScene in selected_units:
		var launcher_shots: int = _fire_selected_offensive_weapons(launcher, candidates, missile_allocation)
		shots_fired += launcher_shots
		if fire_doctrine == FireDoctrine.ECONOMY and shots_fired > 0:
			break
	attack_zone_has_solution = shots_fired > 0
	if shots_fired > 0:
		last_attack_feedback = "SALVE %d TIR(S)" % shots_fired
	elif candidates.is_empty():
		last_attack_feedback = "AUCUNE CIBLE DANS LA ZONE"
	else:
		last_attack_feedback = _get_attack_block_reason(candidates[0])
	_update_status()
	queue_redraw()
	return shots_fired


func _fire_selected_offensive_weapons(
	launcher: TacticalUnitScene,
	targets: Array[TacticalUnitScene],
	missile_allocation: Dictionary
) -> int:
	var allow_missiles: bool = offensive_weapon_selection != OffensiveWeaponSelection.RAILGUN
	var allow_railgun: bool = offensive_weapon_selection != OffensiveWeaponSelection.MISSILES
	var saturation: bool = fire_doctrine == FireDoctrine.SATURATION
	var shots: int = 0
	if saturation:
		if allow_railgun:
			for target: TacticalUnitScene in targets:
				if _fire_railgun(launcher, target):
					shots += 1
					break
		if allow_missiles:
			shots += _launch_missile_salvo(launcher, targets, true, missile_allocation)
		return shots
	# En AUTO, le railgun économise les missiles lorsqu'il possède une solution.
	if allow_railgun:
		for target: TacticalUnitScene in targets:
			if _fire_railgun(launcher, target):
				return 1
	if allow_missiles:
		return _launch_missile_salvo(launcher, targets, false, missile_allocation)
	return 0


func _get_attack_block_reason(target: TacticalUnitScene) -> String:
	var found_weapon: bool = false
	var found_in_range: bool = false
	var found_in_arc: bool = false
	for launcher: TacticalUnitScene in selected_units:
		for system: WeaponSystemProfile in launcher.weapon_system_profiles:
			if offensive_weapon_selection == OffensiveWeaponSelection.MISSILES and system.family != WeaponSystemProfile.Family.MISSILE:
				continue
			if offensive_weapon_selection == OffensiveWeaponSelection.RAILGUN and system.family != WeaponSystemProfile.Family.RAILGUN:
				continue
			if system.family != WeaponSystemProfile.Family.RAILGUN and not (
				system.family == WeaponSystemProfile.Family.MISSILE
				and system.tactical_role == WeaponSystemProfile.TacticalRole.ANTI_SHIP
			):
				continue
			found_weapon = true
			var distance: float = launcher.global_position.distance_to(target.global_position)
			if not system.is_in_range(distance):
				continue
			found_in_range = true
			if not launcher.is_position_in_mount_arc(system.mount_profile, target.global_position):
				continue
			found_in_arc = true
			if not _launcher_has_fire_control_solution(launcher, target):
				return "TIR BLOQUÉ: PISTE OU LIAISON INSUFFISANTE"
	if not found_weapon:
		return "TIR BLOQUÉ: AUCUNE ARME ANTINAVIRE"
	if not found_in_range:
		return "TIR BLOQUÉ: HORS PORTÉE OU DISTANCE MINIMALE"
	if not found_in_arc:
		return "TIR BLOQUÉ: CIBLE HORS ARC"
	return "TIR BLOQUÉ: RECHARGE, MUNITIONS OU SURCHAUFFE"


func _fire_railgun(launcher: TacticalUnitScene, target: TacticalUnitScene) -> bool:
	var system: WeaponSystemProfile = launcher.get_weapon_system(
		WeaponSystemProfile.Family.RAILGUN,
		WeaponSystemProfile.TacticalRole.KINETIC_STRIKE
	)
	if not launcher.can_fire_weapon_system(system, target.global_position):
		return false
	if not _launcher_has_fire_control_solution(launcher, target):
		return false
	var aim_point: Vector2 = _calculate_intercept_point(
		launcher.global_position,
		target.global_position,
		target.velocity,
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
	saturation: bool
) -> int:
	var targets: Array[TacticalUnitScene] = [target]
	return _launch_missile_salvo(launcher, targets, saturation, {"cursor": 0})


func _launch_missile_salvo(
	launcher: TacticalUnitScene,
	targets: Array[TacticalUnitScene],
	saturation: bool,
	allocation: Dictionary
) -> int:
	var eligible_targets: Array[TacticalUnitScene] = []
	var start_index: int = int(allocation.get("cursor", 0))
	for offset: int in targets.size():
		var target: TacticalUnitScene = targets[(start_index + offset) % targets.size()]
		if target.destroyed or not launcher.can_launch_weapon_at(target.global_position):
			continue
		if not _launcher_has_fire_control_solution(launcher, target) or not _is_target_in_missile_range(launcher, target):
			continue
		eligible_targets.append(target)
	if eligible_targets.is_empty():
		return 0
	var requested_count: int = launcher.get_anti_ship_burst_capacity() if saturation else 1
	if requested_count <= 0:
		return 0
	var missile_profile: MissileProfile = launcher.get_anti_ship_missile_profile()
	var launched_count: int = launcher.consume_anti_ship_missiles(eligible_targets[0].global_position, requested_count)
	for launch_index: int in launched_count:
		var assigned_target: TacticalUnitScene = eligible_targets[launch_index % eligible_targets.size()]
		var lane_slot: float = float(launch_index) - float(launched_count - 1) * 0.5
		var lane_direction: Vector2 = launcher.global_position.direction_to(assigned_target.global_position).rotated(PI * 0.5)
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
			missile_profile if missile_profile != null else MISSILE_PROFILE
		)
		missile.set_cruise_lane_offset(lane_offset)
		missile.set_visual_zoom(tactical_camera.zoom.x)
	allocation["cursor"] = start_index + launched_count
	missiles_launched[launcher.team_id] += launched_count
	_update_status()
	return launched_count


func _update_ai(delta: float) -> void:
	if weapons_demo:
		return
	ai_decision_remaining -= delta
	if ai_decision_remaining > 0.0:
		return
	ai_decision_remaining = MATCH_RULES.ai_decision_interval

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
			_execute_enemy_tactical_plan(launcher, target)
		elif DUEL_SANDBOX and target == null:
			var bandit_index: int = enemy_units.find(launcher)
			var approach_offset := Vector2(0.0, float(bandit_index - 1) * 90.0)
			launcher.set_move_target(Vector2(-250.0, 360.0) + approach_offset)


func _execute_enemy_tactical_plan(launcher: TacticalUnitScene, target: TacticalUnitScene) -> void:
	var plan: Dictionary = enemy_tactical_pilot.plan_engagement(launcher, target)
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
		_launch_missile_burst(launcher, target, bool(plan["saturation"]))


func _find_closest_tracked_target(launcher: TacticalUnitScene, candidates: Array[TacticalUnitScene]):
	var closest_target = null
	var closest_distance: float = INF
	var fire_control_providers: Array[TacticalUnitScene] = _get_fire_control_providers(launcher.team_id)
	for candidate: TacticalUnitScene in candidates:
		if candidate.destroyed or launcher.destroyed or launcher.team_id == candidate.team_id:
			continue
		if (
			_sensor_range_ratio_squared(launcher, candidate) > 0.68 * 0.68
			and not _providers_have_fire_control_solution(launcher, candidate, fire_control_providers)
		):
			continue
		var distance: float = launcher.global_position.distance_to(candidate.global_position)
		if distance < closest_distance:
			closest_target = candidate
			closest_distance = distance
	return closest_target


func _launcher_has_fire_control_solution(launcher: TacticalUnitScene, target: TacticalUnitScene) -> bool:
	if launcher.destroyed or target.destroyed or launcher.team_id == target.team_id:
		return false
	if _sensor_range_ratio_squared(launcher, target) <= 0.68 * 0.68:
		return true
	return _providers_have_fire_control_solution(
		launcher,
		target,
		_get_fire_control_providers(launcher.team_id)
	)


func _get_fire_control_providers(team_id: int) -> Array[TacticalUnitScene]:
	var providers: Array[TacticalUnitScene] = []
	var allies: Array[TacticalUnitScene] = friendly_units if team_id == 0 else enemy_units
	for provider: TacticalUnitScene in allies:
		if not provider.destroyed and provider.unit_profile.provides_fire_control:
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
		if launcher.global_position.distance_to(provider.global_position) > provider.unit_profile.fire_control_share_range:
			continue
		if _sensor_range_ratio_squared(provider, target) <= 0.68 * 0.68:
			return true
	return false


func _is_target_in_missile_range(launcher: TacticalUnitScene, target: TacticalUnitScene) -> bool:
	return (
		launcher.get_anti_ship_missile_range() > 0.0
		and launcher.global_position.distance_to(target.global_position) <= launcher.get_anti_ship_missile_range()
	)


func _get_connected_fire_control_provider(unit: TacticalUnitScene):
	var allies: Array[TacticalUnitScene] = friendly_units if unit.team_id == 0 else enemy_units
	for provider: TacticalUnitScene in allies:
		if provider.destroyed or not provider.unit_profile.provides_fire_control:
			continue
		if unit.global_position.distance_to(provider.global_position) <= provider.unit_profile.fire_control_share_range:
			return provider
	return null


func _update_missile_guidance() -> void:
	for missile in missiles_layer.get_children():
		if not missile.is_interceptable() or not is_instance_valid(missile.target):
			continue
		if missile.target is TacticalUnit:
			missile.target.trigger_combat_thermal_mode()
			missile.set_external_guidance(_team_has_track(missile.team_id, missile.target))
		elif missile.target is TacticalMissile:
			# Un intercepteur possède sa propre piste locale sur le missile poursuivi.
			missile.set_external_guidance(true)


func _team_has_track(observer_team_id: int, target: TacticalUnitScene) -> bool:
	if target.destroyed:
		return false
	if observer_team_id == 0 and target.team_id != 0:
		return target.intel_state >= TacticalUnitScene.IntelState.TRACKED

	var sensors: Array[TacticalUnitScene] = friendly_units if observer_team_id == 0 else enemy_units
	for sensor: TacticalUnitScene in sensors:
		if sensor.destroyed:
			continue
		if _sensor_range_ratio_squared(sensor, target) <= 0.68 * 0.68:
			return true
	if objective_station != null and objective_station.team_id == observer_team_id:
		if objective_station.global_position.distance_to(target.global_position) <= objective_station.sensor_range * target.get_thermal_signature() * 0.68:
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
		else target.get_thermal_signature()
	)
	var passive_range: float = sensor.sensor_range * thermal_signature
	var best_ratio_squared: float = distance_squared / maxf(passive_range * passive_range, 0.0001)
	if sensor.sensor_mode == TacticalUnitScene.SensorMode.ACTIVE:
		best_ratio_squared = minf(
			best_ratio_squared,
			distance_squared / maxf(sensor.active_sensor_range * sensor.active_sensor_range, 0.0001)
		)
	if target.sensor_mode == TacticalUnitScene.SensorMode.ACTIVE:
		best_ratio_squared = minf(
			best_ratio_squared,
			distance_squared / maxf(
				sensor.active_emission_detection_range * sensor.active_emission_detection_range,
				0.0001
			)
		)
	return best_ratio_squared


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
	selected_units = selected_units.filter(func(unit): return is_instance_valid(unit) and not unit.destroyed)


func _on_missile_impacted(_target: Node2D, missile_team_id: int) -> void:
	confirmed_impacts += 1
	missile_impacts[missile_team_id] += 1
	_update_status()


func _on_missile_finished(_missile: TacticalMissileScene) -> void:
	_update_status()


func _update_status() -> void:
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
	if not last_attack_feedback.is_empty():
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
		var network_text := "LIAISON —"
		var fire_control_provider = _get_connected_fire_control_provider(unit)
		if fire_control_provider == unit:
			network_text = "DIFFUSION TIR %.0f" % unit.unit_profile.fire_control_share_range
		elif fire_control_provider != null:
			network_text = "LIAISON TIR: %s" % fire_control_provider.callsign
		var route_text := "ROUTE —"
		if unit.is_returning_to_theater:
			route_text = "HORS SECTEUR • RETOUR AUTO"
		elif not unit.navigation_route.is_empty():
			route_text = "ROUTE %d  •  V.PROCH %.0f" % [
				unit.navigation_route.size(), unit.navigation_route[0].planned_speed,
			]
		selection_details_label.text = "%s  //  %s  //  %s  //  %s  •  COQUE %.0f/%.0f\nVIT %.0f/%.0f  •  ACC %.0f  •  ROT %.0f°/s  •  PROP. %s [%s]  •  PHASE %s  •  %s\nCAPT. %s %.0f  •  THERM. %s  •  CHALEUR %.0f/%.0f  •  IR %.2f\nPDC %.0f  MUN %d/%d  •  TIR %.0f  •  TUBES %d/%d  CHARGE %d  •  MISSILES %d/%d  (%s)\nARMES: %s" % [
			unit.callsign, unit.unit_profile.tactical_role, unit.unit_profile.display_name, crew_text,
			unit.hull, unit.maximum_hull,
			unit.velocity.length(), unit.move_speed, unit.maximum_acceleration,
			rad_to_deg(unit.maximum_angular_speed), propulsion_name, unit.get_propulsion_doctrine_name(), unit.get_maneuver_phase_name(), route_text,
			unit.get_sensor_mode_name(), unit.sensor_range,
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
