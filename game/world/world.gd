## Main scene: assembles the world, player, and HUD, and routes debug input.
##
## Terrain art is generated procedurally at runtime (placeholder pixel tiles in
## a muted cold palette) so the repo ships zero binary assets for now. The map
## itself is seeded noise as a stand-in; the handcrafted core map replaces it
## in Milestone 6, keeping the same seeded-distribution approach for resources.
extends Node2D

const PlayerScript := preload("res://game/entities/player.gd")
const VitalsComponentScript := preload("res://game/systems/vitals/vitals_component.gd")
const InventoryComponentScript := preload("res://game/systems/inventory/inventory_component.gd")
const GatheringComponentScript := preload("res://game/systems/gathering/gathering_component.gd")
const CraftingComponentScript := preload("res://game/systems/crafting/crafting_component.gd")
const SkillsComponentScript := preload("res://game/systems/skills/skills_component.gd")
const PickupScript := preload("res://game/entities/pickup.gd")
const ResourceNodeEntityScript := preload("res://game/entities/resource_node_entity.gd")
const TrapEntityScript := preload("res://game/entities/trap_entity.gd")
const BuildControllerScript := preload("res://game/systems/building/build_controller.gd")
const DebugHudScript := preload("res://game/ui/debug_hud.gd")
const VitalsHudScript := preload("res://game/ui/vitals_hud.gd")
const InventoryScreenScript := preload("res://game/ui/inventory_screen.gd")
const CraftingScreenScript := preload("res://game/ui/crafting_screen.gd")
const BuildPaletteScript := preload("res://game/ui/build_palette.gd")
const StorageScreenScript := preload("res://game/ui/storage_screen.gd")

const SPAWNS_PATH := "res://game/data/world_spawns.json"

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
var inventory: InventoryComponent
var gathering: GatheringComponent
var crafting: CraftingComponent
var build: BuildController
var death_overlay: CenterContainer
var _sleeping_in_bed := false
var _terrain: TileMapLayer
var _pickups: Node2D
var _nodes: Node2D
var _canvas_modulate: CanvasModulate
var _current_biome := ""
var _biome_check_accum := 0.0
var _trap_counter := 0
var _timescale_index := 0
var _smoke_test := false
var _smoke_minutes := 0

func _ready() -> void:
	InputSetup.ensure_actions()
	Sim.reset_clock()
	Env.reset()
	_build_terrain()
	_build_lighting()
	_spawn_player()
	_setup_build()
	_build_hud()
	_spawn_world_items()
	EventBus.player_died.connect(_on_player_died)
	EventBus.item_dropped.connect(_on_item_dropped)
	EventBus.sleep_requested.connect(_begin_bed_sleep)
	EventBus.sim_minute.connect(_on_world_minute)
	if "--smoke-test" in OS.get_cmdline_user_args():
		_start_smoke_test()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not vitals.state.alive:
		get_tree().reload_current_scene()
		return
	if not vitals.state.alive:
		return
	if event.is_action_pressed("toggle_build"):
		build.toggle()
	elif event.is_action_pressed("interact"):
		gathering.interact()
	elif event.is_action_pressed("deploy_trap"):
		_deploy_trap()
	elif event.is_action_pressed("debug_eat"):
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
	_terrain = TileMapLayer.new()
	_terrain.name = "Terrain"
	_terrain.tile_set = _build_tile_set()

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
			_terrain.set_cell(Vector2i(x, y), 0, Vector2i(terrain, 0))
	add_child(_terrain)

## True if a tile cell is land (not water) — used for valid item placement.
func _is_land(cell: Vector2i) -> bool:
	return _terrain.get_cell_atlas_coords(cell).x != 3

## A full-screen tint node for day/night + weather darkening.
func _build_lighting() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "Lighting"
	add_child(_canvas_modulate)

func _process(delta: float) -> void:
	if _canvas_modulate != null:
		# Darken toward a cold night-blue as night / weather darkness rises.
		var d := Env.darkness()
		_canvas_modulate.color = Color(1.0 - d, 1.0 - d, 1.0 - d * 0.82)
	_track_biome(delta)

## Throttled check for which biome the player is in, for HUD + notifications.
func _track_biome(delta: float) -> void:
	if player == null:
		return
	_biome_check_accum += delta
	if _biome_check_accum < 0.4:
		return
	_biome_check_accum = 0.0
	var biome: Dictionary = Env.biome_at(player.global_position)
	var id := String(biome.get("id", ""))
	if id != _current_biome:
		_current_biome = id
		EventBus.biome_entered.emit(id, String(biome.get("name", id)))
		var warn := "  — cold; dress warm" if bool(biome.get("gated", false)) else ""
		EventBus.notice.emit("Entered %s%s" % [biome.get("name", id), warn])

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

	inventory = InventoryComponentScript.new()
	inventory.name = "Inventory"
	inventory.setup(vitals)
	player.add_child(inventory)
	player.inventory = inventory

	gathering = GatheringComponentScript.new()
	gathering.name = "Gathering"
	player.add_child(gathering)
	gathering.setup(player, vitals, inventory)
	player.gathering = gathering

	crafting = CraftingComponentScript.new()
	crafting.name = "Crafting"
	crafting.setup(inventory)
	player.add_child(crafting)
	player.crafting = crafting
	inventory.crafting = crafting

	var skills: SkillsComponent = SkillsComponentScript.new()
	skills.name = "Skills"
	skills.setup(crafting)
	player.add_child(skills)
	player.skills = skills
	crafting.skills = skills

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

## --- World items ---

## Place the abandoned-outpost starter kit near spawn and scatter the rest of
## the loot across land tiles. All placement is seeded, so a given world_seed
## always produces the same layout (spec 0.5: seeded procedural distribution).
func _spawn_world_items() -> void:
	_pickups = Node2D.new()
	_pickups.name = "Pickups"
	add_child(_pickups)
	_nodes = Node2D.new()
	_nodes.name = "Nodes"
	add_child(_nodes)

	var spawns: Dictionary = Balance.load_json(SPAWNS_PATH)
	_spawn_nodes(spawns)
	_spawn_stations()
	var rng := SeededRng.new(int(Balance.data["world_seed"])).stream("world_items")

	# Starter kit: a loose ring of items just around the outpost (origin).
	var kit: Array = spawns.get("near_spawn_kit", [])
	for i in kit.size():
		var angle := TAU * float(i) / float(max(1, kit.size()))
		var radius := rng.randf_range(40.0, 90.0)
		var pos := Vector2(cos(angle), sin(angle)) * radius
		_add_pickup(String(kit[i]), 1, pos)

	# Scattered foraging across the map.
	for entry: Dictionary in spawns.get("scatter", []):
		for _i in int(entry["count"]):
			var qty := rng.randi_range(int(entry["qty_min"]), int(entry["qty_max"]))
			_add_pickup(String(entry["item"]), qty, _random_land_position(rng))

## The outpost's surviving stations, arranged just south of spawn. (Player-built
## and player-placed stations arrive with the building system in M7.)
const STATION_LAYOUT := [
	["workbench", Vector2(-40, 60)],
	["campfire", Vector2(0, 70)],
	["forge", Vector2(40, 60)],
	["tailoring_bench", Vector2(80, 70)],
]

func _setup_build() -> void:
	var buildings := Node2D.new()
	buildings.name = "Buildings"
	add_child(buildings)
	build = BuildControllerScript.new()
	build.name = "BuildController"
	build.setup(player, buildings, func(cell: Vector2i) -> bool: return _is_land(cell))
	add_child(build)

## The surviving outpost structures, pre-placed at no cost.
func _spawn_stations() -> void:
	for entry in STATION_LAYOUT:
		build.place_prebuilt(entry[0], entry[1])

## Terrain name -> atlas column (matches _build_terrain).
const TERRAIN_INDEX := {"grass": 0, "dirt": 1, "rock": 2, "water": 3}

## Place resource nodes on terrain types each node type allows. Seeded, so a
## given world_seed always lays out the same nodes.
func _spawn_nodes(spawns: Dictionary) -> void:
	var rng := SeededRng.new(int(Balance.data["world_seed"])).stream("nodes")
	var placed := 0
	for entry: Dictionary in spawns.get("nodes", []):
		var node_id := String(entry["node"])
		var def: Dictionary = GatherDb.node_defs[node_id]
		var allowed: Array = def.get("terrain", ["grass"])
		for _i in int(entry["count"]):
			var pos := _random_cell_position(rng, allowed, node_id)
			if pos == Vector2.INF:
				continue
			var node := ResourceNodeEntityScript.create(node_id, pos, "%s_%d" % [node_id, placed])
			_nodes.add_child(node)
			placed += 1

## A random tile-center whose terrain is in `allowed` AND whose biome permits
## `node_id`, or Vector2.INF if none found in a reasonable number of attempts.
func _random_cell_position(rng: RandomNumberGenerator, allowed: Array, node_id: String) -> Vector2:
	var wanted: Array[int] = []
	for name: String in allowed:
		wanted.append(int(TERRAIN_INDEX[name]))
	for _attempt in 60:
		var cell := Vector2i(
			rng.randi_range(-MAP_HALF_WIDTH + 1, MAP_HALF_WIDTH - 2),
			rng.randi_range(-MAP_HALF_HEIGHT + 1, MAP_HALF_HEIGHT - 2))
		if _terrain.get_cell_atlas_coords(cell).x not in wanted:
			continue
		var pos := Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
		if Env.biomes.allows_node(String(Env.biome_at(pos)["id"]), node_id):
			return pos
	return Vector2.INF

func _random_land_position(rng: RandomNumberGenerator) -> Vector2:
	for _attempt in 30:
		var cell := Vector2i(
			rng.randi_range(-MAP_HALF_WIDTH + 1, MAP_HALF_WIDTH - 2),
			rng.randi_range(-MAP_HALF_HEIGHT + 1, MAP_HALF_HEIGHT - 2))
		if _is_land(cell):
			return Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	return Vector2.ZERO

func _add_pickup(item_id: String, qty: int, world_position: Vector2) -> void:
	if not ItemDb.has(item_id):
		push_warning("Spawn references unknown item: %s" % item_id)
		return
	_pickups.add_child(PickupScript.create(item_id, qty, world_position))

func _on_item_dropped(item_id: String, qty: int) -> void:
	var offset := Vector2(randf_range(-10.0, 10.0), 12.0)
	_add_pickup(item_id, qty, player.global_position + offset)

## Deploy a carried snare trap at the player's feet, consuming the kit and a
## unit of bait, then arming it. (Full placeable-building UI arrives at M7;
## this is the self-contained hook for the trapping subsystem.)
func _deploy_trap() -> void:
	const TRAP_ID := "snare_trap"
	if not gathering.has_item(TRAP_ID, 1):
		EventBus.notice.emit("No snare trap to set")
		return
	var trap_def: Dictionary = GatherDb.trap_defs[TRAP_ID]
	for entry: Dictionary in trap_def.get("bait", []):
		if not gathering.has_item(String(entry["item"]), int(entry["qty"])):
			EventBus.notice.emit("Need bait: %s" % ItemDb.get_def(String(entry["item"])).name)
			return
	gathering.consume(TRAP_ID, 1)
	for entry: Dictionary in trap_def.get("bait", []):
		gathering.consume(String(entry["item"]), int(entry["qty"]))

	var entity := TrapEntityScript.create(TRAP_ID, player.global_position + Vector2(0, 10), str(_trap_counter))
	_trap_counter += 1
	entity.trap.arm()
	_nodes.add_child(entity)
	EventBus.notice.emit("Snare set — check back later")

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

	var inventory_screen: Control = InventoryScreenScript.new()
	inventory_screen.name = "InventoryScreen"
	hud.add_child(inventory_screen)
	inventory_screen.bind(inventory)

	var crafting_screen: Control = CraftingScreenScript.new()
	crafting_screen.name = "CraftingScreen"
	hud.add_child(crafting_screen)
	crafting_screen.bind(crafting)

	var build_palette: Control = BuildPaletteScript.new()
	build_palette.name = "BuildPalette"
	hud.add_child(build_palette)
	build_palette.bind(build)

	var storage_screen: Control = StorageScreenScript.new()
	storage_screen.name = "StorageScreen"
	hud.add_child(storage_screen)
	storage_screen.bind_pack(inventory.inventory)

	_build_toast(hud)
	_build_prompt(hud)

	death_overlay = CenterContainer.new()
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.visible = false
	var death_label := Label.new()
	death_label.text = "You faded out in the cold.\n\nPress R to try again."
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 28)
	death_overlay.add_child(death_label)
	hud.add_child(death_overlay)

## A transient bottom-center message line fed by EventBus.notice
## (pickups, "pack full", equip/use feedback).
func _build_toast(hud: CanvasLayer) -> void:
	var toast := Label.new()
	toast.name = "Toast"
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_top = -70
	toast.offset_left = -200
	toast.offset_right = 200
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 15)
	toast.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	toast.add_theme_constant_override("shadow_offset_x", 1)
	toast.add_theme_constant_override("shadow_offset_y", 1)
	toast.modulate.a = 0.0
	hud.add_child(toast)

	EventBus.notice.connect(func(text: String) -> void:
		toast.text = text
		var tween := create_tween()
		tween.tween_property(toast, "modulate:a", 1.0, 0.15)
		tween.tween_interval(1.6)
		tween.tween_property(toast, "modulate:a", 0.0, 0.5))
	EventBus.item_picked_up.connect(func(item_id: String, qty: int) -> void:
		EventBus.notice.emit("Picked up %s%s" % [
				ItemDb.get_def(item_id).name, "  x%d" % qty if qty > 1 else ""]))

## Centered interaction hint just above the player (fed by interaction_prompt).
func _build_prompt(hud: CanvasLayer) -> void:
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.offset_top = 40
	prompt.offset_left = -220
	prompt.offset_right = 220
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14)
	prompt.add_theme_color_override("font_color", Color(0.96, 0.93, 0.78))
	prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	prompt.add_theme_constant_override("shadow_offset_x", 1)
	prompt.add_theme_constant_override("shadow_offset_y", 1)
	hud.add_child(prompt)
	EventBus.interaction_prompt.connect(func(text: String) -> void: prompt.text = text)

## Bed sleep: accelerate time and wake at first light (or once fully rested).
func _begin_bed_sleep() -> void:
	if _sleeping_in_bed:
		return
	_sleeping_in_bed = true
	vitals.asleep = true
	Sim.time_scale = SLEEP_TIME_SCALE
	EventBus.notice.emit("Sleeping…")

const WAKE_HOUR := 6

func _on_world_minute(_minutes: int) -> void:
	if not _sleeping_in_bed:
		return
	var rested := vitals.system.need_fraction(vitals.state, "energy") >= 0.99
	if Sim.clock.hour() == WAKE_HOUR or rested or not vitals.state.alive:
		_sleeping_in_bed = false
		vitals.asleep = false
		Sim.time_scale = TIME_SCALES[_timescale_index]
		if vitals.state.alive:
			EventBus.notice.emit("You wake at first light")

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
	_smoke_test_inventory()
	EventBus.sim_minute.connect(_on_smoke_minute)
	EventBus.affliction_started.connect(
			func(id: String) -> void: print("[smoke] affliction started: %s (day %d, %s)" % [
					id, Sim.clock.day_index(), Sim.clock.format_time()]))
	EventBus.player_died.connect(_finish_smoke_test.bind("player died"))

## Exercises the M3 inventory wiring through the real engine-side component:
## pickup -> equip (insulation should rise) -> eat (calories should rise).
func _smoke_test_inventory() -> void:
	var base_insulation := player.insulation_c()
	inventory.pickup("padded_jacket", 1)
	# The jacket sits in the last-used slot; find and equip it.
	for i in inventory.inventory.slots.size():
		var stack: Inventory.Stack = inventory.inventory.slots[i]
		if stack != null and stack.item_id == "padded_jacket":
			inventory.use_slot(i)
			break
	var warmed := player.insulation_c()
	print("[smoke] insulation %.1f -> %.1f after equipping jacket" % [base_insulation, warmed])
	assert(warmed > base_insulation, "equipping clothing must raise insulation")

	inventory.pickup("wild_berries", 3)
	vitals.state.calories = 1000.0
	for i in inventory.inventory.slots.size():
		var stack: Inventory.Stack = inventory.inventory.slots[i]
		if stack != null and stack.item_id == "wild_berries":
			inventory.use_slot(i)
			break
	print("[smoke] ate berries -> calories %.0f, weight %.1f kg" % [
			vitals.state.calories, inventory.inventory.total_weight()])

	# --- M4: gather from a node with the right tool, and run a trap cycle ---
	# Equip the axe, then harvest a HarvestNode directly through its loot logic.
	inventory.pickup("stone_axe", 1)
	for i in inventory.inventory.slots.size():
		var stack: Inventory.Stack = inventory.inventory.slots[i]
		if stack != null and stack.item_id == "stone_axe":
			inventory.use_slot(i)
			break
	var tree := GatherDb.new_node("tree", "smoke_tree")
	var tier := gathering.tool_tier_for("axe")
	var loot := tree.harvest(tier)
	print("[smoke] axe tier %d harvested tree -> %s (durability now %d)" % [
			tier, loot, inventory.current_durability("stone_axe") - 0])
	gathering.damage_tool()
	assert(not loot.is_empty(), "a tier-1 axe must harvest a tier-1 tree")
	assert(inventory.current_durability("stone_axe") < ItemDb.get_def("stone_axe").durability_max,
			"harvesting must wear the tool")

	# Trap: arm, fast-forward past the catch interval, confirm it resolves.
	var trap := GatherDb.new_trap("snare_trap")
	trap.arm()
	var trap_rng := SeededRng.new(1).stream("smoke_trap")
	var minutes_waited := 0
	while trap.is_armed() and minutes_waited < 10000:
		trap.tick(60, trap_rng)
		minutes_waited += 60
	print("[smoke] trap resolved after %d min -> %s" % [
			minutes_waited, "caught " + str(trap.collect()) if trap.is_caught() else "empty"])

	# --- M5: crafting chain, station gating, blueprint, repair/salvage ---
	# Hand-craft cordage from fiber (no station needed).
	inventory.pickup("plant_fiber", 4)
	assert(crafting.craft("craft_cord"), "cord should be craftable by hand")
	crafting._on_sim_minute(10)  # advance the craft via the component's deliver path
	print("[smoke] hand-crafted cord -> have %d cord" % inventory.inventory.count("cord"))
	assert(inventory.inventory.count("cord") >= 1, "completed craft must deliver outputs")

	# Forge recipe must be gated until a forge is in range.
	inventory.pickup("iron_ore", 4)
	inventory.pickup("branch", 4)
	var gated := crafting.can_craft("smelt_iron_ingot")
	print("[smoke] smelt gated without forge: ok=%s (%s)" % [gated["ok"], gated["reason"]])
	assert(not gated["ok"], "smelting must require the forge station")
	crafting.add_station("forge")
	assert(crafting.craft("smelt_iron_ingot"), "smelting works with a forge in range")
	crafting._on_sim_minute(100)
	print("[smoke] smelted -> have %d iron_ingot" % inventory.inventory.count("iron_ingot"))
	assert(inventory.inventory.count("iron_ingot") >= 1, "smelting must deliver an ingot")

	# Blueprint learning: hide cloak is locked until the pattern is read.
	assert(not crafting.knows("craft_hide_cloak"), "cloak locked initially")
	inventory.pickup("garment_pattern", 1)
	for i in inventory.inventory.slots.size():
		var st: Inventory.Stack = inventory.inventory.slots[i]
		if st != null and st.item_id == "garment_pattern":
			inventory.use_slot(i)
			break
	print("[smoke] read pattern -> knows hide cloak: %s" % crafting.knows("craft_hide_cloak"))
	assert(crafting.knows("craft_hide_cloak"), "reading the blueprint learns the recipe")

	# Repair and salvage.
	inventory.pickup("stone_pickaxe", 1)
	for i in inventory.inventory.slots.size():
		var st: Inventory.Stack = inventory.inventory.slots[i]
		if st != null and st.item_id == "stone_pickaxe":
			inventory.use_slot(i)  # equip it
			break
	inventory.damage_equipped_tool(20)
	var worn := inventory.current_durability("stone_pickaxe")
	inventory.pickup("stone", 2)
	crafting.repair_equipped_tool()
	print("[smoke] pickaxe durability %d -> %d after repair" % [
			worn, inventory.current_durability("stone_pickaxe")])
	assert(inventory.current_durability("stone_pickaxe") > worn, "repair restores durability")

	# --- M6: weather drives the warmth model; biomes shift temperature ---
	var core_temp := Env.ambient_c_at(Vector2.ZERO)
	var far_temp := Env.ambient_c_at(Vector2(2000, 1500))
	print("[smoke] ambient: outpost %.1f°C vs distant biome %.1f°C, weather=%s" % [
			core_temp, far_temp, Env.weather.display_name()])
	# Force a storm and confirm the vitals env now carries wind chill + wetness.
	Env.weather.current = "storm"
	vitals.campfire_on = false
	var env := vitals._build_env()
	print("[smoke] storm env -> wind_chill %.1f, wetness %.1f" % [
			env["wind_chill_c"], env["wetness"]])
	assert(env["wind_chill_c"] > 0.0 and env["wetness"] > 0.0, "storm must chill and wet the player")

	# --- M7: build a heat source + shelter, confirm it cancels the storm ---
	inventory.pickup("branch", 3)
	inventory.pickup("stone", 2)
	var cell := build.grid.world_to_cell(player.global_position + Vector2(0, 40))
	build.selected_id = "campfire"
	build._place(cell)
	var built := build._cells.has(cell)
	print("[smoke] placed campfire: %s (structures at outpost incl. prebuilt)" % built)
	assert(built, "campfire should place when affordable on land")
	# Simulate standing next to it: heat + shelter applied like proximity would.
	player.nearby_heat_c = 16.0
	player.nearby_shelter = 1
	var sheltered_env := vitals._build_env()
	print("[smoke] beside fire in storm -> heat %.0f, wind_chill %.1f, wetness %.1f" % [
			sheltered_env["heat_source_c"], sheltered_env["wind_chill_c"], sheltered_env["wetness"]])
	assert(sheltered_env["wind_chill_c"] == 0.0 and sheltered_env["wetness"] == 0.0,
			"shelter/heat must cancel wind chill and wetness")

	# Storage round-trip through a chest inventory.
	var chest := Inventory.new(24, 9999.0, ItemDb.catalog)
	inventory.pickup("stone", 5)
	var moved := chest.add("stone", 5)
	inventory.inventory.remove("stone", 5)
	print("[smoke] stored %d stone in chest -> chest has %d" % [moved, chest.count("stone")])
	assert(chest.count("stone") == 5, "storage should hold deposited items")

	# --- M8: skills level through use, unlock recipes, and drive quality ---
	var skills := player.skills
	print("[smoke] crafting skill starts at level %d" % skills.level("crafting"))
	# Tailoring coat is gated behind tailoring level 4 — locked at level 1.
	assert(not crafting.knows("craft_insulated_coat"), "skill-gated recipe locked initially")
	skills.system.add_xp("tailoring", skills.system.xp_for_level(4))
	skills._unlock_skill_recipes("tailoring", skills.level("tailoring"))
	print("[smoke] tailoring -> level %d, knows insulated coat: %s" % [
			skills.level("tailoring"), crafting.knows("craft_insulated_coat")])
	assert(crafting.knows("craft_insulated_coat"), "leveling tailoring unlocks the coat")

	# Quality climbs with skill; a masterwork tool starts with bonus durability.
	skills.system.add_xp("smithing", skills.system.xp_for_level(12))
	var quality_tier: Dictionary = skills.quality_for_recipe("craft_iron_axe")
	print("[smoke] smithing lvl %d -> quality '%s' (durability x%.2f)" % [
			skills.level("smithing"), quality_tier["name"], Quality.durability_mult(quality_tier)])
	assert(String(quality_tier["id"]) == "masterwork", "high smithing yields masterwork quality")

	# Gathering skill grants bonus loot rolls.
	skills.system.add_xp("gathering", skills.system.xp_for_level(6))
	print("[smoke] gathering lvl %d -> +%d bonus loot rolls" % [
			skills.level("gathering"), gathering.skill_bonus_rolls()])
	assert(gathering.skill_bonus_rolls() >= 1, "gathering skill should grant bonus rolls")

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
