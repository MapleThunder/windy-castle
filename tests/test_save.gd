extends TestCase

const F := preload("res://tests/game_fixtures.gd")
const DIR := "user://test_saves"


func _path(name: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	return "%s/%s.json" % [DIR, name]


func _script() -> Array:
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, -1)]
	var out := []
	for i in 20:
		out.append({"type": "move", "dir": dirs[i % dirs.size()]} if i % 4 != 3 else {"type": "search"})
	return out


func test_roundtrip_identical_future() -> void:
	var db := GameData.load_default()
	var g := F.new_game(21)
	var entrance := Vector2i(int(Town.spec()["mine_entrance"][0]), int(Town.spec()["mine_entrance"][1]))
	g.enter_level(g.level, entrance)
	g.perform({"type": "stairs_down"})
	g.perform({"type": "wait"})
	var path := _path("roundtrip")
	assert_eq(SaveIO.save(g, path), OK)
	var loaded := SaveIO.load(path, db)
	assert_true(loaded["ok"], str(loaded.get("error", "")))
	var h: Game = loaded["game"]
	assert_eq(h.level.depth, 1)
	assert_eq(h.player.pos, g.player.pos)
	assert_eq(h.turn, g.turn)
	assert_eq(h.levels.size(), g.levels.size())
	assert_true(h.level.actors.has(h.player))
	for action in _script():
		assert_eq(var_to_str(h.perform(action)), var_to_str(g.perform(action)))
	assert_eq(h.player.hp, g.player.hp)


func test_inventory_and_messages_survive() -> void:
	var db := GameData.load_default()
	var g := F.new_game(2)
	g.inventory.gold = 42
	var path := _path("inv")
	SaveIO.save(g, path)
	var h: Game = SaveIO.load(path, db)["game"]
	assert_eq(h.inventory.gold, 42)
	assert_eq(h.inventory.equipped["weapon"]["id"], "dagger")
	assert_eq(h.messages, g.messages)
	assert_eq(h.spec["name"], "Tester")
	assert_eq(h.player.data["combat"], g.player.data["combat"])


func test_missing_file() -> void:
	var r := SaveIO.load(_path("does_not_exist"), GameData.load_default())
	assert_false(r["ok"])
	assert_true(r["error"].length() > 0)


func test_corrupt_json() -> void:
	var path := _path("corrupt")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var r := SaveIO.load(path, GameData.load_default())
	assert_false(r["ok"])
	assert_has(r["error"], "corrupt")


func test_wrong_version() -> void:
	var path := _path("version")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 999, "game": {}}))
	f.close()
	var r := SaveIO.load(path, GameData.load_default())
	assert_false(r["ok"])
	assert_has(r["error"], "version")


func test_truncated_game_data() -> void:
	var path := _path("truncated")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": SaveIO.VERSION, "game": {"turn": 3}}))
	f.close()
	var r := SaveIO.load(path, GameData.load_default())
	assert_false(r["ok"])


func test_atomic_no_tmp_left() -> void:
	var path := _path("atomic")
	SaveIO.save(F.new_game(), path)
	assert_true(FileAccess.file_exists(path))
	assert_false(FileAccess.file_exists(path + ".tmp"))
