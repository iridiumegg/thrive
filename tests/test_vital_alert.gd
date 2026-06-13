extends "res://tests/test_case.gd"

const T := 0.15  # critical threshold fraction

func test_detects_a_need_crossing_into_critical() -> void:
	var prev := {"warmth": 0.2, "calories": 0.5}
	var curr := {"warmth": 0.1, "calories": 0.5}
	var alerts := VitalAlert.newly_critical(prev, curr, T)
	assert_true("warmth" in alerts)
	assert_false("calories" in alerts)

func test_no_alert_while_already_critical() -> void:
	var prev := {"warmth": 0.1}
	var curr := {"warmth": 0.05}
	assert_true(VitalAlert.newly_critical(prev, curr, T).is_empty(),
			"only the crossing fires, not every tick below the line")

func test_no_alert_when_staying_safe() -> void:
	assert_true(VitalAlert.newly_critical({"energy": 0.9}, {"energy": 0.8}, T).is_empty())

func test_recovery_detected_on_rising_back() -> void:
	var recovered := VitalAlert.recovered({"hydration": 0.1}, {"hydration": 0.2}, T)
	assert_true("hydration" in recovered)

func test_multiple_needs_can_alert_at_once() -> void:
	var prev := {"warmth": 0.2, "hydration": 0.2}
	var curr := {"warmth": 0.1, "hydration": 0.1}
	assert_eq(VitalAlert.newly_critical(prev, curr, T).size(), 2)
