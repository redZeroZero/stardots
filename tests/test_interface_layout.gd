extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = resolution
		root.add_child(viewport)
		var battlefield = load("res://scenes/main.tscn").instantiate()
		battlefield.weapons_demo = true
		viewport.add_child(battlefield)
		battlefield.set_process(false)
		battlefield.set_physics_process(false)
		await process_frame
		_validate_layout(battlefield, resolution, failures)
		if resolution == Vector2i(1280, 720):
			var selected_unit: TacticalUnit = battlefield.friendly_units[0]
			battlefield.selection_state.select_unit(selected_unit)
			var selection_revision: int = battlefield.selection_state.revision
			battlefield.window_mode_controller.current_mode = TacticalWindowModeController.UserMode.BORDERLESS
			battlefield._cycle_window_mode()
			if battlefield.window_mode_controller.current_mode != TacticalWindowModeController.UserMode.EXCLUSIVE_FULLSCREEN:
				failures.append("F11 ne parcourt pas les modes de fenêtre dans l'ordre attendu")
			if battlefield.selection_state.revision != selection_revision or battlefield.selected_units != [selected_unit]:
				failures.append("le changement de mode fenêtre altère la sélection")
			if not battlefield.secondary_info.visible:
				battlefield._toggle_secondary_info()
			if not battlefield.find_child("Scope", true, false).text.contains("AIDE ALPHA"):
				failures.append("l'aide alpha repliable n'explique pas les commandes principales")
			battlefield._toggle_event_log()
			if not battlefield.event_log_margin.visible or not battlefield.event_log_label.text.contains("JOURNAL TACTIQUE"):
				failures.append("le journal tactique ne se replie ou ne s'affiche pas correctement")
			if battlefield.event_log_margin.get_global_rect().intersects(battlefield.selection_dock.get_global_rect()):
				failures.append("le journal tactique chevauche le dock de sélection (%s / %s)" % [battlefield.event_log_margin.get_global_rect(), battlefield.selection_dock.get_global_rect()])
		viewport.free()
	if int(ProjectSettings.get_setting("display/window/size/mode", -1)) != 3:
		failures.append("le plein écran fenêtré n'est pas le mode alpha par défaut")
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Interface validée : cadre compact à 720p/1080p et modes fenêtre sans perte de sélection.")
	quit(0)


func _validate_layout(battlefield, resolution: Vector2i, failures: Array[String]) -> void:
	var viewport_rect: Rect2 = battlefield.get_viewport_rect()
	for button_name: String in [
		"CutEnginesButton",
		"AttackModeButton",
		"SensorModeButton",
		"ThermalModeButton",
		"WeaponSelectButton",
		"FireDoctrineButton",
	]:
		var button: Button = battlefield.find_child(button_name, true, false)
		if button == null or not button.is_visible_in_tree():
			failures.append("le contrôle %s n'est pas visible" % button_name)
			continue
		var button_rect: Rect2 = button.get_global_rect()
		if not viewport_rect.encloses(button_rect):
			failures.append("le contrôle %s déborde en %dx%d" % [button_name, resolution.x, resolution.y])
	var selection_rect: Rect2 = battlefield.selection_dock.get_global_rect()
	if selection_rect.size.y > 200.0:
		failures.append("le panneau de sélection mesure %.0f px en %dx%d" % [selection_rect.size.y, resolution.x, resolution.y])
	var bottom_band: Panel = battlefield.get_node("Interface/BottomHudBand")
	var bottom_band_rect: Rect2 = bottom_band.get_global_rect()
	if not viewport_rect.encloses(bottom_band_rect) or bottom_band_rect.position.y > selection_rect.position.y:
		failures.append("la base IHM inférieure ne réserve pas une zone distincte de la carte en %dx%d" % [resolution.x, resolution.y])
	var top_rect: Rect2 = battlefield.top_margin.get_global_rect()
	var free_map_height: float = selection_rect.position.y - top_rect.end.y
	if free_map_height < float(resolution.y) * 0.64:
		failures.append("la carte libre mesure %.0f px en %dx%d" % [free_map_height, resolution.x, resolution.y])
	var minimap_rect: Rect2 = battlefield.tactical_minimap.get_global_rect()
	if not viewport_rect.encloses(minimap_rect) or minimap_rect.size.x < 160.0:
		failures.append("la minimap devient inaccessible ou décorative en %dx%d" % [resolution.x, resolution.y])
	var task_force_rect: Rect2 = battlefield.task_force_bar_margin.get_global_rect()
	if not viewport_rect.encloses(task_force_rect) or task_force_rect.intersects(battlefield.top_margin.get_global_rect()):
		failures.append("la barre TF chevauche le bandeau supérieur en %dx%d" % [resolution.x, resolution.y])
	var alert_rect: Rect2 = battlefield.get_node("Interface/AlertMargin").get_global_rect()
	if not viewport_rect.encloses(alert_rect):
		failures.append("la bande d'alertes sort de la fenêtre en %dx%d" % [resolution.x, resolution.y])
	if not battlefield.telemetry_label.text.contains("DONNÉES ARMEMENT INCONNUES"):
		failures.append("la télémétrie révèle des détails d'armement rouge non accessibles")
