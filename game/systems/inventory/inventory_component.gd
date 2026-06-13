## Engine-side owner of the player's Inventory + Equipment.
##
## Bridges the pure-logic containers to the rest of the game: applies item use
## (eat/drink/equip), routes drops back into the world, exposes the insulation
## the warmth model needs, and republishes every change as EventBus signals for
## the UI. Holds no balance numbers of its own.
class_name InventoryComponent
extends Node

var inventory: Inventory
var equipment: Equipment

## Per-tool current durability, keyed by item id (tools are unique enough that
## id-keying is fine, and it survives equip/unequip — unlike slot-keying). A
## missing entry means "full". Proper per-instance durability waits on item
## instances; this is the honest minimum that makes wear-and-break real.
var tool_durability: Dictionary = {}

var _vitals: VitalsComponent
var crafting: CraftingComponent   # wired by the player after both components exist

func setup(vitals: VitalsComponent) -> void:
	_vitals = vitals

func _ready() -> void:
	inventory = ItemDb.new_inventory()
	equipment = ItemDb.new_equipment()

func _emit_changed() -> void:
	EventBus.inventory_changed.emit(inventory)
	EventBus.equipment_changed.emit(equipment)

## Try to take `qty` of an item into the pack. Returns the number accepted.
## Emits a notice if the pack couldn't hold all of it.
func pickup(item_id: String, qty: int) -> int:
	var added := inventory.add(item_id, qty)
	if added > 0:
		EventBus.item_picked_up.emit(item_id, added)
		EventBus.inventory_changed.emit(inventory)
	if added < qty:
		EventBus.notice.emit("Pack is full — left %d %s" % [
				qty - added, ItemDb.get_def(item_id).name])
	return added

## Primary action for a grid slot: eat/drink food, or equip wearables/tools.
func use_slot(index: int) -> void:
	var stack: Inventory.Stack = inventory.slots[index]
	if stack == null:
		return
	var def := ItemDb.get_def(stack.item_id)
	if def.teaches_recipe != "":
		_read_blueprint(index, def)
	elif def.is_edible():
		_consume(index, def)
	elif def.is_equippable():
		_equip_from_slot(index, def)

## Reading a blueprint learns its recipe and consumes the page (once).
func _read_blueprint(index: int, def: ItemDef) -> void:
	if crafting == null:
		return
	if crafting.learn_recipe(def.teaches_recipe):
		inventory.remove_slot(index, 1)
		EventBus.notice.emit("Learned: %s" % CraftDb.recipes[def.teaches_recipe]["display_name"])
		EventBus.inventory_changed.emit(inventory)
	else:
		EventBus.notice.emit("You already know this pattern")

func _consume(index: int, def: ItemDef) -> void:
	if _vitals != null:
		var kcal := float(def.food.get("kcal", 0.0))
		var hydration := float(def.food.get("hydration_pct", 0.0))
		if kcal > 0.0:
			_vitals.system.eat(_vitals.state, kcal)
		if hydration > 0.0:
			_vitals.system.drink(_vitals.state, hydration)
		EventBus.vitals_changed.emit(_vitals.state)
	inventory.remove_slot(index, 1)
	# Drinking from a container leaves the empty behind.
	var becomes := String(def.food.get("container_becomes", ""))
	if becomes != "":
		inventory.add(becomes, 1)
	EventBus.notice.emit("Used %s" % def.name)
	EventBus.inventory_changed.emit(inventory)

func _equip_from_slot(index: int, def: ItemDef) -> void:
	inventory.remove_slot(index, 1)
	var displaced := equipment.equip(def.id)
	if displaced != "":
		# Swap the old piece back into the pack; if it somehow can't fit, drop it.
		if inventory.add(displaced, 1) == 0:
			EventBus.item_dropped.emit(displaced, 1)
	EventBus.notice.emit("Equipped %s" % def.name)
	_emit_changed()

func unequip(slot: String) -> void:
	var id := equipment.equipped(slot)
	if id == "":
		return
	if inventory.add(id, 1) > 0:
		equipment.unequip(slot)
		EventBus.notice.emit("Stowed %s" % ItemDb.get_def(id).name)
		_emit_changed()
	else:
		EventBus.notice.emit("No room to stow that")

## Drop one from a slot into the world at the player's feet.
func drop_slot(index: int) -> void:
	var stack: Inventory.Stack = inventory.slots[index]
	if stack == null:
		return
	var item_id := stack.item_id
	inventory.remove_slot(index, 1)
	EventBus.item_dropped.emit(item_id, 1)
	EventBus.inventory_changed.emit(inventory)

## --- Tool durability ---

## Current durability of an item, or -1 if the item has no durability.
func current_durability(item_id: String) -> int:
	var def := ItemDb.get_def(item_id)
	if def == null or def.durability_max <= 0:
		return -1
	return int(tool_durability.get(item_id, def.durability_max))

## Wear down the equipped tool by `amount`; break (and remove) it at zero.
func damage_equipped_tool(amount: int = 1) -> void:
	var id := equipment.equipped("tool")
	if id == "":
		return
	var def := ItemDb.get_def(id)
	if def.durability_max <= 0:
		return
	var remaining := current_durability(id) - amount
	if remaining <= 0:
		equipment.unequip("tool")
		tool_durability.erase(id)
		EventBus.notice.emit("%s broke" % def.name)
		_emit_changed()
	else:
		tool_durability[id] = remaining
		EventBus.equipment_changed.emit(equipment)

## Warmth contribution from clothing, used by the vitals component each tick.
func total_insulation_c() -> float:
	return equipment.total_insulation_c()

## --- Save/load ---

func save() -> Dictionary:
	return {
		"inventory": inventory.to_data(),
		"equipment": equipment.to_data(),
		"tool_durability": tool_durability.duplicate(),
	}

func load_save(data: Dictionary) -> void:
	inventory.load_data(data.get("inventory", []))
	equipment.load_data(data.get("equipment", {}))
	tool_durability = (data.get("tool_durability", {}) as Dictionary).duplicate()
	_emit_changed()

## Movement/drain penalty from how loaded the pack is.
func encumbrance_factors() -> Dictionary:
	return Encumbrance.factors(inventory.weight_fraction(), Balance.data["inventory"])
