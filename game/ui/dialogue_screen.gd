## Dialogue UI: a bottom panel with the speaker, their line, and the currently
## available choices as buttons. Number keys 1-9 also pick choices. Driven
## entirely by EventBus signals from the DialogueComponent.
extends Control

var _dialogue: DialogueComponent
var _panel: Control
var _speaker: Label
var _text: Label
var _choices_box: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_panel.visible = false
	EventBus.dialogue_started.connect(func(_id: String, _name: String) -> void:
		_panel.visible = true)
	EventBus.dialogue_node.connect(_on_node)
	EventBus.dialogue_ended.connect(func() -> void: _panel.visible = false)

func bind(dialogue: DialogueComponent) -> void:
	_dialogue = dialogue

func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_dialogue.close()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode >= KEY_1 and key.keycode <= KEY_9:
		_dialogue.choose(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 80
	_panel.offset_right = -80
	_panel.offset_top = -220
	_panel.offset_bottom = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.97)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 16)
	_speaker.add_theme_color_override("font_color", Color(0.95, 0.9, 0.74))
	box.add_child(_speaker)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(700, 56)
	_text.add_theme_font_size_override("font_size", 14)
	_text.add_theme_color_override("font_color", Color(0.88, 0.9, 0.92))
	box.add_child(_text)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 3)
	box.add_child(_choices_box)

func _on_node(speaker: String, text: String, choices: Array) -> void:
	_speaker.text = speaker
	_text.text = text
	for child in _choices_box.get_children():
		child.queue_free()
	for i in choices.size():
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, choices[i]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_dialogue.choose.bind(i))
		_choices_box.add_child(button)
