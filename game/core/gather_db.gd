## Gathering database (autoload "GatherDb").
##
## Loads resource node, loot table, and trap definitions at startup, mirroring
## ItemDb/Balance: data enters the game here, never hardcoded. Also the factory
## for HarvestNode/Trap runtime objects so they share these definitions.
extends Node

const NODES_PATH := "res://game/data/resource_nodes.json"
const LOOT_PATH := "res://game/data/loot_tables.json"
const TRAPS_PATH := "res://game/data/traps.json"
const WILDLIFE_PATH := "res://game/data/wildlife.json"

var node_defs: Dictionary = {}     # node_id -> Dictionary
var loot_tables: Dictionary = {}   # table_id -> Dictionary
var trap_defs: Dictionary = {}     # trap_id -> Dictionary
var wildlife_defs: Dictionary = {} # creature_id -> Dictionary
var wildlife_ordered: Array[String] = []

func _ready() -> void:
	for entry: Dictionary in Balance.load_json(NODES_PATH):
		node_defs[String(entry["id"])] = entry
	loot_tables = Balance.load_json(LOOT_PATH)
	for entry: Dictionary in Balance.load_json(TRAPS_PATH):
		trap_defs[String(entry["id"])] = entry
	for entry: Dictionary in Balance.load_json(WILDLIFE_PATH):
		wildlife_defs[String(entry["id"])] = entry
		wildlife_ordered.append(String(entry["id"]))
	assert(not node_defs.is_empty(), "resource_nodes.json failed to load")

func loot_table(table_id: String) -> Dictionary:
	return loot_tables.get(table_id, {})

## Build a runtime HarvestNode for a node type, with a deterministic RNG seeded
## from the world seed + a per-node tag (so each placed node rolls reproducibly).
func new_node(node_id: String, rng_tag: String) -> HarvestNode:
	var def: Dictionary = node_defs[node_id]
	var rng := SeededRng.new(int(Balance.data["world_seed"])).stream("node:" + rng_tag)
	return HarvestNode.new(def, loot_table(String(def.get("loot_table", ""))), rng)

func new_trap(trap_id: String) -> Trap:
	var def: Dictionary = trap_defs[trap_id]
	return Trap.new(def, loot_table(String(def.get("loot_table", ""))))
