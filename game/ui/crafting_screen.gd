## Crafting screen: category tabs, a recipe list with craftable-now highlighting
## and missing-ingredient counts, a detail panel, and the live craft queue.
##
## Toggled with C. Recipes you don't yet know are hidden until learned. The list
## shows, per recipe, whether it can be made right now and (if not) what's short
## or which station is needed — the spec's "craftable now" + "where do I get X"
## hooks. Built in code; no scene file, no binary assets.
extends Control

const PANEL_BG := Color(0.06, 0.07, 0.09, 0.96)

var _crafting: CraftingComponent
var _tab_bar: HBoxContainer
var _recipe_list: VBoxContainer
var _detail: VBoxContainer
var _queue_box: VBoxContainer
var _station_label: Label
var _active_category: String = ""
var _selected_recipe: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()
	EventBus.inventory_changed.connect(func(_i: RefCounted) -> void: _refresh())
	EventBus.stations_changed.connect(func(_s: Array) -> void: _refresh())
	EventBus.crafting_queue_changed.connect(func(_q: Array) -> void: _refresh_queue())
	EventBus.recipe_learned.connect(func(_r: String) -> void: _rebuild_tabs())

func bind(component: CraftingComponent) -> void:
	_crafting = component

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_crafting"):
		visible = not visible
		if visible:
			_rebuild_tabs()
			_refresh()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()

## --- Construction ---

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.custom_minimum_size = Vector2(720, 460)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "Crafting"
	title.add_theme_font_size_override("font_size", 20)
	outer.add_child(title)

	_station_label = _muted_label("")
	outer.add_child(_station_label)

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)
	outer.add_child(_tab_bar)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)

	# Left: scrollable recipe list.
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(330, 320)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(list_scroll)
	_recipe_list = VBoxContainer.new()
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list.add_theme_constant_override("separation", 3)
	list_scroll.add_child(_recipe_list)

	# Right: detail + queue.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(330, 0)
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 3)
	right.add_child(_detail)

	var queue_title := Label.new()
	queue_title.text = "Queue"
	queue_title.add_theme_font_size_override("font_size", 16)
	right.add_child(queue_title)
	_queue_box = VBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 3)
	right.add_child(_queue_box)

	outer.add_child(_muted_label("[C] close    Crafting runs over time — keep an eye on your needs."))

func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86))
	return label

## --- Tabs ---

func _rebuild_tabs() -> void:
	if _crafting == null:
		return
	for child in _tab_bar.get_children():
		child.queue_free()
	var cats := _known_categories()
	if _active_category == "" or _active_category not in cats:
		_active_category = cats[0] if not cats.is_empty() else ""
	for category in cats:
		var tab := Button.new()
		tab.text = category
		tab.toggle_mode = true
		tab.button_pressed = category == _active_category
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(func() -> void:
			_active_category = category
			_rebuild_tabs()
			_refresh())
		_tab_bar.add_child(tab)

func _known_categories() -> Array:
	var cats: Array = []
	for category: String in CraftDb.categories:
		for recipe_id: String in CraftDb.recipes:
			if String(CraftDb.recipes[recipe_id].get("category", "")) == category \
					and _crafting.knows(recipe_id):
				cats.append(category)
				break
	return cats

## --- Recipe list ---

func _refresh() -> void:
	if _crafting == null or not visible:
		return
	_station_label.text = "Stations in range: " + ", ".join(_station_names())
	for child in _recipe_list.get_children():
		child.queue_free()
	for recipe_id: String in CraftDb.recipes:
		var recipe: Dictionary = CraftDb.recipes[recipe_id]
		if String(recipe.get("category", "")) != _active_category:
			continue
		if not _crafting.knows(recipe_id):
			continue
		_recipe_list.add_child(_make_recipe_row(recipe_id, recipe))
	_refresh_detail()
	_refresh_queue()

func _station_names() -> Array:
	var names: Array = []
	for id: String in _crafting.station_ids():
		names.append(CraftDb.station_name(id))
	return names

func _make_recipe_row(recipe_id: String, recipe: Dictionary) -> Button:
	var check := _crafting.can_craft(recipe_id)
	var row := Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, 30)
	var mark := "●" if check["ok"] else "○"
	row.text = "  %s  %s" % [mark, recipe.get("display_name", recipe_id)]
	var color := Color(0.85, 0.95, 0.82) if check["ok"] else Color(0.7, 0.72, 0.74)
	row.add_theme_color_override("font_color", color)
	row.add_theme_color_override("font_hover_color", color)
	row.pressed.connect(func() -> void:
		_selected_recipe = recipe_id
		_refresh_detail())
	return row

## --- Detail panel ---

func _refresh_detail() -> void:
	for child in _detail.get_children():
		child.queue_free()
	if _selected_recipe == "" or not CraftDb.recipes.has(_selected_recipe):
		_detail.add_child(_muted_label("Select a recipe."))
		return
	var recipe: Dictionary = CraftDb.recipes[_selected_recipe]
	var counts := _crafting.inventory_counts()

	var name_label := Label.new()
	name_label.text = String(recipe.get("display_name", _selected_recipe))
	name_label.add_theme_font_size_override("font_size", 16)
	_detail.add_child(name_label)

	_detail.add_child(_muted_label("Station: %s    Time: %d min" % [
			CraftDb.station_name(String(recipe.get("station", "hand"))),
			int(recipe.get("craft_time", 0))]))

	# Skill + the quality this craft would currently produce.
	if _crafting.skills != null:
		var skill_id := _crafting.skills.skill_for_recipe(_selected_recipe)
		var tier: Dictionary = _crafting.skills.quality_for_recipe(_selected_recipe)
		_detail.add_child(_muted_label("Skill: %s lvl %d    Quality: %s" % [
				skill_id.capitalize(), _crafting.skills.level(skill_id),
				tier.get("name", "Standard")]))

	_detail.add_child(_muted_label("Needs:"))
	for inp: Dictionary in recipe.get("inputs", []):
		var item_id := String(inp["item"])
		var need := int(inp["qty"])
		var have := int(counts.get(item_id, 0))
		var line := Label.new()
		line.text = "   %s  %d / %d" % [ItemDb.get_def(item_id).name, have, need]
		line.add_theme_font_size_override("font_size", 12)
		line.add_theme_color_override("font_color",
				Color(0.82, 0.9, 0.8) if have >= need else Color(0.9, 0.6, 0.55))
		_detail.add_child(line)

	_detail.add_child(_muted_label("Makes:"))
	for out: Dictionary in recipe.get("outputs", []):
		_detail.add_child(_muted_label("   %s x%d" % [
				ItemDb.get_def(String(out["item"])).name, int(out["qty"])]))

	var check := _crafting.can_craft(_selected_recipe)
	var craft_button := Button.new()
	craft_button.text = "Craft" if check["ok"] else String(check["reason"])
	craft_button.disabled = not check["ok"]
	craft_button.focus_mode = Control.FOCUS_NONE
	craft_button.pressed.connect(func() -> void:
		_crafting.craft(_selected_recipe)
		_refresh())
	_detail.add_child(craft_button)

## --- Queue ---

func _refresh_queue() -> void:
	if _crafting == null:
		return
	for child in _queue_box.get_children():
		child.queue_free()
	if _crafting.system.queue.is_empty():
		_queue_box.add_child(_muted_label("Idle."))
		return
	for i in _crafting.system.queue.size():
		var job: CraftingSystem.Job = _crafting.system.queue[i]
		var row := HBoxContainer.new()
		var label := _muted_label("%s  %d%%" % [
				CraftDb.recipes[job.recipe_id]["display_name"], int(job.progress() * 100.0)])
		label.custom_minimum_size = Vector2(250, 0)
		row.add_child(label)
		if i == 0:
			var cancel := Button.new()
			cancel.text = "✕"
			cancel.focus_mode = Control.FOCUS_NONE
			cancel.pressed.connect(func() -> void: _crafting.cancel_active())
			row.add_child(cancel)
		_queue_box.add_child(row)

func _process(_delta: float) -> void:
	# Live progress while a craft runs.
	if visible and _crafting != null and _crafting.system.is_busy():
		_refresh_queue()
