## Node-based dialogue traversal. Pure logic, unit-testable.
##
## A dialogue tree is { start, nodes: { id: node } }, where a node has text and
## a list of choices, each with an optional `requires` gate and `effects` list
## and a `goto` (empty / "end" ends the conversation). This class evaluates gates
## and looks up nodes; it never mutates the world — the component applies effects
## and decides the next node — so traversal stays pure and testable.
class_name DialogueSystem
extends RefCounted

var trees: Dictionary   # dialogue_id -> tree

func _init(dialogue_defs: Dictionary) -> void:
	trees = dialogue_defs

func start_node_id(dialogue_id: String) -> String:
	return String(trees.get(dialogue_id, {}).get("start", ""))

func node(dialogue_id: String, node_id: String) -> Dictionary:
	return trees.get(dialogue_id, {}).get("nodes", {}).get(node_id, {})

func has_node(dialogue_id: String, node_id: String) -> bool:
	return node_id != "" and node_id != "end" \
			and trees.get(dialogue_id, {}).get("nodes", {}).has(node_id)

## Indices of the node's choices whose `requires` gate is satisfied by ctx.
## ctx keys: flags{}, relationship{npc:points}, item_counts{}, npc.
func available_choices(dialogue_id: String, node_id: String, ctx: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var choices: Array = node(dialogue_id, node_id).get("choices", [])
	for i in choices.size():
		if choice_meets(choices[i], ctx):
			out.append(i)
	return out

func choice_meets(choice: Dictionary, ctx: Dictionary) -> bool:
	var req: Dictionary = choice.get("requires", {})
	if req.is_empty():
		return true
	var flags: Dictionary = ctx.get("flags", {})
	for flag: String in req.get("flags", []):
		if not bool(flags.get(flag, false)):
			return false
	for flag: String in req.get("not_flags", []):
		if bool(flags.get(flag, false)):
			return false
	if req.has("relationship"):
		var r: Dictionary = req["relationship"]
		var npc := String(r.get("npc", ctx.get("npc", "")))
		if int(ctx.get("relationship", {}).get(npc, 0)) < int(r.get("min", 0)):
			return false
	for entry: Dictionary in req.get("items", []):
		if int(ctx.get("item_counts", {}).get(String(entry["item"]), 0)) < int(entry["qty"]):
			return false
	return true
