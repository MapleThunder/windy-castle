extends TestCase


func test_pick_scale() -> void:
	assert_eq(WorldView.pick_scale(Vector2i(1280, 800)), 2)
	assert_eq(WorldView.pick_scale(Vector2i(2560, 1440)), 4)
	assert_eq(WorldView.pick_scale(Vector2i(300, 200)), 1)
	assert_eq(WorldView.pick_scale(Vector2i(0, 0)), 1)
	assert_eq(WorldView.pick_scale(Vector2i(-50, 10)), 1)
