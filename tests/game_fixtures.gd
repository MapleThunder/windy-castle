class_name GameFixtures
extends RefCounted
## Helpers for building controlled game situations in tests.

const SPEC := {"name": "Tester", "gender": "male", "stats": {"str": 50, "int": 50, "con": 50, "dex": 50}}


static func new_game(seed: int = 1) -> Game:
	return Game.new_game(SPEC, seed, GameData.load_default())


## An open floor room (w×h interior) at the given depth, with the player placed at `at`.
static func in_room(g: Game, w: int, h: int, at: Vector2i, depth: int = 1) -> Level:
	var l := Level.new(w + 2, h + 2, depth)
	for y in range(1, h + 1):
		for x in range(1, w + 1):
			l.set_tile(Vector2i(x, y), Tile.T.FLOOR)
	g.enter_level(l, at)
	return l


static func monster(g: Game, kind: String, at: Vector2i, hp: int = -1) -> Actor:
	var m := Actor.new()
	m.kind = kind
	m.pos = at
	m.max_hp = hp if hp > 0 else 6
	m.hp = m.max_hp
	m.speed = 100
	m.data = {"ai": "wander"}
	g.add_actor(m)
	return m


static func types(events: Array) -> Array:
	return events.map(func(e): return e["type"])
