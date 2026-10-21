class_name InventoryPanel
extends PanelContainer
## Paper doll, pack contents and the floor under the player. Drag and drop or keyboard:
## arrows move focus, Enter picks up/places, E equips, D drops, U unequips, Tab switches section, Esc closes.

signal closed

# Paper-doll layout: slot -> position in the doll area (around the silhouette).
const DOLL := {
	"helmet": Vector2(108, 0), "amulet": Vector2(164, 30), "cloak": Vector2(52, 30), "pack": Vector2(216, 0),
	"weapon": Vector2(20, 100), "armor": Vector2(108, 78), "shield": Vector2(196, 100),
	"bracers": Vector2(20, 156), "belt": Vector2(108, 150), "gauntlets": Vector2(196, 156),
	"ring_left": Vector2(52, 212), "purse": Vector2(108, 212), "ring_right": Vector2(164, 212),
	"boots": Vector2(108, 268),
}
const PACK_COLUMNS := 6

var game: Game
var art: ArtPack
var submit: Callable  # func(action: Dictionary) -> Array (events)
var doll := Control.new()
var pack_grid := GridContainer.new()
var floor_row := HBoxContainer.new()
var weight_bar := ProgressBar.new()
var bulk_bar := ProgressBar.new()
var load_label := Label.new()
var _held: ItemSlot = null


func setup(g: Game, a: ArtPack, submit_action: Callable) -> void:
	game = g
	art = a
	submit = submit_action
	custom_minimum_size = Vector2(640, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	add_child(h)
	var left := VBoxContainer.new()
	left.add_child(_title("Equipment"))
	doll.custom_minimum_size = Vector2(260, 320)
	left.add_child(doll)
	h.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	right.add_child(_title("Pack"))
	pack_grid.columns = PACK_COLUMNS
	right.add_child(pack_grid)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	right.add_child(_title("On the ground"))
	right.add_child(floor_row)
	for bar in [weight_bar, bulk_bar]:
		bar.custom_minimum_size = Vector2(0, 10)
		bar.show_percentage = false
		right.add_child(bar)
	load_label.add_theme_color_override("font_color", GameTheme.DIM)
	right.add_child(load_label)
	var hint := Label.new()
	hint.text = "Enter pick up/place · E equip · D drop · U remove · Tab section · Esc close"
	hint.add_theme_color_override("font_color", GameTheme.DIM)
	hint.add_theme_font_size_override("font_size", 11)
	right.add_child(hint)
	h.add_child(right)
	rebuild()


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GameTheme.ACCENT)
	return l


func open() -> void:
	get_parent().show()
	show()
	rebuild()
	_focus_first(pack_grid if pack_grid.get_child_count() > 0 else doll)


func close() -> void:
	_held = null
	hide()
	get_parent().hide()
	closed.emit()


func rebuild() -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focus_key := _key(focused) if focused is ItemSlot else ""
	for c in doll.get_children() + pack_grid.get_children() + floor_row.get_children():
		c.queue_free()
	var silhouette := TextureRect.new()
	silhouette.texture = art.texture("player." + str(game.spec.get("gender", "male")))
	silhouette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	silhouette.position = Vector2(96, 70)
	silhouette.size = Vector2(68, 68)
	silhouette.modulate = Color(1, 1, 1, 0.25)
	doll.add_child(silhouette)
	var inv := game.inventory
	for s in DOLL:
		var b := _slot("equip", inv.equipped[s] if inv.equipped[s] != null else {}, s)
		b.position = DOLL[s]
		if inv.equipped[s] == null:
			b.text = s.replace("_", " ").left(5)
			b.add_theme_font_size_override("font_size", 9)
			b.add_theme_color_override("font_color", GameTheme.DIM)
		doll.add_child(b)
	for it in inv.pack:
		pack_grid.add_child(_slot("pack", it))
	pack_grid.add_child(_slot("pack", {}))  # drop target for "put in pack"
	for it in game.level.items_at(game.player.pos):
		floor_row.add_child(_slot("floor", it))
	floor_row.add_child(_slot("floor", {}))
	_update_load()
	if focus_key != "":
		_refocus.call_deferred(focus_key)


func _slot(area: String, item: Dictionary, slot := "") -> ItemSlot:
	var b := ItemSlot.new()
	b.panel = self
	b.area = area
	b.slot = slot
	b.item = item
	if not item.is_empty():
		b.icon = art.texture(_sprite(item))
		if Settings.get_opt("tooltips"):
			b.tooltip_text = _describe(item)
		if item["qty"] > 1:
			b.text = str(item["qty"])
	b.pressed.connect(func(): _activate(b))
	return b


func _sprite(item: Dictionary) -> String:
	return "item.gold" if item["id"] == "gold" else game.db.item(item["id"])["sprite"]


func _describe(item: Dictionary) -> String:
	if item["id"] == "gold":
		return "%d gold" % int(item["qty"])
	var d := game.db.item(item["id"])
	var lines := [d["name"]]
	if d["damage"] != null:
		lines.append("Weapon class %d (%s)" % [int(d.get("weapon_class", 0)), d["damage"]])
	if int(d["armor"]) > 0:
		lines.append("Armor value %d" % int(d["armor"]))
	lines.append("Weight %d g · Bulk %d cc" % [int(d["weight"]), int(d["bulk"])])
	return "\n".join(lines)


func _update_load() -> void:
	var inv := game.inventory
	var w := inv.total_weight(game.db)
	var wmax := inv.carry_limit()
	var b := inv.total_bulk(game.db)
	var bmax := int(inv.capacity(game.db)["bulk"])
	for pair in [[weight_bar, w, wmax], [bulk_bar, b, bmax]]:
		var bar: ProgressBar = pair[0]
		bar.max_value = maxi(1, pair[2])
		bar.value = pair[1]
		var ratio := float(pair[1]) / maxf(1.0, pair[2])
		var color := GameTheme.HP if ratio >= 1.0 else (GameTheme.ACCENT if ratio > 0.8 else Color("6b9f5a"))
		bar.add_theme_stylebox_override("fill", GameTheme.bar_box(color))
	load_label.text = "Weight %d / %d g    Bulk %d / %d cc    Gold %d" % [w, wmax, b, bmax, inv.gold]


# --- moves -------------------------------------------------------------------------------

func move(from: ItemSlot, to: ItemSlot) -> void:
	var it := from.item
	var uid := int(it.get("uid", 0))
	var steps: Array[Dictionary] = []
	match [from.area, to.area]:
		["pack", "equip"]:
			steps = [{"type": "equip", "uid": uid, "slot": to.slot}]
		["pack", "floor"]:
			steps = [{"type": "drop", "uid": uid}]
		["equip", "pack"]:
			steps = [{"type": "unequip", "slot": from.slot}]
		["equip", "floor"]:
			steps = [{"type": "unequip", "slot": from.slot}, {"type": "drop", "uid": uid}]
		["floor", "pack"]:
			steps = [{"type": "pickup", "uid": uid}]
		["floor", "equip"]:
			steps = [{"type": "pickup", "uid": uid}, {"type": "equip", "uid": uid, "slot": to.slot}]
		["equip", "equip"]:
			steps = [{"type": "unequip", "slot": from.slot}, {"type": "equip", "uid": uid, "slot": to.slot}]
	for step in steps:
		var events: Array = submit.call(step)
		if events.size() == 1 and events[0]["type"] == "message":
			_toast(events[0]["text"])
			break
	_held = null
	rebuild()


func _toast(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GameTheme.ACCENT)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.position = Vector2(20, size.y - 40)
	add_child.call_deferred(l)
	var t := l.create_tween()
	t.tween_interval(1.4)
	t.tween_property(l, "modulate:a", 0.0, 0.4)
	t.tween_callback(l.queue_free)


func natural_slot(item: Dictionary) -> String:
	var s: Variant = game.db.item(item["id"])["slot"]
	if s == "ring":
		return "ring_left" if game.inventory.equipped["ring_left"] == null else "ring_right"
	return s if s != null else ""


# --- keyboard ----------------------------------------------------------------------------

func _activate(b: ItemSlot) -> void:
	if _held == null:
		if not b.item.is_empty():
			_held = b
			b.add_theme_stylebox_override("normal", GameTheme.panel_box(GameTheme.ACCENT))
	elif _held == b:
		_held = null
		rebuild()
	else:
		move(_held, b)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var b: ItemSlot = focused if focused is ItemSlot else null
	var handled := true
	match (event as InputEventKey).keycode:
		KEY_ESCAPE, KEY_I:
			close()
		KEY_TAB:
			_next_section(b)
		KEY_E:
			if b != null and b.area != "equip" and not b.item.is_empty() and natural_slot(b.item) != "":
				var target := ItemSlot.new()
				target.area = "equip"
				target.slot = natural_slot(b.item)
				move(b, target)
		KEY_D:
			if b != null and not b.item.is_empty() and b.area != "floor":
				var target := ItemSlot.new()
				target.area = "floor"
				move(b, target)
		KEY_U:
			if b != null and b.area == "equip" and not b.item.is_empty():
				var target := ItemSlot.new()
				target.area = "pack"
				move(b, target)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _next_section(b: ItemSlot) -> void:
	var order := [doll, pack_grid, floor_row]
	var i := order.find(b.get_parent()) if b != null else -1
	for k in range(1, 4):
		var section: Control = order[(i + k) % order.size()]
		if _focus_first(section):
			return


func _focus_first(section: Control) -> bool:
	for c in section.get_children():
		if c is ItemSlot:
			c.grab_focus()
			return true
	return false


func _key(b: ItemSlot) -> String:
	return "%s:%s:%s" % [b.area, b.slot, str(b.item.get("uid", ""))]


func _refocus(key: String) -> void:
	for section in [doll, pack_grid, floor_row]:
		for c in section.get_children():
			if c is ItemSlot and _key(c) == key and not c.is_queued_for_deletion():
				c.grab_focus()
				return
	_focus_first(pack_grid)
