## Minimal assertion base class for headless unit tests.
## Test scripts extend this and define methods named test_*.
extends RefCounted

var failures: Array[String] = []
var checks: int = 0

func assert_true(condition: bool, message: String = "") -> void:
	checks += 1
	if not condition:
		failures.append("assert_true failed: %s" % message)

func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message)

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	checks += 1
	if actual != expected:
		failures.append("assert_eq failed: expected %s, got %s. %s" % [expected, actual, message])

func assert_almost(actual: float, expected: float, epsilon: float = 0.001, message: String = "") -> void:
	checks += 1
	if absf(actual - expected) > epsilon:
		failures.append("assert_almost failed: expected %s ± %s, got %s. %s" % [expected, epsilon, actual, message])

func assert_lt(a: float, b: float, message: String = "") -> void:
	checks += 1
	if not (a < b):
		failures.append("assert_lt failed: %s < %s is false. %s" % [a, b, message])

static func load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
