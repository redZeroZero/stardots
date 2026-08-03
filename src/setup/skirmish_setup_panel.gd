class_name SkirmishSetupPanel
extends PanelContainer

signal rotate_requested(direction: int)
signal delete_requested
signal clear_requested
signal launch_requested

var entries: Array[Dictionary] = []

@onready var team_option: OptionButton = %DeploymentTeamOption
@onready var group_option: OptionButton = %DeploymentGroupOption
@onready var ship_option: OptionButton = %DeploymentShipOption
@onready var rotate_left_button: Button = %RotateLeftButton
@onready var rotate_right_button: Button = %RotateRightButton
@onready var delete_button: Button = %DeleteUnitButton
@onready var clear_button: Button = %ClearDeploymentButton
@onready var deployment_status_label: Label = %DeploymentStatusLabel
@onready var launch_button: Button = %LaunchSkirmishButton


func _ready() -> void:
	rotate_left_button.pressed.connect(func(): rotate_requested.emit(-1))
	rotate_right_button.pressed.connect(func(): rotate_requested.emit(1))
	delete_button.pressed.connect(delete_requested.emit)
	clear_button.pressed.connect(clear_requested.emit)
	launch_button.pressed.connect(launch_requested.emit)


func configure(catalog_entries: Array[Dictionary]) -> void:
	entries = catalog_entries
	team_option.clear()
	team_option.add_item("BLEU — joueur", 0)
	team_option.add_item("ROUGE — IA", 1)
	group_option.clear()
	for group_id: int in 4:
		group_option.add_item("GROUPE %d" % (group_id + 1), group_id)
	ship_option.clear()
	for entry: Dictionary in entries:
		ship_option.add_item(String(entry["label"]))
	_update_selected_description()
	ship_option.item_selected.connect(func(_index: int): _update_selected_description())


func get_selected_team() -> int:
	return team_option.get_selected_id()


func get_selected_group_id() -> int:
	return group_option.get_selected_id()


func get_selected_ship_id() -> String:
	if ship_option.selected < 0 or ship_option.selected >= entries.size():
		return ""
	return String(entries[ship_option.selected]["id"])


func update_counts(blue_count: int, red_count: int) -> void:
	var mode_text := "TEST LIBRE" if blue_count > 0 and red_count == 0 else "BATAILLE"
	deployment_status_label.text = "%s  •  BLEU %d  •  ROUGE %d" % [mode_text, blue_count, red_count]
	launch_button.disabled = blue_count == 0


func set_has_selection(has_selection: bool) -> void:
	rotate_left_button.disabled = not has_selection
	rotate_right_button.disabled = not has_selection
	delete_button.disabled = not has_selection


func _update_selected_description() -> void:
	if ship_option.selected < 0 or ship_option.selected >= entries.size():
		return
	var profile: UnitProfile = entries[ship_option.selected]["profile"]
	%DeploymentShipDescription.text = "%s  •  %s" % [
		profile.tactical_role,
		profile.get("display_name"),
	]
