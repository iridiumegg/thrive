## Equipment slots: clothing layers (which feed the warmth model), the held
## tool, and accessories. Pure logic, unit-testable.
##
## Holds only item ids; metadata comes from an injected ItemDef catalog, same
## as Inventory. Insulation is the sum of every equipped clothing piece, which
## the vitals warmth sub-model reads each tick.
class_name Equipment
extends RefCounted

const SLOTS: PackedStringArray = ["head", "body", "hands", "feet", "tool"]

var _slots: Dictionary = {}   # slot_name -> item_id ("" if empty)
var _catalog: Dictionary      # item_id -> ItemDef

func _init(catalog: Dictionary) -> void:
	_catalog = catalog
	for slot in SLOTS:
		_slots[slot] = ""

func equipped(slot: String) -> String:
	return _slots.get(slot, "")

func is_slot_empty(slot: String) -> bool:
	return equipped(slot) == ""

func slot_for(item_id: String) -> String:
	return _catalog[item_id].equip_slot

## Equips an item into its slot, returning whatever was displaced ("" if none).
## Caller is responsible for moving the displaced item back to inventory.
func equip(item_id: String) -> String:
	var slot := slot_for(item_id)
	assert(slot in SLOTS, "Item %s is not equippable" % item_id)
	var previous: String = _slots[slot]
	_slots[slot] = item_id
	return previous

## Clears a slot and returns the item that was there ("" if already empty).
func unequip(slot: String) -> String:
	var previous: String = _slots.get(slot, "")
	_slots[slot] = ""
	return previous

## Total warmth contribution (°C) from all equipped clothing.
func total_insulation_c() -> float:
	var total := 0.0
	for slot in SLOTS:
		var id: String = _slots[slot]
		if id != "":
			total += _catalog[id].insulation_c
	return total

## --- Save/load support ---

func to_data() -> Dictionary:
	return _slots.duplicate()

func load_data(data: Dictionary) -> void:
	for slot in SLOTS:
		_slots[slot] = String(data.get(slot, ""))
