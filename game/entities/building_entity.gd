## A placed structure in the world. One class covers every buildable role, read
## from its buildables.json def:
##   - station: grants its crafting recipes while the player is in range
##   - heat_c:  adds warmth to the player nearby (feeds the vitals model)
##   - shelter: cancels wind chill / wetness nearby
##   - storage: holds an Inventory the player can open and transfer to/from
##   - bed:     interact to sleep through to morning (and, later, save)
##
## Proximity wires the station/heat/shelter roles; interact handles storage/bed.
## Replaces the earlier StationEntity (the outpost now uses these too).
class_name BuildingEntity
extends Area2D

var building_id: String
var def: Dictionary
var cell: Vector2i
var storage: Inventory          # only for storage buildings

var _player_in_range: Player
static var _textures: Dictionary = {}

static func create(building_id: String, world_position: Vector2) -> BuildingEntity:
	var e := BuildingEntity.new()
	e.building_id = building_id
	e.def = BuildDb.get_def(building_id)
	e.position = world_position
	if int(e.def.get("storage_slots", 0)) > 0:
		e.storage = Inventory.new(int(e.def["storage_slots"]), 9999.0, ItemDb.catalog)
	return e

func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _texture_for(building_id, def)
	add_child(sprite)

	var label := Label.new()
	label.text = String(def.get("name", building_id))
	label.add_theme_font_size_override("font_size", 8)
	label.position = Vector2(-22, -24)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null:
		return
	_player_in_range = player
	if def.has("station") and player.crafting != null:
		player.crafting.add_station(String(def["station"]))
	player.nearby_heat_c += float(def.get("heat_c", 0.0))
	if bool(def.get("shelter", false)):
		player.nearby_shelter += 1
	if has_interaction() and player.gathering != null:
		player.gathering.set_focus(self)

func _on_body_exited(body: Node) -> void:
	var player := body as Player
	if player == null:
		return
	_player_in_range = null
	if def.has("station") and player.crafting != null:
		player.crafting.remove_station(String(def["station"]))
	player.nearby_heat_c = maxf(0.0, player.nearby_heat_c - float(def.get("heat_c", 0.0)))
	if bool(def.get("shelter", false)):
		player.nearby_shelter = maxi(0, player.nearby_shelter - 1)
	if has_interaction() and player.gathering != null:
		player.gathering.clear_focus(self)

## --- Interaction (storage / bed) ---

func has_interaction() -> bool:
	return storage != null or bool(def.get("bed", false))

func prompt_text(_gathering: GatheringComponent) -> String:
	if storage != null:
		return "[E] Open %s" % def.get("name", building_id)
	if bool(def.get("bed", false)):
		return "[E] Sleep at the %s" % def.get("name", building_id)
	return ""

func interact(gathering: GatheringComponent) -> void:
	if storage != null:
		EventBus.storage_opened.emit(storage)
	elif bool(def.get("bed", false)):
		EventBus.sleep_requested.emit()

## --- Cleanup when picked up ---

func detach(player: Player) -> void:
	# Mirror the exit effects in case the player is standing on it when removed.
	if _player_in_range == player:
		_on_body_exited(player)

## --- Procedural sprite ---

static func _texture_for(building_id: String, def: Dictionary) -> Texture2D:
	if _textures.has(building_id):
		return _textures[building_id]
	var rgb: Array = def.get("color", [150, 150, 150])
	var base := Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
	const S := 28
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var rim := base.darkened(0.4)
	var top := base.lightened(0.15)
	for y in S:
		for x in S:
			if x < 2 or y < 2 or x >= S - 2 or y >= S - 2:
				img.set_pixel(x, y, rim)
			elif y < S / 3:
				img.set_pixel(x, y, top)
			else:
				img.set_pixel(x, y, base)
	var tex := ImageTexture.create_from_image(img)
	_textures[building_id] = tex
	return tex
