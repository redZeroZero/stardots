extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var battlefield = load("res://scenes/main.tscn").instantiate()
	battlefield.propulsion_demo = true
	root.add_child(battlefield)
	battlefield.set_process(false)
	battlefield.set_physics_process(false)

	if battlefield.friendly_units.size() != 3:
		failures.append("le scénario propulsion ne contient pas exactement trois bâtiments")
	if not battlefield.enemy_units.is_empty():
		failures.append("le scénario propulsion contient encore des ennemis")
	if battlefield.selected_units.size() != 3:
		failures.append("les trois démonstrateurs ne sont pas sélectionnés au démarrage")
	var expected_callsigns: Array[String] = ["FLIP-01", "CAP-01", "HYBRID-01"]
	var expected_doctrines: Array[int] = [
		UnitProfile.PropulsionDoctrine.FLIP_AND_BURN,
		UnitProfile.PropulsionDoctrine.HOLD_ATTITUDE,
		UnitProfile.PropulsionDoctrine.HYBRID,
	]
	for index: int in mini(3, battlefield.friendly_units.size()):
		var unit: TacticalUnit = battlefield.friendly_units[index]
		if unit.callsign != expected_callsigns[index]:
			failures.append("un indicatif du scénario propulsion est incorrect")
		if unit.propulsion_doctrine != expected_doctrines[index]:
			failures.append("%s n'utilise pas la doctrine attendue" % unit.callsign)
		if unit.navigation_route.size() != 1 or unit.navigation_route[0].position.x != 1200.0:
			failures.append("%s ne possède pas sa route de démonstration" % unit.callsign)
	if battlefield.friendly_units.size() == 3:
		var flip_unit: TacticalUnit = battlefield.friendly_units[0]
		var hybrid_unit: TacticalUnit = battlefield.friendly_units[2]
		if battlefield.friendly_units[0].retrograde_thrust_multiplier >= battlefield.friendly_units[1].retrograde_thrust_multiplier:
			failures.append("le démonstrateur flip-and-burn n'est pas matériellement distinct du cap maintenu")
		if battlefield.friendly_units[2].retrograde_thrust_multiplier >= battlefield.friendly_units[1].retrograde_thrust_multiplier:
			failures.append("le démonstrateur hybride n'utilise pas une propulsion intermédiaire")
		if hybrid_unit.active_leg_plan.pre_turn_braking_distance <= 0.0:
			failures.append("le démonstrateur hybride n'utilise pas son rétrofreinage avant le flip")
		if hybrid_unit.active_leg_plan.turn_start_remaining >= flip_unit.active_leg_plan.turn_start_remaining:
			failures.append("le démonstrateur hybride ne retourne pas plus tard que le flip-and-burn")

	battlefield.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Scénario propulsion validé : trois doctrines alliées, routes parallèles et aucun ennemi.")
	quit(0)
