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
	_bindings = _canon_all(d["bindings"])
	_vi = _canon_all(d["vi_bindings"])
	if not FileAccess.file_exists(path):
		return
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not saved is Dictionary:
		push_warning("settings file %s is unreadable; using defaults" % path)
		return
	for k in saved.get("options", {}):
		if options.has(k):
			options[k] = saved["options"][k]
	var saved_keys := _canon_all(saved.get("bindings", {}))
	for action in saved_keys:
		if _bindings.has(action):
			_bindings[action] = saved_keys[action]
	var saved_vi := _canon_all(saved.get("vi_bindings", {}))
	for action in saved_vi:
		if _vi.has(action):
			_vi[action] = saved_vi[action]


func save_to(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"options": options, "bindings": _bindings, "vi_bindings": _vi}, "\t"))


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
	key = canon(key)
	var lost := ""
	for other in _bindings:
		if other != action and key in _bindings[other]:
			_bindings[other].erase(key)
			lost = other
	for other in _vi:
		if key in _vi[other]:
			_vi[other].erase(key)
			lost = other if other != action else lost
	if not key in _bindings[action]:
		_bindings[action].append(key)
	apply()
	return lost


func unbind(action: String, key: String) -> void:
	key = canon(key)
	_bindings[action].erase(key)
	if _vi.has(action):
		_vi[action].erase(key)
	apply()


func apply() -> void:
	for action in bindings():
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for key in bindings()[action]:
			InputMap.action_add_event(action, parse_key(key))


## One spelling per key ("s" and "S" are both "S"), so bindings compare reliably.
static func canon(text: String) -> String:
	return key_string(parse_key(text))


static func _canon_all(d: Dictionary) -> Dictionary:
	var out := {}
	for action in d:
		out[action] = d[action].map(canon)
	return out


## How a key is shown to the player: plain letters in lower case, as the original's help does.
static func display(text: String) -> String:
	var parts := text.split("+")
	var last := parts[-1]
	if last.length() == 1 and parts.size() == 1:
		return last.to_lower()
	if last.length() == 1 and parts.size() == 2 and parts[0] == "Shift":
		return last.to_upper()
	return text


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
