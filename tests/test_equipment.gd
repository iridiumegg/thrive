extends "res://tests/test_case.gd"

func _catalog() -> Dictionary:
	var cat: Dictionary = {}
	for entry: Dictionary in load_json("res://game/data/items.json"):
		var def := ItemDef.from_dict(entry)
		cat[def.id] = def
	return cat

func _equip() -> Equipment:
	return Equipment.new(_catalog())

func test_equip_into_slot_and_query() -> void:
	var eq := _equip()
	assert_true(eq.is_slot_empty("body"))
	var displaced := eq.equip("padded_jacket")
	assert_eq(displaced, "", "nothing was displaced from an empty slot")
	assert_eq(eq.equipped("body"), "padded_jacket")
	assert_false(eq.is_slot_empty("body"))

func test_equip_same_slot_displaces_previous() -> void:
	var eq := _equip()
	eq.equip("padded_jacket")
	var displaced := eq.equip("padded_jacket")
	assert_eq(displaced, "padded_jacket", "re-equipping the slot returns the old item")

func test_total_insulation_sums_clothing() -> void:
	var eq := _equip()
	eq.equip("knit_cap")       # +2
	eq.equip("padded_jacket")  # +6
	eq.equip("lined_boots")    # +2
	assert_almost(eq.total_insulation_c(), 10.0)

func test_tool_slot_does_not_add_warmth() -> void:
	var eq := _equip()
	eq.equip("stone_axe")
	assert_eq(eq.equipped("tool"), "stone_axe")
	assert_almost(eq.total_insulation_c(), 0.0)

func test_unequip_clears_slot() -> void:
	var eq := _equip()
	eq.equip("knit_cap")
	assert_eq(eq.unequip("head"), "knit_cap")
	assert_true(eq.is_slot_empty("head"))
	assert_eq(eq.unequip("head"), "", "unequipping an empty slot returns nothing")

func test_serialization_round_trip() -> void:
	var eq := _equip()
	eq.equip("padded_jacket")
	eq.equip("stone_axe")
	var restored := _equip()
	restored.load_data(eq.to_data())
	assert_eq(restored.equipped("body"), "padded_jacket")
	assert_eq(restored.equipped("tool"), "stone_axe")
