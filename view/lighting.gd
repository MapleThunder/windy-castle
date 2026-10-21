class_name Lighting
extends Node2D
## Torch light with wall shadows in the mine, daylight in town.

const MINE_AMBIENT := Color("14111c")
const TOWN_AMBIENT := Color(1.0, 0.97, 0.9)
const TORCH_COLOR := Color("ffb46b")
const TORCH_RADIUS_TILES := 7.5
const FLICKER_ENERGY := 0.06
const FLICKER_SCALE := 0.03
const FLICKER_HZ := 2.0
const FLOOR_MASK := 1
const WALL_MASK := 2

var world: WorldView
var ambient := CanvasModulate.new()
var torch := PointLight2D.new()  # floors and actors, with shadows
var wall_torch := PointLight2D.new()  # wall faces and features, no shadows
var occluders := Node2D.new()
var _noise := FastNoiseLite.new()
var _time := 0.0
var _base_scale := 1.0


func setup(w: WorldView) -> void:
	world = w
	add_child(ambient)
	add_child(occluders)
	torch.texture = _radial_texture(256)
	torch.color = TORCH_COLOR
	torch.energy = 1.15
	torch.shadow_enabled = true
	torch.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	torch.shadow_filter_smooth = 3.0
	torch.shadow_color = Color(0, 0, 0, 0.85)
	_base_scale = TORCH_RADIUS_TILES * world.art.tile_size() * 2.0 / 256.0
	torch.texture_scale = _base_scale
	torch.range_item_cull_mask = FLOOR_MASK
	add_child(torch)
	wall_torch.texture = torch.texture
	wall_torch.color = TORCH_COLOR
	wall_torch.range_item_cull_mask = WALL_MASK
	add_child(wall_torch)
	_noise.frequency = 1.0
	update_level()


static func _radial_texture(size: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


## Rebuild after a level change.
func update_level() -> void:
	var town := world.game.level.depth == 0
	ambient.color = TOWN_AMBIENT if town else MINE_AMBIENT
	torch.enabled = not town
	wall_torch.enabled = not town
	for c in occluders.get_children():
		c.queue_free()
	if town:
		return
	var l := world.game.level
	var s := float(world.art.tile_size())
	var square := OccluderPolygon2D.new()
	square.polygon = PackedVector2Array([Vector2(0, 0), Vector2(s, 0), Vector2(s, s), Vector2(0, s)])
	for y in l.height:
		for x in l.width:
			var p := Vector2i(x, y)
			if Tile.opaque(l.get_tile(p)) and _borders_open(l, p):
				var o := LightOccluder2D.new()
				o.occluder = square
				o.position = Vector2(p) * s
				occluders.add_child(o)


static func _borders_open(l: Level, p: Vector2i) -> bool:
	for d in AI.DIRS:
		if not Tile.opaque(l.get_tile(p + d)) and l.in_bounds(p + d):
			return true
	return false


func _process(delta: float) -> void:
	if world == null:
		return
	_time += delta
	var player_node := world.actor_node(world.game.player.id)
	if player_node != null:
		torch.position = player_node.position
	var n := _noise.get_noise_1d(_time * FLICKER_HZ * 10.0)
	torch.energy = 1.15 * (1.0 + n * FLICKER_ENERGY * 2.0)
	torch.texture_scale = _base_scale * (1.0 + _noise.get_noise_1d(_time * FLICKER_HZ * 10.0 + 100.0) * FLICKER_SCALE * 2.0)
	wall_torch.position = torch.position
	wall_torch.energy = torch.energy * 0.9
	wall_torch.texture_scale = torch.texture_scale
