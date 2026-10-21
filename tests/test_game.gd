extends TestCase

const F := preload("res://tests/game_fixtures.gd")


func test_new_game_in_town() -> void:
	var g := F.new_game()
	assert_eq(g.level.depth, 0)
	assert_eq(g.player.pos, Town.player_start())
	assert_true(g.visible.has(g.player.pos))
	assert_true(g.level.is_explored(g.player.pos))
	assert_eq(g.turn, 0)
	assert_true(g.level.actors.has(g.player))


func test_move_into_wall_no_turn() -> void:
	var g := F.new_game()
	F.in_room(g, 3, 3, Vector2i(1, 1))
	var ev := g.perform({"type": "move", "dir": Vector2i(-1, 0)})
	assert_eq(F.types(ev), ["message"])
	assert_eq(g.turn, 0)
	assert_eq(g.player.pos, Vector2i(1, 1))


func test_move_advances_turn() -> void:
	var g := F.new_game()
	F.in_room(g, 3, 3, Vector2i(1, 1))
	var ev := g.perform({"type": "move", "dir": Vector2i(1, 1)})
	assert_has(F.types(ev), "moved")
	assert_eq(g.player.pos, Vector2i(2, 2))
	assert_eq(g.turn, 1)


func test_invalid_action_type() -> void:
	var g := F.new_game()
	assert_eq(F.types(g.perform({"type": "dance"})), ["message"])
	assert_eq(g.turn, 0)


func test_bump_attacks() -> void:
	var g := F.new_game()
	F.in_room(g, 5, 1, Vector2i(1, 1))
	var m := F.monster(g, "kobold", Vector2i(2, 1), 500)
	var ev := g.perform({"type": "move", "dir": Vector2i(1, 0)})
	var t := F.types(ev)
	assert_true("attacked" in t or "missed" in t)
	assert_eq(ev[0]["attacker_id"], g.player.id)
	assert_eq(ev[0]["target_id"], m.id)
	assert_eq(g.player.pos, Vector2i(1, 1), "attacking does not move")


func test_kill_removes_monster() -> void:
	var g := F.new_game()
	F.in_room(g, 5, 1, Vector2i(1, 1))
	var m := F.monster(g, "kobold", Vector2i(2, 1), 1)
	var died := false
	for i in 40:
		var ev := g.perform({"type": "move", "dir": Vector2i(1, 0)})
		if "died" in F.types(ev):
			died = true
			break
	assert_true(died)
	assert_false(g.level.actors.has(m))


func test_bump_opens_door() -> void:
	var g := F.new_game()
	var l := F.in_room(g, 5, 1, Vector2i(1, 1))
	l.set_tile(Vector2i(2, 1), Tile.T.DOOR_CLOSED)
	var ev := g.perform({"type": "move", "dir": Vector2i(1, 0)})
	assert_has(F.types(ev), "door_opened")
	assert_eq(l.get_tile(Vector2i(2, 1)), Tile.T.DOOR_OPEN)
	assert_eq(g.player.pos, Vector2i(1, 1))


func test_close_door() -> void:
	var g := F.new_game()
	var l := F.in_room(g, 5, 1, Vector2i(1, 1))
	l.set_tile(Vector2i(2, 1), Tile.T.DOOR_OPEN)
	assert_has(F.types(g.perform({"type": "close", "dir": Vector2i(1, 0)})), "door_closed")
	assert_eq(l.get_tile(Vector2i(2, 1)), Tile.T.DOOR_CLOSED)


func test_search_finds_secret() -> void:
	var g := F.new_game(5)
	var l := F.in_room(g, 3, 3, Vector2i(1, 1))
	l.set_tile(Vector2i(0, 1), Tile.T.SECRET_DOOR)
	var found := false
	for i in 30:
		if "secret_found" in F.types(g.perform({"type": "search"})):
			found = true
			break
	assert_true(found)
	assert_eq(l.get_tile(Vector2i(0, 1)), Tile.T.DOOR_CLOSED)


func test_bump_building_shows_sign() -> void:
	var g := F.new_game()
	var store: Vector2i
	for p in g.level.signs:
		if g.level.signs[p] == "Gunnhild's General Store":
			store = p
	var below := store + Vector2i(0, 1)
	while g.level.signs.has(below):
		below += Vector2i(0, 1)
	g.enter_level(g.level, below)
	var ev := g.perform({"type": "move", "dir": Vector2i(0, -1)})
	assert_eq(F.types(ev), ["message"])
	assert_true("Gunnhild" in ev[0]["text"])


func test_pickup_and_drop() -> void:
	var g := F.new_game()
	var l := F.in_room(g, 3, 3, Vector2i(1, 1))
	l.floor_items[Vector2i(1, 1)] = [g.new_item("club")]
	var ev := g.perform({"type": "pickup"})
	assert_has(F.types(ev), "item_picked")
	assert_false(l.floor_items.has(Vector2i(1, 1)))
	var uid: int = ev[0]["uid"]
	assert_true(g.inventory.find(uid) >= 0)
	assert_has(F.types(g.perform({"type": "drop", "uid": uid})), "item_dropped")
	assert_eq(l.items_at(Vector2i(1, 1))[0]["uid"], uid)


func test_pickup_single_uid() -> void:
	var g := F.new_game()
	var l := F.in_room(g, 3, 3, Vector2i(1, 1))
	var club := g.new_item("club")
	var dagger := g.new_item("dagger")
	l.floor_items[Vector2i(1, 1)] = [club, dagger]
	var ev := g.perform({"type": "pickup", "uid": dagger["uid"]})
	assert_has(F.types(ev), "item_picked")
	assert_eq(l.items_at(Vector2i(1, 1)).map(func(it): return it["uid"]), [club["uid"]])
	assert_true(g.inventory.find(dagger["uid"]) >= 0)


func test_pickup_nothing_no_turn() -> void:
	var g := F.new_game()
	F.in_room(g, 3, 3, Vector2i(1, 1))
	assert_eq(F.types(g.perform({"type": "pickup"})), ["message"])
	assert_eq(g.turn, 0)


func test_auto_pickup_gold_option() -> void:
	var g := F.new_game()
	var l := F.in_room(g, 3, 1, Vector2i(1, 1))
	l.floor_items[Vector2i(2, 1)] = [g.new_item("gold", 7)]
	var ev := g.perform({"type": "move", "dir": Vector2i(1, 0)}, {"auto_pickup_gold": true})
	assert_has(F.types(ev), "gold_picked")
	assert_eq(g.inventory.gold, 7)
	l.floor_items[Vector2i(3, 1)] = [g.new_item("gold", 2)]
	g.perform({"type": "move", "dir": Vector2i(1, 0)}, {"auto_pickup_gold": false})
	assert_eq(g.inventory.gold, 7)


func test_equip_refreshes_combat() -> void:
	var g := F.new_game()
	F.in_room(g, 3, 3, Vector2i(1, 1))
	var club := g.new_item("club")
	g.inventory.pack.append(club)
	var ev := g.perform({"type": "equip", "uid": club["uid"], "slot": "weapon"})
	assert_has(F.types(ev), "stats_changed")
	assert_eq(g.player.data["combat"]["damage"], GameData.load_default().item("club")["damage"])


func test_equip_rejected_no_turn() -> void:
	var g := F.new_game()
	F.in_room(g, 3, 3, Vector2i(1, 1))
	var club := g.new_item("club")
	g.inventory.pack.append(club)
	assert_eq(F.types(g.perform({"type": "equip", "uid": club["uid"], "slot": "helmet"})), ["message"])
	assert_eq(g.turn, 0)


func test_stairs_roundtrip_persists_level() -> void:
	var g := F.new_game(3)
	var entrance := Town.mine_arrival()
	g.enter_level(g.level, entrance)
	var ev := g.perform({"type": "stairs_down"})
	assert_has(F.types(ev), "level_changed")
	assert_eq(g.level.depth, 1)
	assert_eq(g.level.get_tile(g.player.pos), Tile.T.STAIRS_UP)
	var victim: Actor = g.level.actors.filter(func(a): return not a.is_player())[0]
	var victim_id := victim.id
	g.level.actors.erase(victim)
	g.perform({"type": "stairs_up"})
	assert_eq(g.level.depth, 0)
	assert_eq(g.player.pos, entrance)
	g.perform({"type": "stairs_down"})
	assert_eq(g.level.depth, 1)
	assert_false(g.level.actors.any(func(a): return a.id == victim_id), "dead monster stays dead")


func test_walking_into_the_gate_goes_to_the_mine() -> void:
	var g := F.new_game()
	g.enter_level(g.level, Town.mine_arrival())
	var ev := g.perform({"type": "move", "dir": Vector2i(0, -1)})
	assert_has(F.types(ev), "level_changed")
	assert_eq(g.level.depth, 1)
	g.perform({"type": "stairs_up"})
	assert_eq(g.level.depth, 0)
	assert_eq(g.player.pos, Town.mine_arrival())


func test_stepping_onto_stairs_hints_the_key() -> void:
	var g := F.new_game()
	var l := F.in_room(g, 3, 1, Vector2i(1, 1))
	l.set_tile(Vector2i(2, 1), Tile.T.STAIRS_DOWN)
	var ev := g.perform({"type": "move", "dir": Vector2i(1, 0)})
	var texts := ev.filter(func(e): return e["type"] == "message").map(func(e): return e["text"])
	assert_true(texts.any(func(t): return "stairs" in t.to_lower() and ">" in t), str(texts))


func test_examine_sign_and_monster() -> void:
	var g := F.new_game()
	var sign_pos: Vector2i = g.level.features.keys()[0]
	g.visible[sign_pos] = true
	var ev := g.perform({"type": "examine", "pos": sign_pos})
	assert_eq(F.types(ev), ["message"])
	assert_true(ev[0]["text"].begins_with("A sign that says:"))
	assert_eq(g.turn, 0, "examining is free")
	F.in_room(g, 3, 1, Vector2i(1, 1))
	F.monster(g, "kobold", Vector2i(2, 1))
	assert_true("Kobold" in g.perform({"type": "examine", "pos": Vector2i(2, 1)})[0]["text"])


func test_examine_unseen_tile() -> void:
	var g := F.new_game()
	F.in_room(g, 3, 1, Vector2i(1, 1))
	assert_eq(g.perform({"type": "examine", "pos": Vector2i(40, 40)})[0]["text"], "You can't see that from here.")


func test_stairs_down_requires_stairs() -> void:
	var g := F.new_game()
	F.in_room(g, 3, 3, Vector2i(1, 1))
	assert_eq(F.types(g.perform({"type": "stairs_down"})), ["message"])


func test_ids_unique_after_level_change() -> void:
	var g := F.new_game(8)
	g.enter_level(g.level, Town.mine_arrival())
	g.perform({"type": "stairs_down"})
	var ids := {}
	for a in g.level.actors:
		assert_false(ids.has(a.id), "duplicate actor id %d" % a.id)
		ids[a.id] = true
	var uids := {}
	for p in g.level.floor_items:
		for it in g.level.floor_items[p]:
			assert_true(int(it["uid"]) > 0)
			assert_false(uids.has(it["uid"]))
			uids[it["uid"]] = true


func test_player_death_event() -> void:
	var g := F.new_game(2)
	F.in_room(g, 3, 1, Vector2i(1, 1))
	g.player.hp = 1
	var m := F.monster(g, "gray_wolf", Vector2i(2, 1), 500)
	m.data["ai"] = "chase"
	var died := false
	for i in 200:
		if "player_died" in F.types(g.perform({"type": "wait"})):
			died = true
			break
	assert_true(died)
	assert_true(g.dead)
	assert_eq(F.types(g.perform({"type": "wait"})), ["message"], "dead players can't act")


func test_rest_stops_when_healed() -> void:
	var g := F.new_game()
	F.in_room(g, 3, 3, Vector2i(1, 1))
	g.player.hp = 1
	g.perform({"type": "rest"})
	assert_eq(g.player.hp, g.player.max_hp)
	assert_true(g.turn > 0)


func test_rest_interrupted_by_visible_monster() -> void:
	var g := F.new_game()
	F.in_room(g, 7, 1, Vector2i(1, 1))
	g.player.hp = 1
	F.monster(g, "kobold", Vector2i(7, 1))
	var ev := g.perform({"type": "rest"})
	assert_true(g.player.hp < g.player.max_hp)
	assert_has(F.types(ev), "message")


func test_stat_adjust_limits() -> void:
	var s := Character.default_stats()
	assert_eq(s["pool"], Character.START_POOL)
	var up := Character.adjust(s, "pool", "str", 10)
	assert_eq(up["str"], s["str"] + 10)
	assert_eq(up["pool"], s["pool"] - 10)
	assert_eq(Character.adjust(s, "pool", "str", Character.MAX_STAT), s, "can't exceed max")
	assert_eq(Character.adjust(s, "dex", "pool", Character.MAX_STAT), s, "can't go below min")
	assert_eq(Character.adjust(s, "pool", "str", -5), s, "amount must be positive")


func test_roll_spends_whole_pool_within_limits() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 20:
		var s := Character.roll(rng)
		assert_eq(s["pool"], 0)
		for k in Character.STATS:
			assert_true(s[k] >= Character.MIN_STAT and s[k] <= Character.MAX_STAT)
		assert_eq(Character.STATS.reduce(func(acc, k): return acc + s[k], 0),
			Character.STATS.size() * Character.BASE_STAT + Character.START_POOL)


func test_derived_from_constitution() -> void:
	var weak := Character.derived({"str": 50, "int": 50, "con": 20, "dex": 50})
	var hardy := Character.derived({"str": 50, "int": 50, "con": 80, "dex": 50})
	assert_true(hardy["max_hp"] > weak["max_hp"])
	assert_eq(hardy["speed"], 100)


func test_starting_kit_equipped() -> void:
	var g := F.new_game()
	for slot in Character.STARTING_KIT:
		assert_eq(g.inventory.equipped[slot]["id"], Character.STARTING_KIT[slot])
	assert_eq(g.inventory.strength, 50)
