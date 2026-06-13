extends "res://tests/test_case.gd"

func _grid() -> PlacementGrid:
	return PlacementGrid.new(16)

func test_world_to_cell_and_back_centres() -> void:
	var g := _grid()
	assert_eq(g.world_to_cell(Vector2(8, 8)), Vector2i(0, 0))
	assert_eq(g.world_to_cell(Vector2(20, -4)), Vector2i(1, -1))
	assert_eq(g.cell_to_world(Vector2i(0, 0)), Vector2(8, 8))

func test_occupancy_blocks_reuse() -> void:
	var g := _grid()
	var cell := Vector2i(2, 3)
	assert_true(g.is_free(cell))
	g.occupy(cell, "campfire")
	assert_false(g.is_free(cell))
	assert_eq(g.building_at(cell), "campfire")
	g.vacate(cell)
	assert_true(g.is_free(cell))

func test_can_afford_and_missing() -> void:
	var cost := [{"item": "wood_plank", "qty": 4}, {"item": "cord", "qty": 2}]
	assert_true(PlacementGrid.can_afford(cost, {"wood_plank": 4, "cord": 2}))
	assert_false(PlacementGrid.can_afford(cost, {"wood_plank": 3, "cord": 2}))
	assert_eq(PlacementGrid.missing(cost, {"wood_plank": 1}), {"wood_plank": 3, "cord": 2})

func test_empty_cost_is_always_affordable() -> void:
	assert_true(PlacementGrid.can_afford([], {}))

func test_real_buildables_have_valid_costs() -> void:
	# Data guard: every buildable's cost references known items.
	var items: Dictionary = {}
	for entry: Dictionary in load_json("res://game/data/items.json"):
		items[String(entry["id"])] = true
	for entry: Dictionary in load_json("res://game/data/buildables.json"):
		for cost_entry: Dictionary in entry.get("cost", []):
			assert_true(items.has(String(cost_entry["item"])),
					"%s costs unknown item %s" % [entry["id"], cost_entry["item"]])
