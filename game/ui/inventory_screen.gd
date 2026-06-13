## Inventory screen: weight-based grid + equipment slots + item detail.
##
## Toggled with Tab/I. The grid is organisational (spec 9); the weight bar is
## the real constraint. Left-click a slot for its primary action (eat/drink or
## equip); right-click to drop one. Equipment slots show what's worn and can be
## clicked to stow. Built entirely in code — no scene file, no binary assets.
extends Control

const COLUMNS := 6
const CELL := 52
const CELL_PAD := 4

var _grid: GridContainer
var _equip_box: VBoxContainer
var _weight_label: Label
var _weight_bar: ProgressBar
var _detail_name: Label
var _detail_body: Label
var _inv_component: InventoryComponent
var _slot_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()
	EventBus.inventory_changed.connect(func(_i: RefCounted) -> void: _refresh())
	EventBus.equipment_changed.connect(func(_e: RefCounted) -> void: _refresh())

func bind(component: InventoryComponent) -> void:
	_inv_component = component
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		visible = not visible
		if visible:
			_refresh()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()

## --- Construction ---

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.add_theme_constant_override("separation", 24)
	add_child(root)
	# Center the panel after layout.
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

	# Left: grid + weight bar.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	left.add_child(_heading("Pack"))
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", CELL_PAD)
	_grid.add_theme_constant_override("v_separation", CELL_PAD)
	left.add_child(_grid)

	_weight_label = _plain_label("")
	left.add_child(_weight_label)
	_weight_bar = ProgressBar.new()
	_weight_bar.show_percentage = false
	_weight_bar.custom_minimum_size = Vector2(COLUMNS * (CELL + CELL_PAD), 10)
	left.add_child(_weight_bar)

	left.add_child(_plain_label("Left-click: use / equip      Right-click: drop one"))

	# Right: equipment + item detail.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(220, 0)
	root.add_child(right)

	right.add_child(_heading("Worn"))
	_equip_box = VBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 4)
	right.add_child(_equip_box)

	right.add_child(_heading("Detail"))
	_detail_name = _plain_label("")
	_detail_name.add_theme_font_size_override("font_size", 15)
	right.add_child(_detail_name)
	_detail_body = _plain_label("")
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.custom_minimum_size = Vector2(220, 0)
	right.add_child(_detail_body)

func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	return label

func _plain_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.82, 0.85, 0.88))
	return label

## --- Refresh ---

func _refresh() -> void:
	if _inv_component == null or not visible:
		return
	_refresh_grid()
	_refresh_equipment()
	_refresh_weight()

func _refresh_grid() -> void:
	var inv := _inv_component.inventory
	# Build buttons once, then update them in place.
	if _slot_buttons.size() != inv.slots.size():
		for child in _grid.get_children():
			child.queue_free()
		_slot_buttons.clear()
		for i in inv.slots.size():
			var button := _make_slot_button(i)
			_grid.add_child(button)
			_slot_buttons.append(button)

	for i in inv.slots.size():
		var button := _slot_buttons[i]
		var stack: Inventory.Stack = inv.slots[i]
		var icon: TextureRect = button.get_child(0)
		var qty_label: Label = button.get_child(1)
		if stack == null:
			icon.texture = null
			qty_label.text = ""
			button.tooltip_text = ""
		else:
			var def := ItemDb.get_def(stack.item_id)
			icon.texture = ItemIcons.texture_for(def)
			qty_label.text = "%d" % stack.qty if stack.qty > 1 else ""
			button.tooltip_text = def.name

func _make_slot_button(index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(CELL, CELL)
	button.focus_mode = Control.FOCUS_NONE

	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	var qty := Label.new()
	qty.add_theme_font_size_override("font_size", 12)
	qty.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	qty.offset_left = -16
	qty.offset_top = -16
	qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(qty)

	button.gui_input.connect(_on_slot_input.bind(index))
	button.mouse_entered.connect(_on_slot_hover.bind(index))
	return button

func _on_slot_input(event: InputEvent, index: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_inv_component.use_slot(index)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_inv_component.drop_slot(index)

func _on_slot_hover(index: int) -> void:
	var stack: Inventory.Stack = _inv_component.inventory.slots[index]
	if stack == null:
		_show_detail(null)
	else:
		_show_detail(ItemDb.get_def(stack.item_id))

func _refresh_equipment() -> void:
	for child in _equip_box.get_children():
		child.queue_free()
	for slot in Equipment.SLOTS:
		var id := _inv_component.equipment.equipped(slot)
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(220, 28)
		if id == "":
			row.text = "  %s: —" % slot.capitalize()
			row.disabled = true
		else:
			var def := ItemDb.get_def(id)
			var warmth := "  (+%.0f°)" % def.insulation_c if def.insulation_c > 0.0 else ""
			row.text = "  %s: %s%s" % [slot.capitalize(), def.name, warmth]
			row.pressed.connect(_inv_component.unequip.bind(slot))
			row.mouse_entered.connect(func() -> void: _show_detail(ItemDb.get_def(id)))
		_equip_box.add_child(row)

func _refresh_weight() -> void:
	var inv := _inv_component.inventory
	_weight_bar.max_value = inv.weight_capacity
	_weight_bar.value = inv.total_weight()
	var fraction := inv.weight_fraction()
	var heavy := float(Balance.data["inventory"]["heavy_threshold_fraction"])
	var suffix := "  (heavy — slowed)" if fraction > heavy else ""
	_weight_label.text = "Weight  %.1f / %.0f kg%s" % [
			inv.total_weight(), inv.weight_capacity, suffix]
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color8(150, 168, 110) if fraction <= heavy else Color8(196, 120, 88)
	_weight_bar.add_theme_stylebox_override("fill", fill)

func _show_detail(def: ItemDef) -> void:
	if def == null:
		_detail_name.text = ""
		_detail_body.text = ""
		return
	_detail_name.text = def.name
	var lines: Array[String] = [def.description, "", "Weight %.1f kg   Value %d" % [def.weight, def.value]]
	if def.is_edible():
		var kcal := int(def.food.get("kcal", 0))
		var hyd := int(def.food.get("hydration_pct", 0))
		var parts: Array[String] = []
		if kcal > 0:
			parts.append("+%d kcal" % kcal)
		if hyd > 0:
			parts.append("+%d%% hydration" % hyd)
		lines.append("Eat/Drink: " + ", ".join(parts))
	if def.is_equippable():
		lines.append("Equip (%s)%s" % [
				def.equip_slot,
				"   +%.0f° warmth" % def.insulation_c if def.insulation_c > 0.0 else ""])
	_detail_body.text = "\n".join(lines)
