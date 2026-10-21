class_name Town
extends RefCounted
## The starting hamlet, loaded from data/maps/town.json (written by tools/town_layout.py).


static func spec() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/town.json"))


static func _v(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func build() -> Level:
	var s := spec()
	var l := Level.new(int(s["width"]), int(s["height"]), 0)
	l.name = s["name"]
	var legend: Dictionary = s["legend"]
	var rows: Array = s["rows"]
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			l.set_tile(Vector2i(x, y), Tile.by_name(legend[row[x]]))
	for b in s["buildings"]:
		var r: Array = b["rect"]
		for y in range(int(r[1]), int(r[1]) + int(r[3])):
			for x in range(int(r[0]), int(r[0]) + int(r[2])):
				l.signs[Vector2i(x, y)] = b["name"]
		if b.has("sign"):
			# source: exe ("A sign that says:"). Right-clicking a sign in the original showed this.
			l.features[_v(b["sign"])] = {"sprite": "tile.sign", "text": "A sign that says: " + b["name"],
				"detail": b.get("flavour", "")}
	return l


static func player_start() -> Vector2i:
	return _v(spec()["player_start"])


## The mine's tunnel: the way down, and where the player arrives back from Mine Level 1.
static func mine_arrival() -> Vector2i:
	return _v(spec()["mine_arrival"])


## The walkable gap in the hamlet gate.
static func gate() -> Vector2i:
	return _v(spec()["gate"]["pass"])


static func highway_row() -> int:
	return int(spec()["highway_row"])
