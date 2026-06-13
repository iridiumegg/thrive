## Engine-side owner of the player's skills. Awards XP from gameplay events,
## handles level-ups, and unlocks skill-gated recipes as the relevant line
## climbs. Other systems read levels here (e.g. crafting asks for the quality
## a skill earns).
class_name SkillsComponent
extends Node

var system: SkillSystem

var _crafting: CraftingComponent
var _cfg: Dictionary
var _category_skill: Dictionary

func setup(crafting: CraftingComponent) -> void:
	_crafting = crafting

func _ready() -> void:
	_cfg = Balance.data["skills"]
	_category_skill = _cfg["category_skill"]
	system = SkillSystem.new(_cfg)
	EventBus.node_harvested.connect(_on_node_harvested)
	EventBus.recipe_crafted.connect(_on_recipe_crafted)
	EventBus.structure_built.connect(_on_structure_built)
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.creature_killed.connect(_on_creature_killed)

func level(skill_id: String) -> int:
	return system.level(skill_id)

## Which skill a recipe trains (explicit field, else inferred from category).
func skill_for_recipe(recipe_id: String) -> String:
	var recipe: Dictionary = CraftDb.recipes.get(recipe_id, {})
	if recipe.has("skill"):
		return String(recipe["skill"])
	return String(_category_skill.get(String(recipe.get("category", "")), "crafting"))

## The quality tier a recipe would currently be crafted at.
func quality_for_recipe(recipe_id: String) -> Dictionary:
	var tiers: Array = Balance.data["crafting"]["quality_tiers"]
	return Quality.tier_for_level(tiers, level(skill_for_recipe(recipe_id)))

## --- XP sources ---

func _on_node_harvested(_node_id: String, _loot: Dictionary) -> void:
	_award("gathering", int(Balance.data["gathering"]["xp_per_harvest"]))

func _on_recipe_crafted(recipe_id: String, _quality: String) -> void:
	var recipe: Dictionary = CraftDb.recipes.get(recipe_id, {})
	_award(skill_for_recipe(recipe_id), int(recipe.get("xp", 1)))

func _on_structure_built(_buildable_id: String) -> void:
	_award("building", int(_cfg["build_xp"]))

func _on_day_advanced(_day: int) -> void:
	_award("survival", int(_cfg["survive_day_xp"]))

func _on_creature_killed(_creature_id: String) -> void:
	_award("survival", int(Balance.data["combat"]["kill_survival_xp"]))

## Public XP award (used by quest rewards).
func award(skill_id: String, amount: int) -> void:
	_award(skill_id, amount)

func save() -> Dictionary:
	return system.to_data()

func load_save(data: Dictionary) -> void:
	system.load_data(data)

func _award(skill_id: String, amount: int) -> void:
	var result := system.add_xp(skill_id, amount)
	EventBus.skill_xp_gained.emit(skill_id, amount)
	if result["leveled"]:
		EventBus.skill_leveled.emit(skill_id, int(result["to"]))
		EventBus.notice.emit("%s is now level %d" % [skill_id.capitalize(), int(result["to"])])
		_unlock_skill_recipes(skill_id, int(result["to"]))

## When a skill levels, learn any recipes gated behind it at the new level.
func _unlock_skill_recipes(skill_id: String, new_level: int) -> void:
	if _crafting == null:
		return
	for recipe_id: String in CraftDb.recipes:
		var unlock: Dictionary = CraftDb.recipes[recipe_id].get("unlock", {})
		if String(unlock.get("type", "")) != "skill":
			continue
		if String(unlock.get("skill", "")) == skill_id and new_level >= int(unlock.get("level", 1)):
			if _crafting.learn_recipe(recipe_id):
				EventBus.notice.emit("New recipe: %s" % CraftDb.recipes[recipe_id]["display_name"])
