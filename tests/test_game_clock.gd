extends "res://tests/test_case.gd"

func _make_clock() -> GameClock:
	return GameClock.new({
		"minutes_per_day": 1440,
		"days_per_season": 2,
		"seasons": ["Frostmelt", "Highsun"],
		"start_hour": 8,
	})

func test_starts_at_start_hour() -> void:
	var clock := _make_clock()
	assert_eq(clock.hour(), 8)
	assert_eq(clock.minute(), 0)
	assert_eq(clock.day_index(), 0)
	assert_eq(clock.format_time(), "08:00")

func test_minute_and_hour_rollover() -> void:
	var clock := _make_clock()
	clock.advance(59)
	assert_eq(clock.hour(), 8)
	assert_eq(clock.minute(), 59)
	clock.advance(1)
	assert_eq(clock.hour(), 9)
	assert_eq(clock.minute(), 0)

func test_day_rollover() -> void:
	var clock := _make_clock()
	clock.advance(1440)
	assert_eq(clock.day_index(), 1)
	assert_eq(clock.hour(), 8, "same wall-clock hour next day")

func test_season_rollover_and_wrap() -> void:
	var clock := _make_clock()
	assert_eq(clock.season_name(), "Frostmelt")
	clock.advance(1440 * 2)
	assert_eq(clock.season_index(), 1)
	assert_eq(clock.season_name(), "Highsun")
	assert_eq(clock.day_of_season(), 1)
	clock.advance(1440 * 2)
	assert_eq(clock.season_index(), 0, "seasons wrap around the year")

func test_night_detection() -> void:
	var clock := _make_clock()
	assert_false(clock.is_night(), "08:00 is daytime")
	clock.advance(15 * 60)  # 23:00
	assert_true(clock.is_night())
	clock.advance(4 * 60)   # 03:00
	assert_true(clock.is_night())
