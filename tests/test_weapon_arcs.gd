extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var profile: UnitProfile = load("res://data/balance/default_unit.tres").duplicate(true)
	profile.weapon_system_profiles = [load("res://data/weapons/long_range_missile_cells.tres")]
	var unit := TacticalUnit.new()
	root.add_child(unit)
	unit.configure("ARC", 0, Vector2.ZERO, profile)
	unit.rotation = 0.0

	if not unit.can_launch_weapon_at(Vector2(0.0, -500.0)):
		failures.append("un montage avant refuse une cible située devant la proue")
	if unit.can_launch_weapon_at(Vector2(500.0, 0.0)):
		failures.append("un montage avant accepte une cible située sur le flanc")
	if unit.can_launch_weapon_at(Vector2(0.0, 500.0)):
		failures.append("un montage avant accepte une cible située derrière la poupe")
	if unit.can_launch_weapon_at(Vector2(0.0, -120.0)):
		failures.append("un missile longue portée ignore sa distance minimale")

	var port_mount: WeaponMountProfile = load("res://data/weapon_mounts/port_broadside.tres")
	if not unit.is_position_in_mount_arc(port_mount, Vector2(-500.0, 0.0)):
		failures.append("la bordée bâbord ne couvre pas le flanc bâbord")
	if unit.is_position_in_mount_arc(port_mount, Vector2(500.0, 0.0)):
		failures.append("la bordée bâbord couvre le flanc tribord")
	var turret_mount: WeaponMountProfile = load("res://data/weapon_mounts/turret.tres")
	for target: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		if not unit.is_position_in_mount_arc(turret_mount, target * 500.0):
			failures.append("la tourelle ne couvre pas toutes les directions")
			break

	unit.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Arcs d'armes validés : proue, bordées, poupe, tourelle et distance minimale.")
	quit(0)
