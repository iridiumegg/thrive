## Bottom-left vitals readout: Condition plus the four needs as bars,
## active affliction tags, and a "you feel..." mood line that translates
## the numbers into words (spec 5.5).
##
## Bars shift toward red as a need approaches critical — color is reinforced
## by position and label so the display stays colorblind-readable.
extends Control

const BAR_SIZE := Vector2(170, 13)
const LOW_FRACTION := 0.3  # below this, bar color slides toward danger red

var DANGER_COLOR := Color8(178, 64, 54)

## stat id -> [display name, healthy bar color]
var BAR_DEFS := {
	"condition": ["Condition", Color8(168, 142, 186)],
	"calories": ["Calories", Color8(186, 152, 96)],
	"hydration": ["Hydration", Color8(96, 142, 176)],
	"energy": ["Energy", Color8(150, 168, 110)],
	"warmth": ["Warmth", Color8(196, 120, 88)],
}

var _bars: Dictionary = {}        # stat -> ProgressBar
var _fills: Dictionary = {}       # stat -> StyleBoxFlat
var _affliction_label: Label
var _mood_label: Label
var _system: VitalsSystem

func _ready() -> void:
	_system = VitalsSystem.new(Balance.data, Balance.afflictions)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 3)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 8.0
	panel.offset_bottom = -8.0

	for stat: String in BAR_DEFS:
		panel.add_child(_build_bar_row(stat))

	_affliction_label = _make_text_label(Color8(214, 140, 130))
	panel.add_child(_affliction_label)
	_mood_label = _make_text_label(Color(0.85, 0.88, 0.9))
	panel.add_child(_mood_label)
	panel.move_child(_mood_label, 0)
	panel.move_child(_affliction_label, 0)

	EventBus.vitals_changed.connect(_refresh)

func _build_bar_row(stat: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var name_label := Label.new()
	name_label.text = BAR_DEFS[stat][0]
	name_label.custom_minimum_size = Vector2(72, 0)
	name_label.add_theme_font_size_override("font_size", UiScale.font_size(12))
	name_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.95))
	row.add_child(name_label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = BAR_SIZE
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = _system.max_value(stat)
	bar.value = bar.max_value

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.09, 0.11, 0.85)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = BAR_DEFS[stat][1]
	bar.add_theme_stylebox_override("fill", fill)

	row.add_child(bar)
	_bars[stat] = bar
	_fills[stat] = fill
	return row

func _make_text_label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", UiScale.font_size(12))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _refresh(state: RefCounted) -> void:
	var vitals := state as VitalsState
	for stat: String in _bars:
		var bar: ProgressBar = _bars[stat]
		bar.value = vitals.get_stat(stat)
		var fraction: float = bar.value / bar.max_value
		var danger := clampf((LOW_FRACTION - fraction) / LOW_FRACTION, 0.0, 1.0)
		_fills[stat].bg_color = (BAR_DEFS[stat][1] as Color).lerp(DANGER_COLOR, danger)

	var names: Array[String] = []
	for id in vitals.active_affliction_ids():
		names.append(String(_system.affliction_def(id).get("name", id)))
	_affliction_label.text = "⚠ " + ", ".join(names) if not names.is_empty() else ""
	_affliction_label.visible = not names.is_empty()
	_mood_label.text = _mood_line(vitals)

## Translate numbers into a readable mood line, worst problem first.
func _mood_line(vitals: VitalsState) -> String:
	if not vitals.alive:
		return "You feel nothing at all."
	var worst_stat := ""
	var worst_fraction := 1.0
	for stat in ["calories", "hydration", "energy", "warmth"]:
		var fraction := _system.need_fraction(vitals, stat)
		if fraction < worst_fraction:
			worst_fraction = fraction
			worst_stat = stat
	if worst_fraction < 0.15:
		match worst_stat:
			"calories": return "You feel ravenous."
			"hydration": return "You feel parched."
			"energy": return "You feel dead on your feet."
			"warmth": return "You feel the cold in your bones."
	if worst_fraction < 0.4:
		return "You feel worn thin."
	if _system.need_fraction(vitals, "condition") > 0.8:
		return "You feel warm and steady."
	return "You feel like you're holding on."
