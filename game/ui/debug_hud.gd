## Top-left debug readout: clock, season, temperatures, FPS, debug-key help.
## Development scaffolding — replaced by the real HUD indicators over time.
extends Control

var _label: Label
var _vitals: VitalsComponent

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.95))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)

func _process(_delta: float) -> void:
	var clock := Sim.clock
	var lines: Array[String] = [
		"Day %d of %s  —  %s%s" % [
			clock.day_of_season(), clock.season_name(), clock.format_time(),
			"  (night)" if clock.is_night() else ""],
	]
	var vitals := _find_vitals()
	if vitals != null:
		lines.append("Ambient %.1f°C   Fire: %s   Asleep: %s" % [
			vitals.ambient_c(),
			"lit" if vitals.campfire_on else "—",
			"yes" if vitals.asleep else "no"])
	lines.append("Speed x%.0f   FPS %d" % [Sim.time_scale, Engine.get_frames_per_second()])
	lines.append("")
	lines.append("[WASD] move  [E] interact  [Q] set trap  [Tab] pack")
	lines.append("[F1] eat  [F2] drink  [F3] sleep  [F4] campfire  [F5] time speed")
	_label.text = "\n".join(lines)

func _find_vitals() -> VitalsComponent:
	if _vitals == null or not is_instance_valid(_vitals):
		var world := get_tree().current_scene
		if world != null:
			_vitals = world.get("vitals") as VitalsComponent
	return _vitals
