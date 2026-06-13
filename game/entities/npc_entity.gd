## An NPC in the world: an original character with a time-of-day routine and a
## conversation. Walks toward its scheduled anchor for the current hour, and on
## proximity registers as the interact focus so [E] opens dialogue.
class_name NpcEntity
extends CharacterBody2D

var npc_id: String
var def: Dictionary

var _player: Player
var _speed: float
static var _textures: Dictionary = {}

static func create(npc_id: String) -> NpcEntity:
	var e := NpcEntity.new()
	e.npc_id = npc_id
	e.def = NpcDb.get_npc(npc_id)
	return e

func _ready() -> void:
	_speed = float(Balance.data["social"]["npc_speed"])
	position = _scheduled_target()

	var sprite := Sprite2D.new()
	sprite.texture = _texture_for(npc_id, def)
	add_child(sprite)

	var name_label := Label.new()
	name_label.text = String(def.get("name", npc_id))
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.position = Vector2(-18, -22)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(name_label)

	var body := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 12)
	body.shape = rect
	add_child(body)

	var area := Area2D.new()
	var area_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	area_shape.shape = circle
	area.add_child(area_shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	# Stand still while talking; otherwise amble toward the scheduled spot.
	if _player != null and _player.dialogue != null and _player.dialogue.is_talking():
		velocity = Vector2.ZERO
		return
	var target := _scheduled_target()
	if position.distance_to(target) > 3.0:
		velocity = position.direction_to(target) * _speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func _scheduled_target() -> Vector2:
	var hour := Sim.clock.hour()
	for entry: Dictionary in def.get("schedule", []):
		var from := int(entry["from"])
		var to := int(entry["to"])
		var active := (from <= hour and hour < to) if from <= to \
				else (hour >= from or hour < to)
		if active:
			var p: Array = entry["pos"]
			return Vector2(float(p[0]), float(p[1]))
	return position

## --- Interaction ---

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null:
		return
	_player = player
	if player.gathering != null:
		player.gathering.set_focus(self)

func _on_body_exited(body: Node) -> void:
	var player := body as Player
	if player != null and player.gathering != null:
		player.gathering.clear_focus(self)

func prompt_text(_gathering: GatheringComponent) -> String:
	var tier := ""
	if _player != null and _player.dialogue != null:
		tier = "  (%s)" % _player.dialogue.relationships.level_name(npc_id)
	return "[E] Talk to %s%s" % [def.get("name", npc_id), tier]

func interact(_gathering: GatheringComponent) -> void:
	if _player != null and _player.dialogue != null:
		_player.dialogue.open(npc_id)

## --- Procedural sprite (a figure, tinted per NPC) ---

static func _texture_for(npc_id: String, def: Dictionary) -> Texture2D:
	if _textures.has(npc_id):
		return _textures[npc_id]
	var rgb: Array = def.get("color", [150, 150, 150])
	var coat := Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
	var dark := coat.darkened(0.3)
	var skin := Color8(196, 176, 150)
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(2, 6):
		for x in range(6, 10):
			img.set_pixel(x, y, skin)
	for y in range(6, 13):
		for x in range(4, 12):
			img.set_pixel(x, y, coat)
	for y in range(13, 15):
		for x in [5, 6, 9, 10]:
			img.set_pixel(x, y, dark)
	var tex := ImageTexture.create_from_image(img)
	_textures[npc_id] = tex
	return tex
