## The player's side of combat: a single melee swing that strikes the nearest
## creature in range. Damage scales with the equipped tool's tier (an iron axe
## hits harder than fists), and swinging costs energy — combat ties back into
## the vitals model rather than being a separate minigame.
class_name CombatComponent
extends Node

var _player: Player
var _vitals: VitalsComponent
var _inventory: InventoryComponent

func setup(player: Player, vitals: VitalsComponent, inventory: InventoryComponent) -> void:
	_player = player
	_vitals = vitals
	_inventory = inventory

## Swing at the closest creature within melee range. No-op if none is near or
## the player is too drained to act.
func attack() -> void:
	var cfg: Dictionary = Balance.data["combat"]
	var target := _nearest_creature(float(cfg["melee_range"]))
	if target == null:
		return
	var damage := float(cfg["player_base_damage"]) + _tool_damage(cfg)
	_vitals.state.energy = maxf(0.0, _vitals.state.energy - float(cfg["energy_per_swing"]))
	EventBus.vitals_changed.emit(_vitals.state)
	AudioService.play("build")
	target.take_damage(damage, _player.global_position)

func _tool_damage(cfg: Dictionary) -> float:
	var id := _inventory.equipment.equipped("tool")
	if id == "":
		return 0.0
	return ItemDb.get_def(id).tier * float(cfg["tool_damage_per_tier"])

func _nearest_creature(range_px: float) -> Node:
	var best: Node = null
	var best_dist := range_px
	for node in get_tree().get_nodes_in_group("wildlife"):
		var creature := node as Node2D
		if creature == null:
			continue
		var d := _player.global_position.distance_to(creature.global_position)
		if d <= best_dist:
			best_dist = d
			best = creature
	return best
