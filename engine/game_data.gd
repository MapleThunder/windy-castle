class_name GameData
extends RefCounted
## Monster and item definitions loaded from data/*.json.

var monsters: Dictionary = {}
var items: Dictionary = {}


static func load_default() -> GameData:
	var db := GameData.new()
	for row in _read("res://data/monsters.json"):
		db.monsters[row["id"]] = row
	for row in _read("res://data/items.json"):
		db.items[row["id"]] = row
	return db


static func _read(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Array, "%s did not parse as a JSON array" % path)
	return parsed


func monster(id: String) -> Dictionary:
	return monsters[id]


func item(id: String) -> Dictionary:
	return items[id]


func monsters_for_depth(depth: int) -> Array:
	return monsters.values().filter(func(m): return int(m["min_depth"]) <= depth)
