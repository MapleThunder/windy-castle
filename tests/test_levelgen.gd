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
	var spec := Town.spec()
	assert_eq(t.width, int(spec["width"]))
	assert_eq(t.height, int(spec["height"]))
	assert_eq(t.depth, 0)
	var start := Town.player_start()
	assert_true(Tile.passable(t.get_tile(start)), "start passable")
	assert_eq(t.get_tile(Town.mine_arrival()), Tile.T.STAIRS_DOWN, "the mine tunnel is the way down")
	var reach := _flood_any(t, start)
	assert_true(reach.has(Town.mine_arrival()), "mine reachable from the hamlet")
	var gate := Town.gate()
	assert_true(reach.has(gate), "through the hamlet gate")
	assert_true(Tile.passable(t.get_tile(gate)))
	assert_false(Tile.passable(t.get_tile(gate + Vector2i(-1, 0))), "gate posts")


func test_highway_runs_edge_to_edge() -> void:
	var t := Town.build()
	var y := Town.highway_row()
	for x in t.width:
		assert_eq(t.get_tile(Vector2i(x, y)), Tile.T.DIRT, "highway at %d" % x)


func test_mountains_in_the_north() -> void:
	var t := Town.build()
	for x in t.width:
		assert_true(t.get_tile(Vector2i(x, 0)) in [Tile.T.MOUNTAIN, Tile.T.SNOW, Tile.T.STAIRS_DOWN, Tile.T.DIRT])
	assert_false(Tile.passable(Tile.T.MOUNTAIN))
	assert_false(Tile.passable(Tile.T.SNOW))


func test_town_is_ringed_by_farmland() -> void:
	var t := Town.build()
	for x in t.width:
		assert_true(t.get_tile(Vector2i(x, t.height - 1)) == Tile.T.FARMLAND, "south edge")
	assert_false(Tile.passable(Tile.T.FARMLAND))
	assert_false(Tile.opaque(Tile.T.FARMLAND))


func test_town_buildings_have_names() -> void:
	var t := Town.build()
	assert_true(t.signs.size() >= 6)
	assert_has(t.signs.values(), "Gunnhild's General Store")
	for p in t.signs:
		assert_true(t.get_tile(p) in [Tile.T.BUILDING, Tile.T.TOWN_GATE], "sign text on %s" % p)


func test_town_signposts() -> void:
	var t := Town.build()
	var texts := []
	for p in t.features:
		var f: Dictionary = t.features[p]
		assert_eq(f["sprite"], "tile.sign")
		assert_true(Tile.passable(t.get_tile(p)) or t.get_tile(p) == Tile.T.GRASS)
		texts.append(f["text"])
	assert_has(texts, "A sign that says: Gunnhild's General Store")
	assert_true(texts.size() >= 5)


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
