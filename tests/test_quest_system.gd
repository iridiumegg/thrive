extends "res://tests/test_case.gd"

func _defs() -> Dictionary:
	return {
		"q_start": {
			"id": "q_start", "auto_start": true,
			"objectives": [
				{"id": "o_wood", "type": "gather", "target": "wood_log", "count": 2},
				{"id": "o_build", "type": "build", "target": "campfire", "count": 1},
			],
		},
		"q_next": {
			"id": "q_next", "prerequisites": {"quests": ["q_start"]},
			"objectives": [
				{"id": "o_craft", "type": "craft", "target": "cord", "count": 1},
				{"id": "o_skill", "type": "reach_skill_level", "target": "survival", "count": 3},
				{"id": "o_opt", "type": "gather", "target": "stone", "count": 5, "optional": true},
			],
		},
		"q_locked": {
			"id": "q_locked", "prerequisites": {"flags": ["secret"]},
			"objectives": [{"id": "o_days", "type": "survive_n_days", "count": 2}],
		},
	}

func _empty_ctx() -> Dictionary:
	return {"flags": {}, "item_counts": {}, "skill_levels": {}}

func _sys() -> QuestSystem:
	return QuestSystem.new(_defs())

func test_auto_start_quest_activates_others_stay_locked() -> void:
	var s := _sys()
	var started := s.auto_activate(_empty_ctx())
	assert_true("q_start" in started)
	assert_true(s.is_active("q_start"))
	assert_false(s.is_active("q_next"), "prereq quest not yet complete")
	assert_eq(s.status("q_locked"), QuestSystem.LOCKED)

func test_objective_progress_accumulates_and_caps() -> void:
	var s := _sys()
	s.activate("q_start")
	s.record("gather", {"item": "wood_log", "qty": 1})
	assert_eq(s.progress_of("q_start", "o_wood"), 1)
	s.record("gather", {"item": "wood_log", "qty": 5})
	assert_eq(s.progress_of("q_start", "o_wood"), 2, "progress caps at the objective count")

func test_unrelated_events_do_not_advance() -> void:
	var s := _sys()
	s.activate("q_start")
	s.record("gather", {"item": "stone", "qty": 9})
	assert_eq(s.progress_of("q_start", "o_wood"), 0)

func test_quest_completes_when_all_required_objectives_done() -> void:
	var s := _sys()
	s.activate("q_start")
	s.record("gather", {"item": "wood_log", "qty": 2})
	var done := s.record("build", {"target": "campfire"})
	assert_true("q_start" in done)
	assert_true(s.is_completed("q_start"))

func test_prereq_quest_completion_enables_auto_activation() -> void:
	var s := _sys()
	s.activate("q_start")
	s.record("gather", {"item": "wood_log", "qty": 2})
	s.record("build", {"target": "campfire"})
	var started := s.auto_activate(_empty_ctx())
	assert_true("q_next" in started, "completing the prereq unlocks the next quest")

func test_craft_objective_matches_recipe_outputs() -> void:
	var s := _sys()
	s.activate("q_next")
	s.record("craft", {"outputs": ["cord"]})
	assert_true(s.is_objective_done("q_next", _defs()["q_next"]["objectives"][0]))

func test_skill_objective_uses_level_reached() -> void:
	var s := _sys()
	s.activate("q_next")
	s.record("skill", {"skill": "survival", "level": 2})
	assert_false(s.is_objective_done("q_next", _defs()["q_next"]["objectives"][1]))
	s.record("skill", {"skill": "survival", "level": 3})
	assert_eq(s.progress_of("q_next", "o_skill"), 3)

func test_optional_objective_not_required_for_completion() -> void:
	var s := _sys()
	s.activate("q_next")
	s.record("craft", {"outputs": ["cord"]})
	var done := s.record("skill", {"skill": "survival", "level": 3})
	assert_true("q_next" in done, "optional stone objective need not be finished")

func test_survive_days_counts_day_events() -> void:
	var s := _sys()
	s.activate("q_locked")
	s.record("survive_day", {})
	assert_eq(s.progress_of("q_locked", "o_days"), 1)
	var done := s.record("survive_day", {})
	assert_true("q_locked" in done)

func test_flag_prerequisite_gates_activation() -> void:
	var s := _sys()
	assert_false("q_locked" in s.auto_activate(_empty_ctx()))
	var ctx := _empty_ctx()
	ctx["flags"] = {"secret": true}
	assert_true("q_locked" in s.auto_activate(ctx))

func test_real_quest_chain_is_well_formed() -> void:
	# Data guard: every prerequisite quest id exists.
	var defs: Dictionary = {}
	for entry: Dictionary in load_json("res://game/data/quests.json"):
		defs[String(entry["id"])] = entry
	for id: String in defs:
		for prereq: String in defs[id].get("prerequisites", {}).get("quests", []):
			assert_true(defs.has(prereq), "%s requires unknown quest %s" % [id, prereq])
