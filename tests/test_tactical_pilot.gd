extends SceneTree

const BATTLE_SCENE: PackedScene = preload("res://scenes/main.tscn")
const PILOT_SCRIPT := preload("res://src/ai/tactical_pilot.gd")
const PILOT_PROFILE: Resource = preload("res://data/ai/default_tactical_pilot.tres")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_axial_weapon_plan(failures)
	_test_omnidirectional_weapon_plan(failures)
	_test_enemy_only_integration(failures)
	_test_ai_demo(failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Pilote tactique validé : portée, cap, arcs, profil et activation IA uniquement.")
	quit(0)


func _profile_with(system: WeaponSystemProfile) -> UnitProfile:
	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	profile.weapon_system_profiles = [system]
	profile.missile_capacity = 0
	profile.missile_launcher_count = 0
	return profile


func _unit(callsign: String, team_id: int, position: Vector2, profile: UnitProfile) -> TacticalUnit:
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure(callsign, team_id, position, profile)
	return unit


func _test_axial_weapon_plan(failures: Array[String]) -> void:
	var railgun: WeaponSystemProfile = load("res://data/weapons/medium_railgun.tres")
	var launcher: TacticalUnit = _unit("RAIL", 1, Vector2.ZERO, _profile_with(railgun))
	var target: TacticalUnit = _unit("CIBLE", 0, Vector2(800.0, 0.0), _profile_with(railgun))
	launcher.rotation = 0.0
	var pilot = PILOT_SCRIPT.new(PILOT_PROFILE)
	var plan: Dictionary = pilot.plan_engagement(launcher, target)
	if plan.is_empty() or not bool(plan["maneuver_required"]):
		failures.append("le railgun axial ne planifie pas son approche et son alignement")
	elif absf(float(plan["desired_heading"]) - PI * 0.5) > 0.01:
		failures.append("le pilote ne tourne pas la proue du railgun vers la cible")
	elif Vector2(plan["maneuver_point"]).distance_to(target.global_position) >= 650.0:
		failures.append("le point d'approche du railgun reste hors de portée")
	launcher.free()
	target.free()


func _test_omnidirectional_weapon_plan(failures: Array[String]) -> void:
	var missiles: WeaponSystemProfile = load("res://data/weapons/medium_missile_tubes.tres")
	var launcher_profile: UnitProfile = _profile_with(missiles)
	launcher_profile.missile_capacity = 6
	launcher_profile.missile_launcher_count = 2
	var launcher: TacticalUnit = _unit("VLS", 1, Vector2.ZERO, launcher_profile)
	var target: TacticalUnit = _unit("CIBLE", 0, Vector2(0.0, -650.0), _profile_with(missiles))
	launcher.rotation = PI
	var pilot = PILOT_SCRIPT.new(PILOT_PROFILE)
	var plan: Dictionary = pilot.plan_engagement(launcher, target)
	if bool(plan.get("maneuver_required", true)):
		failures.append("un VLS omnidirectionnel exige inutilement d'aligner la coque")
	if not bool(plan.get("should_fire", false)):
		failures.append("un VLS prêt et à sa portée préférée ne reçoit pas l'autorisation de tir")
	launcher.free()
	target.free()


func _test_enemy_only_integration(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.benchmark_empty_scenario = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	var missiles: WeaponSystemProfile = load("res://data/weapons/medium_missile_tubes.tres")
	var armed_profile: UnitProfile = _profile_with(missiles)
	armed_profile.missile_capacity = 6
	armed_profile.missile_launcher_count = 2
	var friendly: TacticalUnit = battle._spawn_unit("JOUEUR", 0, Vector2.ZERO, armed_profile)
	var enemy: TacticalUnit = battle._spawn_unit("IA", 1, Vector2(300.0, 0.0), armed_profile)
	enemy.sensor_mode = TacticalUnit.SensorMode.ACTIVE
	battle.ai_decision_remaining = 0.0
	battle._update_ai(0.1)
	if friendly.has_move_target or not friendly.navigation_route.is_empty():
		failures.append("le pilote tactique injecte un ordre automatique au camp joueur")
	if not enemy.has_move_target:
		failures.append("le pilote tactique n'est pas branché sur le camp IA")
	battle.free()


func _test_ai_demo(failures: Array[String]) -> void:
	var battle = BATTLE_SCENE.instantiate()
	battle.ai_demo = true
	root.add_child(battle)
	battle.set_process(false)
	battle.set_physics_process(false)
	if battle.friendly_units.size() != 3 or battle.enemy_units.size() != 3:
		failures.append("le scénario IA ne contient pas trois bâtiments dans chaque camp")
	for friendly: TacticalUnit in battle.friendly_units:
		if friendly.fixed_in_place or not friendly.invulnerable:
			failures.append("un bâtiment bleu du scénario IA n'est pas mobile et indestructible")
	if battle.friendly_units[0].get_weapon_system(WeaponSystemProfile.Family.MISSILE) == null:
		failures.append("la frégate bleue du scénario IA ne possède aucun missile")
	if battle.friendly_units[1].get_weapon_system(WeaponSystemProfile.Family.RAILGUN) == null:
		failures.append("le railgun bleu du scénario IA n'est pas armé")
	if not battle.friendly_units[2].provides_fire_control_data():
		failures.append("l'AWACS bleu ne fournit pas de conduite de tir")
	var manual_target: Vector2 = battle.friendly_units[0].global_position + Vector2(120.0, 40.0)
	battle.friendly_units[0].set_navigation_order(manual_target)
	battle.ai_decision_remaining = 0.0
	battle._update_ai(0.1)
	if not battle.enemy_units[0].has_move_target and not battle.enemy_units[0].is_orienting_to_final_heading:
		failures.append("le railgun du scénario IA ne reçoit aucun plan tactique")
	if not battle.friendly_units[0].has_move_target or battle.friendly_units[0].move_target != manual_target:
		failures.append("l'IA adverse remplace l'ordre manuel d'une unité bleue")
	if battle.friendly_units[1].has_move_target:
		failures.append("une unité bleue sans ordre est pilotée automatiquement")
	battle.free()
