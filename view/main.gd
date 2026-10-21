extends Control
## Entry point. Debug options (after `--`): --screenshot=<path> [--frames=<n>], --start-depth=<n>, --seed=<n>,
## --fps, --keys=<k1,k2,...> (key strings injected one every 10 frames, e.g. "l,l,Shift+l,g").

var options := {}
var screen: GameScreen
var _frames := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		options[kv[0]] = kv[1] if kv.size() > 1 else "true"
	$Title.hide()
	var spec := {"name": "Hero", "gender": "male", "stats": {"str": 50, "int": 50, "con": 50, "dex": 50}}
	var game := Game.new_game(spec, int(options.get("seed", "1")), GameData.load_default())
	for i in int(options.get("start-depth", "0")):
		game.enter_level(game.level, game.level.find_tile(Tile.T.STAIRS_DOWN))
		game.perform({"type": "stairs_down"})
	screen = GameScreen.new()
	add_child(screen)
	screen.start(game, ArtPack.open([]))


func _process(_delta: float) -> void:
	_frames += 1
	if options.has("keys") and _frames % 10 == 0:
		var keys: PackedStringArray = options["keys"].split(",")
		var i := _frames / 10 - 1
		if i < keys.size():
			var ev := GameSettings.parse_key(keys[i])
			ev.pressed = true
			Input.parse_input_event(ev)
			var up: InputEventKey = ev.duplicate()
			up.pressed = false
			Input.parse_input_event(up)
	if options.has("fps") and _frames % 60 == 0:
		print("fps ", Engine.get_frames_per_second())
	if options.has("screenshot") and _frames == int(options.get("frames", "30")):
		get_viewport().get_texture().get_image().save_png(options["screenshot"])
		get_tree().quit()
