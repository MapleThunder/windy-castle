class_name Minimap
extends Control
## Explored tiles at a few pixels each, with stairs marked and a pulsing player dot.

var game: Game
var cell := 2
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var l := game.level
	var town := l.depth == 0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var origin := (size - Vector2(l.width, l.height) * cell) / 2.0
	for y in l.height:
		for x in l.width:
			var p := Vector2i(x, y)
			if not l.is_explored(p):
				continue
			draw_rect(Rect2(origin + Vector2(p) * cell, Vector2(cell, cell)), _color(l.get_tile(p), town, game.visible.has(p)))
	var pulse := 0.6 + 0.4 * sin(_time * 5.0)
	var c := origin + (Vector2(game.player.pos) + Vector2(0.5, 0.5)) * cell
	draw_circle(c, cell * 1.6, Color(GameTheme.ACCENT, 0.35 * pulse))
	draw_circle(c, cell * 0.9, GameTheme.ACCENT)


func _color(t: int, town: bool, seen: bool) -> Color:
	var c: Color
	match t:
		Tile.T.STAIRS_DOWN, Tile.T.STAIRS_UP:
			return Color("ffd060")
		Tile.T.DOOR_CLOSED, Tile.T.DOOR_OPEN:
			c = Color("a0603a")
		Tile.T.WALL, Tile.T.SECRET_DOOR:
			c = Color("4a4658")
		Tile.T.GRASS, Tile.T.TREE:
			c = Color("2f6a2c")
		Tile.T.DIRT:
			c = Color("8a7a3a")
		Tile.T.BUILDING, Tile.T.PALISADE:
			c = Color("7a3a2a")
		_:
			c = Color("cfc6b0") if not town else Color("8a7a3a")
	return c if seen else c.darkened(0.45)
