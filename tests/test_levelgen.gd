extends TestCase

const PASSABLE_FOR_CONNECTIVITY := [Tile.T.FLOOR, Tile.T.DOOR_OPEN, Tile.T.DOOR_CLOSED, Tile.T.SECRET_DOOR,
	Tile.T.STAIRS_UP, Tile.T.STAIRS_DOWN]


func _gen(seed: int, depth: int) -> Level:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return LevelGen.generate_mine(depth, rng, GameData.load_default())


func _flood(l: Level, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue := [from]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = p + d
			if not seen.has(n) and l.get_tile(n) in PASSABLE_FOR_CONNECTIVITY:
				seen[n] = true
				queue.append(n)
	return seen


func test_connected_200_seeds() -> void:
	for seed in range(1, 201):
		var depth := 1 + seed % 3
		var l := _gen(seed, depth)
		var reach := _flood(l, l.find_tile(Tile.T.STAIRS_UP))
		if not reach.has(l.find_tile(Tile.T.STAIRS_DOWN)):
			fail("seed %d: down stairs unreachable" % seed)
			return
		for i in l.tiles.size():
			if l.tiles[i] in PASSABLE_FOR_CONNECTIVITY and not reach.has(Vector2i(i % l.width, i / l.width)):
				fail("seed %d: isolated tile at %d" % [seed, i])
				return


func test_exactly_one_each_stairs() -> void:
	for seed in range(1, 30):
		var l := _gen(seed, 1)
		assert_eq(l.tiles.count(Tile.T.STAIRS_UP), 1, "seed %d up" % seed)
		assert_eq(l.tiles.count(Tile.T.STAIRS_DOWN), 1, "seed %d down" % seed)


func test_size_and_depth() -> void:
	var l := _gen(9, 2)
	assert_eq(l.width, 64)
	assert_eq(l.height, 64)
	assert_eq(l.depth, 2)


func test_monsters_not_on_walls_or_stairs() -> void:
	for seed in range(1, 30):
		var l := _gen(seed, 2)
		assert_eq(l.actors.size(), 3 + 2, "monster count")
		var up := l.find_tile(Tile.T.STAIRS_UP)
		var spots := {}
		for a in l.actors:
			assert_eq(l.get_tile(a.pos), Tile.T.FLOOR, "seed %d monster tile" % seed)
			assert_true(a.pos.distance_to(up) >= 6.0, "seed %d monster too close to arrival" % seed)
			assert_false(spots.has(a.pos), "stacked monsters")
			spots[a.pos] = true
			assert_true(int(GameData.load_default().monster(a.kind)["min_depth"]) <= 2)


func test_floor_items_on_floor() -> void:
	var l := _gen(4, 1)
	assert_true(l.floor_items.size() >= 3)
	for p in l.floor_items:
		assert_eq(l.get_tile(p), Tile.T.FLOOR)


func test_deterministic() -> void:
	var a := _gen(77, 1)
	var b := _gen(77, 1)
	assert_eq(a.tiles, b.tiles)
	assert_eq(a.actors.map(func(x): return x.pos), b.actors.map(func(x): return x.pos))


func test_town_loads() -> void:
	var t := Town.build()
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/town.json"))
	assert_eq(t.width, int(spec["width"]))
	assert_eq(t.height, int(spec["height"]))
	assert_eq(t.depth, 0)
	var start := Vector2i(int(spec["player_start"][0]), int(spec["player_start"][1]))
	assert_true(Tile.passable(t.get_tile(start)), "start passable")
	var mine := Vector2i(int(spec["mine_entrance"][0]), int(spec["mine_entrance"][1]))
	assert_eq(t.get_tile(mine), Tile.T.STAIRS_DOWN)
	assert_true(_flood_any(t, start).has(mine), "mine reachable from start")


func test_town_buildings_have_names() -> void:
	var t := Town.build()
	assert_true(t.signs.size() >= 6)
	assert_has(t.signs.values(), "Gunnhild's General Store")
	for p in t.signs:
		assert_eq(t.get_tile(p), Tile.T.BUILDING)


func _flood_any(l: Level, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue := [from]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = p + d
			if not seen.has(n) and Tile.passable(l.get_tile(n)):
				seen[n] = true
				queue.append(n)
	return seen
