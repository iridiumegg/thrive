## Player character: top-down 8-direction movement.
##
## Walk speed comes from balance.json and is scaled by the vitals component's
## affliction speed multiplier (hypothermia, exhaustion, etc. slow you down).
class_name Player
extends CharacterBody2D

var vitals: VitalsComponent

func _physics_process(_delta: float) -> void:
	if vitals != null and (not vitals.state.alive or vitals.asleep):
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := float(Balance.data["player"]["walk_speed"])
	if vitals != null:
		speed *= vitals.speed_mult
	velocity = direction * speed
	move_and_slide()
