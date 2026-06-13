extends "res://tests/test_case.gd"

## Serializes each pure system, pushes it through real JSON stringify/parse
## (catching any non-JSON-safe values), and restores it — the backbone of the
## save system.

func _through_json(data: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(data))

func _catalog() -> Dictionary:
	var cat: Dictionary = {}
	for entry: Dictionary in load_json("res://game/data/items.json"):
		cat[String(entry["id"])] = ItemDef.from_dict(entry)
	return cat

func test_inventory_survives_json_round_trip() -> void:
	var inv := Inventory.new(24, 40.0, _catalog())
	inv.add("branch", 7)
	inv.add("flint_stone", 3)
	var data: Array = _through_json(inv.to_data())
	var restored := Inventory.new(24, 40.0, _catalog())
	restored.load_data(data)
	assert_eq(restored.count("branch"), 7)
	assert_eq(restored.count("flint_stone"), 3)

func test_vitals_state_round_trip() -> void:
	var s := VitalsState.new()
	s.calories = 1234.5
	s.warmth = 50.0
	s.afflictions = {"hypothermia": {"active": true, "trigger_minutes": 30.0, "cure_minutes": 0.0}}
	var data: Dictionary = _through_json(s.to_data())
	var restored := VitalsState.new()
	restored.load_data(data)
	assert_almost(restored.calories, 1234.5)
	assert_true(restored.afflictions["hypothermia"]["active"])

func test_skills_round_trip() -> void:
	var cfg := {"lines": ["gathering", "smithing"], "xp_curve_base": 50, "xp_curve_exp": 1.6, "max_level": 20}
	var s := SkillSystem.new(cfg)
	s.add_xp("gathering", 320)
	var data: Dictionary = _through_json(s.to_data())
	var restored := SkillSystem.new(cfg)
	restored.load_data(data)
	assert_eq(restored.xp("gathering"), 320)

func test_quests_round_trip() -> void:
	var defs := {"q": {"id": "q", "objectives": [{"id": "o", "type": "gather", "target": "x", "count": 3}]}}
	var s := QuestSystem.new(defs)
	s.activate("q")
	s.record("gather", {"item": "x", "qty": 2})
	var data: Dictionary = _through_json(s.to_data())
	var restored := QuestSystem.new(defs)
	restored.load_data(data)
	assert_true(restored.is_active("q"))
	assert_eq(restored.progress_of("q", "o"), 2)

func test_flags_and_relationships_round_trip() -> void:
	var flags := FlagStore.new()
	flags.set_flag("settled")
	flags.set_var("ending", "stay")
	var f2 := FlagStore.new()
	f2.load_data(_through_json(flags.to_data()))
	assert_true(f2.has_flag("settled"))
	assert_eq(String(f2.get_var("ending")), "stay")

	var rel := RelationshipStore.new([{"name": "Stranger", "min": 0}, {"name": "Friend", "min": 30}], 100)
	rel.add("pell", 45)
	var r2 := RelationshipStore.new([{"name": "Stranger", "min": 0}, {"name": "Friend", "min": 30}], 100)
	r2.load_data(_through_json(rel.to_data()))
	assert_eq(r2.value("pell"), 45)
	assert_eq(r2.level_name("pell"), "Friend")

func test_crafting_queue_round_trip() -> void:
	var recipes := {"r": {"id": "r", "craft_time": 10, "inputs": [], "outputs": []}}
	var s := CraftingSystem.new(recipes)
	s.enqueue("r", "fine")
	s.tick(3)
	var data: Array = _through_json(s.to_data())
	var restored := CraftingSystem.new(recipes)
	restored.load_data(data)
	assert_true(restored.is_busy())
	assert_eq(restored.active_job().remaining, 7)
	assert_eq(restored.active_job().quality, "fine")
