extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	profile.combat_mode_hold_time = 2.0
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("AUTO-THERMAL", 0, Vector2.ZERO, profile)
	var failures: Array[String] = []

	unit._update_automatic_thermal_mode(0.1)
	if unit.thermal_mode != TacticalUnit.ThermalMode.SILENT:
		failures.append("un bâtiment immobile ne passe pas automatiquement en silencieux")
	unit.set_move_target(Vector2(500.0, 0.0))
	unit._update_automatic_thermal_mode(0.1)
	if unit.thermal_mode != TacticalUnit.ThermalMode.NORMAL:
		failures.append("un ordre de poussée ne passe pas automatiquement en régime normal")
	unit.trigger_combat_thermal_mode()
	unit._update_automatic_thermal_mode(1.0)
	if unit.thermal_mode != TacticalUnit.ThermalMode.COMBAT:
		failures.append("une alerte d'engagement ne maintient pas le régime combat")
	unit.cut_engines()
	unit.velocity = Vector2.ZERO
	unit._update_automatic_thermal_mode(1.1)
	if unit.thermal_mode != TacticalUnit.ThermalMode.SILENT:
		failures.append("le bâtiment ne revient pas en silencieux après la fin de l'alerte")

	unit.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Thermique automatique validée : arrêt silencieux, mouvement normal et engagement combat.")
	quit(0)
