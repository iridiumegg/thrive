## Quest database (autoload "QuestDb"). Loads quests.json.
extends Node

const QUESTS_PATH := "res://game/data/quests.json"

var quests: Dictionary = {}      # id -> def
var ordered: Array[String] = []  # file order, for stable journal display

func _ready() -> void:
	for entry: Dictionary in Balance.load_json(QUESTS_PATH):
		quests[String(entry["id"])] = entry
		ordered.append(String(entry["id"]))
	assert(not quests.is_empty(), "quests.json failed to load")
