## NPC + dialogue database (autoload "NpcDb"). Loads npcs.json and dialogues.json.
extends Node

const NPCS_PATH := "res://game/data/npcs.json"
const DIALOGUES_PATH := "res://game/data/dialogues.json"

var npcs: Dictionary = {}       # id -> def
var ordered: Array[String] = []
var dialogues: Dictionary = {}  # dialogue_id -> tree

func _ready() -> void:
	for entry: Dictionary in Balance.load_json(NPCS_PATH):
		npcs[String(entry["id"])] = entry
		ordered.append(String(entry["id"]))
	dialogues = Balance.load_json(DIALOGUES_PATH)
	assert(not npcs.is_empty(), "npcs.json failed to load")

func get_npc(id: String) -> Dictionary:
	return npcs.get(id, {})
