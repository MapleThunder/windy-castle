class_name RebindPanel
extends InfoPanel
## Every action and its keys. Enter captures a new key for the selected action, Delete clears its keys.

var tree := Tree.new()
var status := Label.new()
var _capturing := ""


func _init() -> void:
	super("Key bindings", "", Vector2(620, 440))
	var v: VBoxContainer = get_child(0)
	v.remove_child(body)
	tree.columns = 2
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.set_column_expand_ratio(0, 3)
	tree.set_column_expand_ratio(1, 2)
	tree.item_activated.connect(_begin_capture)
	v.add_child(tree)
	v.move_child(tree, 1)
	status.add_theme_color_override("font_color", GameTheme.ACCENT)
	v.add_child(status)
	v.move_child(status, 2)
	(v.get_child(3) as Label).text = "Enter: add a key · Delete: clear keys · Esc: close"
	refresh()


func _selected_action() -> String:
	var it := tree.get_selected()
	return it.get_metadata(0) if it != null else ""


func refresh() -> void:
	var keep := _selected_action()
	tree.clear()
	var root := tree.create_item()
	var b := Settings.bindings()
	for group in Menus.GROUP_ORDER:
		for action in Menus.DESCRIPTIONS:
			if Menus.DESCRIPTIONS[action][0] != group or not b.has(action):
				continue
			var it := tree.create_item(root)
			it.set_text(0, Menus.DESCRIPTIONS[action][1])
			it.set_text(1, ", ".join(b[action]))
			it.set_custom_color(1, GameTheme.ACCENT)
			it.set_metadata(0, action)
			if action == keep:
				it.select(0)


func open() -> void:
	super()
	refresh()
	tree.grab_focus()
	if tree.get_selected() == null and tree.get_root().get_child_count() > 0:
		tree.get_root().get_child(0).select(0)


func _begin_capture() -> void:
	_capturing = _selected_action()
	if _capturing != "":
		status.text = "Press a key for %s (Esc cancels)…" % Menus.DESCRIPTIONS[_capturing][1]


func _input(event: InputEvent) -> void:
	# Runs before the GUI so the Tree doesn't eat Enter or the captured key.
	if not visible or not event is InputEventKey or not event.is_pressed():
		return
	var key := event as InputEventKey
	if _capturing == "":
		if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_begin_capture()
			get_viewport().set_input_as_handled()
		return
	if key.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return
	get_viewport().set_input_as_handled()
	if key.keycode == KEY_ESCAPE:
		status.text = "Cancelled."
	else:
		var text := GameSettings.key_string(key)
		var lost: String = Settings.bind(_capturing, text)
		Settings.save_to(GameSettings.PATH)
		status.text = "%s now does: %s." % [text, Menus.DESCRIPTIONS[_capturing][1]]
		if lost != "" and lost != _capturing:
			status.text += " Moved from %s." % Menus.DESCRIPTIONS.get(lost, [lost, lost])[1]
	_capturing = ""
	refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and (event as InputEventKey).keycode == KEY_DELETE:
		var action := _selected_action()
		if action != "":
			for k in Settings.bindings()[action].duplicate():
				Settings.unbind(action, k)
			Settings.save_to(GameSettings.PATH)
			refresh()
		get_viewport().set_input_as_handled()
		return
	super(event)
