## Crafting database (autoload "CraftDb").
##
## Loads recipe and station definitions at startup, mirroring the other DB
## autoloads: content enters here, never hardcoded.
extends Node

const RECIPES_PATH := "res://game/data/recipes.json"
const STATIONS_PATH := "res://game/data/stations.json"

var recipes: Dictionary = {}    # recipe_id -> Dictionary
var stations: Dictionary = {}   # station_id -> Dictionary
var categories: Array[String] = []

func _ready() -> void:
	for entry: Dictionary in Balance.load_json(RECIPES_PATH):
		recipes[String(entry["id"])] = entry
		var cat := String(entry.get("category", "Misc"))
		if cat not in categories:
			categories.append(cat)
	for entry: Dictionary in Balance.load_json(STATIONS_PATH):
		stations[String(entry["id"])] = entry
	assert(not recipes.is_empty(), "recipes.json failed to load")

func station_name(station_id: String) -> String:
	return String(stations.get(station_id, {}).get("name", station_id))
