class_name TacticalSelectionState
extends RefCounted

signal changed(revision: int)

var units: Array[TacticalUnit] = []
var selected_task_force: TaskForce
var revision: int = 0


func clear() -> bool:
	return replace([], null)


func select_task_force(force: TaskForce) -> bool:
	if force == null:
		return clear()
	var living_members: Array[TacticalUnit] = []
	for unit: TacticalUnit in force.members:
		if is_instance_valid(unit) and not unit.destroyed:
			living_members.append(unit)
	return replace(living_members, force)


func select_unit(unit: TacticalUnit, parent_force: TaskForce = null) -> bool:
	if unit == null or not is_instance_valid(unit) or unit.destroyed:
		return clear()
	return replace([unit], parent_force)


func add(unit: TacticalUnit) -> bool:
	if unit == null or not is_instance_valid(unit) or unit.destroyed or unit in units:
		return false
	unit.set_selected(true)
	units.append(unit)
	selected_task_force = null
	_mark_changed()
	return true


func replace(new_units: Array, parent_force: TaskForce = null) -> bool:
	var normalized: Array[TacticalUnit] = []
	for candidate in new_units:
		var unit := candidate as TacticalUnit
		if unit == null or not is_instance_valid(unit) or unit.destroyed or unit in normalized:
			continue
		normalized.append(unit)
	if units == normalized and selected_task_force == parent_force:
		return false
	for unit: TacticalUnit in units:
		if is_instance_valid(unit) and unit not in normalized:
			unit.set_selected(false)
	for unit: TacticalUnit in normalized:
		unit.set_selected(true)
	units.assign(normalized)
	selected_task_force = parent_force
	_mark_changed()
	return true


func prune_invalid() -> bool:
	return replace(
		units.filter(func(unit: TacticalUnit): return is_instance_valid(unit) and not unit.destroyed),
		selected_task_force
	)


func _mark_changed() -> void:
	revision += 1
	changed.emit(revision)
