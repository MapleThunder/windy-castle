class_name LoadPanel
extends InfoPanel
## Saved games, newest first. Enter loads the selected one.

signal load_requested(path: String)

var list := ItemList.new()
var _paths: Array = []


func _init() -> void:
	super("Load Saved Game", "", Vector2(520, 340))  # source: exe ("Load Saved Game")
	var v: VBoxContainer = get_child(0)
	v.remove_child(body)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_activated.connect(func(i): load_requested.emit(_paths[i]))
	v.add_child(list)
	v.move_child(list, 1)
	(v.get_child(2) as Label).text = "Enter to load · Esc to close"
	for info in Saves.list():
		if info.has("name"):
			var local := int(info.get("modified", 0)) + int(Time.get_time_zone_from_system()["bias"]) * 60
			var when := Time.get_datetime_string_from_unix_time(local, true)
			var place := "A Tiny Hamlet" if int(info["depth"]) == 0 else "Mine Level %d" % int(info["depth"])
			list.add_item("%s — %s, turn %d — %s" % [info["name"], place, int(info["turn"]), when])
			_paths.append(info["path"])
	if _paths.is_empty():
		list.add_item("No saved games yet.")
		list.set_item_disabled(0, true)


func open() -> void:
	super()
	list.grab_focus()
	if not _paths.is_empty():
		list.select(0)


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.is_pressed() and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		var sel := list.get_selected_items()
		if not sel.is_empty() and sel[0] < _paths.size():
			get_viewport().set_input_as_handled()
			load_requested.emit(_paths[sel[0]])
