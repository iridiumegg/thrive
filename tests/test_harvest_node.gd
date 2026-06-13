extends "res://tests/test_case.gd"

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 1234
	return r

# A tree-like node: needs an axe at tier 1, 3 harvests, regrows in 100 minutes.
func _tree_def() -> Dictionary:
	return {
		"id": "tree", "tool": {"tag": "axe", "tier": 1},
		"max_harvests": 3, "respawn_minutes": 100,
	}

func _loot() -> Dictionary:
	return {"guaranteed": [{"item": "wood_log", "min": 1, "max": 1}]}

func _node(def: Dictionary = {}) -> HarvestNode:
	return HarvestNode.new(_tree_def() if def.is_empty() else def, _loot(), _rng())

func test_requires_matching_tool_tier() -> void:
	var node := _node()
	assert_false(node.can_harvest(0), "bare hands can't fell a tree")
	assert_true(node.can_harvest(1), "an axe of the right tier can")
	assert_true(node.can_harvest(2), "a better tool also works")

func test_hand_node_needs_no_tool() -> void:
	var bush := _node({"tool": {"tag": "", "tier": 0}, "max_harvests": 1, "respawn_minutes": 10})
	assert_true(bush.can_harvest(0))

func test_harvest_yields_loot_and_depletes() -> void:
	var node := _node()
	for i in 3:
		var loot := node.harvest(1)
		assert_true(loot.has("wood_log"), "each harvest yields loot")
	assert_true(node.is_depleted(), "node depletes after max_harvests")
	assert_true(node.harvest(1).is_empty(), "a depleted node yields nothing")

func test_harvest_without_tool_yields_nothing() -> void:
	var node := _node()
	assert_true(node.harvest(0).is_empty())
	assert_eq(node.harvests_remaining, 3, "a failed harvest doesn't consume the node")

func test_respawn_after_delay() -> void:
	var node := _node()
	for i in 3:
		node.harvest(1)
	assert_true(node.is_depleted())
	assert_false(node.tick(99), "not regrown yet")
	assert_true(node.is_depleted())
	assert_true(node.tick(1), "regrows once respawn time elapses")
	assert_false(node.is_depleted())
	assert_eq(node.harvests_remaining, 3, "harvests are restored on regrowth")

func test_higher_tier_tool_grants_bonus_loot() -> void:
	# Pool roll so bonus rolls visibly add output.
	var loot_def := {"rolls": {"count": 1, "entries": [{"item": "x", "weight": 1}]}}
	var node := HarvestNode.new(_tree_def(), loot_def, _rng())
	var loot := node.harvest(3)  # 2 tiers above required -> 2 bonus rolls
	assert_eq(int(loot["x"]), 3, "1 base + 2 bonus rolls from the better tool")
