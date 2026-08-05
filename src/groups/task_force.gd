class_name TaskForce
extends RefCounted

enum FormationShape {
	LINE,
	SWARM,
}

enum FormationSpacing {
	TIGHT,
	LOOSE,
}

enum PhysicalStatus {
	INTEGRATED,
	SUPPORT,
	DETACHED,
}

const MINIMUM_CREATION_SIZE: int = 2
const MAXIMUM_SIZE: int = 10

var task_force_id: int
var team_id: int
var display_name: String
var formation_shape: FormationShape = FormationShape.LINE
var formation_spacing: FormationSpacing = FormationSpacing.TIGHT
var members: Array[TacticalUnit] = []
var _physical_status_by_instance_id: Dictionary = {}


func _init(new_task_force_id: int, new_team_id: int) -> void:
	task_force_id = new_task_force_id
	team_id = new_team_id
	display_name = "TF %s %d" % ["BLEUE" if team_id == 0 else "ROUGE", task_force_id + 1]


func can_add_member(unit: TacticalUnit) -> bool:
	if unit == null or not is_instance_valid(unit) or unit.destroyed or unit.team_id != team_id:
		return false
	return unit in members or members.size() < MAXIMUM_SIZE


func add_member(
	unit: TacticalUnit,
	physical_status: PhysicalStatus = PhysicalStatus.INTEGRATED
) -> bool:
	if not can_add_member(unit) or not _is_valid_physical_status(physical_status):
		return false
	if unit not in members:
		members.append(unit)
	_physical_status_by_instance_id[unit.get_instance_id()] = physical_status
	return true


func remove_member(unit: TacticalUnit) -> bool:
	if unit == null or unit not in members:
		return false
	members.erase(unit)
	_physical_status_by_instance_id.erase(unit.get_instance_id())
	return true


func set_member_status(unit: TacticalUnit, physical_status: PhysicalStatus) -> bool:
	if unit == null or unit not in members or not _is_valid_physical_status(physical_status):
		return false
	_physical_status_by_instance_id[unit.get_instance_id()] = physical_status
	return true


func get_member_status(unit: TacticalUnit) -> int:
	if unit == null or unit not in members:
		return -1
	return int(_physical_status_by_instance_id.get(
		unit.get_instance_id(),
		PhysicalStatus.INTEGRATED
	))


func get_members_with_status(physical_status: PhysicalStatus) -> Array[TacticalUnit]:
	var matching_members: Array[TacticalUnit] = []
	if not _is_valid_physical_status(physical_status):
		return matching_members
	for unit: TacticalUnit in members:
		if get_member_status(unit) == physical_status:
			matching_members.append(unit)
	return matching_members


func set_formation(shape: FormationShape, spacing: FormationSpacing) -> bool:
	if not _is_valid_formation_shape(shape) or not _is_valid_formation_spacing(spacing):
		return false
	formation_shape = shape
	formation_spacing = spacing
	return true


func is_valid_creation_size() -> bool:
	return members.size() >= MINIMUM_CREATION_SIZE and members.size() <= MAXIMUM_SIZE


func can_persist() -> bool:
	return not members.is_empty()


func remove_invalid_members() -> void:
	var valid_members: Array[TacticalUnit] = []
	var valid_statuses: Dictionary = {}
	for unit: TacticalUnit in members:
		if not is_instance_valid(unit) or unit.destroyed:
			continue
		valid_members.append(unit)
		valid_statuses[unit.get_instance_id()] = get_member_status(unit)
	members = valid_members
	_physical_status_by_instance_id = valid_statuses


func _is_valid_formation_shape(shape: int) -> bool:
	return shape == FormationShape.LINE or shape == FormationShape.SWARM


func _is_valid_formation_spacing(spacing: int) -> bool:
	return spacing == FormationSpacing.TIGHT or spacing == FormationSpacing.LOOSE


func _is_valid_physical_status(physical_status: int) -> bool:
	return (
		physical_status == PhysicalStatus.INTEGRATED
		or physical_status == PhysicalStatus.SUPPORT
		or physical_status == PhysicalStatus.DETACHED
	)
