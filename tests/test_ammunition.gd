extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	profile.missile_capacity = 4
	profile.missile_launcher_count = 2
	profile.missile_loader_count = 1
	profile.missile_loading_time = 1.0
	profile.missile_launch_interval = 0.2
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("MAGAZINE", 0, Vector2.ZERO, profile)
	var failures: Array[String] = []

	if unit.missiles_remaining != 4 or unit.get_ready_launcher_count() != 2 or unit.missile_reserve != 2:
		failures.append("les tubes et la réserve ne sont pas initialisés depuis le profil")
	unit.mark_weapon_launched()
	if unit.missiles_remaining != 3 or unit.get_ready_launcher_count() != 1 or unit.get_loading_launcher_count() != 1:
		failures.append("le tir ne vide pas un tube ou ne lance pas son chargement")
	if unit.can_launch_weapon():
		failures.append("l'intervalle minimal entre deux lancements n'est pas respecté")
	unit.weapon_cooldown_remaining = 0.0
	unit.mark_weapon_launched()
	if unit.missiles_remaining != 2 or unit.get_ready_launcher_count() != 0 or unit.get_loading_launcher_count() != 1:
		failures.append("le chargeur unique alimente plusieurs tubes en parallèle")
	unit._update_launcher_loading(1.1)
	if unit.get_ready_launcher_count() != 1 or unit.get_loading_launcher_count() != 1:
		failures.append("le chargeur ne passe pas automatiquement au tube suivant")
	unit.weapon_cooldown_remaining = 0.0
	unit.mark_weapon_launched()
	unit._update_launcher_loading(1.1)
	unit.weapon_cooldown_remaining = 0.0
	unit.mark_weapon_launched()
	if unit.missiles_remaining != 0 or unit.can_launch_weapon() or unit.get_loading_launcher_count() != 0:
		failures.append("un armement épuisé conserve un tir ou un chargement fantôme")

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Armement validé : tubes, réserve, chargeur, intervalle et épuisement.")
	quit(0)
