## Grid occupancy + build-cost math for the building system. Pure logic.
##
## Tracks which grid cells are taken so structures snap to the grid and can't
## overlap, and answers affordability questions against an inventory snapshot.
## Terrain validity (land vs water) stays in the world, which owns the tilemap;
## everything here is engine-free and unit-tested.
class_name PlacementGrid
extends RefCounted

var cell_size: int
var occupied: Dictionary = {}   # Vector2i -> building_id

func _init(cell_size_: int) -> void:
	cell_size = cell_size_

func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.y / cell_size))

## Centre of a cell in world space.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * cell_size) + Vector2(cell_size, cell_size) * 0.5

func is_free(cell: Vector2i) -> bool:
	return not occupied.has(cell)

func occupy(cell: Vector2i, building_id: String) -> void:
	occupied[cell] = building_id

func vacate(cell: Vector2i) -> void:
	occupied.erase(cell)

func building_at(cell: Vector2i) -> String:
	return String(occupied.get(cell, ""))

## --- Build cost ---

static func missing(cost: Array, counts: Dictionary) -> Dictionary:
	var short: Dictionary = {}
	for entry: Dictionary in cost:
		var deficit := int(entry["qty"]) - int(counts.get(String(entry["item"]), 0))
		if deficit > 0:
			short[String(entry["item"])] = deficit
	return short

static func can_afford(cost: Array, counts: Dictionary) -> bool:
	return missing(cost, counts).is_empty()
