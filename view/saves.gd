class_name Saves
extends RefCounted
## Save-file locations and the load list.

const DIR := "user://saves"


## id 0 gives a plain "<name>.json" (Save As); quick-saves pass the character's save_id.
static func path_for(name: String, id: int = 0) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var safe := name.strip_edges().to_lower().replace(" ", "_").validate_filename()
	safe = safe if safe != "" else "hero"
	return "%s/%s.json" % [DIR, safe if id == 0 else "%s_%d" % [safe, id]]


static func list() -> Array:
	var out := []
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			var info := SaveIO.peek(DIR + "/" + f)
			info["path"] = DIR + "/" + f
			out.append(info)
	out.sort_custom(func(a, b): return a.get("modified", 0) > b.get("modified", 0))
	return out
