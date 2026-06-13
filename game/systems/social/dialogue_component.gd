## Engine-side conversation driver: runs the pure DialogueSystem against a live
## context (flags, relationships, inventory), applies a chosen line's effects
## (set flag, change trust, give/take items for barter, teach a recipe), and
## advances to the next node. Also owns the RelationshipStore.
class_name DialogueComponent
extends Node

var dialogue: DialogueSystem
var relationships: RelationshipStore

var _inventory: InventoryComponent
var _crafting: CraftingComponent
var _quests: QuestComponent          # for the shared FlagStore

var _active_dialogue := ""
var _active_npc := ""
var _current_node := ""
var _greeted_today: Dictionary = {}  # npc_id -> day index

func setup(inventory: InventoryComponent, crafting: CraftingComponent, quests: QuestComponent) -> void:
	_inventory = inventory
	_crafting = crafting
	_quests = quests

func _ready() -> void:
	dialogue = DialogueSystem.new(NpcDb.dialogues)
	var social: Dictionary = Balance.data["social"]
	relationships = RelationshipStore.new(social["relationship_levels"], int(social["max_relationship"]))

func is_talking() -> bool:
	return _active_npc != ""

## Texts of the choices currently visible (after requires filtering).
func current_choice_texts() -> Array:
	var node := dialogue.node(_active_dialogue, _current_node)
	var texts: Array = []
	for i in dialogue.available_choices(_active_dialogue, _current_node, _context()):
		texts.append(String(node["choices"][i].get("text", "")))
	return texts

## Begin a conversation with an NPC.
func open(npc_id: String) -> void:
	var npc: Dictionary = NpcDb.get_npc(npc_id)
	if npc.is_empty():
		return
	_active_npc = npc_id
	_active_dialogue = String(npc.get("dialogue", ""))
	_current_node = dialogue.start_node_id(_active_dialogue)
	_greet(npc_id)
	EventBus.dialogue_started.emit(npc_id, String(npc.get("name", npc_id)))
	_emit_node()

## Player picked an available choice (index into the FILTERED choice list shown).
func choose(visible_index: int) -> void:
	var available := dialogue.available_choices(_active_dialogue, _current_node, _context())
	if visible_index < 0 or visible_index >= available.size():
		return
	var choice: Dictionary = dialogue.node(_active_dialogue, _current_node)["choices"][available[visible_index]]
	_apply_effects(choice.get("effects", []))
	var goto := String(choice.get("goto", "end"))
	if not dialogue.has_node(_active_dialogue, goto):
		close()
		return
	_current_node = goto
	_emit_node()

func close() -> void:
	_active_npc = ""
	_active_dialogue = ""
	_current_node = ""
	EventBus.dialogue_ended.emit()

## --- Save/load ---

func save() -> Dictionary:
	return {"relationships": relationships.to_data(), "greeted": _greeted_today.duplicate()}

func load_save(data: Dictionary) -> void:
	relationships.load_data(data.get("relationships", {}))
	_greeted_today = (data.get("greeted", {}) as Dictionary).duplicate()

## --- Internals ---

func _emit_node() -> void:
	var node := dialogue.node(_active_dialogue, _current_node)
	var available := dialogue.available_choices(_active_dialogue, _current_node, _context())
	var texts: Array = []
	for i in available:
		texts.append(String(node["choices"][i].get("text", "...")))
	EventBus.dialogue_node.emit(
		String(node.get("speaker", NpcDb.get_npc(_active_npc).get("name", ""))),
		String(node.get("text", "")), texts)

func _greet(npc_id: String) -> void:
	var day := Sim.clock.day_index()
	if int(_greeted_today.get(npc_id, -1)) != day:
		_greeted_today[npc_id] = day
		_change_relationship(npc_id, int(Balance.data["social"]["greet_bonus_per_day"]))

func _apply_effects(effects: Array) -> void:
	for effect: Dictionary in effects:
		match String(effect.get("type", "")):
			"set_flag":
				_quests.flags.set_flag(String(effect["flag"]))
				EventBus.flag_set.emit(String(effect["flag"]))
			"relationship":
				_change_relationship(_active_npc, int(effect.get("delta", 0)))
			"give_item":
				_inventory.pickup(String(effect["item"]), int(effect.get("qty", 1)))
			"take_item":
				_inventory.inventory.remove(String(effect["item"]), int(effect.get("qty", 1)))
				EventBus.inventory_changed.emit(_inventory.inventory)
			"teach_recipe":
				if _crafting.learn_recipe(String(effect["recipe"])):
					EventBus.notice.emit("Learned: %s" % CraftDb.recipes[String(effect["recipe"])]["display_name"])

func _change_relationship(npc_id: String, delta: int) -> void:
	if delta == 0:
		return
	var value := relationships.add(npc_id, delta)
	EventBus.relationship_changed.emit(npc_id, value, relationships.level_name(npc_id))

func _context() -> Dictionary:
	return {
		"npc": _active_npc,
		"flags": _quests.flags.all_flags(),
		"relationship": {_active_npc: relationships.value(_active_npc)},
		"item_counts": _item_counts(),
	}

func _item_counts() -> Dictionary:
	var counts: Dictionary = {}
	for stack: Inventory.Stack in _inventory.inventory.slots:
		if stack != null:
			counts[stack.item_id] = int(counts.get(stack.item_id, 0)) + stack.qty
	return counts
