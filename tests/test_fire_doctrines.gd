extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var economy_shots: int = _fire_demo_doctrine(0)
	var salvo_shots: int = _fire_demo_doctrine(1)
	var saturation_shots: int = _fire_demo_doctrine(2)
	if economy_shots != 1:
		failures.append("la doctrine économie ne limite pas l'ordre à un seul tir")
	if salvo_shots != 2:
		failures.append("la doctrine salve ne produit pas un tir par bâtiment disponible")
	if saturation_shots != 10:
		failures.append("la saturation ne vide pas les deux tubes et les huit cellules prêts")
	if _fire_railgun_selection() != 1:
		failures.append("la sélection railgun ne filtre pas correctement les missiles")
	_test_turret_traverse(failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Conduite de tir validée : économie, salve, saturation et pointage de tourelle.")
	quit(0)


func _fire_demo_doctrine(doctrine: int) -> int:
	var battlefield = load("res://scenes/main.tscn").instantiate()
	battlefield.weapons_demo = true
	root.add_child(battlefield)
	battlefield.set_process(false)
	battlefield.set_physics_process(false)
	for unit: TacticalUnit in battlefield.selected_units:
		unit.set_selected(false)
	battlefield.selected_units.clear()
	battlefield.selected_units.append(battlefield.friendly_units[1])
	battlefield.selected_units.append(battlefield.friendly_units[3])
	for unit: TacticalUnit in battlefield.selected_units:
		unit.set_selected(true)
	battlefield.offensive_weapon_selection = 1
	battlefield.fire_doctrine = doctrine
	var target: TacticalUnit = battlefield.enemy_units[1]
	var shots: int = battlefield._issue_attack_zone(target.global_position)
	battlefield.free()
	return shots


func _test_turret_traverse(failures: Array[String]) -> void:
	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	var laser: WeaponSystemProfile = load("res://data/weapons/laser_pdc.tres")
	profile.weapon_system_profiles = [laser]
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("TOURELLE", 0, Vector2.ZERO, profile)
	unit.rotation = 0.0
	var side_target := Vector2(100.0, 0.0)
	if unit.can_fire_weapon_system(laser, side_target):
		failures.append("une tourelle tire instantanément à 90 degrés sans pointer")
	unit._physics_process(0.5)
	if unit.is_weapon_system_aligned(laser, side_target):
		failures.append("la tourelle atteint 90 degrés avant son temps de rotation")
	unit._physics_process(0.5)
	if not unit.is_weapon_system_aligned(laser, side_target):
		failures.append("la tourelle n'atteint pas sa cible après son temps de rotation")
	unit.free()


func _fire_railgun_selection() -> int:
	var battlefield = load("res://scenes/main.tscn").instantiate()
	battlefield.weapons_demo = true
	root.add_child(battlefield)
	battlefield.set_process(false)
	battlefield.set_physics_process(false)
	for unit: TacticalUnit in battlefield.selected_units:
		unit.set_selected(false)
	battlefield.selected_units.clear()
	battlefield.selected_units.append(battlefield.friendly_units[2])
	battlefield.offensive_weapon_selection = 2
	battlefield.fire_doctrine = 1
	var shots: int = battlefield._issue_attack_zone(battlefield.enemy_units[2].global_position)
	battlefield.free()
	return shots
