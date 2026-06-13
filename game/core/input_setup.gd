## Registers input actions in code at startup.
##
## Defining the map here (instead of project.godot) keeps bindings readable,
## diff-friendly, and is the single place a future remapping UI will talk to.
class_name InputSetup
extends RefCounted

static func ensure_actions() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("toggle_inventory", [KEY_TAB, KEY_I])
	_add_key_action("toggle_crafting", [KEY_C])
	_add_key_action("interact", [KEY_E, KEY_SPACE])
	_add_key_action("deploy_trap", [KEY_Q])
	# Debug actions — stand-ins until the real systems exist.
	_add_key_action("debug_eat", [KEY_F1])
	_add_key_action("debug_drink", [KEY_F2])
	_add_key_action("debug_sleep", [KEY_F3])
	_add_key_action("debug_fire", [KEY_F4])
	_add_key_action("debug_timescale", [KEY_F5])
	_add_key_action("restart", [KEY_R])

static func _add_key_action(action: StringName, physical_keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: Key in physical_keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
