## Storage transfer screen: the player's pack on the left, a container on the
## right. Click a slot to move one of that item to the other side. Opened by
## interacting with a storage building; closed with E/Esc.
extends Control

var _container: Inventory
var _pack: Inventory
var _pack_grid: GridContainer
var _store_grid: GridContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()
	EventBus.storage_opened.connect(_on_storage_opened)
	EventBus.inventory_changed.connect(func(_i: RefCounted) -> void:
		if visible:
			_refresh())

func bind_pack(pack: Inventory) -> void:
	_pack = pack

func _on_storage_opened(container: RefCounted) -> void:
	_container = container as Inventory
	visible = true
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		visible = false
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.96)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	panel.add_child(cols)
	cols.add_child(_make_side("Pack", false))
	cols.add_child(_make_side("Chest", true))

func _make_side(title: String, is_store: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	box.add_child(label)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	if is_store:
		_store_grid = grid
	else:
		_pack_grid = grid
	box.add_child(_hint("Click an item to move one across"))
	return box

func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.74, 0.78, 0.82))
	return label

func _refresh() -> void:
	if _pack == null or _container == null:
		return
	_fill_grid(_pack_grid, _pack, true)
	_fill_grid(_store_grid, _container, false)

func _fill_grid(grid: GridContainer, inv: Inventory, from_pack: bool) -> void:
	for child in grid.get_children():
		child.queue_free()
	for i in inv.slots.size():
		grid.add_child(_make_cell(inv, i, from_pack))

func _make_cell(inv: Inventory, index: int, from_pack: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(46, 46)
	button.focus_mode = Control.FOCUS_NONE
	var stack: Inventory.Stack = inv.slots[index]
	if stack != null:
		var def := ItemDb.get_def(stack.item_id)
		var icon := TextureRect.new()
		icon.texture = ItemIcons.texture_for(def)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		button.tooltip_text = "%s x%d" % [def.name, stack.qty]
		button.pressed.connect(_transfer.bind(index, from_pack))
	return button

## Move one unit from the clicked side to the other.
func _transfer(index: int, from_pack: bool) -> void:
	var source := _pack if from_pack else _container
	var dest := _container if from_pack else _pack
	var stack: Inventory.Stack = source.slots[index]
	if stack == null:
		return
	if dest.add(stack.item_id, 1) > 0:
		source.remove_slot(index, 1)
		EventBus.inventory_changed.emit(_pack)
		_refresh()
	else:
		EventBus.notice.emit("No room")
