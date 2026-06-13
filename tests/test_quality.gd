extends "res://tests/test_case.gd"

# Uses the real tiers from balance.json so the test guards live tuning too.
func _tiers() -> Array:
	return load_json("res://game/data/balance.json")["crafting"]["quality_tiers"]

func test_low_skill_is_lowest_tier() -> void:
	var tier := Quality.tier_for_level(_tiers(), 0)
	assert_eq(String(tier["id"]), "crude")

func test_tier_climbs_with_skill() -> void:
	var tiers := _tiers()
	assert_eq(String(Quality.tier_for_level(tiers, 3)["id"]), "standard")
	assert_eq(String(Quality.tier_for_level(tiers, 7)["id"]), "fine")
	assert_eq(String(Quality.tier_for_level(tiers, 12)["id"]), "masterwork")
	assert_eq(String(Quality.tier_for_level(tiers, 99)["id"]), "masterwork", "caps at the top tier")

func test_just_below_threshold_stays_lower_tier() -> void:
	assert_eq(String(Quality.tier_for_level(_tiers(), 6)["id"]), "standard",
			"level 6 is below the Fine threshold of 7")

func test_tier_lookup_by_id() -> void:
	assert_eq(String(Quality.tier_by_id(_tiers(), "fine")["name"]), "Fine")
	assert_true(Quality.tier_by_id(_tiers(), "nope").is_empty())

func test_multipliers_increase_with_tier() -> void:
	var tiers := _tiers()
	var crude := Quality.tier_by_id(tiers, "crude")
	var master := Quality.tier_by_id(tiers, "masterwork")
	assert_true(Quality.durability_mult(crude) < 1.0, "crude tools are flimsier")
	assert_true(Quality.durability_mult(master) > 1.0, "masterwork tools last longer")
	assert_true(Quality.bonus_output_chance(master) >= Quality.bonus_output_chance(crude))
