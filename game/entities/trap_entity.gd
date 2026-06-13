## A deployed snare trap in the world. Wraps a pure-logic Trap.
##
## Handles proximity focus, a small status sprite (set / caught), and ticking the
## trap off the sim clock with a deterministic RNG. Catch timing, success, and
## loot all live in the Trap state machine.
class_name TrapEntity
extends Area2D

var trap_id: String
var def: Dictionary
var trap: Trap

var _sprite: Sprite2D
var _rng: RandomNumberGenerator
static var _textures: Dictionary = {}

static func create(trap_id: String, world_position: Vector2, rng_tag: String) -> TrapEntity:
	var e := TrapEntity.new()
	e.trap_id = trap_id
	e.def = GatherDb.trap_defs[trap_id]
	e.position = world_position
	e.trap = GatherDb.new_trap(trap_id)
	e._rng = SeededRng.new(int(Balance.data["world_seed"])).stream("trap:" + rng_tag)
	return e

func _ready() -> void:
	_sprite = Sprite2D.new()
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.sim_minute.connect(_on_sim_minute)
	_refresh_visual()

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player != null and player.gathering != null:
		player.gathering.set_focus(self)

func _on_body_exited(body: Node) -> void:
	var player := body as Player
	if player != null and player.gathering != null:
		player.gathering.clear_focus(self)

func _on_sim_minute(minutes: int) -> void:
	if trap.tick(minutes, _rng):
		_refresh_visual()

## --- Interaction interface ---

func prompt_text(_gathering: GatheringComponent) -> String:
	if trap.is_caught():
		return "[E] Collect the snare's catch"
	if trap.is_armed():
		return "%s (set, waiting)" % def.get("name", trap_id)
	return "[E] Re-bait %s" % def.get("name", trap_id)

func interact(gathering: GatheringComponent) -> void:
	if trap.is_caught():
		gathering.collect_loot(trap.collect())
		_refresh_visual()
	elif trap.is_armed():
		EventBus.notice.emit("The snare is set — nothing yet")
	else:
		if _consume_bait(gathering):
			trap.arm()
			EventBus.notice.emit("Re-baited the snare")
			_refresh_visual()
		else:
			EventBus.notice.emit("You need bait to set this")

func _consume_bait(gathering: GatheringComponent) -> bool:
	for entry: Dictionary in def.get("bait", []):
		if not gathering.has_item(String(entry["item"]), int(entry["qty"])):
			return false
	for entry: Dictionary in def.get("bait", []):
		gathering.consume(String(entry["item"]), int(entry["qty"]))
	return true

func _refresh_visual() -> void:
	_sprite.texture = _status_texture(trap.state)

static func _status_texture(state: int) -> Texture2D:
	if _textures.has(state):
		return _textures[state]
	var color := Color8(150, 130, 90)         # armed: tan
	if state == Trap.State.CAUGHT:
		color = Color8(150, 92, 96)            # caught: meat red
	elif state == Trap.State.EMPTY:
		color = Color8(90, 88, 84)             # empty: drab grey
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var edge := x == 0 or y == 0 or x == 15 or y == 15
			# An X of cord across the trap.
			var cord := absi(x - y) <= 1 or absi(x + y - 15) <= 1
			if edge or cord:
				img.set_pixel(x, y, color.darkened(0.3) if edge else color)
	var tex := ImageTexture.create_from_image(img)
	_textures[state] = tex
	return tex
