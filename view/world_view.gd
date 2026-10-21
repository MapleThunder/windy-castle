class_name WorldView
extends Node2D
## Draws the current level: terrain, features, town buildings, floor items and actors.

const MIN_TILES := Vector2i(15, 11)
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


func _ground_sprite(t: int, town: bool) -> String:
	if town:
		match t:
			Tile.T.GRASS, Tile.T.BUILDING, Tile.T.TREE:
				return "tile.grass"
			Tile.T.PALISADE:
				return "tile.palisade"
			_:
				return "tile.dirt"
	return "tile.wall" if t == Tile.T.WALL or t == Tile.T.SECRET_DOOR else "tile.floor"


func _feature_sprite(t: int, town: bool) -> String:
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
		for b in Town.spec()["buildings"]:
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
	refresh_entities()


func refresh_tile(p: Vector2i, town: bool = game.level.depth == 0) -> void:
	for layer in [memory, memory_features, ground, walls, features]:
		layer.erase_cell(p)
	if not game.level.is_explored(p):
		return
	var seen := game.visible.has(p)
	var t := game.level.get_tile(p)
	var lit_layer := walls if Tile.opaque(t) else ground
	(lit_layer if seen else memory).set_cell(p, _source(_ground_sprite(t, town)), Vector2i.ZERO)
	var f := _feature_sprite(t, town)
	if f != "":
		(features if seen else memory_features).set_cell(p, _source(f), Vector2i.ZERO)


func refresh_entities() -> void:
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
		if not live.has(id):
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
