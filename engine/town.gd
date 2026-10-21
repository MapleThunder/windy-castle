class_name Town
extends RefCounted
## The starting hamlet, loaded from data/maps/town.json.


static func spec() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/town.json"))


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
	return l


static func player_start() -> Vector2i:
	var p: Array = spec()["player_start"]
	return Vector2i(int(p[0]), int(p[1]))
