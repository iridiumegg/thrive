## Engine-side owner of the player's crafting: bridges the pure CraftingSystem
## to the inventory, station availability, and the sim clock.
##
## - Consumes inputs up front and queues a timed job; delivers outputs when the
##   job completes on the sim tick (so crafting costs in-game time, and needs
##   keep draining while you work).
## - Tracks which stations are in range (fed by StationEntity proximity) and
##   which non-default recipes have been learned (blueprints).
## - Also hosts repair and salvage, which operate on item durability/definitions
##   rather than the recipe table.
class_name CraftingComponent
extends Node

var system: CraftingSystem
var known_recipes: Dictionary = {}      # recipe_id -> true (non-default unlocks)
var available_stations: Dictionary = {} # station_id -> in-range count

var skills: SkillsComponent             # wired by the player; drives quality
var _inventory: InventoryComponent
var _rng := RandomNumberGenerator.new()

func setup(inventory: InventoryComponent) -> void:
	_inventory = inventory

func _ready() -> void:
	system = CraftingSystem.new(CraftDb.recipes)
	_rng.randomize()
	EventBus.sim_minute.connect(_on_sim_minute)

## --- Station availability (called by StationEntity) ---

func add_station(station_id: String) -> void:
	available_stations[station_id] = int(available_stations.get(station_id, 0)) + 1
	EventBus.stations_changed.emit(station_ids())

func remove_station(station_id: String) -> void:
	if available_stations.has(station_id):
		available_stations[station_id] -= 1
		if available_stations[station_id] <= 0:
			available_stations.erase(station_id)
	EventBus.stations_changed.emit(station_ids())

## "hand" is always available; plus any station currently in range.
func station_ids() -> Array:
	var ids: Array = ["hand"]
	for id: String in available_stations:
		ids.append(id)
	return ids

## --- Recipe knowledge ---

func knows(recipe_id: String) -> bool:
	return system.is_unlocked(recipe_id, known_recipes)

func learn_recipe(recipe_id: String) -> bool:
	if knows(recipe_id):
		return false
	known_recipes[recipe_id] = true
	EventBus.recipe_learned.emit(recipe_id)
	return true

## --- Crafting ---

## Snapshot of inventory quantities for validation.
func inventory_counts() -> Dictionary:
	var counts: Dictionary = {}
	for stack: Inventory.Stack in _inventory.inventory.slots:
		if stack != null:
			counts[stack.item_id] = int(counts.get(stack.item_id, 0)) + stack.qty
	return counts

func can_craft(recipe_id: String) -> Dictionary:
	return system.can_craft(recipe_id, inventory_counts(), station_ids(), known_recipes)

## Validate, consume inputs, and queue the craft. Returns true if it started.
func craft(recipe_id: String) -> bool:
	var check := can_craft(recipe_id)
	if not check["ok"]:
		EventBus.notice.emit(_explain(recipe_id, check["reason"]))
		return false
	for inp: Dictionary in system.recipe(recipe_id).get("inputs", []):
		_inventory.inventory.remove(String(inp["item"]), int(inp["qty"]))
	EventBus.inventory_changed.emit(_inventory.inventory)
	# Quality is fixed at craft start from the relevant skill level.
	var quality_id := "standard"
	if skills != null:
		quality_id = String(skills.quality_for_recipe(recipe_id).get("id", "standard"))
	system.enqueue(recipe_id, quality_id)
	EventBus.crafting_queue_changed.emit(system.queue)
	EventBus.notice.emit("Crafting: %s" % _display(recipe_id))
	return true

func cancel_active() -> void:
	var job := system.cancel_active()
	if job == null:
		return
	# Refund the inputs of the cancelled job.
	for inp: Dictionary in system.recipe(job.recipe_id).get("inputs", []):
		_inventory.inventory.add(String(inp["item"]), int(inp["qty"]))
	EventBus.inventory_changed.emit(_inventory.inventory)
	EventBus.crafting_queue_changed.emit(system.queue)
	EventBus.notice.emit("Cancelled %s" % _display(job.recipe_id))

func _on_sim_minute(minutes: int) -> void:
	if not system.is_busy():
		return
	var completed := system.tick(minutes)
	for done: Dictionary in completed:
		_deliver(String(done["recipe_id"]), String(done["quality"]))
	if not completed.is_empty():
		EventBus.crafting_queue_changed.emit(system.queue)

func _deliver(recipe_id: String, quality: String) -> void:
	var tiers: Array = Balance.data["crafting"]["quality_tiers"]
	var tier := Quality.tier_by_id(tiers, quality)
	for out: Dictionary in system.recipe(recipe_id).get("outputs", []):
		var item_id := String(out["item"])
		var def := ItemDb.get_def(item_id)
		var qty := int(out["qty"])
		# Fine/masterwork quality can yield a bonus unit of stackable goods.
		if def.stack_size > 1 and _rng.randf() < Quality.bonus_output_chance(tier):
			qty += 1
		_inventory.pickup(item_id, qty)
		# For tools, quality scales the starting durability (stored per item id).
		if def.durability_max > 0:
			_inventory.tool_durability[item_id] = int(round(
					def.durability_max * Quality.durability_mult(tier)))
	EventBus.recipe_crafted.emit(recipe_id, quality)
	var quality_label := String(tier.get("name", "")) + " " if quality != "standard" else ""
	EventBus.notice.emit("Finished: %s%s" % [quality_label, _display(recipe_id)])

## --- Repair & salvage (operate on items, not recipes) ---

## Repair the equipped tool to full durability, consuming its repair material.
func repair_equipped_tool() -> bool:
	var id := _inventory.equipment.equipped("tool")
	if id == "":
		EventBus.notice.emit("No tool equipped to repair")
		return false
	var def := ItemDb.get_def(id)
	if def.repair_with.is_empty() or def.durability_max <= 0:
		EventBus.notice.emit("%s can't be repaired" % def.name)
		return false
	if _inventory.current_durability(id) >= def.durability_max:
		EventBus.notice.emit("%s is already sound" % def.name)
		return false
	var mat := String(def.repair_with["item"])
	var qty := int(def.repair_with["qty"])
	if not _inventory.inventory.has(mat, qty):
		EventBus.notice.emit("Need %d %s to repair" % [qty, ItemDb.get_def(mat).name])
		return false
	_inventory.inventory.remove(mat, qty)
	_inventory.tool_durability[id] = def.durability_max
	EventBus.inventory_changed.emit(_inventory.inventory)
	EventBus.equipment_changed.emit(_inventory.equipment)
	EventBus.notice.emit("Repaired %s" % def.name)
	return true

## Break an inventory item back down into a fraction of its materials.
func salvage_slot(index: int) -> bool:
	var stack: Inventory.Stack = _inventory.inventory.slots[index]
	if stack == null:
		return false
	var def := ItemDb.get_def(stack.item_id)
	if def.salvage.is_empty():
		EventBus.notice.emit("%s can't be salvaged" % def.name)
		return false
	_inventory.inventory.remove_slot(index, 1)
	for ret: Dictionary in def.salvage:
		_inventory.inventory.add(String(ret["item"]), int(ret["qty"]))
	EventBus.inventory_changed.emit(_inventory.inventory)
	EventBus.notice.emit("Salvaged %s" % def.name)
	return true

## --- Save/load ---

func save() -> Dictionary:
	return {"known": known_recipes.duplicate(), "queue": system.to_data()}

func load_save(data: Dictionary) -> void:
	known_recipes = (data.get("known", {}) as Dictionary).duplicate()
	system.load_data(data.get("queue", []))
	EventBus.crafting_queue_changed.emit(system.queue)

## --- Helpers ---

func _display(recipe_id: String) -> String:
	return String(system.recipe(recipe_id).get("display_name", recipe_id))

func _explain(recipe_id: String, reason: String) -> String:
	if reason == "Missing materials":
		var parts: Array[String] = []
		for item_id: String in system.missing_inputs(recipe_id, inventory_counts()):
			parts.append("%s x%d" % [ItemDb.get_def(item_id).name,
					system.missing_inputs(recipe_id, inventory_counts())[item_id]])
		return "Need: " + ", ".join(parts)
	if reason == "Requires a station":
		return "Need a %s nearby" % CraftDb.station_name(String(system.recipe(recipe_id).get("station", "hand")))
	return reason
