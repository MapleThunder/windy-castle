class_name GameScreen
extends Node
## The in-game screen: owns the world view and event player, and turns input into engine actions.

signal menu_requested(action: String)
signal game_over(cause: String)

const DIRS := {
	"move_n": Vector2i(0, -1), "move_ne": Vector2i(1, -1), "move_e": Vector2i(1, 0), "move_se": Vector2i(1, 1),
	"move_s": Vector2i(0, 1), "move_sw": Vector2i(-1, 1), "move_w": Vector2i(-1, 0), "move_nw": Vector2i(-1, -1),
}
const SIMPLE := {"wait": "wait", "search": "search", "rest": "rest", "sleep": "rest", "pickup": "pickup",
	"stairs_up": "stairs_up", "stairs_down": "stairs_down"}
const NEEDS_DIRECTION := {"open": "open", "close": "close"}
const RUN_LIMIT := 60

var game: Game
var world := WorldView.new()
var player := EventPlayer.new()
var hud := Hud.new()
var _queued: Dictionary = {}
var _pending_direction := ""  # "open"/"close" waiting for a direction key
var _running := Vector2i.ZERO


func start(g: Game, art: ArtPack) -> void:
	game = g
	add_child(world)
	add_child(player)
	world.bind(g, art)
	world._fit()
	player.setup(world)
	add_child(hud)
	hud.bind(g)
	world.map_rect = hud.map_rect(world.get_viewport_rect().size)
	world._fit()
	get_viewport().size_changed.connect(func():
		world.map_rect = hud.map_rect(world.get_viewport_rect().size)
		world._fit())
	player.finished.connect(_on_finished)
	player.message_logged.connect(func(_t): hud.refresh())
	player.stats_changed.connect(hud.refresh)
	player.player_died.connect(func(cause): game_over.emit(cause))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or game == null:
		return
	var action := _match(event)
	var run := false
	if action == "" and event is InputEventKey and event.shift_pressed:
		var plain: InputEventKey = event.duplicate()
		plain.shift_pressed = false
		var a := _match(plain)
		if DIRS.has(a):  # source: hlp. Shift + a movement key runs until something stops you.
			action = a
			run = true
	if action == "":
		return
	get_viewport().set_input_as_handled()
	if action.begins_with("menu_"):
		match action:
			"menu_map":
				hud.toggle_minimap()
			"menu_log":
				hud.toggle_full_log()
			_:
				menu_requested.emit(action)
		return
	player.fast = event.is_echo()
	if DIRS.has(action):
		if _pending_direction != "":
			_submit({"type": _pending_direction, "dir": DIRS[action]})
			_pending_direction = ""
		elif run:
			_running = DIRS[action]
			_submit({"type": "move", "dir": _running})
		else:
			_submit({"type": "move", "dir": DIRS[action]})
	elif SIMPLE.has(action):
		_submit({"type": SIMPLE[action]})
	elif NEEDS_DIRECTION.has(action):
		_pending_direction = NEEDS_DIRECTION[action]
		hud.add_transient("Command Pending: %s..." % action.capitalize())  # source: exe


func _match(event: InputEvent) -> String:
	for action in Settings.bindings():
		if InputMap.has_action(action) and event.is_action(action, true):
			return action
	return ""


func _submit(action: Dictionary) -> void:
	if player.is_busy():
		_queued = action  # one buffered action at most
		return
	hud.clear_transient()
	var before := game.visible.duplicate()
	var events := game.perform(action, Settings.options)
	if _running != Vector2i.ZERO and not _keep_running(events):
		_running = Vector2i.ZERO
	player.play(events, before)


func _keep_running(events: Array) -> bool:
	for e in events:
		if e["type"] != "moved" or e["actor_id"] != game.player.id:
			return false
	if events.is_empty():
		return false
	if game.level.actors.any(func(a): return not a.is_player() and game.visible.has(a.pos)):
		return false
	return game.level.items_at(game.player.pos).is_empty()


func _on_finished() -> void:
	hud.refresh()
	if not _queued.is_empty():
		var next := _queued
		_queued = {}
		_submit(next)
	elif _running != Vector2i.ZERO:
		_submit({"type": "move", "dir": _running})
