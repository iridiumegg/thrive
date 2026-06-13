## Drives build mode: a snapped ghost preview, placement validity, material
## cost, and pick-up/move. Lives as a Node2D so it can host the ghost sprite and
## read the world mouse position. Occupancy + cost math come from the pure
## PlacementGrid; terrain validity is delegated back to the world.
class_name BuildController
extends Node2D

const CELL := 16

var active := false
var remove_mode := false
var selected_id := ""

var grid: PlacementGrid
var _player: Player
var _container: Node2D
var _is_land: Callable          # func(Vector2i cell) -> bool, from the world
var _ghost: Sprite2D
var _cells: Dictionary = {}     # Vector2i -> BuildingEntity

func setup(player: Player, container: Node2D, is_land: Callable) -> void:
	_player = player
	_container = container
	_is_land = is_land
	grid = PlacementGrid.new(CELL)

func _ready() -> void:
	_ghost = Sprite2D.new()
	_ghost.modulate = Color(1, 1, 1, 0.55)
	_ghost.visible = false
	add_child(_ghost)

## Pre-place a structure with no cost (the surviving outpost stations).
func place_prebuilt(building_id: String, world_position: Vector2) -> BuildingEntity:
	var cell := grid.world_to_cell(world_position)
	return _spawn(building_id, cell)

## --- Mode ---

func toggle() -> void:
	set_active(not active)

func set_active(value: bool) -> void:
	active = value
	_ghost.visible = active and not remove_mode and selected_id != ""
	if not active:
		remove_mode = false
	EventBus.build_mode_changed.emit(active)

func select(building_id: String) -> void:
	selected_id = building_id
	remove_mode = false
	if active:
		_ghost.texture = BuildingEntity._texture_for(building_id, BuildDb.get_def(building_id))
		_ghost.visible = true

func set_remove_mode(value: bool) -> void:
	remove_mode = value
	_ghost.visible = active and not remove_mode and selected_id != ""

## --- Per-frame ghost ---

func _process(_delta: float) -> void:
	if not active or remove_mode or selected_id == "":
		_ghost.visible = false
		return
	var cell := grid.world_to_cell(get_global_mouse_position())
	_ghost.visible = true
	_ghost.position = grid.cell_to_world(cell)
	_ghost.modulate = Color(0.6, 1.0, 0.6, 0.55) if _can_place(cell) else Color(1.0, 0.5, 0.5, 0.55)

## --- Input (only while active; world routes the toggle) ---

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var cell := grid.world_to_cell(get_global_mouse_position())
		if remove_mode:
			_remove(cell)
		else:
			_place(cell)
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		set_active(false)

## --- Placement ---

func _can_place(cell: Vector2i) -> bool:
	return grid.is_free(cell) and _is_land.call(cell) and _affordable(selected_id)

func _affordable(building_id: String) -> bool:
	return PlacementGrid.can_afford(BuildDb.get_def(building_id).get("cost", []), _counts())

func _place(cell: Vector2i) -> void:
	if selected_id == "":
		return
	if not grid.is_free(cell):
		EventBus.notice.emit("Something's already there")
		return
	if not _is_land.call(cell):
		EventBus.notice.emit("Can't build on water")
		return
	var cost: Array = BuildDb.get_def(selected_id).get("cost", [])
	if not PlacementGrid.can_afford(cost, _counts()):
		EventBus.notice.emit("Need: " + _cost_text(cost))
		return
	for entry: Dictionary in cost:
		_player.inventory.inventory.remove(String(entry["item"]), int(entry["qty"]))
	EventBus.inventory_changed.emit(_player.inventory.inventory)
	_spawn(selected_id, cell)
	EventBus.structure_built.emit(selected_id)
	EventBus.notice.emit("Built %s" % BuildDb.get_def(selected_id)["name"])

func _remove(cell: Vector2i) -> void:
	if not _cells.has(cell):
		return
	var entity: BuildingEntity = _cells[cell]
	var building_id := entity.building_id
	# Refund the full material cost.
	for entry: Dictionary in BuildDb.get_def(building_id).get("cost", []):
		_player.inventory.inventory.add(String(entry["item"]), int(entry["qty"]))
	entity.detach(_player)
	grid.vacate(cell)
	_cells.erase(cell)
	entity.queue_free()
	EventBus.inventory_changed.emit(_player.inventory.inventory)
	EventBus.structure_removed.emit(building_id)
	EventBus.notice.emit("Removed %s" % BuildDb.get_def(building_id)["name"])

func _spawn(building_id: String, cell: Vector2i) -> BuildingEntity:
	var entity := BuildingEntity.create(building_id, grid.cell_to_world(cell))
	entity.cell = cell
	grid.occupy(cell, building_id)
	_cells[cell] = entity
	_container.add_child(entity)
	return entity

func _counts() -> Dictionary:
	var counts: Dictionary = {}
	for stack: Inventory.Stack in _player.inventory.inventory.slots:
		if stack != null:
			counts[stack.item_id] = int(counts.get(stack.item_id, 0)) + stack.qty
	return counts

func _cost_text(cost: Array) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in cost:
		parts.append("%s x%d" % [ItemDb.get_def(String(entry["item"])).name, int(entry["qty"])])
	return ", ".join(parts)
