class_name TacticalUiContract
extends RefCounted

enum NetworkState {
	UNKNOWN,
	CONNECTED,
	ISOLATED,
}

enum OffensiveState {
	UNKNOWN,
	READY,
	DEGRADED,
	EMPTY,
}

enum AlertFlag {
	INCOMING_MISSILE = 1,
	NETWORK_LOST = 2,
	OUT_OF_SECTOR = 4,
}

const TASK_FORCE_SHORTCUTS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
const TASK_FORCE_KEYPAD_SHORTCUTS: Array[Key] = [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4]


class UnitSnapshot extends RefCounted:
	var unit: TacticalUnit
	var identity: String
	var role: String
	var structure_ratio: float
	var heat_ratio: float
	var network_state: NetworkState
	var offensive_state: OffensiveState
	var alert_flags: int
	var selected: bool


class TaskForceSnapshot extends RefCounted:
	var task_force: TaskForce
	var identity: String
	var living_units: int
	var total_units: int
	var network_state: NetworkState
	var offensive_state: OffensiveState
	var alert_flags: int
	var selected: bool


static func build_unit_snapshot(
	unit: TacticalUnit,
	network_state: NetworkState = NetworkState.UNKNOWN,
	offensive_state: OffensiveState = OffensiveState.UNKNOWN,
	alert_flags: int = 0
) -> UnitSnapshot:
	var snapshot := UnitSnapshot.new()
	snapshot.unit = unit
	snapshot.identity = unit.callsign
	snapshot.role = unit.unit_profile.tactical_role
	snapshot.structure_ratio = clampf(unit.hull / unit.maximum_hull, 0.0, 1.0) if unit.maximum_hull > 0.0 else 0.0
	snapshot.heat_ratio = unit.get_heat_ratio()
	snapshot.network_state = network_state
	snapshot.offensive_state = offensive_state
	snapshot.alert_flags = alert_flags
	snapshot.selected = unit.selected
	return snapshot


static func build_task_force_snapshot(
	force: TaskForce,
	unit_snapshots: Array[UnitSnapshot],
	selected_force: TaskForce = null
) -> TaskForceSnapshot:
	var snapshot := TaskForceSnapshot.new()
	snapshot.task_force = force
	snapshot.identity = force.display_name
	snapshot.total_units = force.members.size()
	snapshot.living_units = unit_snapshots.size()
	snapshot.network_state = _aggregate_network_state(unit_snapshots)
	snapshot.offensive_state = _aggregate_offensive_state(unit_snapshots)
	for unit_snapshot: UnitSnapshot in unit_snapshots:
		snapshot.alert_flags |= unit_snapshot.alert_flags
	snapshot.selected = force == selected_force
	return snapshot


static func task_force_shortcut_index(event: InputEventKey) -> int:
	if event == null or not event.pressed or event.echo or event.shift_pressed or event.ctrl_pressed or event.alt_pressed:
		return -1
	var index: int = TASK_FORCE_SHORTCUTS.find(event.physical_keycode)
	if index < 0:
		index = TASK_FORCE_SHORTCUTS.find(event.keycode)
	if index < 0:
		index = TASK_FORCE_KEYPAD_SHORTCUTS.find(event.keycode)
	return index


static func can_present_hostile_contact(known_to_player: bool) -> bool:
	return known_to_player


static func can_present_enemy_loss(confirmed_to_player: bool) -> bool:
	return confirmed_to_player


static func block_reason_label(reason: FireMission.BlockReason) -> String:
	match reason:
		FireMission.BlockReason.NO_CONTACT:
			return "PAS DE CONTACT"
		FireMission.BlockReason.INSUFFICIENT_TRACK:
			return "PISTE INSUFFISANTE"
		FireMission.BlockReason.OUT_OF_LINK:
			return "HORS LIAISON"
		FireMission.BlockReason.OUT_OF_RANGE:
			return "HORS PORTÉE"
		FireMission.BlockReason.OUT_OF_ARC:
			return "HORS ARC"
		FireMission.BlockReason.AIMING:
			return "POINTAGE"
		FireMission.BlockReason.RELOADING:
			return "RECHARGEMENT"
		FireMission.BlockReason.OVERHEATED:
			return "SURCHAUFFE"
		FireMission.BlockReason.NO_AMMUNITION:
			return "AUCUNE MUNITION"
		FireMission.BlockReason.NO_COMPATIBLE_WEAPON:
			return "AUCUNE ARME COMPATIBLE"
		FireMission.BlockReason.NO_RADIO_EMISSION:
			return "PAS D’ÉMISSION RADIO"
		FireMission.BlockReason.FIRE_CONTROL_UNAVAILABLE:
			return "PISTE OU LIAISON"
	return ""


static func _aggregate_network_state(unit_snapshots: Array[UnitSnapshot]) -> NetworkState:
	if unit_snapshots.is_empty():
		return NetworkState.UNKNOWN
	for snapshot: UnitSnapshot in unit_snapshots:
		if snapshot.network_state == NetworkState.ISOLATED:
			return NetworkState.ISOLATED
		if snapshot.network_state == NetworkState.UNKNOWN:
			return NetworkState.UNKNOWN
	return NetworkState.CONNECTED


static func _aggregate_offensive_state(unit_snapshots: Array[UnitSnapshot]) -> OffensiveState:
	if unit_snapshots.is_empty():
		return OffensiveState.UNKNOWN
	var ready_count: int = 0
	var empty_count: int = 0
	for snapshot: UnitSnapshot in unit_snapshots:
		ready_count += 1 if snapshot.offensive_state == OffensiveState.READY else 0
		empty_count += 1 if snapshot.offensive_state == OffensiveState.EMPTY else 0
	if ready_count == unit_snapshots.size():
		return OffensiveState.READY
	if empty_count == unit_snapshots.size():
		return OffensiveState.EMPTY
	return OffensiveState.DEGRADED
