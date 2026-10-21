class_name AI
extends RefCounted
## Monster behaviour: wander until the player is in sight, then chase and attack; flee when badly hurt.

const SIGHT := 8
const FLEE_FRACTION := 0.25
const DIRS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func take_turn(game: Game, m: Actor) -> Array:
	var def := game.db.monster(m.kind)
	var flags: Array = def["flags"]
	var sees := FOV.compute(game.level, m.pos, SIGHT).has(game.player.pos)
	if m.hp < m.max_hp * FLEE_FRACTION and not "mindless" in flags:
		m.data["ai"] = "flee"
	elif sees:
		m.data["ai"] = "chase"
	elif m.data["ai"] == "chase":
		m.data["ai"] = "wander"
	if "erratic" in flags and game.rng.randi() % 2 == 0:
		return _wander(game, m)
	match m.data["ai"]:
		"chase":
			if chebyshev(m.pos, game.player.pos) == 1:
				return game.melee(m, game.player)
			return _step(game, m, 1)
		"flee":
			return _step(game, m, -1)
	return _wander(game, m)


## Step to the free neighbour that best closes (toward = 1) or opens (toward = -1) the distance.
static func _step(game: Game, m: Actor, toward: int) -> Array:
	var target := game.player.pos
	var best := m.pos
	var best_score := toward * (chebyshev(m.pos, target) * 100 + int(m.pos.distance_squared_to(target)))
	for d in DIRS:
		var p: Vector2i = m.pos + d
		if game.level.blocks_move(p):
			continue
		var score := toward * (chebyshev(p, target) * 100 + int(p.distance_squared_to(target)))
		if score < best_score:
			best = p
			best_score = score
	return game.move_actor(m, best) if best != m.pos else []


static func _wander(game: Game, m: Actor) -> Array:
	var d: Vector2i = DIRS[game.rng.randi() % DIRS.size()]
	return game.move_actor(m, m.pos + d) if not game.level.blocks_move(m.pos + d) else []
