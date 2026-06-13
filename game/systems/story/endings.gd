## Ending eligibility. Pure logic.
##
## Each ending lists the story flags it requires; an ending is available when
## every required flag is set. "Leave" requires nothing, so the game is always
## completable, while "Stay" and "Change" are earned by what the player did
## (built a home, learned why the others fled). Tied to decisions, per spec 11.3.
class_name Endings
extends RefCounted

## Ending defs whose requirements are all satisfied by `flags`.
static func available(endings: Array, flags: Dictionary) -> Array:
	var out: Array = []
	for ending: Dictionary in endings:
		if _met(ending.get("requires", []), flags):
			out.append(ending)
	return out

static func is_available(ending: Dictionary, flags: Dictionary) -> bool:
	return _met(ending.get("requires", []), flags)

static func _met(requires: Array, flags: Dictionary) -> bool:
	for flag: String in requires:
		if not bool(flags.get(flag, false)):
			return false
	return true
