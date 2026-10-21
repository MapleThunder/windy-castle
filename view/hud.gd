class_name Hud
extends CanvasLayer
## Character panel (left) with the button bar, message log (bottom), minimap (top right), hover tooltip.

signal action_pressed(action: String)

# source: hlp. The original's Button Bar gave one-click access to the common commands.
const BUTTONS := [
	["Get", "pickup"], ["Examine", "examine"], ["Search", "search"], ["Disarm", "disarm"],
	["Rest", "rest"], ["Open", "open"], ["Close", "close"], ["Up", "stairs_up"], ["Down", "stairs_down"],
	["Inventory", "menu_inventory"], ["Character", "menu_character"], ["Map", "menu_map"],
	["Spells", "menu_spellbook"], ["Save", "menu_save"],
]

const PANEL_WIDTH := 240
const LOG_LINES := 5
const LOG_HEIGHT := 112
const MINIMAP_SMALL := Vector2(140, 140)
const MINIMAP_LARGE := Vector2(420, 420)

var game: Game
var root := Control.new()
var name_label := Label.new()
var hp_bar := ProgressBar.new()
var mp_bar := ProgressBar.new()
var stats_label := Label.new()
var place_label := Label.new()
var log_box := VBoxContainer.new()
var minimap := Minimap.new()
var full_log := PanelContainer.new()
var full_log_text := RichTextLabel.new()
var hover := PanelContainer.new()
var hover_label := Label.new()
var _buttons: Dictionary = {}  # action -> Button
var _transient := ""


func _ready() -> void:
	root.theme = GameTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_side_panel()
	_build_log()
	_build_minimap()
	_build_full_log()
	_build_hover()


func _build_side_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_right = PANEL_WIDTH
	panel.clip_contents = true
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	GameTheme.heading(name_label, 20)
	name_label.clip_text = true
	v.add_child(name_label)
	for pair in [[hp_bar, GameTheme.HP], [mp_bar, GameTheme.MP]]:
		var bar: ProgressBar = pair[0]
		bar.custom_minimum_size = Vector2(0, 20)
		bar.add_theme_stylebox_override("fill", GameTheme.bar_box(pair[1]))
		bar.show_percentage = false
		var value := Label.new()
		value.name = "Value"
		value.set_anchors_preset(Control.PRESET_FULL_RECT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 18)
		bar.add_child(value)
		v.add_child(bar)
	v.add_child(_separator())
	stats_label.add_theme_constant_override("line_spacing", 4)
	v.add_child(stats_label)
	v.add_child(_separator())
	place_label.add_theme_color_override("font_color", GameTheme.DIM)
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(place_label)
	v.add_child(_separator())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for b in BUTTONS:
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE  # keep the keyboard on the game
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.custom_minimum_size = Vector2(0, 26)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func(): action_pressed.emit(b[1]))
		_buttons[b[1]] = [button, b[0]]
		grid.add_child(button)
	v.add_child(grid)


func _separator() -> HSeparator:
	var s := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = GameTheme.HIGHLIGHT
	s.add_theme_stylebox_override("separator", line)
	return s


func _build_log() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = PANEL_WIDTH + 8
	panel.offset_right = -8
	panel.offset_top = -LOG_HEIGHT
	panel.offset_bottom = -8
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	log_box.add_theme_constant_override("separation", 1)
	panel.add_child(log_box)
	for i in LOG_LINES:
		var l := Label.new()
		l.clip_text = true
		log_box.add_child(l)


func _build_minimap() -> void:
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	_size_minimap(false)


func _size_minimap(large: bool) -> void:
	var s := MINIMAP_LARGE if large else MINIMAP_SMALL
	minimap.offset_left = -s.x - 8
	minimap.offset_right = -8
	minimap.offset_top = 8
	minimap.offset_bottom = 8 + s.y
	minimap.cell = 6 if large else 2


func toggle_minimap() -> void:
	_size_minimap(minimap.cell == 2)


func _build_full_log() -> void:
	full_log.set_anchors_preset(Control.PRESET_CENTER)
	full_log.custom_minimum_size = Vector2(640, 420)
	full_log.offset_left = -320
	full_log.offset_top = -210
	full_log.hide()
	root.add_child(full_log)
	full_log_text.scroll_following = true
	full_log_text.custom_minimum_size = Vector2(620, 400)
	full_log.add_child(full_log_text)


func _build_hover() -> void:
	hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover.hide()
	hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hover_label.custom_minimum_size = Vector2(260, 0)
	hover_label.add_theme_font_size_override("font_size", 18)
	hover.add_child(hover_label)
	root.add_child(hover)


## Show `text` near the mouse, or hide the tooltip when text is empty.
func show_hover(text: String, at: Vector2) -> void:
	hover.visible = text != ""
	if text == "":
		return
	hover_label.text = text
	hover.reset_size()
	var view := root.get_viewport_rect().size
	hover.position = (at + Vector2(18, 18)).clamp(Vector2.ZERO, view - hover.size)


func toggle_full_log() -> void:
	full_log.visible = not full_log.visible
	if full_log.visible:
		full_log_text.text = "\n".join(game.messages)


## The map viewport is what the HUD leaves uncovered.
func map_rect(viewport: Vector2) -> Rect2:
	return map_rect_for(viewport)


static func map_rect_for(viewport: Vector2) -> Rect2:
	return Rect2(PANEL_WIDTH, 0, maxf(1.0, viewport.x - PANEL_WIDTH), maxf(1.0, viewport.y - LOG_HEIGHT))


func bind(g: Game) -> void:
	game = g
	minimap.game = g
	refresh()


func add_transient(text: String) -> void:
	_transient = text
	_refresh_log()


func refresh() -> void:
	if game == null:
		return
	name_label.text = str(game.spec.get("name", "Hero"))
	var p := game.player
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	hp_bar.get_node("Value").text = "HP %d / %d" % [p.hp, p.max_hp]
	var mp := int(Character.derived(game.stats)["max_mp"])
	mp_bar.max_value = maxi(1, mp)
	mp_bar.value = mp
	mp_bar.get_node("Value").text = "Mana %d / %d" % [mp, mp]
	var s := game.stats
	stats_label.text = "Str %-4d Int %d\nCon %-4d Dex %d\nGold %-3d Armor %d" % [
		int(s["str"]), int(s["int"]), int(s["con"]), int(s["dex"]), game.inventory.gold,
		int(game.player.data["combat"]["armor"])]
	place_label.text = "%s\nTurn %d" % [game.level.name, game.turn]
	var keys := Settings.bindings()
	for action in _buttons:
		var first: Array = keys.get(action, [])
		var hint := " (%s)" % GameSettings.display(first[0]) if not first.is_empty() else ""
		_buttons[action][0].text = _buttons[action][1] + hint
	_refresh_log()


## The last lines of the log, with repeats folded into "text (×n)".
static func collapse(messages: Array, count: int) -> Array:
	var out := []
	var i := messages.size() - 1
	while i >= 0 and out.size() < count:
		var j := i
		while j > 0 and messages[j - 1] == messages[i]:
			j -= 1
		var n := i - j + 1
		out.push_front(messages[i] if n == 1 else "%s (×%d)" % [messages[i], n])
		i = j - 1
	return out


func _refresh_log() -> void:
	var lines := collapse(game.messages, LOG_LINES)
	if _transient != "":
		lines = lines.slice(1) if lines.size() >= LOG_LINES else lines
		lines.append(_transient)
	for i in LOG_LINES:
		var label: Label = log_box.get_child(i)
		var j := i - (LOG_LINES - lines.size())
		label.text = lines[j] if j >= 0 else ""
		var age := LOG_LINES - 1 - i
		label.add_theme_color_override("font_color", GameTheme.TEXT if age == 0 else GameTheme.DIM.lerp(GameTheme.TEXT, 0.6 - age * 0.15))


func clear_transient() -> void:
	_transient = ""
