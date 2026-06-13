## A wild animal driven by the pure WildlifeAI state machine.
##
## Each physics step it builds a perception snapshot (distance to the player,
## its own health, whether the player has a fire/light deterrent or is sheltered,
## and whether it's the creature's active time of day) and asks the AI for a
## state, then moves accordingly. Predators strike on a cooldown when in range;
## a hit damages Condition and may cause an infected wound. Killing one drops
## meat and hide — the hunting loop deferred from M4.
class_name WildlifeEntity
extends CharacterBody2D

var creature_id: String
var def: Dictionary
var health: float

var _player: Player
var _state: int = WildlifeAI.State.IDLE
var _attack_timer := 0.0
var _wander_target := Vector2.ZERO
var _wander_timer := 0.0
static var _textures: Dictionary = {}

static func create(creature_id: String, world_position: Vector2) -> WildlifeEntity:
	var e := WildlifeEntity.new()
	e.creature_id = creature_id
	e.def = GatherDb.wildlife_defs[creature_id]
	e.position = world_position
	e.health = float(e.def.get("max_health", 30.0))
	return e

func _ready() -> void:
	add_to_group("wildlife")
	var sprite := Sprite2D.new()
	sprite.texture = _texture_for(creature_id, def)
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 10)
	shape.shape = rect
	add_child(shape)
	_wander_target = position

func _physics_process(delta: float) -> void:
	_player = _player if _player != null and is_instance_valid(_player) else _find_player()
	if _player == null:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)

	var distance := global_position.distance_to(_player.global_position)
	_state = WildlifeAI.decide(_state, _perception(distance), def)
	match _state:
		WildlifeAI.State.FLEE:
			_move(global_position.direction_to(_player.global_position) * -1.0)
		WildlifeAI.State.ATTACK:
			_move(global_position.direction_to(_player.global_position))
			if WildlifeAI.in_strike_range(distance, def) and _attack_timer <= 0.0:
				_strike()
		WildlifeAI.State.INVESTIGATE:
			_circle()
		_:
			_wander(delta)

func _perception(distance: float) -> Dictionary:
	var active := String(def.get("active", "any"))
	var time_active := active == "any" \
			or (active == "night") == Sim.clock.is_night()
	return {
		"distance": distance,
		"health_fraction": health / float(def.get("max_health", 30.0)),
		"has_deterrent": _player.nearby_heat_c > 0.0,
		"player_in_shelter": _player.nearby_shelter > 0,
		"time_is_active": time_active,
	}

func _strike() -> void:
	var cfg: Dictionary = Balance.data["combat"]
	_attack_timer = float(cfg["attack_cooldown_seconds"])
	var damage := float(def.get("damage", 0.0))
	if damage <= 0.0 or _player.vitals == null:
		return
	var v := _player.vitals.state
	v.condition = maxf(0.0, v.condition - damage)
	if randf() < float(cfg["wound_infection_chance"]):
		if _player.vitals.system.trigger_affliction(v, "infection"):
			EventBus.affliction_started.emit("infection")
	EventBus.vitals_changed.emit(v)
	EventBus.player_wounded.emit(creature_id, damage)
	AudioService.play("warning")
	if v.condition <= 0.0 and v.alive:
		v.alive = false
		EventBus.player_died.emit()

func take_damage(amount: float, from: Vector2) -> void:
	health -= amount
	# Recoil away from the blow.
	global_position += (global_position - from).normalized() * 6.0
	if health <= 0.0:
		_die()

func _die() -> void:
	var loot := LootTable.roll(GatherDb.loot_table(String(def.get("loot_table", ""))),
			RandomNumberGenerator.new())
	for item_id: String in loot:
		EventBus.item_dropped.emit(item_id, int(loot[item_id]))
	EventBus.creature_killed.emit(creature_id)
	EventBus.notice.emit("The %s falls." % def.get("name", creature_id))
	queue_free()

## --- Movement helpers ---

func _move(direction: Vector2) -> void:
	velocity = direction * float(def.get("speed", 50.0))
	move_and_slide()

func _circle() -> void:
	# Keep distance, sidestep around the player (wary investigation).
	var to_player := global_position.direction_to(_player.global_position)
	_move(to_player.orthogonal() * 0.6)

func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(2.0, 5.0)
		_wander_target = global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	if global_position.distance_to(_wander_target) > 4.0:
		_move(global_position.direction_to(_wander_target) * 0.4)
	else:
		velocity = Vector2.ZERO

func _find_player() -> Player:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null

static func _texture_for(creature_id: String, def: Dictionary) -> Texture2D:
	if _textures.has(creature_id):
		return _textures[creature_id]
	var rgb: Array = def.get("color", [140, 140, 140])
	var body := Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
	var dark := body.darkened(0.3)
	var img := Image.create_empty(16, 14, false, Image.FORMAT_RGBA8)
	for y in range(4, 11):              # body
		for x in range(2, 14):
			img.set_pixel(x, y, body)
	for x in [2, 4, 11, 13]:            # legs
		img.set_pixel(x, 11, dark)
		img.set_pixel(x, 12, dark)
	for y in range(2, 6):               # head
		for x in range(12, 16):
			img.set_pixel(x, y, dark)
	var tex := ImageTexture.create_from_image(img)
	_textures[creature_id] = tex
	return tex
