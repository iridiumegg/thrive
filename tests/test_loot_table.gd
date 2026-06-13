extends "res://tests/test_case.gd"

func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func test_guaranteed_always_drops_in_range() -> void:
	var table := {"guaranteed": [{"item": "wood_log", "min": 1, "max": 2}]}
	for s in 25:
		var loot := LootTable.roll(table, _rng(s))
		assert_true(loot.has("wood_log"))
		var qty: int = loot["wood_log"]
		assert_true(qty >= 1 and qty <= 2, "qty within min..max")

func test_rolls_pick_count_items_from_pool() -> void:
	var table := {"rolls": {"count": 3, "entries": [
		{"item": "a", "weight": 1}, {"item": "b", "weight": 1}]}}
	var loot := LootTable.roll(table, _rng(7))
	var total := 0
	for id: String in loot:
		total += int(loot[id])
	assert_eq(total, 3, "exactly `count` units come out of the weighted pool")

func test_bonus_rolls_add_extra_picks() -> void:
	var table := {"rolls": {"count": 1, "entries": [{"item": "a", "weight": 1}]}}
	var loot := LootTable.roll(table, _rng(3), 2)
	assert_eq(int(loot["a"]), 3, "1 base roll + 2 bonus rolls")

func test_weighting_is_respected_over_many_rolls() -> void:
	# 'common' weight 9 vs 'rare' weight 1 -> common should dominate.
	var table := {"rolls": {"count": 1, "entries": [
		{"item": "common", "weight": 9}, {"item": "rare", "weight": 1}]}}
	var common := 0
	var rare := 0
	var r := _rng(42)
	for _i in 1000:
		var loot := LootTable.roll(table, r)
		common += int(loot.get("common", 0))
		rare += int(loot.get("rare", 0))
	assert_true(common > rare * 3, "heavier weight should dominate (got %d vs %d)" % [common, rare])

func test_rare_chance_zero_and_one() -> void:
	var never := {"rare": [{"item": "x", "chance": 0.0}]}
	var always := {"rare": [{"item": "x", "chance": 1.0}]}
	assert_false(LootTable.roll(never, _rng(5)).has("x"))
	assert_true(LootTable.roll(always, _rng(5)).has("x"))

func test_deterministic_for_same_seed() -> void:
	var table := {
		"guaranteed": [{"item": "g", "min": 1, "max": 5}],
		"rolls": {"count": 2, "entries": [{"item": "a", "weight": 2}, {"item": "b", "weight": 1}]},
		"rare": [{"item": "r", "chance": 0.5}],
	}
	assert_eq(LootTable.roll(table, _rng(99)), LootTable.roll(table, _rng(99)))

func test_empty_table_yields_nothing() -> void:
	assert_true(LootTable.roll({}, _rng()).is_empty())
