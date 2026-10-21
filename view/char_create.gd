class_name CharCreate
extends Control
## Character creation: name, gender, and the four statistics balanced against a pool of points.

signal confirmed(spec: Dictionary)
signal cancelled

const STEP := 5
const NAMES := {"str": "Strength", "int": "Intelligence", "con": "Constitution", "dex": "Dexterity"}

var stats := Character.default_stats()
var gender := "male"
var name_edit := LineEdit.new()
var portrait := TextureRect.new()
var pool_label := Label.new()
var derived_label := Label.new()
var rows := {}  # stat -> [ProgressBar, Label]
var art: ArtPack
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	theme = GameTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art = ArtPack.open([])
	rng.randomize()
	var bg := ColorRect.new()
	bg.color = Color("0c0a12")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Create Character"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GameTheme.ACCENT)
	v.add_child(title)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(portrait)
	var who := VBoxContainer.new()
	name_edit.placeholder_text = "Name"
	name_edit.text = "Hero"
	name_edit.custom_minimum_size = Vector2(240, 0)
	who.add_child(name_edit)
	var genders := HBoxContainer.new()
	for g in [["Son", "male"], ["Daughter", "female"]]:  # source: exe ("son", "daughter")
		var b := Button.new()
		b.text = g[0]
		b.pressed.connect(func():
			gender = g[1]
			_refresh())
		genders.add_child(b)
	who.add_child(genders)
	top.add_child(who)
	v.add_child(top)
	v.add_child(pool_label)
	for k in Character.STATS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = NAMES[k]
		label.custom_minimum_size = Vector2(110, 0)
		row.add_child(label)
		var minus := Button.new()
		minus.text = "−"
		minus.pressed.connect(func(): _move("pool", k, -1))
		row.add_child(minus)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(200, 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", GameTheme.bar_box(GameTheme.ACCENT.darkened(0.2)))
		row.add_child(bar)
		var plus := Button.new()
		plus.text = "+"
		plus.pressed.connect(func(): _move("pool", k, 1))
		row.add_child(plus)
		var value := Label.new()
		value.custom_minimum_size = Vector2(36, 0)
		row.add_child(value)
		rows[k] = [bar, value]
		v.add_child(row)
	derived_label.add_theme_color_override("font_color", GameTheme.DIM)
	v.add_child(derived_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	for a in [["Reroll", _reroll], ["Back", func(): cancelled.emit()], ["Begin", _confirm]]:
		var b := Button.new()
		b.text = a[0]
		b.pressed.connect(a[1])
		actions.add_child(b)
	v.add_child(actions)
	var hint := Label.new()
	hint.text = "Tab moves between controls · Enter presses · Reroll spends the points at random"
	hint.add_theme_color_override("font_color", GameTheme.DIM)
	hint.add_theme_font_size_override("font_size", 11)
	v.add_child(hint)
	_refresh()
	name_edit.grab_focus.call_deferred()


## direction 1 moves STEP points from the pool into the stat; -1 moves them back.
func _move(_pool: String, stat: String, direction: int) -> void:
	stats = Character.adjust(stats, "pool", stat, STEP) if direction > 0 else Character.adjust(stats, stat, "pool", STEP)
	_refresh()


func _reroll() -> void:
	stats = Character.roll(rng)
	_refresh()


func _refresh() -> void:
	portrait.texture = art.texture("player." + gender)
	pool_label.text = "Points to distribute: %d" % int(stats["pool"])
	for k in Character.STATS:
		rows[k][0].value = stats[k]
		rows[k][1].text = str(stats[k])
	var d := Character.derived(stats)
	derived_label.text = "Hit points %d · Mana %d" % [d["max_hp"], d["max_mp"]]


func _confirm() -> void:
	var s := {}
	for k in Character.STATS:
		s[k] = stats[k]
	var who := name_edit.text.strip_edges()
	confirmed.emit({"name": who if who != "" else "Hero", "gender": gender, "stats": s})
