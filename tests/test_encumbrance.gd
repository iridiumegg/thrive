extends "res://tests/test_case.gd"

var cfg: Dictionary = {
	"heavy_threshold_fraction": 0.75,
	"encumbered_speed_min": 0.5,
	"encumbered_activity_max": 2.0,
}

func test_no_penalty_below_threshold() -> void:
	var f := Encumbrance.factors(0.5, cfg)
	assert_almost(f["speed_mult"], 1.0)
	assert_almost(f["activity_mult"], 1.0)

func test_no_penalty_exactly_at_threshold() -> void:
	var f := Encumbrance.factors(0.75, cfg)
	assert_almost(f["speed_mult"], 1.0)
	assert_almost(f["activity_mult"], 1.0)

func test_full_load_hits_worst_case() -> void:
	var f := Encumbrance.factors(1.0, cfg)
	assert_almost(f["speed_mult"], 0.5)
	assert_almost(f["activity_mult"], 2.0)

func test_midpoint_interpolates() -> void:
	# Halfway between threshold (0.75) and cap (1.0) is 0.875.
	var f := Encumbrance.factors(0.875, cfg)
	assert_almost(f["speed_mult"], 0.75)   # halfway 1.0 -> 0.5
	assert_almost(f["activity_mult"], 1.5) # halfway 1.0 -> 2.0

func test_overloaded_clamps_at_worst_case() -> void:
	var f := Encumbrance.factors(1.5, cfg)
	assert_almost(f["speed_mult"], 0.5)
	assert_almost(f["activity_mult"], 2.0)
