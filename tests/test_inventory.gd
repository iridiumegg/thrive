extends "res://tests/test_case.gd"

## Builds a catalog from the real items.json (ItemDef parsing is pure logic),
## so these tests also guard the data file's shape.

func _catalog() -> Dictionary:
	var cat: Dictionary = {}
	for entry: Dictionary in load_json("res://game/data/items.json"):
		var def := ItemDef.from_dict(entry)
		cat[def.id] = def
	return cat

func _inv(slots: int = 24, capacity: float = 40.0) -> Inventory:
	return Inventory.new(slots, capacity, _catalog())

func test_add_stacks_and_counts() -> void:
	var inv := _inv()
	assert_eq(inv.add("branch", 5), 5)
	assert_eq(inv.count("branch"), 5)
	assert_true(inv.has("branch", 5))
	assert_false(inv.has("branch", 6))

func test_add_overflows_into_multiple_slots_at_stack_size() -> void:
	var inv := _inv()
	# branch stack_size is 20; 45 should occupy 3 slots (20 + 20 + 5).
	assert_eq(inv.add("branch", 45), 45)
	var used := 0
	for s: Inventory.Stack in inv.slots:
		if s != null:
			used += 1
	assert_eq(used, 3)
	assert_eq(inv.count("branch"), 45)

func test_weight_cap_limits_additions() -> void:
	# stone weighs 0.8; a 5 kg cap fits only 6 (4.8 kg), rejecting the rest.
	var inv := _inv(24, 5.0)
	var added := inv.add("stone", 100)
	assert_eq(added, 6)
	assert_almost(inv.total_weight(), 4.8, 0.001)

func test_slot_cap_limits_additions() -> void:
	# 2 slots, generous weight: fiber stack_size 40 -> max 80 fits.
	var inv := _inv(2, 1000.0)
	assert_eq(inv.add("plant_fiber", 200), 80)
	assert_eq(inv.count("plant_fiber"), 80)

func test_room_for_is_nonmutating_and_matches_add() -> void:
	var inv := _inv(24, 5.0)
	var predicted := inv.room_for("stone", 100)
	assert_eq(inv.count("stone"), 0, "room_for must not mutate")
	assert_eq(inv.add("stone", 100), predicted)

func test_remove_clears_emptied_slots() -> void:
	var inv := _inv()
	inv.add("branch", 10)
	assert_eq(inv.remove("branch", 4), 4, "remove returns the amount removed")
	assert_eq(inv.count("branch"), 6)
	assert_eq(inv.remove("branch", 999), 6, "removing more than present removes all that remain")
	assert_true(inv.is_empty())

func test_remove_slot_by_index() -> void:
	var inv := _inv()
	inv.add("stone", 12)
	assert_eq(inv.remove_slot(0, 5), 5)
	assert_eq(inv.count("stone"), 7)
	assert_eq(inv.remove_slot(0), 7, "negative qty removes the whole stack")
	assert_true(inv.is_empty())

func test_weight_fraction_tracks_load() -> void:
	var inv := _inv(24, 40.0)
	assert_almost(inv.weight_fraction(), 0.0)
	inv.add("stone", 50)  # 40 kg-worth = 50 stones, but cap is 40 kg -> 50 stones is 40kg
	assert_almost(inv.weight_fraction(), 1.0, 0.02)

func test_serialization_round_trip() -> void:
	var inv := _inv()
	inv.add("branch", 7)
	inv.add("flint_stone", 3)
	var data := inv.to_data()
	var restored := _inv()
	restored.load_data(data)
	assert_eq(restored.count("branch"), 7)
	assert_eq(restored.count("flint_stone"), 3)
