extends "res://tests/test_case.gd"

func _levels() -> Array:
	return [
		{"name": "Stranger", "min": 0},
		{"name": "Acquaintance", "min": 10},
		{"name": "Friend", "min": 30},
		{"name": "Trusted", "min": 60},
	]

func _store() -> RelationshipStore:
	return RelationshipStore.new(_levels(), 100)

func test_starts_as_stranger_at_zero() -> void:
	var r := _store()
	assert_eq(r.value("wend"), 0)
	assert_eq(r.level_name("wend"), "Stranger")

func test_points_accumulate_and_change_tier() -> void:
	var r := _store()
	r.add("wend", 12)
	assert_eq(r.level_name("wend"), "Acquaintance")
	r.add("wend", 20)
	assert_eq(r.level_name("wend"), "Friend")

func test_points_clamp_to_range() -> void:
	var r := _store()
	r.add("pell", 250)
	assert_eq(r.value("pell"), 100, "capped at max")
	r.add("pell", -500)
	assert_eq(r.value("pell"), 0, "never below zero")

func test_at_least_threshold_check() -> void:
	var r := _store()
	r.add("pell", 30)
	assert_true(r.at_least("pell", 30))
	assert_false(r.at_least("pell", 31))

func test_relationships_are_per_npc() -> void:
	var r := _store()
	r.add("wend", 40)
	assert_eq(r.level_name("wend"), "Friend")
	assert_eq(r.level_name("pell"), "Stranger")

func test_serialization_round_trip() -> void:
	var r := _store()
	r.add("wend", 25)
	var restored := _store()
	restored.load_data(r.to_data())
	assert_eq(restored.value("wend"), 25)
