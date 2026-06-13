## Item database (autoload "ItemDb").
##
## Loads items.json into a catalog of ItemDefs at startup and acts as the
## factory for inventories/equipment so they share one metadata source.
## Like Balance, it is the single place item data enters the game — nothing
## hardcodes item stats.
extends Node

## item_id -> ItemDef
var catalog: Dictionary = {}

const ITEMS_PATH := "res://game/data/items.json"

func _ready() -> void:
	var raw: Variant = Balance.load_json(ITEMS_PATH)
	for entry: Dictionary in raw:
		var def := ItemDef.from_dict(entry)
		catalog[def.id] = def
	assert(not catalog.is_empty(), "items.json failed to load or is empty")

func get_def(item_id: String) -> ItemDef:
	return catalog.get(item_id)

func has(item_id: String) -> bool:
	return catalog.has(item_id)

## Build an Inventory sized from balance.json, sharing this catalog.
func new_inventory() -> Inventory:
	var cfg: Dictionary = Balance.data["inventory"]
	return Inventory.new(int(cfg["grid_slots"]), float(cfg["weight_capacity"]), catalog)

func new_equipment() -> Equipment:
	return Equipment.new(catalog)
