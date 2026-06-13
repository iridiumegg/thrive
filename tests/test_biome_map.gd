extends "res://tests/test_case.gd"

var data: Dictionary = load_json("res://game/data/biomes.json")

func _map(seed_value: int = 1337) -> BiomeMap:
	return BiomeMap.new(data, seed_value, 16)

func test_core_region_is_the_outpost_meadow() -> void:
	var m := _map()
	assert_eq(String(m.biome_at(Vector2.ZERO)["id"]), String(data["core_biome"]))
	# Just inside the core radius is still the core biome.
	var inside := (float(data["core_radius_tiles"]) - 1.0) * 16.0
	assert_eq(String(m.biome_at(Vector2(inside, 0))["id"]), String(data["core_biome"]))

func test_outside_core_can_be_other_biomes() -> void:
	var m := _map()
	var seen: Dictionary = {}
	for x in range(-3000, 3000, 120):
		for y in range(-2000, 2000, 120):
			seen[String(m.biome_at(Vector2(x, y))["id"])] = true
	assert_true(seen.size() >= 2, "the world has more than one biome (got %d)" % seen.size())

func test_deterministic_for_same_seed() -> void:
	var a := _map(99)
	var b := _map(99)
	for x in range(-1000, 1000, 137):
		for y in range(-1000, 1000, 137):
			assert_eq(a.biome_at(Vector2(x, y))["id"], b.biome_at(Vector2(x, y))["id"])

func test_temp_offset_reads_from_biome() -> void:
	var m := _map()
	assert_almost(m.temp_offset_at(Vector2.ZERO), 2.0, 0.001, "meadow core offset")

func test_allows_node_respects_biome_node_list() -> void:
	var m := _map()
	assert_true(m.allows_node("meadow", "berry_bush"))
	assert_false(m.allows_node("frostmarsh", "berry_bush"), "no berries in the frostmarsh")
	assert_true(m.allows_node("stony_highland", "ore_vein"))
