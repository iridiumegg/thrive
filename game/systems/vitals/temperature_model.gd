## Temperature math for the warmth sub-model. Pure static logic.
##
## ambient: what a thermometer would read outdoors (season + time of day;
##          weather joins in at Milestone 6).
## feels-like: ambient adjusted by clothing insulation, nearby heat sources,
##          wind chill, and wetness — the number the body actually experiences.
class_name TemperatureModel
extends RefCounted

## Fraction of the day at which temperature peaks (0.625 = 15:00).
const PEAK_TIME_FRACTION := 0.625

## Outdoor temperature for a given season and minute of the day.
## Follows a cosine curve: warmest mid-afternoon, coldest in the small hours.
static func ambient_c(season_index: int, minute_of_day: int, climate: Dictionary,
		minutes_per_day: int = 1440) -> float:
	var bases: Array = climate["season_base_c"]
	var base := float(bases[season_index % bases.size()])
	var amplitude := float(climate["diurnal_amplitude_c"])
	var peak_minute := PEAK_TIME_FRACTION * float(minutes_per_day)
	var phase := TAU * (float(minute_of_day) - peak_minute) / float(minutes_per_day)
	return base + amplitude * cos(phase)

## The temperature the body experiences, given an environment snapshot.
## env keys: ambient_c, insulation_c, heat_source_c, wind_chill_c, wetness (0-1).
static func feels_like_c(env: Dictionary, climate: Dictionary) -> float:
	var wetness_penalty := float(env.get("wetness", 0.0)) * float(climate["wetness_penalty_c"])
	return float(env.get("ambient_c", 0.0)) \
			+ float(env.get("insulation_c", 0.0)) \
			+ float(env.get("heat_source_c", 0.0)) \
			- float(env.get("wind_chill_c", 0.0)) \
			- wetness_penalty
