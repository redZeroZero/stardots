extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_swarm_distribution(failures)
	_test_warhead_safety(failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Salve validée : essaim espacé, allocation multi-cibles et distance d'armement.")
	quit(0)


func _test_swarm_distribution(failures: Array[String]) -> void:
	var battlefield = load("res://scenes/main.tscn").instantiate()
	battlefield.weapons_demo = true
	root.add_child(battlefield)
	battlefield.set_process(false)
	battlefield.set_physics_process(false)
	for unit: TacticalUnit in battlefield.selected_units:
		unit.set_selected(false)
	battlefield.selected_units.clear()
	battlefield.selected_units.append(battlefield.friendly_units[3])
	battlefield.offensive_weapon_selection = 1
	battlefield.fire_doctrine = 2
	var zone_center := Vector2(0.0, 660.0)
	for index: int in 3:
		var target: TacticalUnit = battlefield.enemy_units[index]
		target.global_position = zone_center + Vector2(0.0, float(index - 1) * 60.0)
		target.set_intel_state(TacticalUnit.IntelState.IDENTIFIED)
	battlefield.enemy_units[3].global_position = Vector2(1000.0, -1000.0)
	var shots: int = battlefield._issue_attack_zone(zone_center)
	if shots != 8:
		failures.append("la saturation de l'arsenal ne lance pas ses huit cellules")
	var assigned_targets: Dictionary = {}
	var lane_offsets: Dictionary = {}
	for missile: TacticalMissile in battlefield.missiles_layer.get_children():
		if missile.team_id != 0:
			continue
		assigned_targets[missile.target.get_instance_id()] = true
		lane_offsets["%.2f,%.2f" % [missile.cruise_lane_offset.x, missile.cruise_lane_offset.y]] = true
	if assigned_targets.size() != 3:
		failures.append("les missiles de saturation ne se répartissent pas sur les trois cibles")
	if lane_offsets.size() != 8:
		failures.append("les missiles de saturation partagent encore le même couloir")
	battlefield.free()


func _test_warhead_safety(failures: Array[String]) -> void:
	var profile: MissileProfile = load("res://data/balance/default_missile.tres")
	var target := Node2D.new()
	root.add_child(target)
	target.global_position = Vector2(10.0, 0.0)
	var missile := TacticalMissile.new()
	root.add_child(missile)
	missile.launch(Vector2.ZERO, target, 0, profile)
	missile._physics_process(0.01)
	if missile.exploding or missile.is_warhead_armed():
		failures.append("la charge explose avant sa distance de sûreté")
	missile.distance_travelled = profile.warhead_arming_distance
	missile._physics_process(0.01)
	if not missile.exploding:
		failures.append("la fusée de proximité ne s'active pas après la distance de sûreté")
	missile.free()
	target.free()
