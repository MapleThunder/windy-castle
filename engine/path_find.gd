class_name PathFind
extends RefCounted
## Shortest 8-way route over explored tiles the player can walk through (closed doors open on the way).


static func route(level: Level, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if from == to or not _walkable(level, to):
		return out
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		if p == to:
			break
		for d in AI.DIRS:
			var n: Vector2i = p + d
			if not came.has(n) and _walkable(level, n):
				came[n] = p
				queue.append(n)
	if not came.has(to):
		return out
	var p := to
	while p != from:
		out.push_front(p)
		p = came[p]
	return out


static func _walkable(level: Level, p: Vector2i) -> bool:
	var t := level.get_tile(p)
	return level.is_explored(p) and (Tile.passable(t) or t == Tile.T.DOOR_CLOSED)
