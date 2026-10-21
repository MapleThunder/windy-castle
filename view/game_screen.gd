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
const NOT_YET := {"examine": "Examine", "disarm": "Disarm Trap", "free_hand": "Free Hand", "view": "View"}
const ROUTED := ["menu_new", "menu_load", "menu_save", "menu_save_as", "menu_quit"]

var game: Game
var world := WorldView.new()
var player := EventPlayer.new()
var hud := Hud.new()
var inventory := InventoryPanel.new()
var _modals: Array[Control] = []
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
	_add_modal(inventory)
	inventory.setup(g, art, _submit_now)
	inventory.close()
	player.finished.connect(_on_finished)
	player.message_logged.connect(func(_t): hud.refresh())
	player.stats_changed.connect(hud.refresh)
	player.player_died.connect(func(cause): game_over.emit(cause))


## Panels open over a full-screen dimmed backdrop that centres them.
func _add_modal(panel: Control) -> void:
	hud.root.add_child(Modal.wrap(panel))
	_modals.append(panel)


func open_panel(panel: Control) -> void:
	if not panel in _modals:
		_add_modal(panel)
		if panel is InfoPanel:
			panel.closed.connect(func(): _drop_modal(panel))
	panel.open()


func _drop_modal(panel: Control) -> void:
	if panel == inventory:
		return
	_modals.erase(panel)
	panel.get_parent().queue_free()


func modal_open() -> bool:
	return _modals.any(func(m): return m.visible)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or game == null or game.dead or modal_open():
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
		dispatch_menu(action)
		return
	if NOT_YET.has(action):
		hud.add_transient("%s isn't in this version yet." % NOT_YET[action])
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


func dispatch_menu(action: String) -> void:
	match action:
		"menu_map":
			hud.toggle_minimap()
		"menu_log":
			hud.toggle_full_log()
		"menu_inventory":
			open_panel(inventory)
		"menu_character":
			open_panel(InfoPanel.new("Character", _character_sheet()))
		"menu_story":
			var story: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
			open_panel(InfoPanel.new("The Story So Far", story[0]["text"]))
		"menu_spellbook", "menu_activate":
			open_panel(InfoPanel.new("Not yet", "Spells and item activation arrive in a later version.", Vector2(420, 160)))
		"menu_help":
			open_panel(HelpPanel.new())
		"menu_keys":
			open_panel(InfoPanel.new("Keyboard Commands", cheat_sheet(), Vector2(620, 460)))
		"menu_rebind":
			open_panel(RebindPanel.new())
		"menu_options":
			var o := OptionsPanel.new()
			o.rebind_requested.connect(func():
				o.close()
				dispatch_menu("menu_rebind"))
			open_panel(o)
		_:
			if action in ROUTED:
				menu_requested.emit(action)


func _character_sheet() -> String:
	var s := game.stats
	var c: Dictionary = game.player.data["combat"]
	var inv := game.inventory
	return ("[b]%s[/b]\n\nStrength %d\nIntelligence %d\nConstitution %d\nDexterity %d\n\n" +
		"Hit points %d / %d\nArmor value %d\nPlus to hit %d\nPlus to damage %d\nWeapon damage %s\n\n" +
		"Gold %d\nCarrying %d / %d g") % [game.spec.get("name", "Hero"), int(s["str"]), int(s["int"]),
		int(s["con"]), int(s["dex"]), game.player.hp, game.player.max_hp, int(c["armor"]), int(c["to_hit"]),
		int(c["damage_bonus"]), c["damage"], inv.gold, inv.total_weight(game.db), inv.carry_limit()]


## Generated from the live bindings, grouped like the original's menus.
static func cheat_sheet() -> String:
	var b := Settings.bindings()
	var out := ""
	for group in Menus.GROUP_ORDER:
		var rows := ""
		for action in Menus.DESCRIPTIONS:
			if Menus.DESCRIPTIONS[action][0] == group and b.has(action) and not b[action].is_empty():
				rows += "[cell]%s[/cell][cell][color=#e0a050]%s[/color][/cell]" % [Menus.DESCRIPTIONS[action][1], ", ".join(b[action])]
		if rows != "":
			out += "[b]%s[/b]\n[table=2]%s[/table]\n\n" % [group, rows]
	return out


## Run one action from a panel: the turn passes and monsters act, so play the events too.
func _submit_now(action: Dictionary) -> Array:
	var before := game.visible.duplicate()
	var events := game.perform(action, Settings.options)
	player.play(events, before)
	return events


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
