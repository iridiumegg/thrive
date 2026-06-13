extends "res://tests/test_case.gd"

func _endings() -> Array:
	return [
		{"id": "leave", "requires": []},
		{"id": "stay", "requires": ["hearth_built"]},
		{"id": "change", "requires": ["heard_pell_warning", "read_marsh"]},
	]

func test_leave_is_always_available() -> void:
	var avail := Endings.available(_endings(), {})
	var ids := avail.map(func(e: Dictionary) -> String: return String(e["id"]))
	assert_true("leave" in ids)
	assert_eq(ids.size(), 1, "only the unconditional ending with no flags")

func test_single_flag_unlocks_stay() -> void:
	var avail := Endings.available(_endings(), {"hearth_built": true})
	var ids := avail.map(func(e: Dictionary) -> String: return String(e["id"]))
	assert_true("stay" in ids)
	assert_false("change" in ids)

func test_change_requires_all_its_flags() -> void:
	assert_false(Endings.is_available(_endings()[2], {"heard_pell_warning": true}))
	assert_true(Endings.is_available(_endings()[2],
			{"heard_pell_warning": true, "read_marsh": true}))

func test_all_three_can_be_available() -> void:
	var flags := {"hearth_built": true, "heard_pell_warning": true, "read_marsh": true}
	assert_eq(Endings.available(_endings(), flags).size(), 3)

func test_real_endings_data_has_a_default() -> void:
	# At least one real ending must require nothing, so the game is completable.
	var endings: Array = load_json("res://game/data/endings.json")
	var has_default := false
	for ending: Dictionary in endings:
		if ending.get("requires", []).is_empty():
			has_default = true
	assert_true(has_default, "there must always be a reachable ending")

func test_real_notes_have_unique_flags() -> void:
	var seen: Dictionary = {}
	for note: Dictionary in load_json("res://game/data/notes.json"):
		var flag := String(note["flag"])
		assert_false(seen.has(flag), "duplicate note flag %s" % flag)
		seen[flag] = true
