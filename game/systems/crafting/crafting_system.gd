## The crafting engine: recipe validation + a timed job queue. Pure logic,
## engine-agnostic, fully unit-testable.
##
## Validation (can_craft) is separated from execution so the UI can ask "is this
## craftable, and if not why" without side effects. Execution is a queue of jobs
## processed serially against the sim clock, giving the "passive processing"
## feel (e.g. smelting over 20 in-game minutes) the spec calls for. Input
## consumption and output delivery are the caller's job — this class owns timing
## and rules, not the inventory — which keeps it pure and testable.
##
## Quality is threaded through end to end (Job.quality, completion payload) but
## the milestone ships every craft at "standard"; M8 (skills) will compute a
## real quality and pass it to enqueue().
class_name CraftingSystem
extends RefCounted

const DEFAULT_QUALITY := "standard"

## One queued/active craft.
class Job:
	var recipe_id: String
	var total: int
	var remaining: int
	var quality: String
	func _init(id: String, total_minutes: int, quality_: String) -> void:
		recipe_id = id
		total = maxi(0, total_minutes)
		remaining = total
		quality = quality_
	func progress() -> float:
		return 1.0 if total <= 0 else 1.0 - float(remaining) / float(total)

var recipes: Dictionary       # recipe_id -> def
var queue: Array[Job] = []

func _init(recipe_defs: Dictionary) -> void:
	recipes = recipe_defs

func recipe(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {})

## --- Validation ---

## Default-unlock recipes are always known; others must appear in `known`
## (a set: recipe_id -> true), e.g. learned from a blueprint.
func is_unlocked(recipe_id: String, known: Dictionary) -> bool:
	var unlock: Dictionary = recipe(recipe_id).get("unlock", {})
	if String(unlock.get("type", "default")) == "default":
		return true
	return bool(known.get(recipe_id, false))

## Hand recipes need no station; otherwise the required station must be present.
func station_ok(recipe_id: String, stations: Array) -> bool:
	var needed := String(recipe(recipe_id).get("station", "hand"))
	return needed == "hand" or needed in stations

## item_id -> shortfall for any inputs the counts can't cover.
func missing_inputs(recipe_id: String, counts: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	for inp: Dictionary in recipe(recipe_id).get("inputs", []):
		var short := int(inp["qty"]) - int(counts.get(inp["item"], 0))
		if short > 0:
			missing[String(inp["item"])] = short
	return missing

## Full gate: { ok: bool, reason: String }.
func can_craft(recipe_id: String, counts: Dictionary, stations: Array, known: Dictionary) -> Dictionary:
	if recipe(recipe_id).is_empty():
		return {"ok": false, "reason": "Unknown recipe"}
	if not is_unlocked(recipe_id, known):
		return {"ok": false, "reason": "Not yet learned"}
	if not station_ok(recipe_id, stations):
		return {"ok": false, "reason": "Requires a station"}
	if not missing_inputs(recipe_id, counts).is_empty():
		return {"ok": false, "reason": "Missing materials"}
	return {"ok": true, "reason": ""}

## --- Execution ---

## Queue a craft. The caller must already have validated and consumed inputs.
func enqueue(recipe_id: String, quality: String = DEFAULT_QUALITY) -> Job:
	var job := Job.new(recipe_id, int(recipe(recipe_id).get("craft_time", 1)), quality)
	queue.append(job)
	return job

func active_job() -> Job:
	return queue[0] if not queue.is_empty() else null

func is_busy() -> bool:
	return not queue.is_empty()

## Advance the queue by `minutes`, processing jobs head-first. Returns the
## completed crafts as [{ recipe_id, quality }] for the caller to deliver.
func tick(minutes: int) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	var budget := minutes
	while not queue.is_empty():
		var job := queue[0]
		var step := mini(budget, job.remaining)
		job.remaining -= step
		budget -= step
		if job.remaining <= 0:
			queue.pop_front()
			completed.append({"recipe_id": job.recipe_id, "quality": job.quality})
		else:
			break   # ran out of budget mid-job
	return completed

## Cancel the active job and return it (so the caller can refund inputs).
func cancel_active() -> Job:
	return queue.pop_front() if not queue.is_empty() else null

## --- Save/load (the in-progress queue) ---

func to_data() -> Array:
	var out: Array = []
	for job: Job in queue:
		out.append({"recipe_id": job.recipe_id, "remaining": job.remaining,
				"total": job.total, "quality": job.quality})
	return out

func load_data(data: Array) -> void:
	queue.clear()
	for entry: Dictionary in data:
		var job := Job.new(String(entry["recipe_id"]), int(entry["total"]), String(entry["quality"]))
		job.remaining = int(entry["remaining"])
		queue.append(job)
