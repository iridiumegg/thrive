## Story UI: the document reader, the ending choice, and the ending screen.
##
## - document_text  -> show a found note's title + body (dismiss with E/Esc)
## - ending_choices -> present the available endings as buttons (the finale)
## - ending_reached -> show the chosen ending's narration; R restarts
## All driven by EventBus so it needs no direct references.
extends Control

var _story: StoryComponent
var _panel: PanelContainer
var _title: Label
var _body: Label
var _choices: VBoxContainer
var _mode := ""   # "note" | "choice" | "ending"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_panel.visible = false
	EventBus.document_text.connect(_show_note)
	EventBus.ending_choices.connect(_show_choices)
	EventBus.ending_reached.connect(func(_id: String, title: String, body: String) -> void:
		_show_ending(title, body))

func bind(story: StoryComponent) -> void:
	_story = story

func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if _mode == "note" and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		_panel.visible = false
		get_viewport().set_input_as_handled()
	elif _mode == "ending" and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.custom_minimum_size = Vector2(560, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.07, 0.98)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.93, 0.88, 0.72))
	box.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(520, 0)
	_body.add_theme_font_size_override("font_size", 14)
	_body.add_theme_color_override("font_color", Color(0.86, 0.86, 0.82))
	box.add_child(_body)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 5)
	box.add_child(_choices)

func _clear_choices() -> void:
	for child in _choices.get_children():
		child.queue_free()

func _show_note(title: String, body: String) -> void:
	_mode = "note"
	_title.text = title
	_body.text = body
	_clear_choices()
	_choices.add_child(_hint("[E] put it down"))
	_panel.visible = true

func _show_choices(endings: Array) -> void:
	_mode = "choice"
	_title.text = "The Outpost's Fate"
	_body.text = "You've seen what the cold did here, and what it didn't. The choice is yours now."
	_clear_choices()
	for ending: Dictionary in endings:
		var button := Button.new()
		button.text = String(ending["title"])
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_story.choose_ending.bind(String(ending["id"])))
		_choices.add_child(button)
	_panel.visible = true

func _show_ending(title: String, body: String) -> void:
	_mode = "ending"
	_title.text = title
	_body.text = body
	_clear_choices()
	_choices.add_child(_hint("[R] begin again"))
	_panel.visible = true

func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.74))
	return label
