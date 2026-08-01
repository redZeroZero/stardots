extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("SYSTEMS", 0, Vector2.ZERO, profile)
	var failures: Array[String] = []

	unit.velocity = Vector2(40.0, 0.0)
	unit.set_move_target(Vector2(500.0, 0.0))
	unit.cut_engines()
	var position_before_drift: Vector2 = unit.global_position
	unit._physics_process(1.0)
	if unit.has_move_target or unit.navigation_route.size() > 0:
		failures.append("couper les moteurs ne supprime pas le plan de poussée")
	if unit.velocity != Vector2(40.0, 0.0) or unit.global_position.distance_to(position_before_drift) < 39.0:
		failures.append("couper les moteurs ne conserve pas la dérive")

	unit.velocity = Vector2.ZERO
	unit.heat = 30.0
	var passive_signature: float = unit.get_thermal_signature()
	unit.toggle_sensor_mode()
	unit._update_thermal_state(1.0)
	if unit.sensor_mode != TacticalUnit.SensorMode.ACTIVE or unit.heat <= 30.0:
		failures.append("le capteur actif ne produit pas de chaleur")
	if unit.active_emission_detection_range <= unit.sensor_range or unit.get_thermal_signature() < passive_signature:
		failures.append("le mode actif ne possède pas une signature détectable cohérente")

	var silent_unit := TacticalUnit.new()
	var combat_unit := TacticalUnit.new()
	root.add_child(silent_unit)
	root.add_child(combat_unit)
	silent_unit.configure("SILENT", 0, Vector2.ZERO, profile)
	combat_unit.configure("COMBAT", 0, Vector2.ZERO, profile)
	silent_unit.heat = 80.0
	combat_unit.heat = 80.0
	silent_unit.thermal_mode = TacticalUnit.ThermalMode.SILENT
	combat_unit.thermal_mode = TacticalUnit.ThermalMode.COMBAT
	silent_unit._update_thermal_state(1.0)
	combat_unit._update_thermal_state(1.0)
	if combat_unit.heat >= silent_unit.heat:
		failures.append("le mode combat ne refroidit pas plus vite que le mode silencieux")
	if combat_unit.get_thermal_signature() <= silent_unit.get_thermal_signature():
		failures.append("le refroidissement combat n'augmente pas la signature rayonnée")

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Systèmes validés : dérive, radar actif et régimes thermiques.")
	quit(0)
