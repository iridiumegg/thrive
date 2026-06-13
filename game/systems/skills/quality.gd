## Crafted-item quality tiers. Pure logic.
##
## Quality was built schema-ready in M5 and switches on here: the relevant
## skill's level selects a tier (the highest whose min_skill it meets), and the
## tier carries multipliers the crafting component applies — a durability bonus
## for tools and a bonus-output chance for stackables. Tiers come from
## balance.json so designers can retune without code.
class_name Quality
extends RefCounted

## Pick the tier a given skill level earns (tiers must be ordered by min_skill).
static func tier_for_level(tiers: Array, level: int) -> Dictionary:
	var chosen: Dictionary = tiers[0] if not tiers.is_empty() else {}
	for tier: Dictionary in tiers:
		if level >= int(tier.get("min_skill", 0)):
			chosen = tier
	return chosen

static func tier_by_id(tiers: Array, tier_id: String) -> Dictionary:
	for tier: Dictionary in tiers:
		if String(tier.get("id", "")) == tier_id:
			return tier
	return {}

static func durability_mult(tier: Dictionary) -> float:
	return float(tier.get("durability_mult", 1.0))

static func bonus_output_chance(tier: Dictionary) -> float:
	return float(tier.get("bonus_output_chance", 0.0))
