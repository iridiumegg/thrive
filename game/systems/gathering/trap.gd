## A deployed snare trap: the passive trapping subsystem. Pure logic.
##
## Lifecycle:
##   ARMED  — baited and waiting; counts up to catch_minutes
##   (at the check) a success_chance roll decides the outcome:
##       CAUGHT — game is in the snare, waiting to be collected
##       EMPTY  — the bait was lost / nothing came; must be re-baited
##   Collecting a catch returns its loot and leaves the trap EMPTY.
##
## The owner supplies bait (consumed on arm) and the RNG, keeping this class a
## clean, testable state machine with no engine or inventory dependencies.
class_name Trap
extends RefCounted

enum State { EMPTY, ARMED, CAUGHT }

var state: int = State.EMPTY
var elapsed: int = 0
var caught_loot: Dictionary = {}

var _def: Dictionary          # one entry from traps.json
var _loot_table: Dictionary

func _init(trap_def: Dictionary, loot_table: Dictionary) -> void:
	_def = trap_def
	_loot_table = loot_table

func catch_minutes() -> int:
	return int(_def.get("catch_minutes", 60))

func is_armed() -> bool:
	return state == State.ARMED

func is_caught() -> bool:
	return state == State.CAUGHT

## Arm/re-bait the trap. The caller is responsible for having consumed bait.
func arm() -> void:
	state = State.ARMED
	elapsed = 0
	caught_loot = {}

## Advance time. When an armed trap reaches its check interval, it rolls for a
## catch. Returns true on the tick a catch is made.
func tick(minutes: int, rng: RandomNumberGenerator) -> bool:
	if state != State.ARMED:
		return false
	elapsed += minutes
	if elapsed < catch_minutes():
		return false
	elapsed = 0
	if rng.randf() < float(_def.get("success_chance", 0.5)):
		caught_loot = LootTable.roll(_loot_table, rng)
		state = State.CAUGHT
		return true
	state = State.EMPTY
	return false

## Take the catch (if any) and reset to EMPTY.
func collect() -> Dictionary:
	var loot := caught_loot
	caught_loot = {}
	state = State.EMPTY
	elapsed = 0
	return loot
