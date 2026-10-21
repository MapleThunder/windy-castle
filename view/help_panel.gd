class_name HelpPanel
extends InfoPanel
## The original help file's topics (data/help.json): a topic list and the selected topic's text.

var topics: Array = []
var list := ItemList.new()


func _init() -> void:
	super("Help", "", Vector2(760, 460))
	topics = JSON.parse_string(FileAccess.get_file_as_string("res://data/help.json"))
	var v: VBoxContainer = get_child(0)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 12)
	v.remove_child(body)
	v.add_child(h)
	v.move_child(h, 1)
	list.custom_minimum_size = Vector2(220, 0)
	for t in topics:
		list.add_item(t["title"])
	list.item_selected.connect(_show)
	h.add_child(list)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(body)
	_show(0)
	list.select(0)


func open() -> void:
	super()
	list.grab_focus()


func _show(i: int) -> void:
	body.text = "[b]%s[/b]\n\n%s" % [topics[i]["title"], topics[i]["text"]]
