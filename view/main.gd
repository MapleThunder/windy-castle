extends Control
## Screen router: title → character creation → game, plus saving, loading and death.
## Debug options (after `--`): --start=game (skip the title with a default hero), --start-depth=<n>,
## --seed=<n>, --hp=<n>, --at=<x>,<y>, --screenshot=<path> [--frames=<n>], --fps, --keys=<k1,k2,...> (injected one every 10 frames),
## --click=<x>,<y> [--click-frame=<n>] [--right] (a click at that screen position, default frame 20),
## --hover=<x>,<y> (mouse moved there 5 frames before the click frame).

const DEFAULT_SPEC := {"name": "Hero", "gender": "male", "stats": {"str": 50, "int": 50, "con": 50, "dex": 50}}

var options := {}
var db := GameData.load_default()
var art := ArtPack.open([])
var screen: Node = null
var game_screen: GameScreen = null
var overlay := CanvasLayer.new()
var overlay_root := Control.new()
var save_path := ""
var _frames := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		options[kv[0]] = kv[1] if kv.size() > 1 else "true"
	$Title.hide()
	overlay.layer = 30
	overlay_root.theme = GameTheme.build()
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(overlay_root)
	add_child(overlay)
	if options.get("start") == "game":
		_start_game(DEFAULT_SPEC, int(options.get("seed", "1")))
		for i in int(options.get("start-depth", "0")):
			var g := game_screen.game
			g.enter_level(g.level, Town.mine_arrival() if g.level.depth == 0 else g.level.find_tile(Tile.T.STAIRS_DOWN))
			g.perform({"type": "stairs_down"})
			game_screen.world.refresh_all()
		if options.has("at"):  # debug: stand somewhere on the current level
			var at: PackedStringArray = options["at"].split(",")
			game_screen.game.enter_level(game_screen.game.level, Vector2i(int(at[0]), int(at[1])))
			game_screen.world.refresh_all()
		if options.has("hp"):
			game_screen.game.player.hp = int(options["hp"])
	else:
		show_title()


func _swap(next: Node) -> void:
	if screen != null:
		screen.queue_free()
	screen = next
	game_screen = next as GameScreen
	add_child(next)


func show_title() -> void:
	var t := TitleScreen.new()
	t.chosen.connect(_on_title)
	_swap(t)


func _on_title(choice: String) -> void:
	match choice:
		"new":
			var c := CharCreate.new()
			c.confirmed.connect(func(spec): _start_game(spec, randi()))
			c.cancelled.connect(show_title)
			_swap(c)
		"load":
			_open_load()
		"options":
			_modal(OptionsPanel.new())
		"keys":
			_modal(InfoPanel.new("Keyboard Commands", GameScreen.cheat_sheet(), Vector2(620, 460)))
		"quit":
			get_tree().quit()


func _modal(panel: InfoPanel) -> void:
	overlay_root.add_child(Modal.wrap(panel))
	panel.closed.connect(func(): panel.get_parent().queue_free())
	panel.open()


func _start_game(spec: Dictionary, seed: int) -> void:
	var s := spec.duplicate()
	s["save_id"] = randi() % 1000000  # quick-saves of two characters with one name must not collide
	_begin(Game.new_game(s, seed, db))
	save_path = Saves.path_for(s["name"], s["save_id"])


func _begin(g: Game) -> void:
	var s := GameScreen.new()
	_swap(s)
	s.start(g, art)
	s.extra_modal = func(): return overlay_root.get_children().any(func(c): return c is CenterContainer and c.visible)
	s.menu_requested.connect(_on_menu)
	s.game_over.connect(_on_death)


func _on_menu(action: String) -> void:
	match action:
		"menu_save":
			_save(save_path)
		"menu_save_as":
			var p := SaveAsPanel.new(str(game_screen.game.spec.get("name", "hero")))
			p.named.connect(func(n): _save(Saves.path_for(n)))
			_modal(p)
		"menu_load":
			_open_load()
		"menu_new":
			var c := ConfirmPanel.new("Abandon game in progress?")  # source: exe
			c.confirmed.connect(func(): _on_title("new"))
			_modal(c)
		"menu_quit":
			get_tree().quit()


func _save(path: String) -> void:
	var err := SaveIO.save(game_screen.game, path)
	if err == OK:
		save_path = path
		toast("Game Saved.")  # source: exe
	else:
		toast("Can't write to save file")  # source: exe


func _open_load() -> void:
	var p := LoadPanel.new()
	p.load_requested.connect(func(path):
		var r := SaveIO.load(path, db)
		if not r["ok"]:
			toast(r["error"])
			return
		p.close()
		_begin(r["game"])
		save_path = path
		toast("Loaded %s." % r["game"].spec.get("name", "game")))
	_modal(p)


func _on_death(cause: String) -> void:
	var g := game_screen.game
	var where := g.level.name
	var text := "Killed by %s in %s on turn %d.\n\nPress Esc to return to the title." % [
		("a " + cause) if cause != "" else "misfortune", where, g.turn]
	var p := InfoPanel.new("You have died", text, Vector2(460, 180))
	p.closed.connect(show_title)
	await get_tree().create_timer(0.6).timeout
	_modal(p)


func toast(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GameTheme.ACCENT)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_font_size_override("font_size", 16)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.position.y = 24
	overlay_root.add_child(l)
	var t := l.create_tween()
	t.tween_interval(1.6)
	t.tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)


func _process(_delta: float) -> void:
	_frames += 1
	if options.has("fps") and _frames % 60 == 0:
		print("fps ", Engine.get_frames_per_second())
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
	var click_frame := int(options.get("click-frame", "20"))
	if options.has("hover") and _frames == click_frame - 5:
		var hxy: PackedStringArray = options["hover"].split(",")
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(float(hxy[0]), float(hxy[1]))
		motion.global_position = motion.position
		Input.parse_input_event(motion)
	if options.has("click") and _frames == click_frame:
		var xy: PackedStringArray = options["click"].split(",")
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_RIGHT if options.has("right") else MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = Vector2(float(xy[0]), float(xy[1]))
			click.global_position = click.position
			Input.parse_input_event(click)
	if options.has("screenshot") and _frames == int(options.get("frames", "30")):
		get_viewport().get_texture().get_image().save_png(options["screenshot"])
		get_tree().quit()
