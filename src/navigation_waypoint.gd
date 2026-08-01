class_name NavigationWaypoint
extends RefCounted

enum PassageMode {
	HOLD,
	FLY_THROUGH,
}

var position: Vector2
var passage_mode: PassageMode
var final_heading: float
var has_final_heading: bool
var planned_speed: float = 0.0


func _init(
	new_position: Vector2,
	new_passage_mode: PassageMode = PassageMode.HOLD,
	new_final_heading: float = 0.0,
	new_has_final_heading: bool = false
) -> void:
	position = new_position
	passage_mode = new_passage_mode
	final_heading = new_final_heading
	has_final_heading = new_has_final_heading
