## Deterministic biome assignment over the world. Handcrafted core + seeded
## procedural surroundings (spec 0.5/6): the outpost meadow is always the core
## region, and seeded low-frequency noise lays the harsher biomes around it the
## same way for a given world seed.
##
## Each biome shifts ambient temperature and constrains which resource nodes can
## spawn there; the coldest (Frostmarsh) is effectively gated by gear, since the
## warmth model will punish anyone who enters under-dressed.
class_name BiomeMap
extends RefCounted

var biomes: Array              # ordered biome defs (non-core ones used for noise)
var _by_id: Dictionary = {}
var _core_radius_px: float
var _core_id: String
var _noise: FastNoiseLite
var _non_core: Array = []

func _init(biome_data: Dictionary, world_seed: int, tile_size: int) -> void:
	biomes = biome_data["biomes"]
	for b: Dictionary in biomes:
		_by_id[String(b["id"])] = b
	_core_id = String(biome_data.get("core_biome", "meadow"))
	_core_radius_px = float(biome_data.get("core_radius_tiles", 12)) * float(tile_size)
	for b: Dictionary in biomes:
		if String(b["id"]) != _core_id:
			_non_core.append(b)
	_noise = FastNoiseLite.new()
	_noise.seed = world_seed
	_noise.frequency = float(biome_data.get("noise_frequency", 0.02))

func biome_at(world_position: Vector2) -> Dictionary:
	if world_position.length() <= _core_radius_px:
		return _by_id[_core_id]
	if _non_core.is_empty():
		return _by_id[_core_id]
	# Map noise [-1,1] -> an index into the non-core biomes, deterministically.
	var n := (_noise.get_noise_2dv(world_position) + 1.0) * 0.5
	var idx := clampi(int(n * _non_core.size()), 0, _non_core.size() - 1)
	return _non_core[idx]

func biome(biome_id: String) -> Dictionary:
	return _by_id.get(biome_id, {})

func temp_offset_at(world_position: Vector2) -> float:
	return float(biome_at(world_position).get("temp_offset_c", 0.0))

func allows_node(biome_id: String, node_id: String) -> bool:
	return node_id in biome(biome_id).get("nodes", [])
