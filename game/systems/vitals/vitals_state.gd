## Plain data holder for the player's vitals. Pure logic, no engine nodes.
##
## All mutation rules live in VitalsSystem; this object is just the numbers,
## which keeps it trivial to serialize for the save system later.
class_name VitalsState
extends RefCounted

var calories: float = 0.0
var hydration: float = 0.0
var energy: float = 0.0
var warmth: float = 0.0
var condition: float = 0.0
var alive: bool = true

## id -> { "active": bool, "trigger_minutes": float, "cure_minutes": float }
var afflictions: Dictionary = {}

func get_stat(stat: String) -> float:
	match stat:
		"calories":
			return calories
		"hydration":
			return hydration
		"energy":
			return energy
		"warmth":
			return warmth
		"condition":
			return condition
	push_error("Unknown vitals stat: %s" % stat)
	return 0.0

func active_affliction_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in afflictions:
		if afflictions[id]["active"]:
			out.append(id)
	return out

func to_data() -> Dictionary:
	return {
		"calories": calories, "hydration": hydration, "energy": energy,
		"warmth": warmth, "condition": condition, "alive": alive,
		"afflictions": afflictions.duplicate(true),
	}

func load_data(data: Dictionary) -> void:
	calories = float(data.get("calories", calories))
	hydration = float(data.get("hydration", hydration))
	energy = float(data.get("energy", energy))
	warmth = float(data.get("warmth", warmth))
	condition = float(data.get("condition", condition))
	alive = bool(data.get("alive", true))
	if data.has("afflictions"):
		afflictions = (data["afflictions"] as Dictionary).duplicate(true)
