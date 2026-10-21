class_name SaveAsPanel
extends InfoPanel
## Ask for a save name. Enter saves, Esc cancels.

signal named(name: String)

var edit := LineEdit.new()


func _init(default_name: String) -> void:
	super("Save As", "", Vector2(420, 150))
	var v: VBoxContainer = get_child(0)
	v.remove_child(body)
	edit.text = default_name
	edit.text_submitted.connect(func(t):
		close()
		named.emit(t))
	v.add_child(edit)
	v.move_child(edit, 1)
	(v.get_child(2) as Label).text = "Enter: save · Esc: cancel"


func open() -> void:
	super()
	edit.grab_focus()
	edit.select_all()
