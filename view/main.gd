extends Control
## Entry point. Debug options (after `--`): --screenshot=<path> [--frames=<n>], --start-depth=<n>, --seed=<n>, --fps.

var options := {}
var game: Game
var world: WorldView
var _frames := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		options[kv[0]] = kv[1] if kv.size() > 1 else "true"
	$Title.hide()
	var spec := {"name": "Hero", "gender": "male", "stats": {"str": 50, "int": 50, "con": 50, "dex": 50}}
	game = Game.new_game(spec, int(options.get("seed", "1")), GameData.load_default())
	for i in int(options.get("start-depth", "0")):
		var stairs := game.level.find_tile(Tile.T.STAIRS_DOWN)
		game.enter_level(game.level, stairs)
		game.perform({"type": "stairs_down"})
	world = WorldView.new()
	add_child(world)
	world.bind(game, ArtPack.open([]))
	world._fit()


func _process(_delta: float) -> void:
	_frames += 1
	if options.has("fps") and _frames % 60 == 0:
		print("fps ", Engine.get_frames_per_second())
	if options.has("screenshot") and _frames == int(options.get("frames", "30")):
		get_viewport().get_texture().get_image().save_png(options["screenshot"])
		get_tree().quit()
