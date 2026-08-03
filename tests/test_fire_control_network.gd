extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var frigate_profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	var awacs_profile: UnitProfile = load("res://data/balance/awacs_unit.tres").duplicate(true)
	var frigate := TacticalUnit.new()
	var awacs := TacticalUnit.new()
	var target := TacticalUnit.new()
	root.add_child(frigate)
	root.add_child(awacs)
	root.add_child(target)
	frigate.configure("FRÉGATE", 0, Vector2(100.0, 0.0), frigate_profile)
	awacs.configure("AWACS", 0, Vector2.ZERO, awacs_profile)
	target.configure("BANDIT", 1, Vector2(600.0, 0.0), frigate_profile)

	var battlefield = load("res://src/main.gd").new()
	battlefield.friendly_units.append(frigate)
	battlefield.friendly_units.append(awacs)
	battlefield._rebuild_data_link_networks()
	var failures: Array[String] = []

	if battlefield._sensor_range_ratio(frigate, target) <= 0.68:
		failures.append("la frégate possède déjà une piste propre dans le scénario de test")
	if not battlefield._launcher_has_fire_control_solution(frigate, target):
		failures.append("l'AWACS ne fournit pas sa solution de tir à la frégate reliée")
	if not battlefield._is_target_in_missile_range(frigate, target):
		failures.append("une cible proche est refusée par la portée missile")
	if awacs.can_launch_weapon() or awacs.missile_launcher_count != 0 or awacs.missiles_remaining != 0:
		failures.append("l'AWACS dispose encore d'un armement missile")

	frigate.global_position = Vector2(2000.0, 0.0)
	battlefield._rebuild_data_link_networks()
	if battlefield._launcher_has_fire_control_solution(frigate, target):
		failures.append("la solution de tir reste partagée hors de la portée de liaison")
	if battlefield._is_target_in_missile_range(frigate, target):
		failures.append("une cible lointaine reste dans la portée missile")

	battlefield.free()
	frigate.free()
	awacs.free()
	target.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Réseau de tir validé : piste AWACS, liaison bornée et aucun missile embarqué.")
	quit(0)
