## Environment service (autoload "Env").
##
## Owns the live weather state machine and the biome map, ticking weather off
## the sim clock. Other systems read the current environment here: the vitals
## warmth model pulls wind chill / wetness / temperature offsets, the world pulls
## darkness for day/night-plus-weather lighting, and spawners ask which biome a
## position belongs to. Centralising this keeps those systems decoupled.
extends Node

const WEATHER_PATH := "res://game/data/weather.json"
const BIOMES_PATH := "res://game/data/biomes.json"
const TILE_SIZE := 16

var weather: WeatherSystem
var biomes: BiomeMap

func _ready() -> void:
	reset()
	EventBus.sim_minute.connect(_on_sim_minute)

## (Re)create weather + biomes from the world seed. Called on a fresh run.
func reset() -> void:
	var seed_value := int(Balance.data["world_seed"])
	var rng := SeededRng.new(seed_value).stream("weather")
	weather = WeatherSystem.new(Balance.load_json(WEATHER_PATH), rng)
	biomes = BiomeMap.new(Balance.load_json(BIOMES_PATH), seed_value, TILE_SIZE)

func _on_sim_minute(minutes: int) -> void:
	if weather.tick(minutes, base_ambient_c(), Sim.clock.season_index()):
		EventBus.weather_changed.emit(weather.current, weather.display_name())

## Outdoor temperature from season + time of day only (no biome/weather), used
## internally to decide rain vs snow.
func base_ambient_c() -> float:
	return TemperatureModel.ambient_c(
		Sim.clock.season_index(),
		Sim.clock.minute_of_day(),
		Balance.data["climate"],
		int(Balance.data["time"]["minutes_per_day"]))

## Ambient temperature a thermometer would read at a position right now:
## season + time of day + biome offset + weather offset.
func ambient_c_at(world_position: Vector2) -> float:
	return base_ambient_c() \
			+ biomes.temp_offset_at(world_position) \
			+ weather.effects()["temp_offset_c"]

func weather_effects() -> Dictionary:
	return weather.effects()

func biome_at(world_position: Vector2) -> Dictionary:
	return biomes.biome_at(world_position)

## Combined darkness 0..1 from night-time and current weather, for lighting.
func darkness() -> float:
	return clampf(_night_darkness() + weather.effects()["darkness"], 0.0, 0.75)

func _night_darkness() -> float:
	# Smooth dark band centred on the small hours, peaking ~0.5 at deep night.
	var frac := float(Sim.clock.minute_of_day()) / float(Sim.clock.minutes_per_day)
	# cos peaks at midnight (frac 0) — shift so trough is midday.
	return clampf(0.27 + 0.27 * cos(TAU * frac), 0.0, 0.55)
