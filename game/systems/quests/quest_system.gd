## Data-driven quest engine. Pure logic, unit-testable.
##
## Tracks each quest's status (locked → active → completed) and per-objective
## progress, advancing objectives from gameplay events. Prerequisite-driven
## activation chains the story: a quest with `prerequisites.quests` becomes
## active the moment those complete. Reward application is side-effectful and
## lives in the QuestComponent — this class only decides state, so it stays pure.
##
## Objective types handled here (others — talk_to/deliver/defeat — are accepted
## in data and wired as their systems arrive):
##   gather, craft, build, survive_n_days, reach_skill_level, discover/reach_location
class_name QuestSystem
extends RefCounted

const LOCKED := "locked"
const ACTIVE := "active"
const COMPLETED := "completed"

var quests: Dictionary               # id -> def
var states: Dictionary = {}          # id -> { status, progress: {obj_id:int} }

func _init(quest_defs: Dictionary) -> void:
	quests = quest_defs
	for id: String in quests:
		states[id] = {"status": LOCKED, "progress": {}}

func status(id: String) -> String:
	return String(states[id]["status"])

func is_active(id: String) -> bool:
	return status(id) == ACTIVE

func is_completed(id: String) -> bool:
	return status(id) == COMPLETED

func active_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in quests:
		if is_active(id):
			out.append(id)
	return out

func completed_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in quests:
		if is_completed(id):
			out.append(id)
	return out

func progress_of(id: String, objective_id: String) -> int:
	return int(states[id]["progress"].get(objective_id, 0))

## --- Activation ---

func activate(id: String) -> bool:
	if status(id) != LOCKED:
		return false
	states[id]["status"] = ACTIVE
	for obj: Dictionary in quests[id].get("objectives", []):
		states[id]["progress"][String(obj["id"])] = 0
	return true

func prerequisites_met(id: String, ctx: Dictionary) -> bool:
	var p: Dictionary = quests[id].get("prerequisites", {})
	for flag: String in p.get("flags", []):
		if not bool(ctx.get("flags", {}).get(flag, false)):
			return false
	for quest_id: String in p.get("quests", []):
		if not is_completed(quest_id):
			return false
	for entry: Dictionary in p.get("items", []):
		if int(ctx.get("item_counts", {}).get(String(entry["item"]), 0)) < int(entry["qty"]):
			return false
	for entry: Dictionary in p.get("skills", []):
		if int(ctx.get("skill_levels", {}).get(String(entry["skill"]), 1)) < int(entry["level"]):
			return false
	return true

## Activate every locked quest whose prerequisites are now satisfied (and that
## is allowed to auto-start). Returns the newly activated ids.
func auto_activate(ctx: Dictionary) -> Array[String]:
	var started: Array[String] = []
	for id: String in quests:
		if status(id) != LOCKED:
			continue
		var has_prereqs: bool = not quests[id].get("prerequisites", {}).is_empty()
		if not (bool(quests[id].get("auto_start", false)) or has_prereqs):
			continue
		if prerequisites_met(id, ctx):
			activate(id)
			started.append(id)
	return started

## --- Objective progress ---

## Feed a gameplay event; returns the ids of quests completed by it.
## event types: gather{item,qty}, craft{outputs:[ids]}, build{target},
## survive_day{}, skill{skill,level}, discover{target}.
func record(event_type: String, payload: Dictionary) -> Array[String]:
	var completed: Array[String] = []
	for id: String in quests:
		if not is_active(id):
			continue
		var changed := false
		for obj: Dictionary in quests[id].get("objectives", []):
			if _advance(id, obj, event_type, payload):
				changed = true
		if changed and _all_required_done(id):
			states[id]["status"] = COMPLETED
			completed.append(id)
	return completed

func _advance(id: String, obj: Dictionary, event_type: String, payload: Dictionary) -> bool:
	var obj_id := String(obj["id"])
	var target := String(obj.get("target", ""))
	var count := int(obj.get("count", 1))
	match String(obj["type"]):
		"gather":
			if event_type == "gather" and String(payload.get("item", "")) == target:
				return _bump(id, obj_id, int(payload.get("qty", 1)), count)
		"craft":
			if event_type == "craft" and target in payload.get("outputs", []):
				return _bump(id, obj_id, 1, count)
		"build":
			if event_type == "build" and String(payload.get("target", "")) == target:
				return _bump(id, obj_id, 1, count)
		"survive_n_days":
			if event_type == "survive_day":
				return _bump(id, obj_id, 1, count)
		"reach_skill_level":
			if event_type == "skill" and String(payload.get("skill", "")) == target:
				var lvl := int(payload.get("level", 0))
				if lvl > progress_of(id, obj_id):
					states[id]["progress"][obj_id] = mini(lvl, count)
					return true
		"discover", "reach_location":
			if event_type == "discover" and String(payload.get("target", "")) == target:
				states[id]["progress"][obj_id] = count
				return true
	return false

func _bump(id: String, obj_id: String, amount: int, count: int) -> bool:
	var cur := progress_of(id, obj_id)
	if cur >= count:
		return false
	states[id]["progress"][obj_id] = mini(count, cur + amount)
	return true

func is_objective_done(id: String, obj: Dictionary) -> bool:
	return progress_of(id, String(obj["id"])) >= int(obj.get("count", 1))

func _all_required_done(id: String) -> bool:
	for obj: Dictionary in quests[id].get("objectives", []):
		if not bool(obj.get("optional", false)) and not is_objective_done(id, obj):
			return false
	return true

## --- Save/load support ---

func to_data() -> Dictionary:
	return states.duplicate(true)

func load_data(data: Dictionary) -> void:
	for id: String in data:
		if states.has(id):
			states[id] = data[id]
