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


func test_rebind_conflict_moves_key() -> void:
	var s := _fresh()
	assert_eq(s.bind("pickup", "s"), "search")
	assert_false("s" in s.bindings()["search"])
	assert_has(s.bindings()["pickup"], "s")
	assert_eq(s.bind("pickup", "s"), "", "binding again is a no-op")
	s.free()


func test_corrupt_settings_falls_back_to_defaults() -> void:
	var path := "user://corrupt_settings.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var s: Node = SettingsScript.new()
	s.load_from(path)
	assert_eq(s.get_opt("vi_keys"), true)
	assert_has(s.bindings()["search"], "s")
	s.free()


func test_unknown_saved_entries_ignored() -> void:
	var path := "user://odd_settings.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"options": {"bogus": 1, "tooltips": false}, "bindings": {"nope": ["q"]}}))
	f.close()
	var s: Node = SettingsScript.new()
	s.load_from(path)
	assert_eq(s.get_opt("tooltips"), false)
	assert_false(s.options.has("bogus"))
	assert_false(s.bindings().has("nope"))
	s.free()


func test_vi_keys_toggle() -> void:
	var s := _fresh()
	assert_has(s.bindings()["move_n"], "k")
	s.options["vi_keys"] = false
	assert_false("k" in s.bindings()["move_n"])
	assert_has(s.bindings()["move_n"], "Kp 8")
	s.free()


func test_roundtrip() -> void:
	var path := "user://roundtrip_settings.json"
	var s := _fresh()
	s.options["damage_numbers"] = false
	s.bind("search", "F5")
	s.save_to(path)
	var t: Node = SettingsScript.new()
	t.load_from(path)
	assert_eq(t.get_opt("damage_numbers"), false)
	assert_has(t.bindings()["search"], "F5")
	s.free()
	t.free()


func test_every_menu_item_has_action() -> void:
	var menus: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/menus.json"))
	var s := _fresh()
	var missing := []
	for menu in menus:
		for label in _labels(menu["items"]):
			var target: Variant = Menus.ITEMS.get(label)
			if target == null:
				missing.append(label)
			elif target is String and target.begins_with("n/a"):
				assert_true(target.length() > 5, "%s needs a reason" % label)
			elif not s.bindings().has(target):
				fail("%s maps to unbound action %s" % [label, target])
	assert_eq(missing, [])
	s.free()


func _labels(items: Array) -> Array:
	var out := []
	for it in items:
		if it.get("separator", false):
			continue
		if it.has("items") and not it["items"].is_empty():
			out.append_array(_labels(it["items"]))
		else:
			out.append(it["label"])
	return out
