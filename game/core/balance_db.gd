## Balance database (autoload "Balance").
##
## Loads every tunable number and data definition from /game/data at startup.
## Nothing in the simulation may hardcode a rate: if you want to tune the game,
## you edit JSON, not code.
extends Node

const BALANCE_PATH := "res://game/data/balance.json"
const AFFLICTIONS_PATH := "res://game/data/afflictions.json"

## Full contents of balance.json.
var data: Dictionary = {}

## Array of affliction definition Dictionaries from afflictions.json.
var afflictions: Array = []

func _ready() -> void:
	data = load_json(BALANCE_PATH)
	afflictions = load_json(AFFLICTIONS_PATH)
	assert(not data.is_empty(), "balance.json failed to load or is empty")

## Parse a JSON file into a Variant (Dictionary or Array). Returns {} on error.
static func load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read JSON file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("Invalid JSON in: %s" % path)
		return {}
	return parsed
