extends "res://tests/test_case.gd"

var climate: Dictionary = {
	"season_base_c": [4.0, 14.0, 2.0, -12.0],
	"diurnal_amplitude_c": 6.0,
	"comfort_c": 10.0,
	"wetness_penalty_c": 10.0,
}

func test_ambient_peaks_mid_afternoon_and_bottoms_before_dawn() -> void:
	var peak_minute := int(TemperatureModel.PEAK_TIME_FRACTION * 1440.0)
	var trough_minute := (peak_minute + 720) % 1440
	assert_almost(TemperatureModel.ambient_c(0, peak_minute, climate), 4.0 + 6.0)
	assert_almost(TemperatureModel.ambient_c(0, trough_minute, climate), 4.0 - 6.0)

func test_seasons_shift_the_baseline() -> void:
	var peak_minute := int(TemperatureModel.PEAK_TIME_FRACTION * 1440.0)
	assert_almost(TemperatureModel.ambient_c(3, peak_minute, climate), -12.0 + 6.0,
			0.001, "deep winter is cold even at the day's warmest")

func test_season_index_wraps() -> void:
	var at_noonish := int(TemperatureModel.PEAK_TIME_FRACTION * 1440.0)
	assert_almost(
			TemperatureModel.ambient_c(4, at_noonish, climate),
			TemperatureModel.ambient_c(0, at_noonish, climate))

func test_feels_like_combines_all_factors() -> void:
	var env := {
		"ambient_c": 0.0,
		"insulation_c": 8.0,
		"heat_source_c": 18.0,
		"wind_chill_c": 5.0,
		"wetness": 0.5,
	}
	# 0 + 8 + 18 - 5 - (0.5 * 10) = 16
	assert_almost(TemperatureModel.feels_like_c(env, climate), 16.0)

func test_feels_like_defaults_missing_keys_to_zero() -> void:
	assert_almost(TemperatureModel.feels_like_c({"ambient_c": 7.0}, climate), 7.0)
