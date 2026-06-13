extends "res://tests/test_case.gd"

func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

func _def(success: float) -> Dictionary:
	return {"catch_minutes": 240, "success_chance": success}

func _loot() -> Dictionary:
	return {"guaranteed": [{"item": "raw_meat", "min": 1, "max": 1}]}

func test_starts_empty() -> void:
	var t := Trap.new(_def(1.0), _loot())
	assert_true(t.state == Trap.State.EMPTY)
	assert_false(t.is_armed())

func test_armed_trap_catches_after_interval_when_successful() -> void:
	var t := Trap.new(_def(1.0), _loot())
	t.arm()
	assert_false(t.tick(239, _rng(1)), "no catch before the interval")
	assert_true(t.is_armed())
	assert_true(t.tick(1, _rng(1)), "catch lands at the interval")
	assert_true(t.is_caught())

func test_failed_check_empties_the_trap() -> void:
	var t := Trap.new(_def(0.0), _loot())  # never succeeds
	t.arm()
	assert_false(t.tick(240, _rng(1)))
	assert_false(t.is_caught())
	assert_true(t.state == Trap.State.EMPTY, "a failed check loses the bait")

func test_collect_returns_loot_and_resets() -> void:
	var t := Trap.new(_def(1.0), _loot())
	t.arm()
	t.tick(240, _rng(1))
	var loot := t.collect()
	assert_true(loot.has("raw_meat"))
	assert_true(t.state == Trap.State.EMPTY, "collecting resets the trap")
	assert_true(t.collect().is_empty(), "nothing left to collect")

func test_idle_trap_does_not_tick() -> void:
	var t := Trap.new(_def(1.0), _loot())
	assert_false(t.tick(10000, _rng(1)), "an unbaited trap never catches")
	assert_true(t.state == Trap.State.EMPTY)

func test_rearm_resets_timer() -> void:
	var t := Trap.new(_def(0.0), _loot())
	t.arm()
	t.tick(240, _rng(1))   # fails -> EMPTY
	t.arm()                 # re-bait
	assert_true(t.is_armed())
	assert_eq(t.elapsed, 0, "re-arming resets the catch timer")
