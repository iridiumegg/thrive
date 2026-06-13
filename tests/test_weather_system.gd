extends "res://tests/test_case.gd"

var data: Dictionary = load_json("res://game/data/weather.json")

func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _sys(seed_value: int = 1) -> WeatherSystem:
	return WeatherSystem.new(data, _rng(seed_value))

func test_starts_in_initial_state() -> void:
	assert_eq(_sys().current, String(data["initial"]))

func test_no_change_before_duration_elapses() -> void:
	var sys := _sys()
	var before := sys.current
	var changed := sys.tick(10, 10.0, 0)
	assert_false(changed, "weather holds until its duration runs out")
	assert_eq(sys.current, before)

func test_transitions_only_to_declared_states() -> void:
	var sys := _sys(5)
	var valid: Array = data["states"].keys()
	for _i in 200:
		sys.tick(1000, 8.0, 1)  # force frequent changes
		assert_true(sys.current in valid, "state %s is declared" % sys.current)

func test_warm_precip_is_rain_cold_precip_is_snow() -> void:
	# Drive many transitions warm, then cold, and check precип type matches.
	var warm := _sys(3)
	var saw_rain := false
	var saw_snow_when_warm := false
	for _i in 300:
		warm.tick(1000, 12.0, 1)
		if warm.current == "rain":
			saw_rain = true
		if warm.current == "snow":
			saw_snow_when_warm = true
	assert_true(saw_rain, "warm weather should produce rain")
	assert_false(saw_snow_when_warm, "it should never snow when well above freezing")

	var cold := _sys(3)
	var saw_snow := false
	var saw_rain_when_cold := false
	for _i in 300:
		cold.tick(1000, -10.0, 3)
		if cold.current == "snow":
			saw_snow = true
		if cold.current == "rain":
			saw_rain_when_cold = true
	assert_true(saw_snow, "hard cold should produce snow")
	assert_false(saw_rain_when_cold, "it should never rain in hard cold")

func test_effects_expose_expected_keys() -> void:
	var fx := _sys().effects()
	for key in ["wind_chill_c", "wetness", "temp_offset_c", "darkness"]:
		assert_true(fx.has(key), "effects include %s" % key)

func test_deterministic_for_same_seed() -> void:
	var a := _sys(77)
	var b := _sys(77)
	for _i in 50:
		a.tick(100, 5.0, 2)
		b.tick(100, 5.0, 2)
		assert_eq(a.current, b.current)
