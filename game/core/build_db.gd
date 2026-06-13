## Buildable structure database (autoload "BuildDb").
##
## Loads buildables.json: placeable structures with their material cost and the
## roles they fill (crafting station, heat source, shelter, storage, bed).
extends Node

const BUILDABLES_PATH := "res://game/data/buildables.json"

var buildables: Dictionary = {}   # id -> def
var ordered: Array[String] = []   # ids in file order, for the build palette
var categories: Array[String] = []

func _ready() -> void:
	for entry: Dictionary in Balance.load_json(BUILDABLES_PATH):
		var id := String(entry["id"])
		buildables[id] = entry
		ordered.append(id)
		var cat := String(entry.get("category", "Misc"))
		if cat not in categories:
			categories.append(cat)
	assert(not buildables.is_empty(), "buildables.json failed to load")

func get_def(id: String) -> Dictionary:
	return buildables.get(id, {})
