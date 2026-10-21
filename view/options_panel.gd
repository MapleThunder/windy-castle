class_name OptionsPanel
extends InfoPanel
## Quality-of-life toggles. Each option is independent and saved immediately.

const LABELS := {
	"tooltips": "Item tooltips",
	"vi_keys": "Letter movement keys (h j k l y u b n), as in the original",
	"click_to_move": "Click to move",
	"auto_pickup_gold": "Pick up gold automatically",
	"damage_numbers": "Floating damage numbers",
}

signal rebind_requested


func _init() -> void:
	super("Options", "", Vector2(520, 320))
	var v: VBoxContainer = get_child(0)
	v.remove_child(body)
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(box)
	v.move_child(box, 1)
	for key in LABELS:
		var c := CheckBox.new()
		c.text = LABELS[key]
		c.button_pressed = bool(Settings.get_opt(key))
		c.toggled.connect(func(on):
			Settings.set_opt(key, on)
			Settings.save_to(GameSettings.PATH))
		c.add_theme_color_override("font_color", GameTheme.TEXT)
		box.add_child(c)
	var keys := Button.new()
	keys.text = "Change key bindings…"
	keys.pressed.connect(func(): rebind_requested.emit())
	box.add_child(keys)


func open() -> void:
	super()
	(get_child(0).get_child(1).get_child(0) as Control).grab_focus()
