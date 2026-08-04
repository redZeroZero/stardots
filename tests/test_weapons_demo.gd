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
	if not awacs.provides_fire_control_data() or awacs.missile_launcher_count != 0:
		failures.append("l'AWACS d'essai ne fournit pas une liaison de tir non armée")
	battlefield.tactical_overlay._rebuild_engagement_groups()
	if battlefield.tactical_overlay.engagement_groups.size() != 1:
		failures.append("les zones des bâtiments reliés à l'AWACS ne forment pas une enveloppe commune")
	else:
		var common_group: Dictionary = battlefield.tactical_overlay.engagement_groups[0]
		if common_group.passive_sensor.contours.is_empty():
			failures.append("la sélection multiple ne produit pas de veille nominale commune")
		if not common_group.active_sensor.contours.is_empty():
			failures.append("une flotte en veille passive affiche une enveloppe active")
		if common_group.weapon.sources.size() != 3:
			failures.append("la vue AUTO ne conserve pas les trois armements offensifs disponibles")
	if battlefield.tactical_overlay.fire_control_target_ids.is_empty():
		failures.append("aucun réticule n'identifie les pistes possédant une solution de tir réelle")
	for friendly: TacticalUnit in battlefield.friendly_units:
		if friendly.show_support_ranges or friendly.show_individual_weapon_ranges:
			failures.append("une sélection multiple conserve des cercles individuels en vue normale")
			break
	battlefield._toggle_range_debug()
	battlefield.tactical_overlay._rebuild_engagement_groups()
	if not battlefield.tactical_overlay.engagement_groups.is_empty():
		failures.append("le blob reste visible en mode de portées détaillées")
	if not battlefield.friendly_units[0].show_individual_weapon_ranges:
		failures.append("le mode debug ne restaure pas les arcs d'armes individuels")
	battlefield._toggle_range_debug()
	battlefield.offensive_weapon_selection = battlefield.OffensiveWeaponSelection.MISSILES
	battlefield.tactical_overlay._rebuild_engagement_groups()
	if battlefield.tactical_overlay.engagement_groups[0].weapon.sources.size() != 2:
		failures.append("W MISSILES ne filtre pas l'enveloppe sur les deux systèmes antinavires")
	battlefield.offensive_weapon_selection = battlefield.OffensiveWeaponSelection.RAILGUN
	battlefield.tactical_overlay._rebuild_engagement_groups()
	if battlefield.tactical_overlay.engagement_groups[0].weapon.sources.size() != 1:
		failures.append("W RAILGUN ne limite pas l'enveloppe au canon axial")
	battlefield.offensive_weapon_selection = battlefield.OffensiveWeaponSelection.AUTO
	awacs.global_position = Vector2(3000.0, 3000.0)
	battlefield._rebuild_data_link_networks()
	battlefield.tactical_overlay._rebuild_engagement_groups()
	if battlefield.tactical_overlay.engagement_groups.size() != 5:
		failures.append("la perte de conduite de tir produit %d enveloppes armées au lieu de cinq" % battlefield.tactical_overlay.engagement_groups.size())
	battlefield._clear_selection()
	var technical_unit: TacticalUnit = battlefield.friendly_units[1]
	battlefield.selected_units.append(technical_unit)
	technical_unit.set_selected(true)
	battlefield._refresh_range_visualization()
	battlefield.tactical_overlay._rebuild_engagement_groups()
	if not technical_unit.show_support_ranges or not technical_unit.show_individual_weapon_ranges:
		failures.append("une unité sélectionnée seule ne restaure pas son détail technique")
	if not battlefield.tactical_overlay.engagement_groups.is_empty():
		failures.append("une sélection unique conserve les enveloppes de task force")
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
