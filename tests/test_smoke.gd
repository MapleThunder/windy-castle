extends TestCase


func test_truth() -> void:
	assert_eq(1 + 1, 2)


func test_runner_catches_failure_is_reported() -> void:
	var t := TestCase.new()
	t.assert_eq(1, 2)
	assert_eq(t.failures.size(), 1)

