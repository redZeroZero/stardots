class_name TaskForceRegistry
extends RefCounted

var validation_errors: Array[String] = []
var _forces_by_team: Array[Dictionary] = [{}, {}]
var _force_by_unit_id: Dictionary = {}


func clear() -> void:
	validation_errors.clear()
	_forces_by_team = [{}, {}]
	_force_by_unit_id.clear()


func rebuild_from_tactical_groups(units: Array) -> bool:
	clear()
	for unit: TacticalUnit in units:
		if not _is_eligible_unit(unit):
			continue
		var team_id: int = unit.team_id
		var force_id: int = unit.tactical_group_id
		var force: TaskForce = _forces_by_team[team_id].get(force_id)
		if force == null:
			force = TaskForce.new(force_id, team_id)
			_forces_by_team[team_id][force_id] = force
		if not force.add_member(unit):
			validation_errors.append(
				"%s dépasse la capacité maximale de %d bâtiments" % [
					force.display_name,
					TaskForce.MAXIMUM_SIZE,
				]
			)
			continue
		_force_by_unit_id[unit.get_instance_id()] = force
	return validation_errors.is_empty()


func register_forces(forces: Array[TaskForce]) -> bool:
	clear()
	for force: TaskForce in forces:
		if force == null or force.team_id < 0 or force.team_id >= _forces_by_team.size():
			validation_errors.append("Task Force absente ou équipe invalide")
			continue
		if _forces_by_team[force.team_id].has(force.task_force_id):
			validation_errors.append("Identifiant de Task Force dupliqué: %d" % force.task_force_id)
			continue
		_forces_by_team[force.team_id][force.task_force_id] = force
		for unit: TacticalUnit in force.members:
			if not _is_eligible_unit(unit) or unit.team_id != force.team_id:
				validation_errors.append("%s contient un membre invalide" % force.display_name)
				continue
			if _force_by_unit_id.has(unit.get_instance_id()):
				validation_errors.append("%s appartient à plusieurs Task Forces" % unit.callsign)
				continue
			_force_by_unit_id[unit.get_instance_id()] = force
	return validation_errors.is_empty()


func get_forces(team_id: int) -> Array[TaskForce]:
	var forces: Array[TaskForce] = []
	if team_id < 0 or team_id >= _forces_by_team.size():
		return forces
	for force: TaskForce in _forces_by_team[team_id].values():
		forces.append(force)
	forces.sort_custom(func(first: TaskForce, second: TaskForce):
		return first.task_force_id < second.task_force_id
	)
	return forces


func get_force_for_unit(unit: TacticalUnit) -> TaskForce:
	if unit == null or not is_instance_valid(unit):
		return null
	return _force_by_unit_id.get(unit.get_instance_id())


func _is_eligible_unit(unit: TacticalUnit) -> bool:
	return (
		unit != null
		and is_instance_valid(unit)
		and not unit.destroyed
		and unit.team_id >= 0
		and unit.team_id < _forces_by_team.size()
	)
