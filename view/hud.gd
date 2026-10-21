class_name Hud
extends CanvasLayer
## Character panel (left), message log (bottom) and minimap (top right).

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


func _build_side_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_right = PANEL_WIDTH
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", GameTheme.ACCENT)
	v.add_child(name_label)
	v.add_child(_separator())
	for pair in [[hp_bar, GameTheme.HP, "HP"], [mp_bar, GameTheme.MP, "Mana"]]:
		var bar: ProgressBar = pair[0]
		var cap := Label.new()
		cap.text = pair[2]
		cap.add_theme_color_override("font_color", GameTheme.DIM)
		v.add_child(cap)
		bar.custom_minimum_size = Vector2(0, 18)
		bar.add_theme_stylebox_override("fill", GameTheme.bar_box(pair[1]))
		bar.show_percentage = false
		var value := Label.new()
		value.name = "Value"
		value.set_anchors_preset(Control.PRESET_FULL_RECT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.add_theme_font_size_override("font_size", 12)
		bar.add_child(value)
		v.add_child(bar)
	v.add_child(_separator())
	stats_label.add_theme_constant_override("line_spacing", 4)
	v.add_child(stats_label)
	v.add_child(_separator())
	place_label.add_theme_color_override("font_color", GameTheme.DIM)
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(place_label)


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


func toggle_full_log() -> void:
	full_log.visible = not full_log.visible
	if full_log.visible:
		full_log_text.text = "\n".join(game.messages)


## The map viewport is what the HUD leaves uncovered.
func map_rect(viewport: Vector2) -> Rect2:
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
	hp_bar.get_node("Value").text = "%d / %d" % [p.hp, p.max_hp]
	var mp := int(Character.derived(game.stats)["max_mp"])
	mp_bar.max_value = maxi(1, mp)
	mp_bar.value = mp
	mp_bar.get_node("Value").text = "%d / %d" % [mp, mp]
	var s := game.stats
	stats_label.text = "Str  %d\nInt  %d\nCon  %d\nDex  %d\n\nGold  %d\nArmor  %d" % [
		int(s["str"]), int(s["int"]), int(s["con"]), int(s["dex"]), game.inventory.gold,
		int(game.player.data["combat"]["armor"])]
	place_label.text = "%s\nTurn %d" % [game.level.name, game.turn]
	_refresh_log()


func _refresh_log() -> void:
	var lines := game.messages.slice(maxi(0, game.messages.size() - LOG_LINES))
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
