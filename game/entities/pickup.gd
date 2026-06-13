## A stack of an item lying in the world. Walk over it to collect.
##
## Auto-collects on contact; if the pack can't hold the whole stack, it keeps
## the remainder on the ground so nothing is silently lost.
class_name Pickup
extends Area2D

var item_id: String
var qty: int

var _sprite: Sprite2D
var _qty_label: Label

static func create(item_id: String, qty: int, world_position: Vector2) -> Pickup:
	var p := Pickup.new()
	p.item_id = item_id
	p.qty = qty
	p.position = world_position
	return p

func _ready() -> void:
	var def := ItemDb.get_def(item_id)

	_sprite = Sprite2D.new()
	_sprite.texture = ItemIcons.texture_for(def)
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)

	_qty_label = Label.new()
	_qty_label.add_theme_font_size_override("font_size", 8)
	_qty_label.position = Vector2(2, -2)
	add_child(_qty_label)
	_refresh_label()

	body_entered.connect(_on_body_entered)

func _refresh_label() -> void:
	_qty_label.text = "x%d" % qty if qty > 1 else ""

func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null or player.inventory == null:
		return
	var taken := player.inventory.pickup(item_id, qty)
	qty -= taken
	if qty <= 0:
		queue_free()
	else:
		_refresh_label()
