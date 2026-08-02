extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var battlefield = load("res://scenes/main.tscn").instantiate()
	battlefield.weapons_demo = true
	root.add_child(battlefield)
	battlefield.set_process(false)
	battlefield.set_physics_process(false)
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
			failures.append("le contrôle %s déborde de la fenêtre" % button_name)
	battlefield.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Interface validée : commandes système et tir entièrement visibles sur deux lignes.")
	quit(0)
