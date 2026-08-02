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
	if battlefield.friendly_units.size() != 5 or battlefield.enemy_units.size() != 4:
		failures.append("le scénario d'armes ne crée pas la task force, son AWACS et quatre cibles")
	if battlefield.selected_units.size() != 5:
		failures.append("les plateformes d'armes ne sont pas sélectionnées au démarrage")
	if battlefield.missiles_layer.get_child_count() != 1:
		failures.append("le scénario ne crée pas le missile entrant de validation défensive")
	var expected_families: Array[int] = [
		WeaponSystemProfile.Family.LASER_PDC,
		WeaponSystemProfile.Family.MISSILE,
		WeaponSystemProfile.Family.RAILGUN,
		WeaponSystemProfile.Family.MISSILE,
	]
	for index: int in mini(4, battlefield.friendly_units.size()):
		var found: bool = false
		for system: WeaponSystemProfile in battlefield.friendly_units[index].weapon_system_profiles:
			if system.family == expected_families[index]:
				found = true
				break
		if not found:
			failures.append("une plateforme du scénario ne possède pas son armement spécialisé")
	var awacs: TacticalUnit = battlefield.friendly_units[4]
	if not awacs.unit_profile.provides_fire_control or awacs.missile_launcher_count != 0:
		failures.append("l'AWACS d'essai ne fournit pas une liaison de tir non armée")
	for target: TacticalUnit in battlefield.enemy_units:
		if not target.invulnerable or not target.fixed_in_place:
			failures.append("un plastron n'est pas fixe et invulnérable")
			break
		var hull_before: float = target.hull
		target.apply_fragment_damage(10000.0)
		target._physics_process(1.0)
		if target.hull != hull_before or target.destroyed or target.velocity != Vector2.ZERO:
			failures.append("un plastron est détruit ou déplacé par le test de résistance")
			break
	battlefield.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Scénario d'armes validé : défense proche, missiles, railgun, arsenal et arcs.")
	quit(0)
