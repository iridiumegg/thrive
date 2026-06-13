## Engine-side adapter that runs the pure VitalsSystem for the player.
##
## Each sim minute it snapshots the environment (ambient temperature from the
## clock, insulation, campfire, activity level), advances the simulation, and
## republishes results as EventBus signals for the UI and other systems.
## Wind chill and wetness are wired but fed zeros until the weather system
## arrives (Milestone 6).
class_name VitalsComponent
extends Node

var system: VitalsSystem
var state: VitalsState

## Debug/world toggles (set by the world scene for now; real shelter, fires,
## and beds will drive these in later milestones).
var asleep: bool = false
var campfire_on: bool = false

## Cached movement-speed multiplier from afflictions; the player reads this.
var speed_mult: float = 1.0

var _player: CharacterBody2D

func setup(player: CharacterBody2D) -> void:
	_player = player

func _ready() -> void:
	system = VitalsSystem.new(Balance.data, Balance.afflictions)
	state = system.new_state()
	EventBus.sim_minute.connect(_on_sim_minute)
	EventBus.vitals_changed.emit(state)

func _on_sim_minute(minutes: int) -> void:
	if not state.alive:
		return
	var events := system.tick(state, _build_env(), minutes)
	speed_mult = system.speed_multiplier(state)
	EventBus.vitals_changed.emit(state)
	for event in events:
		var parts := event.split(":")
		match parts[0]:
			"affliction_started":
				EventBus.affliction_started.emit(parts[1])
			"affliction_ended":
				EventBus.affliction_ended.emit(parts[1])
			"died":
				EventBus.player_died.emit()

func _build_env() -> Dictionary:
	var time_cfg: Dictionary = Balance.data["time"]
	var vitals_cfg: Dictionary = Balance.data["vitals"]
	var climate: Dictionary = Balance.data["climate"]
	var moving := not asleep and _player != null and _player.velocity.length_squared() > 1.0
	return {
		"ambient_c": ambient_c(),
		"insulation_c": float(Balance.data["player"]["starting_insulation_c"]),
		"heat_source_c": float(climate["campfire_bonus_c"]) if campfire_on else 0.0,
		"wind_chill_c": 0.0,
		"wetness": 0.0,
		"activity": float(vitals_cfg["activity_multiplier_moving"]) if moving \
				else float(vitals_cfg["activity_multiplier_idle"]),
		"asleep": asleep,
	}

func ambient_c() -> float:
	return TemperatureModel.ambient_c(
		Sim.clock.season_index(),
		Sim.clock.minute_of_day(),
		Balance.data["climate"],
		int(Balance.data["time"]["minutes_per_day"]))

## --- Debug actions (stand-ins until food/water items exist) ---

func debug_eat() -> void:
	system.eat(state, float(Balance.data["debug"]["eat_kcal"]))
	EventBus.vitals_changed.emit(state)

func debug_drink() -> void:
	system.drink(state, float(Balance.data["debug"]["drink_pct"]))
	EventBus.vitals_changed.emit(state)
