## Player character: top-down 8-direction movement.
##
## Walk speed (from balance.json) is scaled by two survival factors:
##   - the vitals affliction speed multiplier (hypothermia, exhaustion, …)
##   - encumbrance from a heavy pack
## The player also exposes the warmth insulation its gear provides, which the
## vitals component samples each tick.
class_name Player
extends CharacterBody2D

var vitals: VitalsComponent
var inventory: InventoryComponent
var gathering: GatheringComponent
var crafting: CraftingComponent
var skills: SkillsComponent
var quests: QuestComponent
var dialogue: DialogueComponent
var story: StoryComponent

## Environmental warmth/shelter from nearby built structures (updated by
## BuildingEntity proximity). Heat sources sum; any shelter piece counts.
var nearby_heat_c: float = 0.0
var nearby_shelter: int = 0

func is_sheltered() -> bool:
	return nearby_shelter > 0 or nearby_heat_c > 0.0

func _physics_process(_delta: float) -> void:
	if vitals != null and (not vitals.state.alive or vitals.asleep):
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := float(Balance.data["player"]["walk_speed"])
	if vitals != null:
		speed *= vitals.speed_mult
	speed *= float(encumbrance()["speed_mult"])
	velocity = direction * speed
	move_and_slide()

## Total warmth insulation: the body's baseline plus all equipped clothing.
func insulation_c() -> float:
	var base := float(Balance.data["player"]["base_insulation_c"])
	if inventory != null:
		return base + inventory.total_insulation_c()
	return base

func encumbrance() -> Dictionary:
	if inventory != null:
		return inventory.encumbrance_factors()
	return {"speed_mult": 1.0, "activity_mult": 1.0}
