class_name FOV
extends RefCounted
## Recursive shadowcasting over eight octants. Opaque tiles are visible but block what lies behind.

# Octant transforms: (xx, xy, yx, yy).
const _OCTANTS := [
	[1, 0, 0, 1], [0, 1, 1, 0], [0, -1, 1, 0], [-1, 0, 0, 1],
	[-1, 0, 0, -1], [0, -1, -1, 0], [0, 1, -1, 0], [1, 0, 0, -1],
]


static func compute(level: Level, origin: Vector2i, radius: int) -> Dictionary:
	var seen := {origin: true}
	for o in _OCTANTS:
		_cast(level, origin, radius, 1, 1.0, 0.0, o[0], o[1], o[2], o[3], seen)
	return seen


static func _cast(level: Level, origin: Vector2i, radius: int, row: int, start: float, end: float,
		xx: int, xy: int, yx: int, yy: int, seen: Dictionary) -> void:
	if start < end:
		return
	var r2 := radius * radius + radius
	var new_start := 0.0
	for j in range(row, radius + 1):
		var blocked := false
		var dy := -j
		for dx in range(-j, 1):
			var l_slope := (dx - 0.5) / (dy + 0.5)
			var r_slope := (dx + 0.5) / (dy - 0.5)
			if start < r_slope:
				continue
			if end > l_slope:
				break
			var p := origin + Vector2i(dx * xx + dy * xy, dx * yx + dy * yy)
			if dx * dx + dy * dy <= r2 and level.in_bounds(p):
				seen[p] = true
			var opaque := Tile.opaque(level.get_tile(p))
			if blocked:
				if opaque:
					new_start = r_slope
				else:
					blocked = false
					start = new_start
			elif opaque and j < radius:
				blocked = true
				_cast(level, origin, radius, j + 1, start, l_slope, xx, xy, yx, yy, seen)
				new_start = r_slope
		if blocked:
			return
