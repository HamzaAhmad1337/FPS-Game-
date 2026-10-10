extends RefCounted
class_name TestCase
## Base class for headless logic tests. Subclasses live in tools/test/cases/
## and expose methods named test_*.

var failures: Array[String] = []
var _current := ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func _fail(msg: String) -> void:
	failures.append("%s: %s" % [_current, msg])


func set_current(name: String) -> void:
	_current = name


func assert_true(value: bool, msg := "") -> void:
	if not value:
		_fail("expected true %s" % msg)


func assert_false(value: bool, msg := "") -> void:
	if value:
		_fail("expected false %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if actual != expected:
		_fail("expected %s got %s %s" % [str(expected), str(actual), msg])


func assert_almost_eq(actual: float, expected: float, eps := 0.0001, msg := "") -> void:
	if absf(actual - expected) > eps:
		_fail("expected ~%f got %f %s" % [expected, actual, msg])
