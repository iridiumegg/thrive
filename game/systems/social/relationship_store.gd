## Per-NPC relationship/trust points and named tiers. Pure logic.
##
## Trust rises through conversation, gifts, and completed requests, and gates
## dialogue, trades, and help. Tier thresholds come from balance.json so they're
## tunable. Original mechanic — no gift/heart system copied from any game.
class_name RelationshipStore
extends RefCounted

var levels: Array            # [{name, min}, ...] ascending by min
var max_points: int
var _points: Dictionary = {} # npc_id -> int

func _init(level_defs: Array, max_points_: int) -> void:
	levels = level_defs
	max_points = max_points_

func value(npc_id: String) -> int:
	return int(_points.get(npc_id, 0))

func add(npc_id: String, delta: int) -> int:
	var updated := clampi(value(npc_id) + delta, 0, max_points)
	_points[npc_id] = updated
	return updated

func level_name(npc_id: String) -> String:
	var name := String(levels[0].get("name", "")) if not levels.is_empty() else ""
	for tier: Dictionary in levels:
		if value(npc_id) >= int(tier.get("min", 0)):
			name = String(tier["name"])
	return name

func at_least(npc_id: String, min_points: int) -> bool:
	return value(npc_id) >= min_points

func to_data() -> Dictionary:
	return _points.duplicate()

func load_data(data: Dictionary) -> void:
	for npc_id: String in data:
		_points[npc_id] = int(data[npc_id])
