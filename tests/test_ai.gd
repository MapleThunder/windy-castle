extends TestCase

const F := preload("res://tests/game_fixtures.gd")


func test_monster_chases_and_attacks() -> void:
	var g := F.new_game(1)
	F.in_room(g, 9, 9, Vector2i(1, 5))
	g.player.max_hp = 1000
	g.player.hp = 1000
	var m := F.monster(g, "kobold", Vector2i(4, 5))
	var events := []
	for i in 3:
		events.append_array(g.perform({"type": "wait"}))
	var t := F.types(events)
	assert_eq(maxi(absi(m.pos.x - 1), absi(m.pos.y - 5)), 1, "adjacent after closing in")
	assert_true("attacked" in t or "missed" in t, "attacks once adjacent")
	assert_eq(m.data["ai"], "chase")


func test_flee_when_hurt() -> void:
	var g := F.new_game(1)
	F.in_room(g, 9, 1, Vector2i(1, 1))
	var m := F.monster(g, "kobold", Vector2i(3, 1), 20)
	m.hp = 2
	m.data["ai"] = "chase"
	g.perform({"type": "wait"})
	assert_eq(m.data["ai"], "flee")
	assert_true(m.pos.x > 3, "moved away")


func test_wander_when_unseen() -> void:
	var g := F.new_game(1)
	var l := F.in_room(g, 9, 9, Vector2i(1, 1))
	for y in range(1, 10):
		l.set_tile(Vector2i(5, y), Tile.T.WALL)
	var m := F.monster(g, "kobold", Vector2i(8, 8))
	for i in 20:
		g.perform({"type": "wait"})
		assert_true(m.pos.x > 5, "stays behind the wall")
	assert_eq(m.data["ai"], "wander")
