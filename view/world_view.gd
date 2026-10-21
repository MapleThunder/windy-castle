class_name WorldView
extends Node2D
## Draws the current level: terrain, features, town buildings, floor items and actors.

const MIN_TILES := Vector2i(15, 10)
const MAX_SCALE := 4

var game: Game
var art: ArtPack
var memory := TileMapLayer.new()  # explored, out of sight
var memory_features := TileMapLayer.new()
var ground := TileMapLayer.new()  # in sight, lit, receives shadows
var walls := TileMapLayer.new()  # in sight, lit without shadows so wall faces catch the torch
var features := TileMapLayer.new()
var lighting := Lighting.new()
var fx := Fx.new()
var buildings := Node2D.new()
var items := Node2D.new()
var actors := Node2D.new()
var camera := Camera2D.new()
var map_rect := Rect2()  # the part of the screen the map shows through (empty = whole viewport)
var _sources: Dictionary = {}  # sprite name -> TileSet source id
var _actor_nodes: Dictionary = {}  # actor id -> Sprite2D


static func pick_scale(map_area: Vector2i) -> int:
	for s in range(MAX_SCALE, 1, -1):
		if map_area.x >= MIN_TILES.x * 32 * s and map_area.y >= MIN_TILES.y * 32 * s:
			return s
	return 1


func _ready() -> void:
	for n in [memory, memory_features, ground, walls, features, buildings, items, actors, camera]:
		add_child(n)
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = preload("res://view/shaders/ground.gdshader")
	ground.material = ground_mat
	var wall_mat := ShaderMaterial.new()
	wall_mat.shader = preload("res://view/shaders/wall.gdshader")
	walls.material = wall_mat
	walls.light_mask = Lighting.WALL_MASK
	features.light_mask = Lighting.WALL_MASK
	var memory_mat := ShaderMaterial.new()
	memory_mat.shader = preload("res://view/shaders/memory.gdshader")
	memory.material = memory_mat
	memory_features.material = memory_mat
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	get_viewport().size_changed.connect(_fit)


func bind(g: Game, a: ArtPack) -> void:
	game = g
	art = a
	var ts := TileSet.new()
	ts.tile_size = Vector2i(a.tile_size(), a.tile_size())
	for layer in [memory, memory_features, ground, walls, features]:
		layer.tile_set = ts
	_sources.clear()
	refresh_all()
	camera.reset_smoothing()
	if lighting.get_parent() == null:
		add_child(lighting)
		lighting.setup(self)
		add_child(fx)
		fx.setup(self)


func _source(name: String) -> int:
	if not _sources.has(name):
		var src := TileSetAtlasSource.new()
		src.texture = art.texture(name)
		src.texture_region_size = Vector2i(art.tile_size(), art.tile_size())
		src.create_tile(Vector2i.ZERO)
		_sources[name] = ground.tile_set.add_source(src)
	return _sources[name]


func tile_to_px(p: Vector2i) -> Vector2:
	var s := art.tile_size()
	return Vector2(p * s) + Vector2(s, s) / 2.0


# source: exe — the original's 32×32 transition bitmaps (see tools/extract/manifest.py TRANSITIONS).
# Grass with road on two adjacent sides: the road fills that half of the tile, so stepped roads draw as smooth 45° bands.
const ROAD_HALF := {"ne": "edge.dirt.grass.1", "nw": "edge.dirt.grass.3", "se": "edge.dirt.grass.2", "sw": "edge.dirt.grass.0"}
const ROCK_HALF := {"nw": "edge.wall.grass.0", "ne": "edge.wall.grass.1"}  # jagged mountain corners on grass
const SNOW_ON_ROCK := {"nw": "edge.wall.floor.2", "ne": "edge.wall.floor.0", "sw": "edge.wall.floor.3", "se": "edge.wall.floor.1"}


static func _kind(t: int) -> String:
	match t:
		Tile.T.DIRT, Tile.T.STAIRS_DOWN, Tile.T.STAIRS_UP:
			return "road"
		Tile.T.MOUNTAIN:
			return "rock"
		Tile.T.SNOW:
			return "snow"
		Tile.T.FARMLAND, Tile.T.TOWN_GATE:
			return "farm"
	return "grass"


## Which pair of adjacent sides (and only those two) match `kind`: "ne", "nw", "se", "sw" or "".
func _corner(p: Vector2i, kind: String) -> String:
	var l := game.level
	var n := _kind(l.get_tile(p + Vector2i.UP)) == kind and l.in_bounds(p + Vector2i.UP)
	var s := _kind(l.get_tile(p + Vector2i.DOWN)) == kind and l.in_bounds(p + Vector2i.DOWN)
	var e := _kind(l.get_tile(p + Vector2i.RIGHT)) == kind and l.in_bounds(p + Vector2i.RIGHT)
	var w := _kind(l.get_tile(p + Vector2i.LEFT)) == kind and l.in_bounds(p + Vector2i.LEFT)
	var diagonal := func(d: Vector2i) -> bool: return _kind(l.get_tile(p + d)) == kind
	# A staircase notch has the tile between the two sides unfilled; a junction or a plaza corner
	# has it filled, and those stay square, as in the original.
	if n and e and not s and not w and not diagonal.call(Vector2i(1, -1)):
		return "ne"
	if n and w and not s and not e and not diagonal.call(Vector2i(-1, -1)):
		return "nw"
	if s and e and not n and not w and not diagonal.call(Vector2i(1, 1)):
		return "se"
	if s and w and not n and not e and not diagonal.call(Vector2i(-1, 1)):
		return "sw"
	return ""


func _outdoor_sprite(p: Vector2i, t: int) -> String:
	var l := game.level
	match _kind(t):
		"grass":
			var c := _corner(p, "road")
			if c != "":
				return ROAD_HALF[c]
			c = _corner(p, "rock")
			if ROCK_HALF.has(c):
				return ROCK_HALF[c]
			return "tile.grass"
		"rock":
			var c := _corner(p, "snow")
			if c != "":
				return SNOW_ON_ROCK[c]
			if _kind(l.get_tile(p + Vector2i.DOWN)) == "grass":
				return "edge.wall.floor.4"  # grass fringe along the bottom
			if _kind(l.get_tile(p + Vector2i.LEFT)) == "grass":
				return "edge.wall.grass_edge.0"
			if _kind(l.get_tile(p + Vector2i.RIGHT)) == "grass":
				return "edge.wall.grass_edge.1"
			return "tile.wall"
		"snow":
			if _kind(l.get_tile(p + Vector2i.DOWN)) == "rock":
				return "edge.wall.floor.5"
			if _kind(l.get_tile(p + Vector2i.LEFT)) == "rock":
				return "edge.wall.floor.6"
			if _kind(l.get_tile(p + Vector2i.RIGHT)) == "rock":
				return "edge.wall.floor.7"
			return "tile.floor"
	if t == Tile.T.FARMLAND:
		return "tile.farmland"
	if t == Tile.T.TOWN_GATE:
		return "tile.farmland"  # the gate posts stand in the fields; the gate bitmap draws over them
	return "tile.dirt"


func _ground_sprite(t: int, town: bool) -> String:
	if town:
		match t:
			Tile.T.GRASS, Tile.T.BUILDING, Tile.T.TREE:
				return "tile.grass"
			Tile.T.PALISADE:
				return "tile.palisade"
			Tile.T.FARMLAND:
				return "tile.farmland"
			_:
				return "tile.dirt"
	return "tile.wall" if t == Tile.T.WALL or t == Tile.T.SECRET_DOOR else "tile.floor"


func _feature_sprite(t: int, town: bool) -> String:
	if town and t == Tile.T.TOWN_GATE:
		return ""  # drawn as the gate bitmap with the buildings
	if town and t == Tile.T.STAIRS_DOWN:
		return "tile.mine.entrance"
	if t in [Tile.T.DOOR_CLOSED, Tile.T.DOOR_OPEN, Tile.T.STAIRS_DOWN, Tile.T.STAIRS_UP, Tile.T.TOWN_GATE]:
		return Tile.sprite(t)
	return ""


func refresh_all() -> void:
	for layer in [memory, memory_features, ground, walls, features]:
		layer.clear()
	var l := game.level
	var town := l.depth == 0
	for y in l.height:
		for x in l.width:
			refresh_tile(Vector2i(x, y), town)
	for c in buildings.get_children():
		c.queue_free()
	if town:
		var spec := Town.spec()
		for b in spec["buildings"] + [spec["gate"]]:
			var s := Sprite2D.new()
			s.texture = ArtPack._load(ArtPack.ORIGINAL + "/" + b["bitmap"])
			s.centered = false
			s.position = Vector2(int(b["rect"][0]), int(b["rect"][1])) * art.tile_size()
			buildings.add_child(s)
	refresh_entities()
	camera.position = tile_to_px(game.player.pos)
	if lighting.world != null:
		lighting.update_level()
		fx.update_level()


## Redraw the tiles whose visibility may have changed since `previous` was the visible set.
func refresh_visibility(previous: Dictionary) -> void:
	var town := game.level.depth == 0
	for p in previous:
		refresh_tile(p, town)
	for p in game.visible:
		refresh_tile(p, town)
	refresh_entities(false)


func refresh_tile(p: Vector2i, town: bool = game.level.depth == 0) -> void:
	for layer in [memory, memory_features, ground, walls, features]:
		layer.erase_cell(p)
	if not game.level.is_explored(p):
		return
	var seen := game.visible.has(p)
	var t := game.level.get_tile(p)
	var lit_layer := walls if Tile.opaque(t) else ground
	var sprite := _outdoor_sprite(p, t) if town else _ground_sprite(t, town)
	(lit_layer if seen else memory).set_cell(p, _source(sprite), Vector2i.ZERO)
	var f := _feature_sprite(t, town)
	if game.level.features.has(p):
		f = game.level.features[p]["sprite"]
	if f != "":
		(features if seen else memory_features).set_cell(p, _source(f), Vector2i.ZERO)


## prune = false keeps sprites of actors that just left the level (killed) for their death animation.
func refresh_entities(prune: bool = true) -> void:
	for c in items.get_children():
		c.queue_free()
	for p: Vector2i in game.level.floor_items:
		if not game.visible.has(p):
			continue
		var top: Dictionary = game.level.floor_items[p][-1]
		var s := Sprite2D.new()
		s.texture = art.texture("item.gold" if top["id"] == "gold" else game.db.item(top["id"])["sprite"])
		s.position = tile_to_px(p)
		items.add_child(s)
	var live := {}
	for a in game.level.actors:
		live[a.id] = true
		var node: Sprite2D = _actor_nodes.get(a.id)
		if node == null:
			node = Sprite2D.new()
			node.texture = art.texture(actor_sprite(a))
			actors.add_child(node)
			_actor_nodes[a.id] = node
		node.position = tile_to_px(a.pos)
		node.visible = a.is_player() or game.visible.has(a.pos)
	for id in _actor_nodes.keys():
		if prune and not live.has(id):
			_actor_nodes[id].queue_free()
			_actor_nodes.erase(id)


func actor_sprite(a: Actor) -> String:
	if a.is_player():
		return "player." + str(game.spec.get("gender", "male"))
	return game.db.monster(a.kind)["sprite"]


func actor_node(id: int) -> Node2D:
	return _actor_nodes.get(id)


func clear_actors() -> void:
	for n in _actor_nodes.values():
		n.queue_free()
	_actor_nodes.clear()


func _fit() -> void:
	var view := get_viewport_rect().size
	var area := map_rect if map_rect.has_area() else Rect2(Vector2.ZERO, view)
	var s := pick_scale(Vector2i(area.size))
	camera.zoom = Vector2(s, s)
	camera.offset = (view / 2.0 - area.get_center()) / float(s)


func _process(_delta: float) -> void:
	if game == null:
		return
	var p := actor_node(game.player.id)
	if p != null:
		camera.position = p.position
