class_name TacticalWindowModeController
extends RefCounted

enum UserMode {
	WINDOWED,
	BORDERLESS,
	EXCLUSIVE_FULLSCREEN,
}

var current_mode: UserMode = UserMode.BORDERLESS


func sync_from_display() -> void:
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			current_mode = UserMode.BORDERLESS
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			current_mode = UserMode.EXCLUSIVE_FULLSCREEN
		_:
			current_mode = UserMode.WINDOWED


func cycle() -> UserMode:
	current_mode = (int(current_mode) + 1) % UserMode.size() as UserMode
	apply_current_mode()
	return current_mode


func apply_current_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match current_mode:
		UserMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		UserMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		UserMode.EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func get_label() -> String:
	match current_mode:
		UserMode.WINDOWED:
			return "FENÊTRÉ"
		UserMode.BORDERLESS:
			return "PLEIN ÉCRAN FENÊTRÉ"
		UserMode.EXCLUSIVE_FULLSCREEN:
			return "PLEIN ÉCRAN"
	return ""
