class_name GameSettings
extends Node
## Autoload "Settings": QoL options and key bindings, saved to user://settings.json.

const DEFAULTS := "res://settings/defaults.json"
const PATH := "user://settings.json"

var options: Dictionary = {}
var _bindings: Dictionary = {}  # action -> Array of key strings
var _vi: Dictionary = {}


func _ready() -> void:
	load_from(PATH)
	apply()


func _defaults() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS))


func load_from(path: String) -> void:
	var d := _defaults()
	options = d["options"].duplicate()
	_bindings = d["bindings"].duplicate(true)
	_vi = d["vi_bindings"].duplicate(true)
	if not FileAccess.file_exists(path):
		return
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not saved is Dictionary:
		push_warning("settings file %s is unreadable; using defaults" % path)
		return
	for k in saved.get("options", {}):
		if options.has(k):
			options[k] = saved["options"][k]
	for action in saved.get("bindings", {}):
		if _bindings.has(action):
			_bindings[action] = saved["bindings"][action]


func save_to(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"options": options, "bindings": _bindings}, "\t"))


func get_opt(name: String) -> Variant:
	return options.get(name)


func set_opt(name: String, value: Variant) -> void:
	options[name] = value
	apply()


func bindings() -> Dictionary:
	var out := _bindings.duplicate(true)
	if options.get("vi_keys", false):
		for action in _vi:
			out[action] = out.get(action, []) + _vi[action]
	return out


## Bind `key` to `action`, removing it from any other action. Returns the action that lost it, or "".
func bind(action: String, key: String) -> String:
	var lost := ""
	for other in _bindings:
		if other != action and key in _bindings[other]:
			_bindings[other].erase(key)
			lost = other
	if not key in _bindings[action]:
		_bindings[action].append(key)
	apply()
	return lost


func unbind(action: String, key: String) -> void:
	_bindings[action].erase(key)
	apply()


func apply() -> void:
	for action in bindings():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for key in bindings()[action]:
			InputMap.action_add_event(action, parse_key(key))


static func parse_key(text: String) -> InputEventKey:
	var ev := InputEventKey.new()
	var parts := text.split("+")
	for mod in parts.slice(0, parts.size() - 1):
		match mod.to_lower():
			"ctrl":
				ev.ctrl_pressed = true
			"shift":
				ev.shift_pressed = true
			"alt":
				ev.alt_pressed = true
	ev.keycode = OS.find_keycode_from_string(parts[-1])
	return ev


static func key_string(ev: InputEventKey) -> String:
	var mods := ""
	if ev.ctrl_pressed:
		mods += "Ctrl+"
	if ev.shift_pressed:
		mods += "Shift+"
	if ev.alt_pressed:
		mods += "Alt+"
	return mods + OS.get_keycode_string(ev.keycode)
