class_name Level
extends RefCounted
## One map: terrain, what the player has explored, actors and floor items.

var width: int
var height: int
var depth: int  # 0 = town
var tiles: PackedByteArray
var explored: PackedByteArray
var actors: Array[Actor] = []
var floor_items: Dictionary = {}  # Vector2i -> Array of item instances {"uid", "id", "qty"}
var signs: Dictionary = {}  # Vector2i -> description shown when the player bumps or examines it
var features: Dictionary = {}  # Vector2i -> {"sprite", "text", "detail"}: signposts and other things to examine
var name: String = ""


func _init(w: int = 1, h: int = 1, d: int = 0) -> void:
	width = w
	height = h
	depth = d
	tiles = PackedByteArray()
	tiles.resize(w * h)
	tiles.fill(Tile.T.WALL)
	explored = PackedByteArray()
	explored.resize(w * h)


func index(p: Vector2i) -> int:
	return p.y * width + p.x


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func get_tile(p: Vector2i) -> int:
	return tiles[index(p)] if in_bounds(p) else Tile.T.WALL


func set_tile(p: Vector2i, t: int) -> void:
	tiles[index(p)] = t


func actor_at(p: Vector2i) -> Actor:
	for a in actors:
		if a.pos == p:
			return a
	return null


func blocks_move(p: Vector2i) -> bool:
	return not Tile.passable(get_tile(p)) or actor_at(p) != null


func is_explored(p: Vector2i) -> bool:
	return in_bounds(p) and explored[index(p)] == 1


func find_tile(t: int) -> Vector2i:
	var i := tiles.find(t)
	return Vector2i(i % width, i / width) if i >= 0 else Vector2i(-1, -1)


func items_at(p: Vector2i) -> Array:
	return floor_items.get(p, [])


func to_dict() -> Dictionary:
	var items := {}
	for p in floor_items:
		items["%d,%d" % [p.x, p.y]] = floor_items[p]
	var sign_out := {}
	for p in signs:
		sign_out["%d,%d" % [p.x, p.y]] = signs[p]
	var feature_out := {}
	for p in features:
		feature_out["%d,%d" % [p.x, p.y]] = features[p]
	return {"width": width, "height": height, "depth": depth, "name": name, "signs": sign_out,
		"features": feature_out,
		"tiles": Marshalls.raw_to_base64(tiles), "explored": Marshalls.raw_to_base64(explored),
		"actors": actors.map(func(a): return a.to_dict()), "floor_items": items}


static func from_dict(d: Dictionary) -> Level:
	var l := Level.new(int(d["width"]), int(d["height"]), int(d["depth"]))
	l.tiles = Marshalls.base64_to_raw(d["tiles"])
	l.explored = Marshalls.base64_to_raw(d["explored"])
	l.name = d.get("name", "")
	for key: String in d.get("signs", {}):
		var sxy := key.split(",")
		l.signs[Vector2i(int(sxy[0]), int(sxy[1]))] = d["signs"][key]
	for key: String in d.get("features", {}):
		var fxy := key.split(",")
		l.features[Vector2i(int(fxy[0]), int(fxy[1]))] = d["features"][key]
	for a in d["actors"]:
		l.actors.append(Actor.from_dict(a))
	for key: String in d["floor_items"]:
		var xy := key.split(",")
		l.floor_items[Vector2i(int(xy[0]), int(xy[1]))] = d["floor_items"][key].map(item_from_dict)
	return l


static func item_from_dict(it: Dictionary) -> Dictionary:
	var out := it.duplicate()
	out["uid"] = int(it["uid"])
	out["qty"] = int(it["qty"])
	return out
