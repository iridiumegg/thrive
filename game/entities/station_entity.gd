## A crafting station in the world (workbench, campfire, forge, tailoring bench).
##
## Proximity grants access to that station's recipes: stepping into range adds
## the station id to the player's crafting component, leaving removes it. A
## campfire/forge also doubles as a heat source for the warmth model while the
## player stands near it. Placement is hardcoded near the outpost for now; the
## building system (M7) will let the player craft and place these.
class_name StationEntity
extends Area2D

var station_id: String
var def: Dictionary

var _player_in_range := false
static var _textures: Dictionary = {}

static func create(station_id: String, world_position: Vector2) -> StationEntity:
	var e := StationEntity.new()
	e.station_id = station_id
	e.def = CraftDb.stations[station_id]
	e.position = world_position
	return e

func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _texture_for(station_id, def)
	add_child(sprite)

	var label := Label.new()
	label.text = String(def.get("name", station_id))
	label.add_theme_font_size_override("font_size", 8)
	label.position = Vector2(-20, -22)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null or player.crafting == null:
		return
	_player_in_range = true
	player.crafting.add_station(station_id)
	if bool(def.get("heat_source", false)) and player.vitals != null:
		player.vitals.campfire_on = true

func _on_body_exited(body: Node) -> void:
	var player := body as Player
	if player == null or player.crafting == null:
		return
	_player_in_range = false
	player.crafting.remove_station(station_id)
	if bool(def.get("heat_source", false)) and player.vitals != null:
		player.vitals.campfire_on = false

static func _texture_for(station_id: String, def: Dictionary) -> Texture2D:
	if _textures.has(station_id):
		return _textures[station_id]
	var rgb: Array = def.get("color", [150, 150, 150])
	var base := Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
	const S := 28
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var rim := base.darkened(0.4)
	var top := base.lightened(0.15)
	for y in S:
		for x in S:
			# A blocky "structure": darker rim, lighter top third.
			if x < 2 or y < 2 or x >= S - 2 or y >= S - 2:
				img.set_pixel(x, y, rim)
			elif y < S / 3:
				img.set_pixel(x, y, top)
			else:
				img.set_pixel(x, y, base)
	var tex := ImageTexture.create_from_image(img)
	_textures[station_id] = tex
	return tex
