extends "res://tests/test_case.gd"

func _cfg() -> Dictionary:
	return {
		"lines": ["gathering", "crafting", "smithing"],
		"xp_curve_base": 50,
		"xp_curve_exp": 1.6,
		"max_level": 20,
	}

func _sys() -> SkillSystem:
	return SkillSystem.new(_cfg())

func test_everything_starts_at_level_one() -> void:
	var s := _sys()
	assert_eq(s.level("gathering"), 1)
	assert_eq(s.xp("gathering"), 0)
	assert_almost(s.progress("gathering"), 0.0)

func test_xp_curve_is_monotonic() -> void:
	var s := _sys()
	var prev := -1
	for lvl in range(1, 10):
		var need := s.xp_for_level(lvl)
		assert_true(need > prev, "XP-to-level must strictly increase")
		prev = need

func test_adding_xp_raises_level_at_thresholds() -> void:
	var s := _sys()
	var to_two := s.xp_for_level(2)
	var result := s.add_xp("gathering", to_two)
	assert_true(result["leveled"])
	assert_eq(result["from"], 1)
	assert_eq(result["to"], 2)
	assert_eq(s.level("gathering"), 2)

func test_xp_below_threshold_does_not_level() -> void:
	var s := _sys()
	var result := s.add_xp("gathering", s.xp_for_level(2) - 1)
	assert_false(result["leveled"])
	assert_eq(s.level("gathering"), 1)

func test_progress_fraction_advances_between_levels() -> void:
	var s := _sys()
	var floor2 := s.xp_for_level(2)
	var ceil3 := s.xp_for_level(3)
	s.add_xp("crafting", floor2 + (ceil3 - floor2) / 2)
	assert_true(s.progress("crafting") > 0.3 and s.progress("crafting") < 0.7,
			"progress should sit mid-way between levels 2 and 3")

func test_level_caps_at_max() -> void:
	var s := _sys()
	s.add_xp("smithing", 100000000)
	assert_eq(s.level("smithing"), 20)
	assert_almost(s.progress("smithing"), 1.0)

func test_skills_are_independent() -> void:
	var s := _sys()
	s.add_xp("gathering", s.xp_for_level(3))
	assert_eq(s.level("gathering"), 3)
	assert_eq(s.level("crafting"), 1, "XP in one line doesn't bleed into another")

func test_serialization_round_trip() -> void:
	var s := _sys()
	s.add_xp("gathering", 240)
	s.add_xp("smithing", 75)
	var restored := _sys()
	restored.load_data(s.to_data())
	assert_eq(restored.xp("gathering"), 240)
	assert_eq(restored.level("smithing"), s.level("smithing"))
