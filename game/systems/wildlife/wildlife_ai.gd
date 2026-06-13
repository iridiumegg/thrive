## Wildlife behaviour: a small state machine. Pure logic, unit-testable.
##
## Survival-flavored (spec 15): avoidance, deterrents, and shelter are
## first-class. Timid animals flee; predators pursue — but a fire/light
## deterrent downgrades a predator to wary investigation, and a sheltered player
## can't be reached at all. Fighting is a last resort, not the design's focus.
##
## `decide` is a pure function of the creature's current state, a perception
## snapshot, and its definition — so every transition is testable in isolation.
class_name WildlifeAI
extends RefCounted

enum State { IDLE, INVESTIGATE, FLEE, ATTACK }

## perception keys: distance, health_fraction, has_deterrent (bool),
##                  player_in_shelter (bool), time_is_active (bool)
## def keys: aggressive, detect_range, attack_range, flee_health
static func decide(_current: int, p: Dictionary, def: Dictionary) -> int:
	var distance := float(p.get("distance", INF))
	var detect := float(def.get("detect_range", 100.0))
	var hurt := float(p.get("health_fraction", 1.0)) <= float(def.get("flee_health", 0.25))

	if not bool(def.get("aggressive", false)):
		# Timid: bolt at the first sign of the player, or when hurt.
		if hurt or distance <= detect:
			return State.FLEE
		return State.IDLE

	# Predator.
	if hurt:
		return State.FLEE
	if not bool(p.get("time_is_active", true)) or bool(p.get("player_in_shelter", false)):
		return State.IDLE
	if bool(p.get("has_deterrent", false)):
		# Fire/light: it circles warily but won't close in.
		return State.INVESTIGATE if distance <= detect else State.IDLE
	if distance <= detect:
		return State.ATTACK   # pursue; the entity strikes once within attack_range
	return State.IDLE

## Whether a creature in ATTACK state is close enough to land a hit.
static func in_strike_range(distance: float, def: Dictionary) -> bool:
	return distance <= float(def.get("attack_range", 0.0))
