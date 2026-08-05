extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var task_force := TaskForce.new(0, 0)
	var units: Array[TacticalUnit] = []
	for index: int in TaskForce.MAXIMUM_SIZE + 1:
		var unit := TacticalUnit.new()
		unit.callsign = "TF-%02d" % (index + 1)
		unit.team_id = 0
		root.add_child(unit)
		units.append(unit)

	if task_force.is_valid_creation_size() or task_force.can_persist():
		failures.append("une TF vide est considérée comme valide")
	if not task_force.add_member(units[0]):
		failures.append("le premier membre valide est refusé")
	if task_force.is_valid_creation_size() or not task_force.can_persist():
		failures.append("un survivant ne persiste pas sans devenir une création valide")
	if not task_force.add_member(units[1], TaskForce.PhysicalStatus.SUPPORT):
		failures.append("le second membre ne crée pas une TF valide")
	if not task_force.is_valid_creation_size():
		failures.append("une TF de deux membres n'est pas valide")
	if task_force.get_member_status(units[1]) != TaskForce.PhysicalStatus.SUPPORT:
		failures.append("le statut d'appui n'est pas mémorisé")
	if not task_force.set_member_status(units[0], TaskForce.PhysicalStatus.DETACHED):
		failures.append("un membre ne peut pas être détaché")
	if task_force.get_members_with_status(TaskForce.PhysicalStatus.DETACHED) != [units[0]]:
		failures.append("le filtrage des membres détachés est incorrect")

	if not task_force.set_formation(
		TaskForce.FormationShape.SWARM,
		TaskForce.FormationSpacing.LOOSE
	):
		failures.append("la formation essaim lâche est refusée")
	if (
		task_force.formation_shape != TaskForce.FormationShape.SWARM
		or task_force.formation_spacing != TaskForce.FormationSpacing.LOOSE
	):
		failures.append("la forme et l'espacement ne restent pas indépendants")

	for index: int in range(2, TaskForce.MAXIMUM_SIZE):
		if not task_force.add_member(units[index]):
			failures.append("un membre est refusé avant le plafond")
	if task_force.members.size() != TaskForce.MAXIMUM_SIZE:
		failures.append("la TF n'atteint pas exactement son plafond de dix membres")
	if task_force.add_member(units[TaskForce.MAXIMUM_SIZE]):
		failures.append("un onzième membre est accepté")
	if not task_force.add_member(units[0], TaskForce.PhysicalStatus.INTEGRATED):
		failures.append("un membre existant ne peut pas changer de statut au plafond")
	if task_force.members.size() != TaskForce.MAXIMUM_SIZE:
		failures.append("un changement de statut duplique un membre")

	var enemy := TacticalUnit.new()
	enemy.team_id = 1
	root.add_child(enemy)
	if task_force.add_member(enemy):
		failures.append("une unité ennemie peut rejoindre la TF")
	if task_force.set_member_status(enemy, TaskForce.PhysicalStatus.SUPPORT):
		failures.append("une unité extérieure reçoit un statut dans la TF")

	for index: int in range(1, TaskForce.MAXIMUM_SIZE):
		task_force.remove_member(units[index])
	if task_force.members.size() != 1 or not task_force.can_persist():
		failures.append("une TF réduite à un survivant est dissoute")
	if task_force.is_valid_creation_size():
		failures.append("une TF survivante d'une unité redevient créable")
	units[0].destroyed = true
	task_force.remove_invalid_members()
	if task_force.can_persist() or not task_force.members.is_empty():
		failures.append("une TF sans survivant continue d'exister")

	for unit: TacticalUnit in units:
		unit.free()
	enemy.free()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Task Forces validées : taille, survivant, formations et statuts physiques.")
	quit(0)
