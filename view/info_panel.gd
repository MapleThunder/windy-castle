class_name InfoPanel
extends PanelContainer
## A titled, scrollable text panel. Esc closes it.

signal closed

var title := Label.new()
var body := RichTextLabel.new()


func _init(heading: String = "", bbcode: String = "", min_size := Vector2(560, 380)) -> void:
	custom_minimum_size = min_size
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	title.text = heading
	GameTheme.heading(title, 20)
	v.add_child(title)
	body.bbcode_enabled = true
	body.text = bbcode
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.focus_mode = Control.FOCUS_ALL
	v.add_child(body)
	var hint := Label.new()
	hint.text = "Esc to close"
	hint.add_theme_color_override("font_color", GameTheme.DIM)
	hint.add_theme_font_size_override("font_size", 16)
	v.add_child(hint)


func open() -> void:
	get_parent().show()
	show()
	if body.is_inside_tree():
		body.grab_focus()


func close() -> void:
	hide()
	get_parent().hide()
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
