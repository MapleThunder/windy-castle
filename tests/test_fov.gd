extends TestCase


func _room(w: int, h: int) -> Level:
	var l := Level.new(w + 2, h + 2, 1)
	for y in range(1, h + 1):
		for x in range(1, w + 1):
			l.set_tile(Vector2i(x, y), Tile.T.FLOOR)
	return l


func test_open_room_all_visible() -> void:
	var l := _room(9, 9)
	var seen := FOV.compute(l, Vector2i(5, 5), 8)
	for y in range(1, 10):
		for x in range(1, 10):
			assert_has(seen, Vector2i(x, y))


func test_origin_included() -> void:
	var seen := FOV.compute(_room(3, 3), Vector2i(2, 2), 0)
	assert_has(seen, Vector2i(2, 2))


func test_wall_blocks() -> void:
	var l := _room(9, 9)
	l.set_tile(Vector2i(5, 3), Tile.T.WALL)
	var seen := FOV.compute(l, Vector2i(5, 5), 8)
	assert_false(seen.has(Vector2i(5, 2)), "tile directly behind the pillar")
	assert_false(seen.has(Vector2i(5, 1)))


func test_wall_itself_visible() -> void:
	var l := _room(9, 9)
	l.set_tile(Vector2i(5, 3), Tile.T.WALL)
	var seen := FOV.compute(l, Vector2i(5, 5), 8)
	assert_has(seen, Vector2i(5, 3))
	assert_has(seen, Vector2i(0, 5), "room boundary wall")


func test_closed_door_blocks_open_door_not() -> void:
	var l := _room(9, 1)
	l.set_tile(Vector2i(5, 1), Tile.T.DOOR_CLOSED)
	assert_false(FOV.compute(l, Vector2i(1, 1), 10).has(Vector2i(7, 1)))
	l.set_tile(Vector2i(5, 1), Tile.T.DOOR_OPEN)
	assert_has(FOV.compute(l, Vector2i(1, 1), 10), Vector2i(7, 1))


func test_symmetric_corridor() -> void:
	var l := _room(11, 1)
	var seen := FOV.compute(l, Vector2i(1, 1), 10)
	for x in range(1, 12):
		assert_has(seen, Vector2i(x, 1))


func test_radius_limits() -> void:
	var l := _room(20, 1)
	var seen := FOV.compute(l, Vector2i(1, 1), 5)
	assert_has(seen, Vector2i(6, 1))
	assert_false(seen.has(Vector2i(8, 1)))
