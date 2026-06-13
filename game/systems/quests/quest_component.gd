## Engine-side owner of quests + story flags. Translates gameplay events into
## quest progress, applies rewards on completion, and re-checks prerequisites so
## the story chain advances itself.
class_name QuestComponent
extends Node

var system: QuestSystem
var flags: FlagStore

var _inventory: InventoryComponent
var _skills: SkillsComponent
var _crafting: CraftingComponent

func setup(inventory: InventoryComponent, skills: SkillsComponent, crafting: CraftingComponent) -> void:
	_inventory = inventory
	_skills = skills
	_crafting = crafting

func _ready() -> void:
	system = QuestSystem.new(QuestDb.quests)
	flags = FlagStore.new()
	# Translate gameplay signals into quest events.
	EventBus.item_picked_up.connect(func(item: String, qty: int) -> void:
		_record("gather", {"item": item, "qty": qty}))
	EventBus.recipe_crafted.connect(func(recipe_id: String, _q: String) -> void:
		_record("craft", {"outputs": _recipe_outputs(recipe_id)}))
	EventBus.structure_built.connect(func(id: String) -> void:
		_record("build", {"target": id}))
	EventBus.day_advanced.connect(func(_day: int) -> void:
		_record("survive_day", {}))
	EventBus.skill_leveled.connect(func(skill: String, level: int) -> void:
		_record("skill", {"skill": skill, "level": level}))
	EventBus.biome_entered.connect(func(id: String, _name: String) -> void:
		_record("discover", {"target": id}))
	# Activate any quests that start from the off (auto_start / met prereqs).
	call_deferred("_refresh_activation")

func _refresh_activation() -> void:
	for id in system.auto_activate(_context()):
		EventBus.quest_activated.emit(id)
		EventBus.notice.emit("New quest: %s" % QuestDb.quests[id]["title"])
	EventBus.quest_progress_changed.emit()

func _record(event_type: String, payload: Dictionary) -> void:
	var completed := system.record(event_type, payload)
	for id in completed:
		_complete(id)
	if not completed.is_empty():
		_refresh_activation()
	EventBus.quest_progress_changed.emit()

func _complete(id: String) -> void:
	var quest: Dictionary = QuestDb.quests[id]
	var rewards: Dictionary = quest.get("rewards", {})
	for entry: Dictionary in rewards.get("items", []):
		_inventory.pickup(String(entry["item"]), int(entry["qty"]))
	for recipe_id: String in rewards.get("recipes", []):
		_crafting.learn_recipe(recipe_id)
	var xp: Dictionary = rewards.get("xp", {})
	for skill_id: String in xp:
		_skills.award(skill_id, int(xp[skill_id]))
	for flag: String in rewards.get("flags", []):
		flags.set_flag(flag)
		EventBus.flag_set.emit(flag)
	EventBus.quest_completed.emit(id)
	EventBus.notice.emit("Quest complete: %s" % quest["title"])

## --- Context for prerequisite checks ---

func _context() -> Dictionary:
	return {
		"flags": flags.all_flags(),
		"item_counts": _item_counts(),
		"skill_levels": _skill_levels(),
	}

func _item_counts() -> Dictionary:
	var counts: Dictionary = {}
	for stack: Inventory.Stack in _inventory.inventory.slots:
		if stack != null:
			counts[stack.item_id] = int(counts.get(stack.item_id, 0)) + stack.qty
	return counts

func _skill_levels() -> Dictionary:
	var levels: Dictionary = {}
	if _skills != null:
		for line: String in _skills.system.lines:
			levels[line] = _skills.system.level(line)
	return levels

func _recipe_outputs(recipe_id: String) -> Array:
	var ids: Array = []
	for out: Dictionary in CraftDb.recipes.get(recipe_id, {}).get("outputs", []):
		ids.append(String(out["item"]))
	return ids
