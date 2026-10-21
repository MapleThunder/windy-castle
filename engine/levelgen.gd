class_name LevelGen
extends RefCounted
## Mine levels: rectangular rooms joined by L-shaped corridors, with doors where corridors meet rooms.
## Item uids and actor ids are left at 0; the Game assigns them when the level is first entered.

const SIZE := 64
# ASSUMED: room counts and sizes, door odds and item counts. The HLP gives no numbers.
const ROOM_ATTEMPTS := 200
const ROOMS_MIN := 6
const ROOMS_MAX := 12
const ROOM_SIDE_MIN := 4
const ROOM_SIDE_MAX := 12
const DOOR_CLOSED_PCT := 60
const DOOR_SECRET_PCT := 10
const MONSTER_SAFE_DISTANCE := 6.0


static func generate_mine(depth: int, rng: RandomNumberGenerator, db: GameData) -> Level:
	var l := Level.new(SIZE, SIZE, depth)
	l.name = "Mine Level %d" % depth  # source: exe ("Mine Level")
	var rooms := _place_rooms(l, rng)
	for i in range(1, rooms.size()):
		_corridor(l, rng, _center(rooms[i - 1]), _center(rooms[i]))
	for i in rng.randi_range(1, 3):  # a few loops so the map is not a single chain
		_corridor(l, rng, _center(rooms[rng.randi() % rooms.size()]), _center(rooms[rng.randi() % rooms.size()]))
	_place_doors(l, rng, rooms)
	var up := _random_floor(l, rng, rooms[0])
	l.set_tile(up, Tile.T.STAIRS_UP)
	l.set_tile(_random_floor(l, rng, rooms[rooms.size() - 1]), Tile.T.STAIRS_DOWN)  # never `up`: that tile is no longer FLOOR
	_place_monsters(l, rng, db, depth, up)
	_place_items(l, rng, db)
	return l


static func _place_rooms(l: Level, rng: RandomNumberGenerator) -> Array[Rect2i]:
	var want := rng.randi_range(ROOMS_MIN, ROOMS_MAX)
	var rooms: Array[Rect2i] = []
	for attempt in ROOM_ATTEMPTS:
		if rooms.size() >= want:
			break
		var w := rng.randi_range(ROOM_SIDE_MIN, ROOM_SIDE_MAX)
		var h := rng.randi_range(ROOM_SIDE_MIN, ROOM_SIDE_MAX)
		var r := Rect2i(rng.randi_range(2, SIZE - w - 3), rng.randi_range(2, SIZE - h - 3), w, h)
		if rooms.any(func(o: Rect2i): return o.grow(2).intersects(r)):
			continue
		rooms.append(r)
	rooms.sort_custom(func(a: Rect2i, b: Rect2i): return a.position.x + a.position.y < b.position.x + b.position.y)
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				l.set_tile(Vector2i(x, y), Tile.T.FLOOR)
	return rooms


static func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


static func _corridor(l: Level, rng: RandomNumberGenerator, a: Vector2i, b: Vector2i) -> void:
	var corner := Vector2i(b.x, a.y) if rng.randi() % 2 == 0 else Vector2i(a.x, b.y)
	for seg in [[a, corner], [corner, b]]:
		var p: Vector2i = seg[0]
		var end: Vector2i = seg[1]
		var step := (end - p).sign()
		while true:
			l.set_tile(p, Tile.T.FLOOR)
			if p == end:
				break
			p += step


static func _place_doors(l: Level, rng: RandomNumberGenerator, rooms: Array[Rect2i]) -> void:
	# A door goes on each corridor tile in a room's wall ring that has rock on both sides along the ring.
	for r in rooms:
		var ring := r.grow(1)
		for x in range(ring.position.x, ring.end.x):
			for y in [ring.position.y, ring.end.y - 1]:
				_maybe_door(l, rng, Vector2i(x, y), Vector2i.LEFT)
		for y in range(ring.position.y + 1, ring.end.y - 1):
			for x in [ring.position.x, ring.end.x - 1]:
				_maybe_door(l, rng, Vector2i(x, y), Vector2i.UP)


static func _maybe_door(l: Level, rng: RandomNumberGenerator, p: Vector2i, along: Vector2i) -> void:
	if l.get_tile(p) != Tile.T.FLOOR:
		return
	if l.get_tile(p + along) != Tile.T.WALL or l.get_tile(p - along) != Tile.T.WALL:
		return
	var roll := rng.randi_range(1, 100)
	if roll <= DOOR_SECRET_PCT:
		l.set_tile(p, Tile.T.SECRET_DOOR)
	elif roll <= DOOR_SECRET_PCT + DOOR_CLOSED_PCT:
		l.set_tile(p, Tile.T.DOOR_CLOSED)
	else:
		l.set_tile(p, Tile.T.DOOR_OPEN)


static func _random_floor(l: Level, rng: RandomNumberGenerator, r: Rect2i) -> Vector2i:
	while true:
		var p := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
		if l.get_tile(p) == Tile.T.FLOOR:
			return p
	return Vector2i.ZERO


static func _floor_tiles(l: Level) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in l.tiles.size():
		if l.tiles[i] == Tile.T.FLOOR:
			out.append(Vector2i(i % l.width, i / l.width))
	return out


static func _place_monsters(l: Level, rng: RandomNumberGenerator, db: GameData, depth: int, up: Vector2i) -> void:
	var pool := db.monsters_for_depth(depth)
	pool.sort_custom(func(a, b): return a["id"] < b["id"])
	var spots := _floor_tiles(l).filter(func(p: Vector2i): return p.distance_to(up) >= MONSTER_SAFE_DISTANCE)
	for i in 3 + depth:
		if spots.is_empty():
			return
		var m: Dictionary = pool[rng.randi() % pool.size()]
		var p: Vector2i = spots.pop_at(rng.randi() % spots.size())
		var a := Actor.new()
		a.kind = m["id"]
		a.pos = p
		a.max_hp = maxi(1, RngUtil.roll(rng, m["hp"]))
		a.hp = a.max_hp
		a.speed = int(m["speed"])
		a.data = {"ai": "wander"}
		l.actors.append(a)


static func _place_items(l: Level, rng: RandomNumberGenerator, db: GameData) -> void:
	var pool := db.items.values().filter(func(it):
		return (it["kind"] == "weapon" and int(it.get("weapon_class", 0)) <= 5) \
			or (it["kind"] == "armor" and int(it["armor"]) <= 6 and it["slot"] != null))
	pool.sort_custom(func(a, b): return a["id"] < b["id"])
	var spots := _floor_tiles(l)
	for i in rng.randi_range(2, 4):
		var it: Dictionary = pool[rng.randi() % pool.size()]
		l.floor_items[spots.pop_at(rng.randi() % spots.size())] = [{"uid": 0, "id": it["id"], "qty": 1}]
	for i in rng.randi_range(1, 2):  # ASSUMED: gold piles of 1d20 gp per level
		l.floor_items[spots.pop_at(rng.randi() % spots.size())] = [{"uid": 0, "id": "gold", "qty": RngUtil.roll(rng, "1d20")}]
