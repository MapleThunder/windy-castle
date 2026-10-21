class_name TestCase
extends RefCounted

var failures: Array[String] = []


func fail(msg: String) -> void:
	failures.append(msg)


func assert_eq(a: Variant, b: Variant, msg := "") -> void:
	if typeof(a) != typeof(b) and not (_is_number(a) and _is_number(b)):
		fail("%s expected %s (%s), got %s (%s)" % [msg, var_to_str(b), type_string(typeof(b)), var_to_str(a), type_string(typeof(a))])
	elif a != b:
		fail("%s expected %s, got %s" % [msg, var_to_str(b), var_to_str(a)])


func assert_true(c: bool, msg := "") -> void:
	if not c:
		fail("%s expected true" % msg)


func assert_false(c: bool, msg := "") -> void:
	if c:
		fail("%s expected false" % msg)


func assert_has(container: Variant, value: Variant, msg := "") -> void:
	if not value in container:
		fail("%s expected %s to contain %s" % [msg, str(container).left(200), var_to_str(value)])


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
