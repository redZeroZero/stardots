class_name TacticalGroup
extends RefCounted

var group_id: int
var team_id: int
var display_name: String
var members: Array[TacticalUnit] = []
var track_picture: TrackPicture


func _init(new_group_id: int, new_team_id: int) -> void:
	group_id = new_group_id
	team_id = new_team_id
	display_name = "%s %d" % ["BLEU" if team_id == 0 else "ROUGE", group_id + 1]
	track_picture = TrackPicture.new(team_id)


func add_member(unit: TacticalUnit) -> void:
	if unit not in members:
		members.append(unit)


func remove_invalid_members() -> void:
	members = members.filter(func(unit): return is_instance_valid(unit) and not unit.destroyed)
