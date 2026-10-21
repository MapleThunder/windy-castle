extends TestCase

const SettingsScript := preload("res://view/settings.gd")


func _fresh() -> Node:
	var s: Node = SettingsScript.new()
	s.load_from("user://does_not_exist_settings.json")
	return s


func test_defaults_load() -> void:
	var s := _fresh()
	assert_eq(s.get_opt("vi_keys"), true, "original movement keys on by default")
	assert_eq(s.get_opt("auto_pickup_gold"), true)
	assert_has(s.bindings(), "move_n")
	assert_has(s.bindings()["search"], "s")
	s.free()


func test_applies_to_input_map() -> void:
	var s := _fresh()
	s.apply()
	assert_true(InputMap.has_action("move_n"))
	var ev := GameSettings.parse_key("Kp 8")
	assert_true(InputMap.action_has_event("move_n", ev))
	assert_true(InputMap.action_has_event("move_n", GameSettings.parse_key("k")), "vi key active")
	s.free()


func test_parse_key_modifiers() -> void:
	var ev := GameSettings.parse_key("Ctrl+Shift+s")
	assert_eq(ev.keycode, KEY_S)
	assert_true(ev.ctrl_pressed)
	assert_true(ev.shift_pressed)
	assert_eq(GameSettings.key_string(ev), "Ctrl+Shift+S")
	assert_eq(GameSettings.parse_key("Kp 8").keycode, KEY_KP_8)
