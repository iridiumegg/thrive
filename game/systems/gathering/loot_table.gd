## Weighted, data-driven, seed-aware loot resolution. Pure static logic.
##
## A loot table (from loot_tables.json) can mix three independent mechanisms,
## all optional:
##   guaranteed: entries that always drop, each a min..max quantity
##   rolls:      pick `count` times from a weighted pool (with replacement)
##   rare:       entries that drop on an independent per-entry chance
##
## All randomness comes from the caller's RandomNumberGenerator, so a given
## seed always produces the same drops (reproducible worlds, testable rolls).
class_name LootTable
extends RefCounted

## Resolve a table into { item_id: qty }. `bonus_rolls` adds extra weighted
## picks (used to reward harvesting with a tool above the required tier).
static func roll(table: Dictionary, rng: RandomNumberGenerator, bonus_rolls: int = 0) -> Dictionary:
	var result: Dictionary = {}

	for entry: Dictionary in table.get("guaranteed", []):
		_add(result, String(entry["item"]), _qty(entry, rng))

	var rolls: Dictionary = table.get("rolls", {})
	if not rolls.is_empty():
		var entries: Array = rolls.get("entries", [])
		var count := int(rolls.get("count", 1)) + bonus_rolls
		for _i in count:
			var picked := _weighted_pick(entries, rng)
			if not picked.is_empty():
				_add(result, String(picked["item"]), _qty(picked, rng))

	for entry: Dictionary in table.get("rare", []):
		if rng.randf() < float(entry["chance"]):
			_add(result, String(entry["item"]), _qty(entry, rng))

	return result

static func _qty(entry: Dictionary, rng: RandomNumberGenerator) -> int:
	var lo := int(entry.get("min", 1))
	var hi := int(entry.get("max", lo))
	return rng.randi_range(lo, hi) if hi > lo else lo

static func _weighted_pick(entries: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for e: Dictionary in entries:
		total += float(e.get("weight", 1.0))
	if total <= 0.0:
		return {}
	var pick := rng.randf() * total
	for e: Dictionary in entries:
		pick -= float(e.get("weight", 1.0))
		if pick <= 0.0:
			return e
	return entries.back()

static func _add(result: Dictionary, item_id: String, qty: int) -> void:
	if qty <= 0:
		return
	result[item_id] = int(result.get(item_id, 0)) + qty
