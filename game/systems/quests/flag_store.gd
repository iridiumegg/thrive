## Story flags + named variables. Pure logic.
##
## The narrative state the quest and (later) dialogue systems read and write.
## Flags are simple booleans ("intro_done"); variables hold arbitrary values
## for counters or choices. Kept tiny and serializable for saves.
class_name FlagStore
extends RefCounted

var _flags: Dictionary = {}
var _vars: Dictionary = {}

func set_flag(flag: String, value: bool = true) -> void:
	_flags[flag] = value

func has_flag(flag: String) -> bool:
	return bool(_flags.get(flag, false))

func set_var(key: String, value: Variant) -> void:
	_vars[key] = value

func get_var(key: String, default_value: Variant = null) -> Variant:
	return _vars.get(key, default_value)

func all_flags() -> Dictionary:
	return _flags

func to_data() -> Dictionary:
	return {"flags": _flags.duplicate(), "vars": _vars.duplicate()}

func load_data(data: Dictionary) -> void:
	_flags = data.get("flags", {}).duplicate()
	_vars = data.get("vars", {}).duplicate()
