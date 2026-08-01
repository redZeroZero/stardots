extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var battlefield = load("res://scenes/main.tscn").instantiate()
	root.add_child(battlefield)
	battlefield.set_process(false)
	var frigate_one: TacticalUnit = battlefield.friendly_units[1]
	var frigate_two: TacticalUnit = battlefield.friendly_units[2]
	var awacs: TacticalUnit = battlefield.friendly_units[0]
	var bandit: TacticalUnit = battlefield.enemy_units[0]
	frigate_one.global_position = Vector2(700.0, 330.0)
	frigate_two.global_position = Vector2(700.0, 390.0)
	awacs.global_position = Vector2.ZERO
	bandit.global_position = Vector2(1500.0, 360.0)
	bandit.set_intel_state(TacticalUnit.IntelState.TRACKED)
	for unit: TacticalUnit in [awacs, frigate_one, frigate_two]:
		battlefield.selected_units.append(unit)
		unit.set_selected(true)
	var failures: Array[String] = []

	var shots: int = battlefield._issue_attack_zone(bandit.global_position + Vector2(100.0, 0.0))
	if shots != 2 or battlefield.missiles_layer.get_child_count() != 2:
		failures.append("la formation ne déclenche pas une salve par frégate armée")
	if frigate_one.thermal_mode != TacticalUnit.ThermalMode.COMBAT or frigate_two.thermal_mode != TacticalUnit.ThermalMode.COMBAT:
		failures.append("un lancement ne déclenche pas automatiquement le régime thermique combat")
	battlefield._update_missile_guidance()
	if bandit.thermal_mode != TacticalUnit.ThermalMode.COMBAT:
		failures.append("un missile entrant ne déclenche pas automatiquement le régime thermique combat")
	for unit: TacticalUnit in [awacs, frigate_one, frigate_two]:
		if unit.has_move_target or not unit.navigation_route.is_empty():
			failures.append("une zone d'attaque a créé un ordre de navigation dans la formation")
			break

	var missiles_before_empty_order: int = battlefield.missiles_layer.get_child_count()
	shots = battlefield._issue_attack_zone(Vector2(-3000.0, -3000.0))
	if shots != 0 or battlefield.missiles_layer.get_child_count() != missiles_before_empty_order:
		failures.append("une zone vide déclenche un tir")
	for unit: TacticalUnit in [awacs, frigate_one, frigate_two]:
		if unit.has_move_target or not unit.navigation_route.is_empty():
			failures.append("une zone vide fait courir la formation vers le clic")
			break

	battlefield.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Zone d'attaque validée : salve de formation, AWACS non armé et aucun mouvement parasite.")
	quit(0)
