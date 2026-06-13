## Typed view over a single item definition from items.json. Pure data.
##
## Kept as a small class (rather than passing raw Dictionaries around) so the
## inventory, equipment, UI, and future crafting systems share one vocabulary
## for "what is this item" — weight, stack size, food stats, insulation, etc.
class_name ItemDef
extends RefCounted

var id: String
var name: String
var category: String
var description: String
var stack_size: int
var weight: float
var value: int
var tags: PackedStringArray
var food: Dictionary          # {} if not consumable; else {kcal, hydration_pct, container_becomes?}
var equip_slot: String        # "" if not equippable; else head/body/hands/feet/tool
var insulation_c: float       # warmth contribution when equipped (clothing)
var durability_max: int       # 0 if the item has no durability
var tool_tag: String          # "" if not a tool; else axe/pickaxe/... (gathering gate)
var tier: int                 # tool quality tier; gates which nodes it can work
var teaches_recipe: String    # "" unless this item is a blueprint that unlocks a recipe
var repair_with: Dictionary   # {} or {item, qty} material to fully repair this item
var salvage: Array            # [] or [{item, qty}] materials returned when salvaged

static func from_dict(d: Dictionary) -> ItemDef:
	var def := ItemDef.new()
	def.id = String(d["id"])
	def.name = String(d.get("name", d["id"]))
	def.category = String(d.get("category", "material"))
	def.description = String(d.get("description", ""))
	def.stack_size = int(d.get("stack_size", 1))
	def.weight = float(d.get("weight", 0.0))
	def.value = int(d.get("value", 0))
	def.tags = PackedStringArray(d.get("tags", []))
	def.food = d.get("food", {})
	def.equip_slot = String(d.get("equip_slot", ""))
	def.insulation_c = float(d.get("insulation_c", 0.0))
	def.durability_max = int(d.get("durability_max", 0))
	def.tool_tag = String(d.get("tool_tag", ""))
	def.tier = int(d.get("tier", 0))
	def.teaches_recipe = String(d.get("teaches_recipe", ""))
	def.repair_with = d.get("repair_with", {})
	def.salvage = d.get("salvage", [])
	return def

func is_edible() -> bool:
	return not food.is_empty()

func is_equippable() -> bool:
	return equip_slot != ""

func has_tag(tag: String) -> bool:
	return tag in tags
