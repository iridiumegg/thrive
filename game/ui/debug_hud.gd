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
		var biome: Dictionary = Env.biome_at(vitals.get_parent().global_position) \
				if vitals.get_parent() is Node2D else {}
		lines.append("%s  —  %s   Ambient %.1f°C" % [
			biome.get("name", "?"), Env.weather.display_name(), vitals.ambient_c()])
		lines.append("Fire: %s   Asleep: %s" % [
			"lit" if vitals.campfire_on else "—",
			"yes" if vitals.asleep else "no"])
	lines.append("Speed x%.0f   FPS %d" % [Sim.time_scale, Engine.get_frames_per_second()])
	lines.append("")
	lines.append("[WASD] move [E] interact [Q] trap [Tab] pack [C] craft [B] build [J] journal")
	lines.append("[F1] eat  [F2] drink  [F3] sleep  [F4] campfire  [F5] time speed")
	_label.text = "\n".join(lines)

func _find_vitals() -> VitalsComponent:
	if _vitals == null or not is_instance_valid(_vitals):
		var world := get_tree().current_scene
		if world != null:
			_vitals = world.get("vitals") as VitalsComponent
	return _vitals
