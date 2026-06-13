## Runtime state of one resource node (tree, boulder, ore vein, …). Pure logic.
##
## A node yields a limited number of harvests, then depletes and regrows after a
## respawn delay. Harvesting requires a tool of the right tag at or above the
## node's tier (tier 0 = bare hands). A higher-tier tool grants bonus loot rolls.
## The node owns its own seeded RNG so its drops are reproducible per world.
class_name HarvestNode
extends RefCounted

var def: Dictionary           # one entry from resource_nodes.json
var harvests_remaining: int
var respawn_remaining: int = 0   # minutes left until regrowth (only when depleted)

var _loot_table: Dictionary
var _rng: RandomNumberGenerator

func _init(node_def: Dictionary, loot_table: Dictionary, rng: RandomNumberGenerator) -> void:
	def = node_def
	_loot_table = loot_table
	_rng = rng
	harvests_remaining = int(def.get("max_harvests", 1))

func required_tag() -> String:
	return String(def.get("tool", {}).get("tag", ""))

func required_tier() -> int:
	return int(def.get("tool", {}).get("tier", 0))

func is_depleted() -> bool:
	return harvests_remaining <= 0

## Can the node be worked right now with a tool of the given tag/tier?
## tool_tier should be 0 unless the equipped tool's tag matches required_tag().
func can_harvest(tool_tier: int) -> bool:
	return not is_depleted() and tool_tier >= required_tier()

## Perform one harvest, returning the loot { item_id: qty }. Returns {} if the
## node can't currently be harvested. `extra_bonus` adds loot rolls on top of
## the tool-tier bonus (e.g. from the gathering skill). Depletes the node when
## the last harvest is taken, starting the respawn timer.
func harvest(tool_tier: int, extra_bonus: int = 0) -> Dictionary:
	if not can_harvest(tool_tier):
		return {}
	harvests_remaining -= 1
	var bonus := maxi(0, tool_tier - required_tier()) + maxi(0, extra_bonus)
	var loot := LootTable.roll(_loot_table, _rng, bonus)
	if is_depleted():
		respawn_remaining = int(def.get("respawn_minutes", 0))
	return loot

## Advance time; returns true on the minute the node finishes regrowing.
func tick(minutes: int) -> bool:
	if not is_depleted() or respawn_remaining <= 0:
		return false
	respawn_remaining -= minutes
	if respawn_remaining <= 0:
		respawn_remaining = 0
		harvests_remaining = int(def.get("max_harvests", 1))
		return true
	return false
