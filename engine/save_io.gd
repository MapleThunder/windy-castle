class_name SaveIO
extends RefCounted
## Versioned, atomic save files: {"version": VERSION, "game": Game.to_dict()}.

const VERSION := 1


static func save(game: Game, path: String) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": VERSION, "game": game.to_dict()}))
	f.close()
	return DirAccess.rename_absolute(tmp, path)


static func load(path: String, db: GameData) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "No saved game at %s." % path}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.has("game") or not parsed["game"] is Dictionary:
		return {"ok": false, "error": "The save file is corrupt."}
	if int(parsed.get("version", -1)) != VERSION:
		return {"ok": false, "error": "The save file is from an unsupported version (%s)." % str(parsed.get("version"))}
	var game: Dictionary = parsed["game"]
	for key in Game.SAVE_KEYS:
		if not game.has(key):
			return {"ok": false, "error": "The save file is corrupt (missing %s)." % key}
	return {"ok": true, "game": Game.from_dict(game, db)}


static func peek(path: String) -> Dictionary:
	## Summary for a load menu without building the whole game.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("game") is Dictionary:
		return {}
	var g: Dictionary = parsed["game"]
	return {"name": g.get("spec", {}).get("name", "?"), "depth": int(g.get("depth", 0)), "turn": int(g.get("turn", 0)),
		"modified": FileAccess.get_modified_time(path)}
