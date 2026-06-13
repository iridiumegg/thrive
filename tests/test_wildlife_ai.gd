extends "res://tests/test_case.gd"

func _timid() -> Dictionary:
	return {"aggressive": false, "detect_range": 80.0, "attack_range": 0.0, "flee_health": 0.5}

func _predator() -> Dictionary:
	return {"aggressive": true, "detect_range": 120.0, "attack_range": 18.0, "flee_health": 0.25}

func _p(overrides: Dictionary) -> Dictionary:
	var base := {"distance": 1000.0, "health_fraction": 1.0, "has_deterrent": false,
			"player_in_shelter": false, "time_is_active": true}
	base.merge(overrides, true)
	return base

func test_timid_idles_when_player_is_far() -> void:
	var s := WildlifeAI.decide(WildlifeAI.State.IDLE, _p({"distance": 300.0}), _timid())
	assert_eq(s, WildlifeAI.State.IDLE)

func test_timid_flees_when_player_is_near() -> void:
	var s := WildlifeAI.decide(WildlifeAI.State.IDLE, _p({"distance": 40.0}), _timid())
	assert_eq(s, WildlifeAI.State.FLEE)

func test_predator_attacks_in_range_at_active_time() -> void:
	var s := WildlifeAI.decide(WildlifeAI.State.IDLE, _p({"distance": 60.0}), _predator())
	assert_eq(s, WildlifeAI.State.ATTACK)

func test_fire_deterrent_downgrades_attack_to_investigate() -> void:
	var s := WildlifeAI.decide(WildlifeAI.State.ATTACK,
			_p({"distance": 60.0, "has_deterrent": true}), _predator())
	assert_eq(s, WildlifeAI.State.INVESTIGATE, "a fire keeps the predator at bay")

func test_shelter_makes_player_untargetable() -> void:
	var s := WildlifeAI.decide(WildlifeAI.State.ATTACK,
			_p({"distance": 10.0, "player_in_shelter": true}), _predator())
	assert_eq(s, WildlifeAI.State.IDLE)

func test_predator_idle_outside_its_active_time() -> void:
	var s := WildlifeAI.decide(WildlifeAI.State.IDLE,
			_p({"distance": 30.0, "time_is_active": false}), _predator())
	assert_eq(s, WildlifeAI.State.IDLE, "a nocturnal hunter rests by day")

func test_wounded_predator_flees() -> void:
	var s := WildlifeAI.decide(WildlifeAI.State.ATTACK,
			_p({"distance": 20.0, "health_fraction": 0.1}), _predator())
	assert_eq(s, WildlifeAI.State.FLEE)

func test_strike_range_check() -> void:
	assert_true(WildlifeAI.in_strike_range(17.0, _predator()))
	assert_false(WildlifeAI.in_strike_range(40.0, _predator()))

func test_real_wildlife_loot_tables_exist() -> void:
	var loot: Dictionary = load_json("res://game/data/loot_tables.json")
	for creature: Dictionary in load_json("res://game/data/wildlife.json"):
		assert_true(loot.has(String(creature["loot_table"])),
				"%s references missing loot table" % creature["id"])
