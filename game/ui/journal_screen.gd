## Quest journal: active quests with checklists and progress counts, plus a
## completed list. Toggled with J. A compact always-on tracker (top-right) shows
## the current active objectives at a glance.
extends Control

var _quests: QuestComponent
var _active_box: VBoxContainer
var _done_box: VBoxContainer
var _lore_box: VBoxContainer
var _tracker: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_tracker()
	_build_panel()
	_panel.visible = false
	EventBus.quest_progress_changed.connect(_refresh)
	EventBus.quest_activated.connect(func(_id: String) -> void: _refresh())
	EventBus.quest_completed.connect(func(_id: String) -> void: _refresh())

var _panel: Control

func bind(quests: QuestComponent) -> void:
	_quests = quests
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_journal"):
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refresh()
		get_viewport().set_input_as_handled()
	elif _panel.visible and event.is_action_pressed("ui_cancel"):
		_panel.visible = false
		get_viewport().set_input_as_handled()

## --- Always-on tracker ---

func _build_tracker() -> void:
	_tracker = Label.new()
	_tracker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tracker.offset_left = -320
	_tracker.offset_top = 10
	_tracker.offset_right = -12
	_tracker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tracker.add_theme_font_size_override("font_size", 12)
	_tracker.add_theme_color_override("font_color", Color(0.92, 0.9, 0.74))
	_tracker.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_tracker.add_theme_constant_override("shadow_offset_x", 1)
	_tracker.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_tracker)

## --- Full panel ---

func _build_panel() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(dim)

	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	frame.custom_minimum_size = Vector2(560, 440)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	style.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", style)
	_panel.add_child(frame)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	box.add_child(_title("Journal  [J to close]", 20))
	box.add_child(_title("Active", 16))
	_active_box = VBoxContainer.new()
	_active_box.add_theme_constant_override("separation", 8)
	box.add_child(_active_box)
	box.add_child(_title("Completed", 16))
	_done_box = VBoxContainer.new()
	_done_box.add_theme_constant_override("separation", 2)
	box.add_child(_done_box)

	box.add_child(_title("Lore", 16))
	_lore_box = VBoxContainer.new()
	_lore_box.add_theme_constant_override("separation", 2)
	box.add_child(_lore_box)

func _title(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label

## --- Refresh ---

func _refresh() -> void:
	if _quests == null:
		return
	_refresh_tracker()
	if not _panel.visible:
		return
	for child in _active_box.get_children():
		child.queue_free()
	for id in _quests.system.active_ids():
		_active_box.add_child(_quest_block(id))
	if _quests.system.active_ids().is_empty():
		_active_box.add_child(_line("Nothing pressing right now.", Color(0.7, 0.72, 0.74)))
	for child in _done_box.get_children():
		child.queue_free()
	for id in _quests.system.completed_ids():
		_done_box.add_child(_line("✓ " + String(QuestDb.quests[id]["title"]), Color(0.6, 0.78, 0.62)))

	for child in _lore_box.get_children():
		child.queue_free()
	var flags := _quests.flags
	var any_lore := false
	for note_id in LoreDb.ordered_notes:
		var note: Dictionary = LoreDb.get_note(note_id)
		if flags.has_flag(String(note.get("flag", ""))):
			any_lore = true
			_lore_box.add_child(_line("• " + String(note["title"]), Color(0.86, 0.82, 0.66)))
			_lore_box.add_child(_line("   " + String(note["body"]).replace("\n", " "), Color(0.7, 0.7, 0.66)))
	if not any_lore:
		_lore_box.add_child(_line("No documents found yet.", Color(0.66, 0.68, 0.7)))

func _quest_block(id: String) -> VBoxContainer:
	var quest: Dictionary = QuestDb.quests[id]
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 1)
	var head := _line(String(quest["title"]), Color(0.95, 0.92, 0.78))
	head.add_theme_font_size_override("font_size", 14)
	block.add_child(head)
	block.add_child(_line(String(quest.get("description", "")), Color(0.76, 0.79, 0.82)))
	for obj: Dictionary in quest.get("objectives", []):
		var done := _quests.system.is_objective_done(id, obj)
		var prog := _quests.system.progress_of(id, String(obj["id"]))
		var box := "☑" if done else "☐"
		var text := "   %s %s  (%d/%d)" % [box, _objective_label(obj), prog, int(obj.get("count", 1))]
		block.add_child(_line(text, Color(0.7, 0.85, 0.7) if done else Color(0.84, 0.86, 0.88)))
	return block

func _refresh_tracker() -> void:
	var lines: Array[String] = []
	for id in _quests.system.active_ids():
		lines.append("◆ " + String(QuestDb.quests[id]["title"]))
		for obj: Dictionary in QuestDb.quests[id].get("objectives", []):
			var prog := _quests.system.progress_of(id, String(obj["id"]))
			var mark := "✓" if _quests.system.is_objective_done(id, obj) else "·"
			lines.append("  %s %s %d/%d" % [mark, _objective_label(obj), prog, int(obj.get("count", 1))])
	_tracker.text = "\n".join(lines)

func _objective_label(obj: Dictionary) -> String:
	var target := String(obj.get("target", ""))
	match String(obj["type"]):
		"gather":
			return "Gather %s" % ItemDb.get_def(target).name
		"craft":
			return "Craft %s" % ItemDb.get_def(target).name
		"build":
			return "Build %s" % BuildDb.get_def(target).get("name", target)
		"survive_n_days":
			return "Survive days"
		"reach_skill_level":
			return "%s skill" % target.capitalize()
		"discover", "reach_location":
			return "Reach %s" % target.capitalize()
	return String(obj["type"])

func _line(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(510, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label
