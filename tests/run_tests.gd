## Headless test runner. Discovers tests/test_*.gd and runs every test_* method.
##
## Usage (after a one-time `godot --headless --path . --import`):
##   godot --headless --path . -s tests/run_tests.gd
## Exits non-zero if any assertion fails.
extends SceneTree

func _initialize() -> void:
	var paths: Array[String] = []
	for file in DirAccess.open("res://tests").get_files():
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd":
			paths.append("res://tests/" + file)
	paths.sort()

	var total_checks := 0
	var total_tests := 0
	var all_failures: Array[String] = []

	for path in paths:
		var script: GDScript = load(path)
		var instance: RefCounted = script.new()
		var methods: Array[String] = []
		for m in instance.get_method_list():
			var method_name := String(m.name)
			if method_name.begins_with("test_"):
				methods.append(method_name)
		methods.sort()
		for method_name in methods:
			total_tests += 1
			instance.failures.clear()
			instance.checks = 0
			instance.call(method_name)
			total_checks += instance.checks
			if instance.failures.is_empty():
				print("  PASS  %s :: %s" % [path.get_file(), method_name])
			else:
				for failure: String in instance.failures:
					all_failures.append("%s :: %s — %s" % [path.get_file(), method_name, failure])
					print("  FAIL  %s :: %s — %s" % [path.get_file(), method_name, failure])

	print("")
	if all_failures.is_empty():
		print("OK: %d tests, %d assertions, 0 failures" % [total_tests, total_checks])
		quit(0)
	else:
		print("FAILED: %d tests, %d assertions, %d failures" % [total_tests, total_checks, all_failures.size()])
		quit(1)
