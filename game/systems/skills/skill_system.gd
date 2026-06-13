## Skill lines that level through use. Pure logic, unit-testable.
##
## Each skill accumulates XP; level is derived from total XP via a smooth curve
## (cumulative XP to reach level L = base * (L-1)^exp). Leveling is what unlocks
## recipes, efficiency, and crafted quality — so the curve lives in balance.json,
## never in code.
class_name SkillSystem
extends RefCounted

var lines: PackedStringArray
var max_level: int
var _base: float
var _exp: float
var _xp: Dictionary = {}     # skill_id -> total xp

func _init(cfg: Dictionary) -> void:
	lines = PackedStringArray(cfg.get("lines", []))
	max_level = int(cfg.get("max_level", 20))
	_base = float(cfg.get("xp_curve_base", 50.0))
	_exp = float(cfg.get("xp_curve_exp", 1.6))
	for line: String in lines:
		_xp[line] = 0

func xp(skill_id: String) -> int:
	return int(_xp.get(skill_id, 0))

## Cumulative XP required to be AT a given level (level 1 = 0).
func xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(round(_base * pow(level - 1, _exp)))

func level(skill_id: String) -> int:
	var total := xp(skill_id)
	var lvl := 1
	while lvl < max_level and total >= xp_for_level(lvl + 1):
		lvl += 1
	return lvl

## Fraction of progress from the current level toward the next (0..1).
func progress(skill_id: String) -> float:
	var lvl := level(skill_id)
	if lvl >= max_level:
		return 1.0
	var floor_xp := xp_for_level(lvl)
	var next_xp := xp_for_level(lvl + 1)
	if next_xp <= floor_xp:
		return 1.0
	return clampf(float(xp(skill_id) - floor_xp) / float(next_xp - floor_xp), 0.0, 1.0)

## Add XP; returns { leveled: bool, from: int, to: int }.
func add_xp(skill_id: String, amount: int) -> Dictionary:
	if not _xp.has(skill_id):
		_xp[skill_id] = 0
	var before := level(skill_id)
	_xp[skill_id] = int(_xp[skill_id]) + maxi(0, amount)
	var after := level(skill_id)
	return {"leveled": after > before, "from": before, "to": after}

## --- Save/load support ---

func to_data() -> Dictionary:
	return _xp.duplicate()

func load_data(data: Dictionary) -> void:
	for skill_id: String in data:
		_xp[skill_id] = int(data[skill_id])
