## Procedural item icons, so the repo ships no binary art (see ASSETS_LICENSES).
##
## Each item gets a small icon: a rounded, bordered tile tinted by category with
## a lighter inner glyph block, cached by item id. Reused by world pickups and
## the inventory grid so an item looks the same everywhere.
class_name ItemIcons
extends RefCounted

const SIZE := 16

## Muted cold palette, one tint per item category (locked art direction).
static var _category_color := {
	"material": Color8(120, 124, 130),
	"food": Color8(150, 92, 96),
	"clothing": Color8(86, 110, 140),
	"tool": Color8(170, 124, 72),
	"container": Color8(86, 140, 134),
}

static var _cache: Dictionary = {}   # item_id -> Texture2D

static func texture_for(def: ItemDef) -> Texture2D:
	if _cache.has(def.id):
		return _cache[def.id]
	var tex := ImageTexture.create_from_image(_render(def))
	_cache[def.id] = tex
	return tex

static func _render(def: ItemDef) -> Image:
	var base: Color = _category_color.get(def.category, Color8(120, 124, 130))
	var border := base.darkened(0.4)
	var inner := base.lightened(0.25)
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			# Rounded corners: leave the four corner pixels transparent.
			var corner := (x == 0 or x == SIZE - 1) and (y == 0 or y == SIZE - 1)
			if corner:
				continue
			var edge := x <= 1 or y <= 1 or x >= SIZE - 2 or y >= SIZE - 2
			img.set_pixel(x, y, border if edge else base)
	# Inner glyph block, its shape hinting at the category.
	for y in range(5, 11):
		for x in range(5, 11):
			img.set_pixel(x, y, inner)
	return img
