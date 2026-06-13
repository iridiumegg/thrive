## Build-mode palette: a side panel listing buildables grouped by category, each
## showing its material cost and whether you can afford it right now. Clicking a
## row selects it for placement; a Remove toggle switches to pick-up mode.
## Shown only while build mode is active.
extends Control

var _controller: BuildController
var _list: VBoxContainer
var _remove_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	visible = false
	_build_ui()
	EventBus.build_mode_changed.connect(_on_build_mode_changed)
	EventBus.inventory_changed.connect(func(_i: RefCounted) -> void:
		if visible:
			_refresh())

func bind(controller: BuildController) -> void:
	_controller = controller

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -240
	panel.offset_top = 20
	panel.custom_minimum_size = Vector2(220, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.95)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Build  [B to exit]"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)

	_remove_button = Button.new()
	_remove_button.text = "Remove mode: off"
	_remove_button.toggle_mode = true
	_remove_button.focus_mode = Control.FOCUS_NONE
	_remove_button.toggled.connect(func(on: bool) -> void:
		_controller.set_remove_mode(on)
		_remove_button.text = "Remove mode: %s" % ("on" if on else "off"))
	box.add_child(_remove_button)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	box.add_child(_list)

func _on_build_mode_changed(is_active: bool) -> void:
	visible = is_active
	if is_active:
		_remove_button.button_pressed = false
		_remove_button.text = "Remove mode: off"
		_refresh()

func _refresh() -> void:
	if _controller == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var counts := _afford_counts()
	for category: String in BuildDb.categories:
		var header := Label.new()
		header.text = category
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color(0.7, 0.74, 0.78))
		_list.add_child(header)
		for id: String in BuildDb.ordered:
			var def: Dictionary = BuildDb.buildables[id]
			if String(def.get("category", "")) != category:
				continue
			_list.add_child(_make_row(id, def, counts))

func _make_row(id: String, def: Dictionary, counts: Dictionary) -> Button:
	var affordable := PlacementGrid.can_afford(def.get("cost", []), counts)
	var row := Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.text = "  %s — %s" % [def.get("name", id), _cost_text(def.get("cost", []))]
	row.add_theme_font_size_override("font_size", 11)
	var col := Color(0.86, 0.94, 0.84) if affordable else Color(0.72, 0.72, 0.74)
	row.add_theme_color_override("font_color", col)
	row.add_theme_color_override("font_hover_color", col)
	row.pressed.connect(func() -> void:
		_controller.select(id)
		_remove_button.button_pressed = false)
	return row

func _afford_counts() -> Dictionary:
	var counts: Dictionary = {}
	if _controller == null or _controller._player == null:
		return counts
	for stack: Inventory.Stack in _controller._player.inventory.inventory.slots:
		if stack != null:
			counts[stack.item_id] = int(counts.get(stack.item_id, 0)) + stack.qty
	return counts

func _cost_text(cost: Array) -> String:
	var parts: Array[String] = []
	for entry: Dictionary in cost:
		parts.append("%dx %s" % [int(entry["qty"]), ItemDb.get_def(String(entry["item"])).name])
	return ", ".join(parts)
