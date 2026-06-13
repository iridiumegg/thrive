## In-game calendar/clock. Pure logic — no engine nodes, fully unit-testable.
##
## Time is stored as a single integer: total in-game minutes elapsed since the
## start of day 0 (offset by the configured start hour). Everything else
## (hour, day, season) is derived, so the clock can never drift or desync.
class_name GameClock
extends RefCounted

var minutes_per_day: int
var days_per_season: int
var season_names: PackedStringArray
var night_start_hour: int = 22
var night_end_hour: int = 6

## Total in-game minutes elapsed (includes the start-hour offset).
var total_minutes: int = 0

func _init(time_cfg: Dictionary) -> void:
	minutes_per_day = int(time_cfg.get("minutes_per_day", 1440))
	days_per_season = int(time_cfg.get("days_per_season", 14))
	season_names = PackedStringArray(time_cfg.get("seasons", ["Spring", "Summer", "Autumn", "Winter"]))
	total_minutes = int(time_cfg.get("start_hour", 8)) * 60

func advance(minutes: int) -> void:
	total_minutes += minutes

func minute_of_day() -> int:
	return total_minutes % minutes_per_day

func hour() -> int:
	@warning_ignore("integer_division")
	return minute_of_day() / 60

func minute() -> int:
	return minute_of_day() % 60

func day_index() -> int:
	@warning_ignore("integer_division")
	return total_minutes / minutes_per_day

## Day number within the current season, starting at 1 (for display).
func day_of_season() -> int:
	return day_index() % days_per_season + 1

func season_index() -> int:
	@warning_ignore("integer_division")
	return (day_index() / days_per_season) % season_names.size()

func season_name() -> String:
	return season_names[season_index()]

func is_night() -> bool:
	return hour() >= night_start_hour or hour() < night_end_hour

func format_time() -> String:
	return "%02d:%02d" % [hour(), minute()]
