## A resource node in the world (tree, boulder, ore vein, bush, spring).
##
## Wraps a pure-logic HarvestNode and handles only the engine concerns:
## proximity focus, a procedural sprite, depletion/regrowth visuals, and ticking
## the respawn timer off the sim clock. All yield/gating rules live in HarvestNode.
class_name ResourceNodeEntity
extends Area2D

var node_id: String
var def: Dictionary
var harvest_node: HarvestNode    # null for non-harvest nodes (e.g. springs)

var _sprite: Sprite2D
static var _texture_cache: Dictionary = {}

static func create(node_id: String, world_position: Vector2, rng_tag: String) -> ResourceNodeEntity:
	var e := ResourceNodeEntity.new()
	e.node_id = node_id
	e.def = GatherDb.node_defs[node_id]
	e.position = world_position
	if e.def.get("action", "harvest") == "harvest":
		e.harvest_node = GatherDb.new_node(node_id, rng_tag)
	return e

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = _texture_for(node_id, def)
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if harvest_node != null:
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
	if harvest_node.tick(minutes):
		_refresh_visual()

## --- Interaction interface (called by the gathering component) ---

func prompt_text(gathering: GatheringComponent) -> String:
	var label := String(def.get("name", node_id))
	if def.get("action", "harvest") == "drink":
		return "[E] Drink at %s" % label
	if harvest_node.is_depleted():
		return "%s (regrowing)" % label
	var tag := harvest_node.required_tag()
	if gathering.tool_tier_for(tag) < harvest_node.required_tier():
		return "%s — needs %s (tier %d)" % [label, tag.capitalize(), harvest_node.required_tier()]
	return "[E] Harvest %s" % label

func interact(gathering: GatheringComponent) -> void:
	if def.get("action", "harvest") == "drink":
		_drink(gathering)
		return
	var tag := harvest_node.required_tag()
	var tier := gathering.tool_tier_for(tag)
	if harvest_node.is_depleted():
		EventBus.notice.emit("%s is spent — give it time" % def.get("name", node_id))
		return
	if not harvest_node.can_harvest(tier):
		EventBus.notice.emit("You need a %s (tier %d) for that" % [
				tag.capitalize(), harvest_node.required_tier()])
		return
	var loot := harvest_node.harvest(tier, gathering.skill_bonus_rolls())
	gathering.collect_loot(loot)
	if tag != "":
		gathering.damage_tool()
	gathering.spend_energy(float(Balance.data["gathering"]["harvest_energy_cost"]))
	EventBus.node_harvested.emit(node_id, loot)
	_refresh_visual()

func _drink(gathering: GatheringComponent) -> void:
	gathering.restore_hydration(float(def.get("hydration_pct", 0.0)))
	EventBus.notice.emit("You drink deeply at the %s" % def.get("name", node_id))
	var fills: Dictionary = def.get("fills", {})
	if not fills.is_empty() and gathering.fill_container(String(fills["from"]), String(fills["to"])):
		EventBus.notice.emit("Filled a waterskin")

func _refresh_visual() -> void:
	if harvest_node != null and harvest_node.is_depleted():
		_sprite.modulate = Color(0.5, 0.5, 0.5, 0.6)
	else:
		_sprite.modulate = Color.WHITE

## --- Procedural sprite (no binary assets) ---

static func _texture_for(node_id: String, def: Dictionary) -> Texture2D:
	if _texture_cache.has(node_id):
		return _texture_cache[node_id]
	var rgb: Array = def.get("color", [120, 120, 120])
	var base := Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))
	var tex := ImageTexture.create_from_image(_render_blob(base))
	_texture_cache[node_id] = tex
	return tex

## A rounded blob with a darker rim — reads as "a thing on the ground".
static func _render_blob(base: Color) -> Image:
	const S := 24
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var center := Vector2(S, S) * 0.5
	var rim := base.darkened(0.35)
	for y in S:
		for x in S:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= S * 0.5 - 1.0:
				img.set_pixel(x, y, rim if d > S * 0.5 - 3.0 else base)
	return img
