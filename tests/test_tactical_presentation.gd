extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []

	if TacticalPresentation.detail_level(0.15) != TacticalPresentation.DetailLevel.STRATEGIC:
		failures.append("le zoom minimal n'active pas la vue stratégique")
	if TacticalPresentation.detail_level(0.28) != TacticalPresentation.DetailLevel.TACTICAL:
		failures.append("le seuil 0,28 n'active pas la vue tactique")
	if TacticalPresentation.detail_level(0.65) != TacticalPresentation.DetailLevel.TACTICAL:
		failures.append("le seuil 0,65 ne reste pas dans la vue tactique")
	if TacticalPresentation.detail_level(0.651) != TacticalPresentation.DetailLevel.CLOSE:
		failures.append("un zoom supérieur à 0,65 n'active pas la vue rapprochée")

	var strategic_radius: float = TacticalPresentation.compensated_radius(
		TacticalUnit.BODY_RADIUS,
		TacticalPresentation.MINIMUM_UNIT_DIAMETER_PX,
		0.15
	)
	if strategic_radius * 2.0 * 0.15 < TacticalPresentation.MINIMUM_UNIT_DIAMETER_PX - 0.01:
		failures.append("la taille minimale écran des unités n'est pas garantie")
	var waypoint_radius: float = TacticalPresentation.compensated_radius(
		4.0,
		TacticalPresentation.MINIMUM_WAYPOINT_DIAMETER_PX,
		0.15
	)
	if waypoint_radius * 2.0 * 0.15 < TacticalPresentation.MINIMUM_WAYPOINT_DIAMETER_PX - 0.01:
		failures.append("la taille minimale écran des waypoints n'est pas garantie")

	for zoom: float in [0.15, 0.28, 0.42, 1.0, 2.2]:
		var apparent_stroke: float = TacticalPresentation.stroke_width(1.0, zoom) * zoom
		if apparent_stroke < TacticalPresentation.MINIMUM_STROKE_PX - 0.01:
			failures.append("un trait devient inférieur à un pixel au zoom %.2f" % zoom)
		if apparent_stroke > TacticalPresentation.MAXIMUM_STROKE_PX + 0.01:
			failures.append("un trait dépasse la borne écran au zoom %.2f" % zoom)

	var small_circle_segments: int = TacticalPresentation.circle_segments(30.0, 0.15)
	var large_circle_segments: int = TacticalPresentation.circle_segments(2800.0, 1.0)
	if small_circle_segments < 16 or large_circle_segments > 128 or large_circle_segments <= small_circle_segments:
		failures.append("la tessellation des cercles ne suit pas leur rayon apparent")
	if TacticalPresentation.grid_alpha(TacticalPresentation.STRATEGIC_GRID_SPACING, 0.15) <= 0.5:
		failures.append("la grille stratégique n'est pas dominante au zoom minimal")
	if TacticalPresentation.grid_alpha(TacticalPresentation.CLOSE_GRID_SPACING, 1.0) <= 0.5:
		failures.append("la grille fine n'est pas dominante en vue rapprochée")
	if TacticalPresentation.strategic_detail_alpha(0.15) < 0.99:
		failures.append("les détails stratégiques ne sont pas pleinement visibles au zoom minimal")
	if TacticalPresentation.close_detail_alpha(1.0) < 0.99:
		failures.append("les détails rapprochés ne sont pas pleinement visibles au zoom 1")
	var transition_sum: float = (
		TacticalPresentation.strategic_detail_alpha(0.28)
		+ TacticalPresentation.tactical_detail_alpha(0.28)
		+ TacticalPresentation.close_detail_alpha(0.28)
	)
	if not is_equal_approx(transition_sum, 1.0):
		failures.append("les poids de transition ne forment pas un fondu continu")
	var occupied_labels: Array[Rect2] = [Rect2(Vector2(8.0, -16.0), Vector2(48.0, 14.0))]
	var displaced_label: Rect2 = TacticalPresentation.available_label_rect(Vector2.ZERO, Vector2(48.0, 14.0), occupied_labels)
	if displaced_label.size == Vector2.ZERO or displaced_label.intersects(occupied_labels[0]):
		failures.append("le placement des indicatifs ne résout pas un chevauchement simple")

	var fixed_world_heading: float = deg_to_rad(37.0)
	var expected_world_direction: Vector2 = Vector2.UP.rotated(fixed_world_heading)
	for ship_rotation: float in [deg_to_rad(-120.0), 0.0, deg_to_rad(85.0)]:
		var local_heading: Vector2 = TacticalPresentation.local_direction_for_world_heading(
			fixed_world_heading,
			ship_rotation
		)
		var rendered_world_direction: Vector2 = local_heading.rotated(ship_rotation)
		if rendered_world_direction.distance_to(expected_world_direction) > 0.001:
			failures.append("le marqueur de cap final tourne avec le navire")
			break

	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.global_position = Vector2(321.0, -147.0)
	var original_position: Vector2 = unit.global_position
	unit.set_visual_zoom(0.15)
	if unit.global_position != original_position or unit.scale != Vector2.ONE:
		failures.append("la compensation visuelle modifie la transformation monde de l'unité")
	var enlarged_click_point := original_position + Vector2(40.0, 0.0)
	if not unit.contains_world_point(enlarged_click_point):
		failures.append("la zone de clic minimale n'est pas compensée au zoom stratégique")
	unit.free()

	var railgun_projectile := RailgunProjectile.new()
	root.add_child(railgun_projectile)
	railgun_projectile.set_visual_zoom(0.15)
	if (
		railgun_projectile.get_visual_trail_length() * 0.15
		< RailgunProjectile.MINIMUM_TRAIL_LENGTH_PX - 0.01
	):
		failures.append("la traînée railgun disparaît au zoom stratégique")
	if (
		railgun_projectile.get_visual_head_radius() * 2.0 * 0.15
		< RailgunProjectile.MINIMUM_HEAD_DIAMETER_PX - 0.01
	):
		failures.append("la tête du projectile railgun devient sous-pixel au dézoom")
	railgun_projectile.free()

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Présentation tactique validée : niveaux, tailles, traits, tessellation, grille et coordonnées monde.")
	quit(0)
