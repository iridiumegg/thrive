extends "res://tests/test_case.gd"

## All expectations are computed from balance.json / afflictions.json so the
## suite stays valid when designers retune numbers (no hardcoded rates —
## the same rule the simulation itself follows).

var balance: Dictionary = load_json("res://game/data/balance.json")
var afflictions: Array = load_json("res://game/data/afflictions.json")
var v: Dictionary = balance["vitals"]
var climate: Dictionary = balance["climate"]

func _system() -> VitalsSystem:
	return VitalsSystem.new(balance, afflictions)

## Mild environment: no cold stress, no activity, awake.
func _warm_env() -> Dictionary:
	return {"ambient_c": float(climate["comfort_c"]) + 10.0, "activity": 1.0, "asleep": false}

func _cold_env(ambient: float) -> Dictionary:
	return {"ambient_c": ambient, "activity": 1.0, "asleep": false}

func test_baseline_drain_rates_match_balance() -> void:
	var sys := _system()
	var state := sys.new_state()
	sys.tick(state, _warm_env(), 60)
	assert_almost(state.calories, float(v["calories_max"]) - float(v["calories_drain_per_hour"]), 0.01)
	assert_almost(state.hydration, float(v["hydration_max"]) - float(v["hydration_drain_per_hour"]), 0.01)
	assert_almost(state.energy, float(v["energy_max"]) - float(v["energy_drain_per_hour_awake"]), 0.01)
	assert_almost(state.warmth, float(v["warmth_max"]), 0.01, "warmth stays full in a warm environment")
	assert_almost(state.condition, float(v["condition_max"]), 0.01, "condition stays full when healthy")

func test_activity_scales_calorie_and_hydration_drain() -> void:
	var sys := _system()
	var state := sys.new_state()
	var env := _warm_env()
	env["activity"] = float(v["activity_multiplier_moving"])
	sys.tick(state, env, 60)
	var mult := float(v["activity_multiplier_moving"])
	assert_almost(state.calories, float(v["calories_max"]) - float(v["calories_drain_per_hour"]) * mult, 0.01)
	assert_almost(state.hydration, float(v["hydration_max"]) - float(v["hydration_drain_per_hour"]) * mult, 0.01)

func test_cold_increases_calorie_burn() -> void:
	var sys := _system()
	var state := sys.new_state()
	sys.tick(state, _cold_env(float(climate["comfort_c"]) - 5.0), 60)
	var expected := float(v["calories_max"]) \
			- float(v["calories_drain_per_hour"]) * float(v["calories_cold_multiplier"])
	assert_almost(state.calories, expected, 0.01)

func test_sleep_restores_energy_and_slows_metabolism() -> void:
	var sys := _system()
	var state := sys.new_state()
	state.energy = float(v["energy_max"]) * 0.5
	var env := _warm_env()
	env["asleep"] = true
	sys.tick(state, env, 60)
	assert_almost(state.energy,
			float(v["energy_max"]) * 0.5 + float(v["energy_regen_per_hour_asleep"]), 0.01)
	var expected_calories := float(v["calories_max"]) \
			- float(v["calories_drain_per_hour"]) * float(v["sleep_metabolism_multiplier"])
	assert_almost(state.calories, expected_calories, 0.01)

func test_warmth_drains_proportional_to_cold_and_wetness_makes_it_worse() -> void:
	var sys := _system()
	var dry := sys.new_state()
	var ambient := float(climate["comfort_c"]) - 20.0
	sys.tick(dry, _cold_env(ambient), 60)
	var expected_dry := float(v["warmth_max"]) \
			- 20.0 * float(v["warmth_drain_per_degree_deficit_per_hour"])
	assert_almost(dry.warmth, expected_dry, 0.01)

	var wet := sys.new_state()
	var wet_env := _cold_env(ambient)
	wet_env["wetness"] = 1.0
	sys.tick(wet, wet_env, 60)
	assert_lt(wet.warmth, dry.warmth, "being wet must accelerate heat loss")

func test_needs_clamp_at_zero_and_condition_drains_per_critical_need() -> void:
	var sys := _system()
	var state := sys.new_state()
	state.calories = 0.0
	state.hydration = 0.0
	sys.tick(state, _warm_env(), 30)
	assert_eq(state.calories, 0.0)
	assert_eq(state.hydration, 0.0)
	var expected := float(v["condition_max"]) \
			- 2.0 * float(v["condition_drain_per_need_critical"]) * 0.5
	assert_almost(state.condition, expected, 0.01, "two bottomed needs stack their penalties")

func test_condition_regen_requires_adequate_needs_and_rest() -> void:
	var sys := _system()
	var rested := sys.new_state()
	rested.condition = 50.0
	sys.tick(rested, _warm_env(), 60)
	assert_almost(rested.condition, 50.0 + float(v["condition_regen_per_hour"]), 0.01)

	var weary := sys.new_state()
	weary.condition = 50.0
	weary.energy = float(v["energy_max"]) * float(v["rested_energy_fraction"]) - 1.0
	sys.tick(weary, _warm_env(), 60)
	assert_almost(weary.condition, 50.0, 0.01, "no regen when not rested, but no drain either")

func test_hypothermia_triggers_after_sustained_freezing_and_cures_after_sustained_warmth() -> void:
	var sys := _system()
	var state := sys.new_state()
	state.warmth = 0.0
	var freezing := _cold_env(float(climate["comfort_c"]) - 30.0)

	var trigger_minutes := int(_def("hypothermia")["trigger"]["sustained_minutes"])
	var events := sys.tick(state, freezing, trigger_minutes - 1)
	assert_false("affliction_started:hypothermia" in events, "not yet sustained long enough")
	events = sys.tick(state, freezing, 1)
	assert_true("affliction_started:hypothermia" in events)
	assert_true("hypothermia" in state.active_affliction_ids())
	assert_lt(sys.speed_multiplier(state), 1.0, "hypothermia slows movement")

	state.warmth = float(_def("hypothermia")["cure"]["above"]) + 10.0
	var cure_minutes := int(_def("hypothermia")["cure"]["sustained_minutes"])
	events = sys.tick(state, _warm_env(), cure_minutes)
	assert_true("affliction_ended:hypothermia" in events)
	assert_false("hypothermia" in state.active_affliction_ids())

func test_active_affliction_drains_condition() -> void:
	var sys := _system()
	var state := sys.new_state()
	state.warmth = 0.0
	var freezing := _cold_env(float(climate["comfort_c"]) - 30.0)
	sys.tick(state, freezing, int(_def("hypothermia")["trigger"]["sustained_minutes"]))
	var condition_after_trigger := state.condition
	sys.tick(state, freezing, 60)
	var expected_drop := float(v["condition_drain_per_need_critical"]) \
			+ float(_def("hypothermia")["effects"]["condition_drain_per_hour"])
	assert_almost(state.condition, condition_after_trigger - expected_drop, 0.01,
			"critical warmth + hypothermia drains stack")

func test_death_at_zero_condition() -> void:
	var sys := _system()
	var state := sys.new_state()
	state.condition = 1.0
	state.calories = 0.0
	state.hydration = 0.0
	state.energy = 0.0
	var events := sys.tick(state, _warm_env(), 60)
	assert_true("died" in events)
	assert_false(state.alive)
	assert_eq(state.condition, 0.0)

func test_eat_and_drink_clamp_at_max() -> void:
	var sys := _system()
	var state := sys.new_state()
	state.calories = float(v["calories_max"]) - 100.0
	sys.eat(state, 600.0)
	assert_eq(state.calories, float(v["calories_max"]), "overeating is capped at max")
	state.hydration = 50.0
	sys.drink(state, 1000.0)
	assert_eq(state.hydration, float(v["hydration_max"]))

func _def(id: String) -> Dictionary:
	for def: Dictionary in afflictions:
		if def["id"] == id:
			return def
	return {}
