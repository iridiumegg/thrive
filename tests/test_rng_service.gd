extends "res://tests/test_case.gd"

func test_same_seed_same_stream_is_reproducible() -> void:
	var a := SeededRng.new(1337).stream("loot")
	var b := SeededRng.new(1337).stream("loot")
	for i in 10:
		assert_eq(a.randi(), b.randi(), "stream must be deterministic for a given seed")

func test_different_streams_diverge() -> void:
	var a := SeededRng.new(1337).stream("loot")
	var b := SeededRng.new(1337).stream("weather")
	var all_equal := true
	for i in 10:
		if a.randi() != b.randi():
			all_equal = false
	assert_false(all_equal, "named streams must be independent")

func test_different_seeds_diverge() -> void:
	var a := SeededRng.new(1).stream("loot")
	var b := SeededRng.new(2).stream("loot")
	var all_equal := true
	for i in 10:
		if a.randi() != b.randi():
			all_equal = false
	assert_false(all_equal)
