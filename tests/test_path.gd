extends TestCase


func _room() -> Level:
	var l := Level.new(9, 5, 1)
	for y in range(1, 4):
		for x in range(1, 8):
			l.set_tile(Vector2i(x, y), Tile.T.FLOOR)
			l.explored[l.index(Vector2i(x, y))] = 1
	return l


func test_straight_path() -> void:
	var p := PathFind.route(_room(), Vector2i(1, 2), Vector2i(5, 2))
	assert_eq(p.size(), 4)
	assert_eq(p[-1], Vector2i(5, 2))


func test_diagonal_steps_count_once() -> void:
	var p := PathFind.route(_room(), Vector2i(1, 1), Vector2i(3, 3))
	assert_eq(p.size(), 2)


func test_routes_around_wall() -> void:
	var l := _room()
	for y in range(1, 3):
		l.set_tile(Vector2i(4, y), Tile.T.WALL)
	var p := PathFind.route(l, Vector2i(2, 1), Vector2i(6, 1))
	assert_eq(p.size(), 4, "diagonal detour under the wall")
	assert_has(p, Vector2i(4, 3))
	for step in p:
		assert_true(Tile.passable(l.get_tile(step)))


func test_unexplored_tiles_are_not_used() -> void:
	var l := _room()
	l.explored[l.index(Vector2i(6, 2))] = 0
	assert_eq(PathFind.route(l, Vector2i(1, 2), Vector2i(6, 2)), [], "can't target unexplored")
	for y in range(1, 4):
		l.explored[l.index(Vector2i(4, y))] = 0
	assert_eq(PathFind.route(l, Vector2i(1, 2), Vector2i(7, 2)), [], "no known way through")


func test_closed_door_is_routable() -> void:
	var l := _room()
	for y in range(1, 4):
		l.set_tile(Vector2i(4, y), Tile.T.WALL)
	l.set_tile(Vector2i(4, 2), Tile.T.DOOR_CLOSED)
	var p := PathFind.route(l, Vector2i(1, 2), Vector2i(7, 2))
	assert_has(p, Vector2i(4, 2))


func test_same_tile_is_empty() -> void:
	assert_eq(PathFind.route(_room(), Vector2i(2, 2), Vector2i(2, 2)), [])


func test_route_toward_unreachable_gets_closest() -> void:
	var l := _room()
	for y in range(1, 4):
		l.set_tile(Vector2i(5, y), Tile.T.WALL)
	var p := PathFind.route_toward(l, Vector2i(1, 2), Vector2i(7, 2))
	assert_eq(p[-1], Vector2i(4, 2), "stops at the closest reachable tile")


func test_route_toward_reachable_is_route() -> void:
	assert_eq(PathFind.route_toward(_room(), Vector2i(1, 2), Vector2i(5, 2)), PathFind.route(_room(), Vector2i(1, 2), Vector2i(5, 2)))


func test_route_toward_already_closest_is_empty() -> void:
	var l := _room()
	for y in range(1, 4):
		l.set_tile(Vector2i(2, y), Tile.T.WALL)
	assert_eq(PathFind.route_toward(l, Vector2i(1, 2), Vector2i(7, 2)), [])
