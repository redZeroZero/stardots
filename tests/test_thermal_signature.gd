extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("THERMAL", 0, Vector2.ZERO, profile)
	var failures: Array[String] = []
	var initial_heat: float = unit.heat
	var initial_signature: float = unit.get_thermal_signature()
	if not is_equal_approx(unit.get_passive_detection_signature(), 1.0):
		failures.append("une coque au régime initial ne reste pas à la portée passive nominale")

	unit.heat = unit.heat_capacity
	unit.thermal_mode = TacticalUnit.ThermalMode.NORMAL
	unit.engine_signature_activity = 0.0
	if not is_equal_approx(unit.get_passive_detection_signature(), 2.0):
		failures.append("une coque très chaude n'atteint pas le double de la portée passive")
	unit.thermal_mode = TacticalUnit.ThermalMode.COMBAT
	if unit.get_passive_detection_signature() <= 2.0:
		failures.append("les radiateurs de combat n'étendent pas la signature d'une coque chaude")
	unit.engine_signature_activity = 1.0
	if not is_equal_approx(unit.get_passive_detection_signature(), 2.5):
		failures.append("la pointe thermique ne plafonne pas à deux fois et demie la portée passive")
	unit.heat = initial_heat
	unit.thermal_mode = TacticalUnit.ThermalMode.NORMAL
	unit.engine_signature_activity = 0.0

	unit.set_move_target(Vector2(500.0, 0.0))
	for frame: int in 120:
		unit._physics_process(1.0 / 60.0)
	if unit.heat <= initial_heat or unit.get_thermal_signature() <= initial_signature:
		failures.append("une poussée soutenue n'augmente pas chaleur et signature")

	var heat_before_launch: float = unit.heat
	unit.mark_weapon_launched()
	if unit.heat <= heat_before_launch:
		failures.append("un lancement de missile ne produit pas de chaleur")

	unit.heat = unit.heat_capacity
	if unit.can_launch_weapon() or unit.can_fire_point_defense():
		failures.append("la sécurité thermique ne bloque pas les armes")
	unit.velocity = Vector2.ZERO
	unit.has_move_target = false
	unit.navigation_route.clear()
	unit._update_thermal_state(10.0)
	if unit.heat >= unit.heat_capacity or unit.is_weapons_overheated():
		failures.append("un bâtiment au repos ne refroidit pas")

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Thermique validée : propulsion, signature, armement, sécurité et refroidissement.")
	quit(0)
