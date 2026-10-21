extends TestCase


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func test_roll_range() -> void:
	var rng := _rng(1)
	var lo := 999
	var hi := -999
	for i in 1000:
		var r := RngUtil.roll(rng, "2d6+1")
		lo = mini(lo, r)
		hi = maxi(hi, r)
	assert_eq(lo, 3, "min")
	assert_eq(hi, 13, "max")


func test_roll_plain_and_zero() -> void:
	var rng := _rng(5)
	for i in 50:
		var r := RngUtil.roll(rng, "1d3")
		assert_true(r >= 1 and r <= 3)
	assert_eq(RngUtil.roll(rng, "0d6+2"), 2)


func test_roll_deterministic() -> void:
	var a := _rng(42)
	var b := _rng(42)
	for i in 20:
		assert_eq(RngUtil.roll(a, "3d8"), RngUtil.roll(b, "3d8"))


func test_chance_bounds() -> void:
	var rng := _rng(3)
	for i in 100:
		assert_false(RngUtil.chance(rng, 0))
		assert_true(RngUtil.chance(rng, 100))


func test_tile_rules() -> void:
	assert_true(Tile.opaque(Tile.T.WALL))
	assert_false(Tile.passable(Tile.T.WALL))
	assert_true(Tile.opaque(Tile.T.SECRET_DOOR))
	assert_false(Tile.passable(Tile.T.SECRET_DOOR))
	assert_true(Tile.passable(Tile.T.DOOR_OPEN))
	assert_false(Tile.opaque(Tile.T.DOOR_OPEN))
	assert_true(Tile.opaque(Tile.T.DOOR_CLOSED))
	assert_false(Tile.passable(Tile.T.DOOR_CLOSED))
	assert_eq(Tile.sprite(Tile.T.SECRET_DOOR), Tile.sprite(Tile.T.WALL))
	assert_eq(Tile.sprite(Tile.T.STAIRS_DOWN), "tile.stairs.down")


func _sample_level() -> Level:
	var l := Level.new(10, 8, 2)
	l.set_tile(Vector2i(3, 3), Tile.T.FLOOR)
	l.set_tile(Vector2i(4, 3), Tile.T.DOOR_CLOSED)
	l.explored[l.index(Vector2i(3, 3))] = 1
	var a := Actor.new()
	a.id = 7
	a.kind = "kobold"
	a.pos = Vector2i(3, 3)
	a.hp = 4
	a.max_hp = 6
	a.speed = 100
	a.data = {"ai": "wander"}
	l.actors.append(a)
	l.floor_items[Vector2i(3, 3)] = [{"uid": 1, "id": "dagger", "qty": 1}]
	return l


func test_level_basics() -> void:
	var l := _sample_level()
	assert_eq(l.get_tile(Vector2i(0, 0)), Tile.T.WALL, "default fill")
	assert_false(l.in_bounds(Vector2i(10, 0)))
	assert_eq(l.get_tile(Vector2i(-1, 0)), Tile.T.WALL, "out of bounds reads as wall")
	assert_true(l.blocks_move(Vector2i(3, 3)), "actor blocks")
	assert_true(l.blocks_move(Vector2i(4, 3)), "closed door blocks")
	assert_eq(l.actor_at(Vector2i(3, 3)).id, 7)
	assert_eq(l.actor_at(Vector2i(5, 5)), null)


func test_level_roundtrip() -> void:
	var l := _sample_level()
	var copy := Level.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	assert_eq(copy.width, 10)
	assert_eq(copy.depth, 2)
	assert_eq(copy.tiles, l.tiles)
	assert_eq(copy.explored, l.explored)
	assert_eq(copy.actors.size(), 1)
	assert_eq(copy.actors[0].pos, Vector2i(3, 3))
	assert_eq(copy.actors[0].data, {"ai": "wander"})
	assert_eq(copy.floor_items[Vector2i(3, 3)][0]["id"], "dagger")
	assert_eq(typeof(copy.floor_items[Vector2i(3, 3)][0]["uid"]), TYPE_INT)


func test_game_data_loads() -> void:
	var db := GameData.load_default()
	assert_eq(db.monster("giant_rat")["name"], "Giant Rat")
	assert_eq(db.item("dagger")["weight"], 500)
	var shallow := db.monsters_for_depth(1)
	assert_true(shallow.size() >= 3)
	for m in shallow:
		assert_true(int(m["min_depth"]) <= 1)
