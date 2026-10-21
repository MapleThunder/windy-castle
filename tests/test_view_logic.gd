extends TestCase

const F := preload("res://tests/game_fixtures.gd")


func test_default_window_scale_is_2x() -> void:
	assert_eq(WorldView.pick_scale(Vector2i(Hud.map_rect_for(Vector2(1280, 800)).size)), 2)
	assert_eq(WorldView.pick_scale(Vector2i(Hud.map_rect_for(Vector2(2560, 1440)).size)), 4)
	assert_eq(WorldView.pick_scale(Vector2i(Hud.map_rect_for(Vector2(200, 100)).size)), 1)


func test_save_paths_distinct_per_character() -> void:
	assert_true(Saves.path_for("Hero", 1) != Saves.path_for("Hero", 2))
	assert_eq(Saves.path_for("Hero", 1), Saves.path_for("Hero", 1))


func test_running_ignores_unseen_monster_moves() -> void:
	var g := F.new_game()
	F.in_room(g, 9, 1, Vector2i(1, 1))
	var events := [{"type": "moved", "actor_id": g.player.id, "from": Vector2i(1, 1), "to": Vector2i(2, 1)},
		{"type": "moved", "actor_id": 999, "from": Vector2i(40, 40), "to": Vector2i(41, 40)}]
	assert_true(GameScreen.keeps_running(events, g))
	events.append({"type": "message", "text": "You see: Dagger"})
	assert_false(GameScreen.keeps_running(events, g), "a message stops the run")


func test_panel_move_prevalidates_floor_to_wrong_slot() -> void:
	var g := F.new_game()
	F.in_room(g, 3, 3, Vector2i(1, 1))
	var dagger := g.new_item("dagger")
	var plan := InventoryPanel.plan_move(g, "floor", "", dagger, "equip", "helmet")
	assert_true(plan["reject"] != "")
	assert_eq(plan["steps"], [])


func test_panel_move_prevalidates_equip_to_wrong_slot() -> void:
	var g := F.new_game()
	var armor: Dictionary = g.inventory.equipped["armor"]
	var plan := InventoryPanel.plan_move(g, "equip", "armor", armor, "equip", "helmet")
	assert_true(plan["reject"] != "")
	assert_eq(plan["steps"], [])


func test_panel_move_prevalidates_two_handed_with_shield() -> void:
	var g := F.new_game()
	g.inventory.equipped["shield"] = g.new_item("small_wooden_shield")
	var sword := g.new_item("two_handed_sword")
	var plan := InventoryPanel.plan_move(g, "floor", "", sword, "equip", "weapon")
	assert_eq(plan["reject"], Inventory.TWO_HAND_MSG)


func test_panel_move_valid_steps() -> void:
	var g := F.new_game()
	var club := g.new_item("club")
	var plan := InventoryPanel.plan_move(g, "floor", "", club, "equip", "weapon")
	assert_eq(plan["reject"], "")
	assert_eq(plan["steps"].map(func(s): return s["type"]), ["pickup", "equip"])


func test_killed_monster_sprite_survives_until_playback_ends() -> void:
	var g := F.new_game()
	F.in_room(g, 5, 1, Vector2i(1, 1))
	var m := F.monster(g, "kobold", Vector2i(2, 1), 1)
	var w := WorldView.new()
	Engine.get_main_loop().root.add_child(w)
	w.bind(g, ArtPack.open([]))
	var before := g.visible.duplicate()
	g.level.actors.erase(m)  # what the engine does on a kill
	w.refresh_visibility(before)
	assert_true(w.actor_node(m.id) != null, "kept for the death animation")
	w.refresh_entities()
	assert_eq(w.actor_node(m.id), null, "removed once playback finishes")
	w.queue_free()
