## The core survival simulation: four interlocking needs draining a single
## Condition pool, plus data-driven afflictions. Pure logic — runs headless,
## unit-tested, knows nothing about nodes, rendering, or input.
##
## Every rate comes from balance.json (passed in as a Dictionary); affliction
## definitions come from afflictions.json. Zero hardcoded numbers.
##
## Usage:
##   var sys := VitalsSystem.new(Balance.data, Balance.afflictions)
##   var state := sys.new_state()
##   var events := sys.tick(state, env, minutes)   # once per sim minute
##
## `env` snapshot keys (all optional, sane defaults):
##   ambient_c, insulation_c, heat_source_c, wind_chill_c, wetness (0-1),
##   activity (drain multiplier, 1.0 = idle), asleep (bool)
##
## `tick` returns an Array of event strings for the caller to translate into
## signals: "affliction_started:<id>", "affliction_ended:<id>", "died".
class_name VitalsSystem
extends RefCounted

var _v: Dictionary       # the "vitals" section of balance.json
var _climate: Dictionary # the "climate" section of balance.json
var _affliction_defs: Array

func _init(balance: Dictionary, affliction_defs: Array) -> void:
	_v = balance["vitals"]
	_climate = balance["climate"]
	_affliction_defs = affliction_defs

## A freshly spawned survivor: every need full, perfect condition.
func new_state() -> VitalsState:
	var s := VitalsState.new()
	s.calories = float(_v["calories_max"])
	s.hydration = float(_v["hydration_max"])
	s.energy = float(_v["energy_max"])
	s.warmth = float(_v["warmth_max"])
	s.condition = float(_v["condition_max"])
	for def: Dictionary in _affliction_defs:
		s.afflictions[def["id"]] = {"active": false, "trigger_minutes": 0.0, "cure_minutes": 0.0}
	return s

## Advance the simulation by `minutes` in-game minutes (stepped 1 minute at a
## time so threshold crossings and sustained-timers stay exact).
func tick(state: VitalsState, env: Dictionary, minutes: int) -> Array[String]:
	var events: Array[String] = []
	for _i in minutes:
		if not state.alive:
			break
		_step_one_minute(state, env, events)
	return events

func _step_one_minute(state: VitalsState, env: Dictionary, events: Array[String]) -> void:
	var asleep: bool = env.get("asleep", false)
	var activity := float(env.get("activity", 1.0))
	var metabolism := float(_v["sleep_metabolism_multiplier"]) if asleep else 1.0

	# -- Warmth: compare feels-like temperature against the comfort threshold.
	var feels_like := TemperatureModel.feels_like_c(env, _climate)
	var cold_deficit := float(_climate["comfort_c"]) - feels_like
	if cold_deficit > 0.0:
		state.warmth -= cold_deficit * float(_v["warmth_drain_per_degree_deficit_per_hour"]) / 60.0
	else:
		state.warmth += float(_v["warmth_regen_per_hour_when_warm"]) / 60.0

	# -- Calories: baseline drain, scaled up by activity, cold, and metabolism.
	var calorie_drain := float(_v["calories_drain_per_hour"]) * activity * metabolism
	if cold_deficit > 0.0:
		calorie_drain *= float(_v["calories_cold_multiplier"])
	state.calories -= calorie_drain / 60.0

	# -- Hydration: drains faster than hunger, scaled by activity.
	state.hydration -= float(_v["hydration_drain_per_hour"]) * activity * metabolism / 60.0

	# -- Energy: drains awake, recovers asleep.
	if asleep:
		state.energy += float(_v["energy_regen_per_hour_asleep"]) / 60.0
	else:
		state.energy -= float(_v["energy_drain_per_hour_awake"]) / 60.0

	_clamp_needs(state)

	# -- Afflictions: data-driven triggers/cures with sustained-time windows.
	var affliction_drain_per_hour := _update_afflictions(state, events)

	# -- Condition: drains while any need is bottomed out (penalties stack),
	#    regenerates only when everything is adequately met AND rested.
	var critical_count := 0
	for stat in ["calories", "hydration", "energy", "warmth"]:
		if state.get_stat(stat) <= 0.0:
			critical_count += 1
	var delta := -critical_count * float(_v["condition_drain_per_need_critical"]) / 60.0
	delta -= affliction_drain_per_hour / 60.0
	if critical_count == 0 and _is_adequately_met(state) and _is_rested(state):
		delta += float(_v["condition_regen_per_hour"]) / 60.0
	state.condition = clampf(state.condition + delta, 0.0, float(_v["condition_max"]))

	if state.condition <= 0.0 and state.alive:
		state.alive = false
		events.append("died")

## Returns the summed condition drain (per hour) of all active afflictions,
## after updating each affliction's trigger/cure timers for this minute.
func _update_afflictions(state: VitalsState, events: Array[String]) -> float:
	var total_drain := 0.0
	for def: Dictionary in _affliction_defs:
		var id: String = def["id"]
		var st: Dictionary = state.afflictions[id]
		if st["active"]:
			var cure: Dictionary = def["cure"]
			if state.get_stat(cure["stat"]) > float(cure["above"]):
				st["cure_minutes"] = float(st["cure_minutes"]) + 1.0
				if st["cure_minutes"] >= maxf(1.0, float(cure["sustained_minutes"])):
					st["active"] = false
					st["trigger_minutes"] = 0.0
					st["cure_minutes"] = 0.0
					events.append("affliction_ended:" + id)
					continue
			else:
				st["cure_minutes"] = 0.0
			total_drain += float(def["effects"].get("condition_drain_per_hour", 0.0))
		else:
			var trig: Dictionary = def["trigger"]
			if state.get_stat(trig["stat"]) < float(trig["below"]):
				st["trigger_minutes"] = float(st["trigger_minutes"]) + 1.0
				if st["trigger_minutes"] >= maxf(1.0, float(trig["sustained_minutes"])):
					st["active"] = true
					st["cure_minutes"] = 0.0
					events.append("affliction_started:" + id)
					total_drain += float(def["effects"].get("condition_drain_per_hour", 0.0))
			else:
				st["trigger_minutes"] = 0.0
	return total_drain

## Movement-speed multiplier from active afflictions (product of all penalties).
func speed_multiplier(state: VitalsState) -> float:
	var mult := 1.0
	for def: Dictionary in _affliction_defs:
		if state.afflictions[def["id"]]["active"]:
			mult *= float(def["effects"].get("speed_multiplier", 1.0))
	return mult

## --- Need restoration (food/water items will route through these later) ---

func eat(state: VitalsState, kcal: float) -> void:
	state.calories = clampf(state.calories + kcal, 0.0, float(_v["calories_max"]))

func drink(state: VitalsState, pct: float) -> void:
	state.hydration = clampf(state.hydration + pct, 0.0, float(_v["hydration_max"]))

## --- Queries used by UI / gameplay ---

func need_fraction(state: VitalsState, stat: String) -> float:
	return state.get_stat(stat) / max_value(stat)

func max_value(stat: String) -> float:
	return float(_v[stat + "_max"])

func affliction_def(id: String) -> Dictionary:
	for def: Dictionary in _affliction_defs:
		if def["id"] == id:
			return def
	return {}

## --- Internals ---

func _clamp_needs(state: VitalsState) -> void:
	state.calories = clampf(state.calories, 0.0, float(_v["calories_max"]))
	state.hydration = clampf(state.hydration, 0.0, float(_v["hydration_max"]))
	state.energy = clampf(state.energy, 0.0, float(_v["energy_max"]))
	state.warmth = clampf(state.warmth, 0.0, float(_v["warmth_max"]))

func _is_adequately_met(state: VitalsState) -> bool:
	var threshold := float(_v["adequate_need_fraction"])
	for stat in ["calories", "hydration", "energy", "warmth"]:
		if need_fraction(state, stat) < threshold:
			return false
	return true

func _is_rested(state: VitalsState) -> bool:
	return need_fraction(state, "energy") >= float(_v["rested_energy_fraction"])
