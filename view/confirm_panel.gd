class_name ConfirmPanel
extends InfoPanel
## A yes/no question: Enter confirms, Esc declines.

signal confirmed


func _init(question: String, detail: String = "") -> void:
	super(question, detail, Vector2(420, 150))
	(get_child(0).get_child(2) as Label).text = "Enter: yes · Esc: no"


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.is_pressed() and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		close()
		confirmed.emit()
