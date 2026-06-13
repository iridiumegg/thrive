extends "res://tests/test_case.gd"

func _trees() -> Dictionary:
	return {
		"dlg": {
			"start": "root",
			"nodes": {
				"root": {
					"speaker": "X",
					"text": "Hello.",
					"choices": [
						{"text": "Always", "goto": "a"},
						{"text": "If friend", "goto": "b", "requires": {"relationship": {"npc": "x", "min": 30}}},
						{"text": "If has gift", "goto": "c", "requires": {"items": [{"item": "berry", "qty": 2}]}},
						{"text": "If flag", "goto": "d", "requires": {"flags": ["told"]}},
						{"text": "If NOT flag", "goto": "e", "requires": {"not_flags": ["told"]}},
					],
				},
				"a": {"text": "A", "choices": []},
			},
		},
	}

func _sys() -> DialogueSystem:
	return DialogueSystem.new(_trees())

func test_start_and_node_lookup() -> void:
	var s := _sys()
	assert_eq(s.start_node_id("dlg"), "root")
	assert_eq(String(s.node("dlg", "root")["speaker"]), "X")

func test_has_node_treats_end_as_terminal() -> void:
	var s := _sys()
	assert_true(s.has_node("dlg", "a"))
	assert_false(s.has_node("dlg", "end"))
	assert_false(s.has_node("dlg", ""))
	assert_false(s.has_node("dlg", "missing"))

func test_unconditional_choice_always_available() -> void:
	var avail := _sys().available_choices("dlg", "root", {"npc": "x"})
	assert_true(0 in avail)

func test_relationship_gate() -> void:
	var s := _sys()
	var low := s.available_choices("dlg", "root", {"npc": "x", "relationship": {"x": 10}})
	assert_false(1 in low, "friend-only choice hidden below threshold")
	var high := s.available_choices("dlg", "root", {"npc": "x", "relationship": {"x": 30}})
	assert_true(1 in high)

func test_item_gate() -> void:
	var s := _sys()
	assert_false(2 in s.available_choices("dlg", "root", {"npc": "x", "item_counts": {"berry": 1}}))
	assert_true(2 in s.available_choices("dlg", "root", {"npc": "x", "item_counts": {"berry": 2}}))

func test_flag_and_not_flag_gates() -> void:
	var s := _sys()
	var told := s.available_choices("dlg", "root", {"npc": "x", "flags": {"told": true}})
	assert_true(3 in told, "flag-gated choice visible when flag set")
	assert_false(4 in told, "not_flag choice hidden when flag set")
	var untold := s.available_choices("dlg", "root", {"npc": "x", "flags": {}})
	assert_false(3 in untold)
	assert_true(4 in untold)

func test_real_dialogues_reference_valid_nodes() -> void:
	# Data guard: every choice goto points to a real node or a terminal.
	var trees: Dictionary = load_json("res://game/data/dialogues.json")
	var sys := DialogueSystem.new(trees)
	for dlg_id: String in trees:
		for node_id: String in trees[dlg_id]["nodes"]:
			for choice: Dictionary in trees[dlg_id]["nodes"][node_id].get("choices", []):
				var goto := String(choice.get("goto", "end"))
				assert_true(goto == "end" or sys.has_node(dlg_id, goto),
						"%s/%s -> unknown node %s" % [dlg_id, node_id, goto])
