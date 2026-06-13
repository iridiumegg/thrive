extends "res://tests/test_case.gd"

## Small hand-built recipe set so the engine tests don't depend on game content.
func _recipes() -> Dictionary:
	return {
		"cord": {
			"id": "cord", "station": "hand",
			"inputs": [{"item": "fiber", "qty": 2}],
			"outputs": [{"item": "cord", "qty": 1}],
			"craft_time": 2, "unlock": {"type": "default"},
		},
		"ingot": {
			"id": "ingot", "station": "forge",
			"inputs": [{"item": "ore", "qty": 2}],
			"outputs": [{"item": "ingot", "qty": 1}],
			"craft_time": 20, "unlock": {"type": "default"},
		},
		"cloak": {
			"id": "cloak", "station": "hand",
			"inputs": [{"item": "hide", "qty": 1}],
			"outputs": [{"item": "cloak", "qty": 1}],
			"craft_time": 5, "unlock": {"type": "blueprint"},
		},
	}

func _sys() -> CraftingSystem:
	return CraftingSystem.new(_recipes())

func test_can_craft_with_materials_and_station() -> void:
	var sys := _sys()
	var ok := sys.can_craft("cord", {"fiber": 2}, ["hand"], {})
	assert_true(ok["ok"], ok["reason"])

func test_missing_materials_blocks_and_reports_shortfall() -> void:
	var sys := _sys()
	var check := sys.can_craft("cord", {"fiber": 1}, ["hand"], {})
	assert_false(check["ok"])
	assert_eq(check["reason"], "Missing materials")
	assert_eq(sys.missing_inputs("cord", {"fiber": 1}), {"fiber": 1})

func test_station_requirement_enforced() -> void:
	var sys := _sys()
	assert_false(sys.can_craft("ingot", {"ore": 2}, ["hand"], {})["ok"], "forge recipe needs the forge")
	assert_true(sys.can_craft("ingot", {"ore": 2}, ["hand", "forge"], {})["ok"])

func test_hand_recipes_need_no_station() -> void:
	assert_true(_sys().station_ok("cord", ["hand"]))

func test_locked_recipe_requires_knowledge() -> void:
	var sys := _sys()
	assert_false(sys.is_unlocked("cloak", {}), "blueprint recipe unknown by default")
	assert_true(sys.is_unlocked("cloak", {"cloak": true}), "known once learned")
	assert_false(sys.can_craft("cloak", {"hide": 1}, ["hand"], {})["ok"])
	assert_true(sys.can_craft("cloak", {"hide": 1}, ["hand"], {"cloak": true})["ok"])

func test_default_recipes_always_unlocked() -> void:
	assert_true(_sys().is_unlocked("cord", {}))

func test_enqueue_then_tick_completes_after_craft_time() -> void:
	var sys := _sys()
	sys.enqueue("cord")
	assert_true(sys.is_busy())
	assert_true(sys.tick(1).is_empty(), "not done after 1 of 2 minutes")
	var done := sys.tick(1)
	assert_eq(done.size(), 1)
	assert_eq(done[0]["recipe_id"], "cord")
	assert_false(sys.is_busy(), "queue empties on completion")

func test_jobs_process_serially_and_carry_leftover_time() -> void:
	var sys := _sys()
	sys.enqueue("cord")   # 2 min
	sys.enqueue("cord")   # 2 min
	var done := sys.tick(5)   # enough for both, with 1 left over
	assert_eq(done.size(), 2, "both jobs finish within the budget")
	assert_false(sys.is_busy())

func test_partial_progress_is_tracked() -> void:
	var sys := _sys()
	var job := sys.enqueue("ingot")   # 20 min
	sys.tick(5)
	assert_almost(job.progress(), 0.25)

func test_default_quality_is_standard() -> void:
	var sys := _sys()
	sys.enqueue("cord")
	assert_eq(sys.tick(2)[0]["quality"], CraftingSystem.DEFAULT_QUALITY)

func test_cancel_active_removes_job() -> void:
	var sys := _sys()
	sys.enqueue("cord")
	var cancelled := sys.cancel_active()
	assert_eq(cancelled.recipe_id, "cord")
	assert_false(sys.is_busy())

func test_game_recipes_form_a_processing_chain() -> void:
	# Integration with real data: ore -> ingot -> iron tool requires the chain.
	var sys := CraftingSystem.new(_load_game_recipes())
	# Iron pickaxe needs iron_ingot, which is itself a forge craft from ore.
	var pick := sys.recipe("craft_iron_pickaxe")
	assert_false(pick.is_empty(), "iron pickaxe recipe exists")
	var needs_ingot := false
	for inp: Dictionary in pick["inputs"]:
		if inp["item"] == "iron_ingot":
			needs_ingot = true
	assert_true(needs_ingot, "iron pickaxe is downstream of smelting")
	assert_eq(String(sys.recipe("smelt_iron_ingot")["station"]), "forge")

func _load_game_recipes() -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in load_json("res://game/data/recipes.json"):
		out[String(entry["id"])] = entry
	return out
