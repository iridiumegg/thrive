## Lore database (autoload "LoreDb"). Found documents + ending definitions.
extends Node

const NOTES_PATH := "res://game/data/notes.json"
const ENDINGS_PATH := "res://game/data/endings.json"

var notes: Dictionary = {}       # id -> def
var ordered_notes: Array[String] = []
var endings: Array = []          # ending defs in display order

func _ready() -> void:
	for entry: Dictionary in Balance.load_json(NOTES_PATH):
		notes[String(entry["id"])] = entry
		ordered_notes.append(String(entry["id"]))
	endings = Balance.load_json(ENDINGS_PATH)
	assert(not notes.is_empty(), "notes.json failed to load")

func get_note(id: String) -> Dictionary:
	return notes.get(id, {})

func get_ending(id: String) -> Dictionary:
	for ending: Dictionary in endings:
		if String(ending["id"]) == id:
			return ending
	return {}
