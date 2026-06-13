## A found document in the world — a note, journal page, or carving. Walk up and
## interact to read it: this reveals lore, sets a story flag, and logs it in the
## codex. Uses the same proximity-focus pattern as nodes and NPCs.
class_name NoteEntity
extends Area2D

var note_id: String
var def: Dictionary

var _player: Player
static var _texture: Texture2D

static func create(note_id: String) -> NoteEntity:
	var e := NoteEntity.new()
	e.note_id = note_id
	e.def = LoreDb.get_note(note_id)
	var p: Array = e.def.get("pos", [0, 0])
	e.position = Vector2(float(p[0]), float(p[1]))
	return e

func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _parchment_texture()
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

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
	var seen := _player != null and _player.story != null and _player.story.has_read(note_id)
	return "[E] %s %s" % ["Reread" if seen else "Read", def.get("title", "a note")]

func interact(_gathering: GatheringComponent) -> void:
	if _player != null and _player.story != null:
		_player.story.read_document(note_id)

static func _parchment_texture() -> Texture2D:
	if _texture != null:
		return _texture
	var paper := Color8(196, 184, 150)
	var ink := Color8(90, 78, 58)
	var img := Image.create_empty(14, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 14:
			if x == 0 or y == 0 or x == 13 or y == 13:
				img.set_pixel(x, y, ink)
			else:
				img.set_pixel(x, y, paper)
	for y in [3, 5, 7, 9]:               # ruled lines of "text"
		for x in range(3, 11):
			img.set_pixel(x, y, ink)
	_texture = ImageTexture.create_from_image(img)
	return _texture
