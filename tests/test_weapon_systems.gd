extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")
const MISSILE_PROFILE: MissileProfile = preload("res://data/balance/default_missile.tres")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_laser_pdc(failures)
	_test_short_interceptor(failures)
	_test_railgun(failures)
	_test_fixed_cells(failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Systèmes d'armes validés : laser PDC, intercepteur court, railgun et cellules fixes.")
	quit(0)


func _empty_battle():
	var battle = BATTLE_SCENE.instantiate()
	battle.benchmark_empty_scenario = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	return battle


func _unit_profile_with(system: WeaponSystemProfile) -> UnitProfile:
	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	profile.weapon_system_profiles = [system]
	profile.missile_capacity = 0
	profile.missile_launcher_count = 0
	return profile


func _test_laser_pdc(failures: Array[String]) -> void:
	var battle = _empty_battle()
	var laser: WeaponSystemProfile = load("res://data/weapons/laser_pdc.tres")
	var defender: TacticalUnit = battle._spawn_unit("LASER", 0, Vector2.ZERO, _unit_profile_with(laser))
	var target_unit: TacticalUnit = battle._spawn_unit("CIBLE", 0, Vector2.ZERO, _unit_profile_with(laser))
	var hostile := TacticalMissile.new()
	battle.missiles_layer.add_child(hostile)
	hostile.launch(Vector2(0.0, -100.0), target_unit, 1, MISSILE_PROFILE)
	hostile.set_physics_process(false)
	var integrity_before: float = hostile.integrity
	battle._update_point_defense(0.05)
	if hostile.integrity >= integrity_before:
		failures.append("le PDC laser n'endommage pas un missile dans son arc")
	if defender.heat <= defender.unit_profile.initial_heat:
		failures.append("le PDC laser ne produit pas de chaleur")
	battle.free()


func _test_short_interceptor(failures: Array[String]) -> void:
	var battle = _empty_battle()
	var interceptor_system: WeaponSystemProfile = load("res://data/weapons/short_interceptor_launcher.tres")
	var defender: TacticalUnit = battle._spawn_unit("INTERCEPTEUR", 0, Vector2.ZERO, _unit_profile_with(interceptor_system))
	var target_unit: TacticalUnit = battle._spawn_unit("CIBLE", 0, Vector2.ZERO, _unit_profile_with(interceptor_system))
	var hostile := TacticalMissile.new()
	battle.missiles_layer.add_child(hostile)
	hostile.launch(Vector2(0.0, -200.0), target_unit, 1, MISSILE_PROFILE)
	hostile.set_physics_process(false)
	var ammunition_before: int = defender.get_weapon_system_ammunition(interceptor_system)
	battle._update_point_defense(0.05)
	if battle.missiles_layer.get_child_count() < 2:
		failures.append("le lanceur court ne crée pas de missile intercepteur")
	battle._update_missile_guidance()
	for missile in battle.missiles_layer.get_children():
		if missile.team_id == defender.team_id and missile.target is TacticalMissile and not missile.external_guidance_available:
			failures.append("le missile intercepteur perd le guidage sur une cible missile")
	if defender.get_weapon_system_ammunition(interceptor_system) != ammunition_before - 1:
		failures.append("le missile intercepteur ne consomme pas sa munition")
	battle.free()


func _test_railgun(failures: Array[String]) -> void:
	var battle = _empty_battle()
	var railgun: WeaponSystemProfile = load("res://data/weapons/medium_railgun.tres")
	var launcher: TacticalUnit = battle._spawn_unit("RAIL", 0, Vector2.ZERO, _unit_profile_with(railgun))
	var target: TacticalUnit = battle._spawn_unit("CIBLE", 1, Vector2(0.0, -200.0), _unit_profile_with(railgun))
	target.set_intel_state(TacticalUnit.IntelState.TRACKED)
	launcher.rotation = 0.0
	if not battle._fire_railgun(launcher, target):
		failures.append("le railgun axial refuse une cible valide dans son arc")
	if battle.pdc_projectiles_layer.get_child_count() != 1:
		failures.append("le railgun ne crée pas son projectile cinétique")
	battle.free()


func _test_fixed_cells(failures: Array[String]) -> void:
	var cells: WeaponSystemProfile = load("res://data/weapons/medium_missile_cells.tres")
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("ARSENAL", 0, Vector2.ZERO, _unit_profile_with(cells))
	var ammunition_before: int = unit.get_weapon_system_ammunition(cells)
	if not unit.can_launch_weapon_at(Vector2(0.0, -500.0)):
		failures.append("une cellule fixe prête refuse une cible valide")
	else:
		unit.mark_anti_ship_missile_launched(Vector2(0.0, -500.0))
		if unit.get_weapon_system_ammunition(cells) != ammunition_before - 1:
			failures.append("une cellule fixe ne devient pas indisponible après lancement")
	unit.free()
