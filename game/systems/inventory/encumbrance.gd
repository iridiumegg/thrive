## Encumbrance model: how a heavy load slows you and burns extra energy.
## Pure static logic so it can be unit-tested and reused by both the player
## (movement) and the vitals component (drain). Spec 0.5/9: the weight cap is
## the real constraint and feeds the overexertion/exhaustion pressure.
##
## Below the "heavy" threshold there is no penalty at all. Between the threshold
## and the cap, the speed and activity multipliers interpolate linearly toward
## their worst-case values, so loading up is a smooth, readable trade-off.
class_name Encumbrance
extends RefCounted

## Returns {speed_mult, activity_mult} for a given weight fraction (0..1+).
static func factors(weight_fraction: float, cfg: Dictionary) -> Dictionary:
	var threshold := float(cfg["heavy_threshold_fraction"])
	if weight_fraction <= threshold:
		return {"speed_mult": 1.0, "activity_mult": 1.0}
	var t := clampf((weight_fraction - threshold) / maxf(0.0001, 1.0 - threshold), 0.0, 1.0)
	return {
		"speed_mult": lerpf(1.0, float(cfg["encumbered_speed_min"]), t),
		"activity_mult": lerpf(1.0, float(cfg["encumbered_activity_max"]), t),
	}
