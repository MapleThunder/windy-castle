class_name ArtPack
extends RefCounted
## Looks up sprites by semantic name ("monster.kobold") across art packs.
## A pack is a folder with manifest.json ({"tile_size", "sprites": {name: relative png path}}).
## Earlier packs win, and the original art is always the last fallback.

const ORIGINAL := "res://assets/original"

var packs: Array[Dictionary] = []  # [{"dir", "sprites"}]
var cache: Dictionary = {}
var warned: Dictionary = {}
var _size := 32


static func open(dirs: Array) -> ArtPack:
	var art := ArtPack.new()
	for dir in dirs + [ORIGINAL]:
		var text := FileAccess.get_file_as_string(dir + "/manifest.json")
		var m: Variant = JSON.parse_string(text) if text != "" else null
		if not m is Dictionary:
			push_warning("art pack %s has no readable manifest.json" % dir)
			continue
		art.packs.append({"dir": dir, "sprites": m["sprites"]})
		if dir == ORIGINAL:
			art._size = int(m["tile_size"])
	return art


func tile_size() -> int:
	return _size


func has(name: String) -> bool:
	return packs.any(func(p): return p["sprites"].has(name))


func texture(name: String) -> Texture2D:
	if cache.has(name):
		return cache[name]
	var tex: Texture2D = null
	for p in packs:
		if p["sprites"].has(name):
			tex = _load(p["dir"] + "/" + p["sprites"][name])
			if tex != null:
				break
	if tex == null:
		if not warned.has(name):
			warned[name] = true
			push_warning("missing sprite: " + name)
		var img := Image.create(_size, _size, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		tex = ImageTexture.create_from_image(img)
	cache[name] = tex
	return tex


static func _load(path: String) -> Texture2D:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		return load(path)
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img != null else null
