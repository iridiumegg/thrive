## Deterministic, seedable RNG service. Pure logic.
##
## One root seed (from balance.json) deterministically derives independent
## named streams, so e.g. world generation and loot rolls never interfere
## with each other's sequences. Same seed + same stream name = same numbers,
## which keeps worlds reproducible for testing.
class_name SeededRng
extends RefCounted

var _root_seed: int

func _init(root_seed: int) -> void:
	_root_seed = root_seed

## Returns a fresh RNG whose seed is derived from the root seed + stream name.
func stream(stream_name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [_root_seed, stream_name])
	return rng
