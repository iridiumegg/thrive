## The player's interface to the world's interactables (nodes, traps, springs).
##
## Resource node and trap entities register themselves as the "focus" when the
## player steps into range; pressing interact delegates to the focused entity.
## This component stays thin — it resolves tool tier, moves loot into the pack,
## spends a little energy per action, and brokers bait/deploy — while the
## node/trap state lives in the pure-logic HarvestNode/Trap classes.
class_name GatheringComponent
extends Node

## In-game minutes of energy-equivalent spent per harvest (a light exertion
## cost so gathering isn't free). Read from balance.json.
var _player: Player
var _vitals: VitalsComponent
var _inventory: InventoryComponent
var _focus: Node = null

func setup(player: Player, vitals: VitalsComponent, inventory: InventoryComponent) -> void:
	_player = player
	_vitals = vitals
	_inventory = inventory

## --- Focus management (called by interactable entities) ---

func set_focus(entity: Node) -> void:
	_focus = entity
	if entity != null and entity.has_method("prompt_text"):
		EventBus.interaction_prompt.emit(entity.prompt_text(self))

func clear_focus(entity: Node) -> void:
	if _focus == entity:
		_focus = null
		EventBus.interaction_prompt.emit("")

func refresh_prompt() -> void:
	if _focus != null and _focus.has_method("prompt_text"):
		EventBus.interaction_prompt.emit(_focus.prompt_text(self))

## --- Actions (routed from input by the world) ---

func interact() -> void:
	if _focus != null and is_instance_valid(_focus) and _focus.has_method("interact"):
		_focus.interact(self)
		refresh_prompt()

## --- Helpers used by the entities ---

## Tier of the equipped tool for a required tag (0 = bare hands / no match).
func tool_tier_for(tag: String) -> int:
	if tag == "":
		return 0
	var id := _inventory.equipment.equipped("tool")
	if id == "":
		return 0
	var def := ItemDb.get_def(id)
	return def.tier if def.tool_tag == tag else 0

## Move a loot dictionary into the pack and announce what came out.
func collect_loot(loot: Dictionary) -> void:
	if loot.is_empty():
		EventBus.notice.emit("Nothing this time")
		return
	var parts: Array[String] = []
	for item_id: String in loot:
		_inventory.pickup(item_id, int(loot[item_id]))
		parts.append("%s x%d" % [ItemDb.get_def(item_id).name, int(loot[item_id])])
	EventBus.notice.emit("+ " + ", ".join(parts))

func damage_tool() -> void:
	_inventory.damage_equipped_tool(1)

## Light exertion: drop a little energy per action (clamped at 0).
func spend_energy(pct: float) -> void:
	var vcfg: Dictionary = Balance.data["vitals"]
	_vitals.state.energy = clampf(_vitals.state.energy - pct, 0.0, float(vcfg["energy_max"]))
	EventBus.vitals_changed.emit(_vitals.state)

func restore_hydration(pct: float) -> void:
	_vitals.system.drink(_vitals.state, pct)
	EventBus.vitals_changed.emit(_vitals.state)

## Try to consume items (e.g. bait, or the trap kit being deployed).
func consume(item_id: String, qty: int) -> bool:
	if not _inventory.inventory.has(item_id, qty):
		return false
	_inventory.inventory.remove(item_id, qty)
	EventBus.inventory_changed.emit(_inventory.inventory)
	return true

func has_item(item_id: String, qty: int = 1) -> bool:
	return _inventory.inventory.has(item_id, qty)

func player_position() -> Vector2:
	return _player.global_position

func fill_container(from_id: String, to_id: String) -> bool:
	if not _inventory.inventory.has(from_id, 1):
		return false
	_inventory.inventory.remove(from_id, 1)
	_inventory.inventory.add(to_id, 1)
	EventBus.inventory_changed.emit(_inventory.inventory)
	return true
