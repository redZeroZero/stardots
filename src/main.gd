extends Node2D

const TacticalUnitScene := preload("res://src/tactical_unit.gd")
const TacticalMissileScene := preload("res://src/tactical_missile.gd")
const PdcProjectileScene := preload("res://src/pdc_projectile.gd")
const StrategicStationScene := preload("res://src/strategic_station.gd")
const UNIT_PROFILE: UnitProfile = preload("res://data/balance/default_unit.tres")
const AWACS_PROFILE: UnitProfile = preload("res://data/balance/awacs_unit.tres")
const MISSILE_PROFILE: MissileProfile = preload("res://data/balance/default_missile.tres")
const MATCH_RULES: MatchRules = preload("res://data/balance/match_rules.tres")
const GRID_SPACING: float = 64.0
const CAMERA_SPEED: float = 620.0
const EDGE_SCROLL_MARGIN: float = 18.0
const ATTACK_ZONE_RADIUS: float = 180.0
const ATTACK_ZONE_DISPLAY_DURATION: float = 1.6
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
var confirmed_impacts: int = 0
var missiles_launched: Array[int] = [0, 0]
var missile_impacts: Array[int] = [0, 0]
var missile_interceptions: Array[int] = [0, 0]
var ai_decision_remaining: float = 1.8
var objective_station: StrategicStationScene
var team_hold_time: Array[float] = [0.0, 0.0]
var match_over: bool = false

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
@onready var sensor_mode_button: Button = %SensorModeButton
@onready var thermal_mode_button: Button = %ThermalModeButton
@onready var restart_button: Button = %RestartButton
@onready var info_button: Button = %InfoButton
@onready var secondary_info: PanelContainer = %SecondaryInfo
@onready var victory_label: Label = %VictoryLabel
@onready var tactical_minimap: TacticalMinimap = %TacticalMinimap


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	restart_button.pressed.connect(_restart_match)
	info_button.pressed.connect(_toggle_secondary_info)
	cut_engines_button.pressed.connect(_cut_selected_engines)
	attack_mode_button.pressed.connect(_toggle_attack_command)
	sensor_mode_button.pressed.connect(_toggle_selected_sensors)
	tactical_minimap.bind(self, WORLD_RECT)
	_spawn_demo_units()
	if DUEL_SANDBOX:
		objective_label.text = "SCÉNARIO: VEILLE DÉPORTÉE"
	else:
		_spawn_objective_station()
	_update_status()
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


func _process(delta: float) -> void:
	if attack_zone_display_remaining > 0.0:
		attack_zone_display_remaining = maxf(0.0, attack_zone_display_remaining - delta)
		queue_redraw()
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
	_update_sensor_picture()
	_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_X:
			_cut_selected_engines()
		elif event.keycode == KEY_A:
			_arm_attack_command()
		elif event.keycode == KEY_S:
			_toggle_selected_sensors()
		elif event.keycode == KEY_I:
			_toggle_secondary_info()
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
		_set_camera_zoom(tactical_camera.zoom.x * 1.12)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_set_camera_zoom(tactical_camera.zoom.x / 1.12)


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
	var clamped_zoom := clampf(value, MIN_ZOOM, MAX_ZOOM)
	tactical_camera.zoom = Vector2.ONE * clamped_zoom
	_clamp_camera_to_world()


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
	if DUEL_SANDBOX:
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


func _spawn_unit(callsign: String, team_id: int, start_position: Vector2, profile: UnitProfile) -> TacticalUnitScene:
	var unit := TacticalUnitScene.new() as TacticalUnitScene
	unit.configure(callsign, team_id, start_position, profile)
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
		var best_range_ratio: float = INF
		for friendly: TacticalUnitScene in friendly_units:
			if friendly.destroyed:
				continue
			best_range_ratio = minf(best_range_ratio, _sensor_range_ratio(friendly, enemy))
		if objective_station != null and objective_station.team_id == 0:
			var station_distance: float = objective_station.global_position.distance_to(enemy.global_position)
			best_range_ratio = minf(best_range_ratio, station_distance / (objective_station.sensor_range * enemy.get_thermal_signature()))

		var new_state: TacticalUnitScene.IntelState = TacticalUnitScene.IntelState.HIDDEN
		var uncertainty := Vector2.ZERO
		if best_range_ratio <= 0.36:
			new_state = TacticalUnitScene.IntelState.IDENTIFIED
			identified_count += 1
		elif best_range_ratio <= 0.68:
			new_state = TacticalUnitScene.IntelState.TRACKED
			tracked_count += 1
		elif best_range_ratio <= 1.0:
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
	for launcher: TacticalUnitScene in selected_units:
		for target: TacticalUnitScene in candidates:
			if _launch_missile(launcher, target):
				shots_fired += 1
				break
	attack_zone_has_solution = shots_fired > 0
	_update_status()
	queue_redraw()
	return shots_fired


func _launch_missile(launcher: TacticalUnitScene, target: TacticalUnitScene) -> bool:
	if not launcher.can_launch_weapon() or target.destroyed:
		return false
	if not _launcher_has_fire_control_solution(launcher, target) or not _is_target_in_missile_range(launcher, target):
		return false
	var missile := TacticalMissileScene.new() as TacticalMissileScene
	missiles_layer.add_child(missile)
	missile.impacted.connect(_on_missile_impacted.bind(launcher.team_id))
	missile.detonated.connect(_on_missile_detonated)
	missile.finished.connect(_on_missile_finished)
	missile.launch(launcher.global_position, target, launcher.team_id, MISSILE_PROFILE)
	launcher.mark_weapon_launched()
	missiles_launched[launcher.team_id] += 1
	_update_status()
	return true


func _update_ai(delta: float) -> void:
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
		elif DUEL_SANDBOX and target == null:
			var bandit_index: int = enemy_units.find(launcher)
			var approach_offset := Vector2(0.0, float(bandit_index - 1) * 90.0)
			launcher.set_move_target(Vector2(-250.0, 360.0) + approach_offset)
		if not launcher.can_launch_weapon():
			continue
		target = _find_closest_tracked_target(launcher, friendly_units)
		if target != null:
			_launch_missile(launcher, target)


func _find_closest_tracked_target(launcher: TacticalUnitScene, candidates: Array[TacticalUnitScene]):
	var closest_target = null
	var closest_distance: float = INF
	for candidate: TacticalUnitScene in candidates:
		if candidate.destroyed or not _launcher_has_fire_control_solution(launcher, candidate):
			continue
		var distance: float = launcher.global_position.distance_to(candidate.global_position)
		if distance < closest_distance:
			closest_target = candidate
			closest_distance = distance
	return closest_target


func _launcher_has_fire_control_solution(launcher: TacticalUnitScene, target: TacticalUnitScene) -> bool:
	if launcher.destroyed or target.destroyed or launcher.team_id == target.team_id:
		return false
	if _sensor_range_ratio(launcher, target) <= 0.68:
		return true
	var allies: Array[TacticalUnitScene] = friendly_units if launcher.team_id == 0 else enemy_units
	for provider: TacticalUnitScene in allies:
		if provider == launcher or provider.destroyed or not provider.unit_profile.provides_fire_control:
			continue
		if launcher.global_position.distance_to(provider.global_position) > provider.unit_profile.fire_control_share_range:
			continue
		if _sensor_range_ratio(provider, target) <= 0.68:
			return true
	return false


func _is_target_in_missile_range(launcher: TacticalUnitScene, target: TacticalUnitScene) -> bool:
	return (
		launcher.unit_profile.missile_launch_range > 0.0
		and launcher.global_position.distance_to(target.global_position) <= launcher.unit_profile.missile_launch_range
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
		if missile.target is TacticalUnitScene:
			missile.target.trigger_combat_thermal_mode()
		missile.set_external_guidance(_team_has_track(missile.team_id, missile.target))


func _team_has_track(observer_team_id: int, target: TacticalUnitScene) -> bool:
	if target.destroyed:
		return false
	if observer_team_id == 0 and target.team_id != 0:
		return target.intel_state >= TacticalUnitScene.IntelState.TRACKED

	var sensors: Array[TacticalUnitScene] = friendly_units if observer_team_id == 0 else enemy_units
	for sensor: TacticalUnitScene in sensors:
		if sensor.destroyed:
			continue
		if _sensor_range_ratio(sensor, target) <= 0.68:
			return true
	if objective_station != null and objective_station.team_id == observer_team_id:
		if objective_station.global_position.distance_to(target.global_position) <= objective_station.sensor_range * target.get_thermal_signature() * 0.68:
			return true
	return false


func _sensor_range_ratio(sensor: TacticalUnitScene, target: TacticalUnitScene) -> float:
	var distance: float = sensor.global_position.distance_to(target.global_position)
	var best_ratio: float = distance / (sensor.sensor_range * target.get_thermal_signature())
	if sensor.sensor_mode == TacticalUnitScene.SensorMode.ACTIVE:
		best_ratio = minf(best_ratio, distance / sensor.active_sensor_range)
	if target.sensor_mode == TacticalUnitScene.SensorMode.ACTIVE:
		best_ratio = minf(best_ratio, distance / sensor.active_emission_detection_range)
	return best_ratio


func _update_point_defense(delta: float) -> void:
	var _unused_delta := delta
	var missiles := missiles_layer.get_children()
	if missiles.is_empty():
		return

	var defenders: Array = friendly_units + enemy_units
	for defender in defenders:
		if not is_instance_valid(defender) or not defender.can_fire_point_defense():
			continue
		var nearest_missile = null
		var nearest_distance: float = INF
		for missile in missiles:
			if not is_instance_valid(missile) or not missile.is_interceptable():
				continue
			if missile.team_id == defender.team_id:
				continue
			var distance: float = defender.global_position.distance_to(missile.global_position)
			if distance <= defender.point_defense_range and distance < nearest_distance:
				nearest_missile = missile
				nearest_distance = distance
		if nearest_missile != null:
			_fire_point_defense_burst(defender, nearest_missile)


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
		selection_details_label.text = "%s  //  %s  //  %s  //  %s  •  COQUE %.0f/%.0f\nVIT %.0f/%.0f  •  ACC %.0f  •  ROT %.0f°/s  •  %s\nCAPT. %s %.0f  •  THERM. %s  •  CHALEUR %.0f/%.0f  •  IR %.2f\nPDC %.0f  MUN %d/%d  •  TIR %.0f  •  TUBES %d/%d  CHARGE %d  •  MISSILES %d/%d  (%s)" % [
			unit.callsign, unit.unit_profile.tactical_role, unit.unit_profile.display_name, crew_text,
			unit.hull, unit.maximum_hull,
			unit.velocity.length(), unit.move_speed, unit.maximum_acceleration,
			rad_to_deg(unit.maximum_angular_speed), route_text,
			unit.get_sensor_mode_name(), unit.sensor_range,
			unit.get_thermal_mode_name(), unit.heat, unit.heat_capacity, unit.get_thermal_signature(),
			unit.point_defense_range, unit.point_defense_ammunition, unit.point_defense_ammunition_capacity,
			unit.unit_profile.missile_launch_range,
			unit.get_ready_launcher_count(), unit.missile_launcher_count,
			unit.get_loading_launcher_count(), unit.missiles_remaining, unit.missile_capacity, reload_text,
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

	var x: float = WORLD_RECT.position.x
	while x <= WORLD_RECT.end.x:
		draw_line(Vector2(x, WORLD_RECT.position.y), Vector2(x, WORLD_RECT.end.y), GRID_COLOR)
		x += GRID_SPACING

	var y: float = WORLD_RECT.position.y
	while y <= WORLD_RECT.end.y:
		draw_line(Vector2(WORLD_RECT.position.x, y), Vector2(WORLD_RECT.end.x, y), GRID_COLOR)
		y += GRID_SPACING

	var edge_width: float = 32.0
	draw_rect(Rect2(WORLD_RECT.position, Vector2(WORLD_RECT.size.x, edge_width)), WORLD_EDGE_FILL)
	draw_rect(Rect2(Vector2(WORLD_RECT.position.x, WORLD_RECT.end.y - edge_width), Vector2(WORLD_RECT.size.x, edge_width)), WORLD_EDGE_FILL)
	draw_rect(Rect2(WORLD_RECT.position, Vector2(edge_width, WORLD_RECT.size.y)), WORLD_EDGE_FILL)
	draw_rect(Rect2(Vector2(WORLD_RECT.end.x - edge_width, WORLD_RECT.position.y), Vector2(edge_width, WORLD_RECT.size.y)), WORLD_EDGE_FILL)
	draw_rect(WORLD_RECT, WORLD_BORDER_COLOR, false, 4.0)

	if is_selecting:
		var selection_rect := Rect2(selection_start, selection_end - selection_start).abs()
		draw_rect(selection_rect, SELECTION_FILL, true)
		draw_rect(selection_rect, SELECTION_BORDER, false, 1.5)
	if is_defining_move_order:
		var order_color := Color("8dffaf") if move_order_fly_through else Color("9bf0ff")
		draw_circle(move_order_start, 7.0, Color(order_color, 0.18))
		draw_arc(move_order_start, 7.0, 0.0, TAU, 20, order_color, 2.0)
		if move_order_end.distance_to(move_order_start) >= 12.0 and not move_order_fly_through:
			draw_line(move_order_start, move_order_end, order_color, 2.0)
			var direction := move_order_start.direction_to(move_order_end)
			var arrow_base := move_order_end - direction * 8.0
			draw_line(move_order_end, arrow_base + direction.rotated(PI * 0.5) * 4.0, order_color, 2.0)
			draw_line(move_order_end, arrow_base - direction.rotated(PI * 0.5) * 4.0, order_color, 2.0)
	if attack_zone_display_remaining > 0.0:
		var attack_color := Color("8dffaf") if attack_zone_has_solution else Color("ffbd48")
		var alpha: float = attack_zone_display_remaining / ATTACK_ZONE_DISPLAY_DURATION
		draw_circle(attack_zone_center, ATTACK_ZONE_RADIUS, Color(attack_color, 0.05 * alpha))
		draw_arc(attack_zone_center, ATTACK_ZONE_RADIUS, 0.0, TAU, 96, Color(attack_color, 0.85 * alpha), 2.0)
		draw_line(attack_zone_center + Vector2(-12.0, 0.0), attack_zone_center + Vector2(12.0, 0.0), attack_color, 2.0)
		draw_line(attack_zone_center + Vector2(0.0, -12.0), attack_zone_center + Vector2(0.0, 12.0), attack_color, 2.0)
