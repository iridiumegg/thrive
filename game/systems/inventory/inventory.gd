## Weight-based grid inventory. Pure logic, fully unit-testable.
##
## Two constraints (spec 0.5 + 9):
##   - A total WEIGHT CAP is the real limit and is what feeds encumbrance.
##   - A fixed number of GRID SLOTS gives organisation/visual clarity; each
##     slot holds one stack up to that item's stack_size.
##
## Item metadata (weight, stack size) is injected as a catalog of ItemDefs so
## this class never touches the engine or autoloads — tests build their own.
class_name Inventory
extends RefCounted

## One occupied grid cell.
class Stack:
	var item_id: String
	var qty: int
	func _init(id: String, amount: int) -> void:
		item_id = id
		qty = amount

var slots: Array        # of Stack or null, length == slot_count
var weight_capacity: float

var _catalog: Dictionary  # item_id -> ItemDef

func _init(slot_count: int, weight_capacity_: float, catalog: Dictionary) -> void:
	slots = []
	slots.resize(slot_count)
	weight_capacity = weight_capacity_
	_catalog = catalog

func _def(item_id: String) -> ItemDef:
	return _catalog[item_id]

## --- Queries ---

func total_weight() -> float:
	var w := 0.0
	for s: Stack in slots:
		if s != null:
			w += _def(s.item_id).weight * s.qty
	return w

func weight_fraction() -> float:
	if weight_capacity <= 0.0:
		return 0.0
	return total_weight() / weight_capacity

func count(item_id: String) -> int:
	var total := 0
	for s: Stack in slots:
		if s != null and s.item_id == item_id:
			total += s.qty
	return total

func has(item_id: String, qty: int = 1) -> bool:
	return count(item_id) >= qty

func is_empty() -> bool:
	for s: Stack in slots:
		if s != null:
			return false
	return true

## How many of `item_id` would actually fit right now, limited by both the
## weight cap and available stack/slot space. Non-mutating.
func room_for(item_id: String, qty: int) -> int:
	var def := _def(item_id)
	var by_weight := qty
	if def.weight > 0.0:
		by_weight = int(floor((weight_capacity - total_weight()) / def.weight))
	var by_slots := 0
	var empty := 0
	for s: Stack in slots:
		if s == null:
			empty += 1
		elif s.item_id == item_id and s.qty < def.stack_size:
			by_slots += def.stack_size - s.qty
	by_slots += empty * def.stack_size
	return clampi(mini(qty, mini(by_weight, by_slots)), 0, qty)

## --- Mutation ---

## Adds up to `qty`, filling partial stacks first, then empty slots.
## Returns the number actually added (may be < qty if space/weight ran out).
func add(item_id: String, qty: int) -> int:
	var def := _def(item_id)
	var to_add := room_for(item_id, qty)
	var added := 0
	for s: Stack in slots:
		if added >= to_add:
			break
		if s != null and s.item_id == item_id and s.qty < def.stack_size:
			var take := mini(def.stack_size - s.qty, to_add - added)
			s.qty += take
			added += take
	for i in slots.size():
		if added >= to_add:
			break
		if slots[i] == null:
			var take := mini(def.stack_size, to_add - added)
			slots[i] = Stack.new(item_id, take)
			added += take
	return added

## Removes up to `qty`. Returns the number actually removed.
func remove(item_id: String, qty: int) -> int:
	var removed := 0
	for i in slots.size():
		if removed >= qty:
			break
		var s: Stack = slots[i]
		if s != null and s.item_id == item_id:
			var take := mini(s.qty, qty - removed)
			s.qty -= take
			removed += take
			if s.qty <= 0:
				slots[i] = null
	return removed

func remove_slot(index: int, qty: int = -1) -> int:
	var s: Stack = slots[index]
	if s == null:
		return 0
	var take := s.qty if qty < 0 else mini(qty, s.qty)
	s.qty -= take
	if s.qty <= 0:
		slots[index] = null
	return take

## --- Save/load support (used by the M12 save system) ---

func to_data() -> Array:
	var out: Array = []
	for s: Stack in slots:
		out.append(null if s == null else {"id": s.item_id, "qty": s.qty})
	return out

func load_data(data: Array) -> void:
	for i in mini(data.size(), slots.size()):
		var entry: Variant = data[i]
		slots[i] = null if entry == null else Stack.new(String(entry["id"]), int(entry["qty"]))
