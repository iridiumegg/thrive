## Detects when a need crosses into (or out of) the critical zone between two
## vitals snapshots. Pure logic, so the "should we warn the player" decision is
## testable and separate from playing the sound / flashing the UI.
class_name VitalAlert
extends RefCounted

const NEEDS := ["calories", "hydration", "energy", "warmth", "condition"]

## Needs whose fraction fell from at/above `threshold` to below it.
static func newly_critical(prev: Dictionary, curr: Dictionary, threshold: float) -> Array[String]:
	var out: Array[String] = []
	for need in NEEDS:
		if float(prev.get(need, 1.0)) >= threshold and float(curr.get(need, 1.0)) < threshold:
			out.append(need)
	return out

## Needs whose fraction rose from below `threshold` back to at/above it.
static func recovered(prev: Dictionary, curr: Dictionary, threshold: float) -> Array[String]:
	var out: Array[String] = []
	for need in NEEDS:
		if float(prev.get(need, 1.0)) < threshold and float(curr.get(need, 1.0)) >= threshold:
			out.append(need)
	return out
