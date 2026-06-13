## Small helper for the accessibility text-scale option. HUD scripts route their
## font sizes through this so a single balance.json value scales readouts for
## low-vision players.
class_name UiScale
extends RefCounted

static func factor() -> float:
	return float(Balance.data.get("accessibility", {}).get("ui_text_scale", 1.0))

static func font_size(base: int) -> int:
	return int(round(base * factor()))
