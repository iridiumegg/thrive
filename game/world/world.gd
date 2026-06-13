## Main scene: assembles the world, player, and HUD, and routes debug input.
##
## Terrain art is generated procedurally at runtime (placeholder pixel tiles in
## a muted cold palette) so the repo ships zero binary assets for now. The map
## itself is seeded noise as a stand-in; the handcrafted core map replaces it
## in Milestone 6, keeping the same seeded-distribution approach for resources.
extends Node2D

const PlayerScript := preload("res://game/entities/player.gd")
const VitalsComponentScript := preload("res://game/systems/vitals/vitals_component.gd")
const DebugHudScript := preload("res://game/ui/debug_hud.gd")
const VitalsHudScript := preload("res://game/ui/vitals_hud.gd")

const TILE_SIZE := 16
const MAP_HALF_WIDTH := 48   # tiles each side of the origin
const MAP_HALF_HEIGHT := 32

## Atlas column -> terrain. Muted, naturalistic cold palette (locked art dir).
## (var, not const: Color8 calls aren't valid constant expressions.)
var TERRAIN_COLORS: Array[Color] = [
	Color8(96, 116, 88),    # 0 grass
	Color8(110, 95, 75),    # 1 dirt
	Color8(112, 118, 124),  # 2 rock
	Color8(58, 86, 106),    # 3 water
]

const TIME_SCALES: Array[float] = [1.0, 8.0, 32.0]
const SLEEP_TIME_SCALE := 8.0

var player: Player
var vitals: VitalsComponent
var death_overlay: CenterContainer
var _timescale_index := 0
var _smoke_test := false
var _smoke_minutes := 0

func _ready() -> void:
	InputSetup.ensure_actions()
	Sim.reset_clock()
	_build_terrain()
	_spawn_player()
	_build_hud()
	EventBus.player_died.connect(_on_player_died)
	if "--smoke-test" in OS.get_cmdline_user_args():
		_start_smoke_test()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not vitals.state.alive:
		get_tree().reload_current_scene()
		return
	if not vitals.state.alive:
		return
	if event.is_action_pressed("debug_eat"):
		vitals.debug_eat()
	elif event.is_action_pressed("debug_drink"):
		vitals.debug_drink()
	elif event.is_action_pressed("debug_sleep"):
		vitals.asleep = not vitals.asleep
		Sim.time_scale = SLEEP_TIME_SCALE if vitals.asleep else TIME_SCALES[_timescale_index]
	elif event.is_action_pressed("debug_fire"):
		vitals.campfire_on = not vitals.campfire_on
	elif event.is_action_pressed("debug_timescale"):
		_timescale_index = (_timescale_index + 1) % TIME_SCALES.size()
		if not vitals.asleep:
			Sim.time_scale = TIME_SCALES[_timescale_index]

## --- World construction ---

func _build_terrain() -> void:
	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = _build_tile_set()

	var noise := FastNoiseLite.new()
	noise.seed = int(Balance.data["world_seed"])
	noise.frequency = 0.05
	for y in range(-MAP_HALF_HEIGHT, MAP_HALF_HEIGHT):
		for x in range(-MAP_HALF_WIDTH, MAP_HALF_WIDTH):
			var n := noise.get_noise_2d(float(x), float(y))
			var terrain := 0  # grass
			if n < -0.38:
				terrain = 3   # water
			elif n > 0.45:
				terrain = 2   # rock
			elif n > 0.22:
				terrain = 1   # dirt
			layer.set_cell(Vector2i(x, y), 0, Vector2i(terrain, 0))
	add_child(layer)

func _build_tile_set() -> TileSet:
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(_render_tile_atlas())
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in TERRAIN_COLORS.size():
		source.create_tile(Vector2i(i, 0))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, 0)
	return tile_set

## One atlas image, one 16x16 tile per terrain, with subtle deterministic
## per-pixel variation so flat colors read as ground instead of plastic.
func _render_tile_atlas() -> Image:
	var rng := SeededRng.new(int(Balance.data["world_seed"])).stream("tile_atlas")
	var image := Image.create_empty(TILE_SIZE * TERRAIN_COLORS.size(), TILE_SIZE, false, Image.FORMAT_RGBA8)
	for i in TERRAIN_COLORS.size():
		var base := TERRAIN_COLORS[i]
		for y in TILE_SIZE:
			for x in TILE_SIZE:
				var jitter := rng.randf_range(-0.03, 0.03)
				var color := Color(base.r + jitter, base.g + jitter, base.b + jitter)
				image.set_pixel(i * TILE_SIZE + x, y, color)
	return image

func _spawn_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"

	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(_render_player_sprite())
	player.add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 12)
	shape.shape = rect
	player.add_child(shape)

	var camera := Camera2D.new()
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true
	player.add_child(camera)

	vitals = VitalsComponentScript.new()
	vitals.name = "Vitals"
	vitals.setup(player)
	player.add_child(vitals)
	player.vitals = vitals

	add_child(player)

## Placeholder survivor sprite: a hooded figure, drawn in code.
func _render_player_sprite() -> Image:
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var cloak := Color8(70, 90, 110)
	var cloak_dark := Color8(54, 70, 88)
	var skin := Color8(196, 176, 150)
	for y in range(1, 6):       # hood
		for x in range(5, 11):
			image.set_pixel(x, y, cloak_dark)
	for y in range(3, 6):       # face opening
		for x in range(6, 10):
			image.set_pixel(x, y, skin)
	for y in range(6, 13):      # body
		for x in range(4, 12):
			image.set_pixel(x, y, cloak)
	for y in range(13, 15):     # legs
		for x in [5, 6, 9, 10]:
			image.set_pixel(x, y, cloak_dark)
	return image

## --- UI ---

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	add_child(hud)

	var debug_hud: Control = DebugHudScript.new()
	debug_hud.name = "DebugHud"
	hud.add_child(debug_hud)

	var vitals_hud: Control = VitalsHudScript.new()
	vitals_hud.name = "VitalsHud"
	hud.add_child(vitals_hud)

	death_overlay = CenterContainer.new()
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.visible = false
	var death_label := Label.new()
	death_label.text = "You faded out in the cold.\n\nPress R to try again."
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 28)
	death_overlay.add_child(death_label)
	hud.add_child(death_overlay)

func _on_player_died() -> void:
	death_overlay.visible = true
	Sim.time_scale = 1.0

## --- Headless smoke test (`godot --headless --path . -- --smoke-test`) ---
## Fast-forwards an idle, unfed survivor for up to two in-game days to prove
## the full wiring (Sim tick -> EventBus -> vitals -> afflictions -> death)
## works in the running game, not just in unit tests.

func _start_smoke_test() -> void:
	_smoke_test = true
	Sim.time_scale = 240.0
	EventBus.sim_minute.connect(_on_smoke_minute)
	EventBus.affliction_started.connect(
			func(id: String) -> void: print("[smoke] affliction started: %s (day %d, %s)" % [
					id, Sim.clock.day_index(), Sim.clock.format_time()]))
	EventBus.player_died.connect(_finish_smoke_test.bind("player died"))

func _on_smoke_minute(minutes: int) -> void:
	_smoke_minutes += minutes
	if _smoke_minutes >= 2880:
		_finish_smoke_test("survived the time limit")

func _finish_smoke_test(reason: String) -> void:
	if not _smoke_test:
		return
	_smoke_test = false
	var s := vitals.state
	print("[smoke] done after %d sim minutes (%s) — condition %.1f, calories %.0f, hydration %.1f, energy %.1f, warmth %.1f, afflictions %s" % [
			_smoke_minutes, reason, s.condition, s.calories, s.hydration, s.energy, s.warmth,
			s.active_affliction_ids()])
	get_tree().quit(0)
