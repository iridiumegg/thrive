## Fixed-step simulation driver (autoload "Sim").
##
## Converts real frame time into discrete in-game minutes: 1 sim tick = 1
## in-game minute, regardless of framerate. The day length (20 real minutes
## per full day/night cycle) comes from balance.json, never from code.
## Systems subscribe to EventBus.sim_minute rather than _process so the whole
## simulation advances on one shared, deterministic step.
extends Node

var clock: GameClock

## Real-time multiplier for debugging / sleeping (1.0 = normal speed).
var time_scale: float = 1.0
var paused: bool = false

var _accumulator: float = 0.0
var _seconds_per_game_minute: float = 1.0
var _last_day: int = 0
var _last_season: int = 0

func _ready() -> void:
	reset_clock()

## Start a fresh in-game clock (called by the world scene on a new run).
func reset_clock() -> void:
	var time_cfg: Dictionary = Balance.data["time"]
	_seconds_per_game_minute = float(time_cfg["day_length_real_minutes"]) * 60.0 \
			/ float(time_cfg["minutes_per_day"])
	clock = GameClock.new(time_cfg)
	time_scale = 1.0
	paused = false
	_accumulator = 0.0
	_last_day = clock.day_index()
	_last_season = clock.season_index()

func _process(delta: float) -> void:
	if paused:
		return
	_accumulator += delta * time_scale
	while _accumulator >= _seconds_per_game_minute:
		_accumulator -= _seconds_per_game_minute
		_step_minute()

func _step_minute() -> void:
	clock.advance(1)
	EventBus.sim_minute.emit(1)
	if clock.day_index() != _last_day:
		_last_day = clock.day_index()
		EventBus.day_advanced.emit(_last_day)
	if clock.season_index() != _last_season:
		_last_season = clock.season_index()
		EventBus.season_changed.emit(clock.season_name())
