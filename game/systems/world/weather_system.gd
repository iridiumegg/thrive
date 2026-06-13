## Weather as a seeded state machine. Pure logic, unit-testable.
##
## clear → cloudy → rain/snow → storm, with season-weighted transition odds.
## Each state lasts a randomised duration, then a weighted roll picks the next.
## Precipitation is reconciled with temperature at transition time: a "rain"
## roll becomes "snow" below the snow threshold (and vice versa), so winter is
## snowy and summer rainy without separate tables. The resulting effects
## (wind chill, wetness, temperature offset, darkness) feed the warmth model
## and the day/night lighting.
class_name WeatherSystem
extends RefCounted

var current: String
var minutes_until_change: int

var _data: Dictionary
var _states: Dictionary
var _transitions: Dictionary
var _rng: RandomNumberGenerator

func _init(weather_data: Dictionary, rng: RandomNumberGenerator) -> void:
	_data = weather_data
	_states = weather_data["states"]
	_transitions = weather_data["transitions"]
	_rng = rng
	current = String(weather_data.get("initial", "clear"))
	minutes_until_change = _roll_duration()

## Advance weather. Returns true on the tick the state changes. `ambient_c` and
## `season_index` decide rain-vs-snow and seasonal storminess.
func tick(minutes: int, ambient_c: float, season_index: int) -> bool:
	minutes_until_change -= minutes
	if minutes_until_change > 0:
		return false
	current = _pick_next(ambient_c, season_index)
	minutes_until_change = _roll_duration()
	return true

## { wind_chill_c, wetness, temp_offset_c, darkness } for the current state.
func effects() -> Dictionary:
	var s: Dictionary = _states[current]
	return {
		"wind_chill_c": float(s.get("wind_chill_c", 0.0)),
		"wetness": float(s.get("wetness", 0.0)),
		"temp_offset_c": float(s.get("temp_offset_c", 0.0)),
		"darkness": float(s.get("darkness", 0.0)),
	}

func display_name() -> String:
	return String(_states[current].get("name", current))

func is_precipitating() -> bool:
	return current in _data.get("precip_states", [])

## --- Internals ---

func _roll_duration() -> int:
	var d: Dictionary = _data["duration_minutes"]
	return _rng.randi_range(int(d["min"]), int(d["max"]))

func _pick_next(ambient_c: float, season_index: int) -> String:
	var candidates: Array = _transitions.get(current, [])
	if candidates.is_empty():
		return current
	var precip: Array = _data.get("precip_states", [])
	var mults: Array = _data.get("season_precip_multiplier", [])
	var season_mult := 1.0
	if not mults.is_empty():
		season_mult = float(mults[season_index % mults.size()])

	var total := 0.0
	var weights: Array[float] = []
	for c: Dictionary in candidates:
		var w := float(c.get("weight", 1.0))
		if String(c["to"]) in precip:
			w *= season_mult
		weights.append(w)
		total += w

	var pick := _rng.randf() * total
	var chosen := String(candidates[0]["to"])
	for i in candidates.size():
		pick -= weights[i]
		if pick <= 0.0:
			chosen = String(candidates[i]["to"])
			break
	return _reconcile_precip(chosen, ambient_c)

## Swap rain<->snow to match temperature.
func _reconcile_precip(state: String, ambient_c: float) -> String:
	var threshold := float(_data.get("snow_threshold_c", 1.0))
	if state == "rain" and ambient_c <= threshold:
		return "snow"
	if state == "snow" and ambient_c > threshold:
		return "rain"
	return state
