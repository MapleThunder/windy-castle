extends TestCase

const PACK_DIR := "user://test_pack"


func _make_pack() -> void:
	DirAccess.make_dir_recursive_absolute(PACK_DIR)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png(PACK_DIR + "/red.png")
	var f := FileAccess.open(PACK_DIR + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"tile_size": 32, "sprites": {"tile.floor": "red.png"}}))
	f.close()


func test_original_sprite_loads() -> void:
	var art := ArtPack.open([])
	var t := art.texture("tile.wall")
	assert_eq(t.get_size(), Vector2(32, 32))
	assert_eq(t.get_image().get_pixel(5, 5), Color8(128, 128, 128))
	assert_eq(art.tile_size(), 32)


func test_missing_sprite_magenta_and_single_warning() -> void:
	var art := ArtPack.open([])
	var a := art.texture("monster.does_not_exist")
	var b := art.texture("monster.does_not_exist")
	assert_eq(a.get_image().get_pixel(0, 0), Color.MAGENTA)
	assert_eq(a, b, "cached")
	assert_eq(art.warned.size(), 1)


func test_pack_override_order() -> void:
	_make_pack()
	var art := ArtPack.open([PACK_DIR])
	assert_eq(art.texture("tile.floor").get_image().get_pixel(1, 1), Color.RED, "override wins")
	assert_eq(art.texture("tile.wall").get_image().get_pixel(1, 1), Color8(128, 128, 128), "falls back to original")


func test_has() -> void:
	var art := ArtPack.open([])
	assert_true(art.has("player.male"))
	assert_false(art.has("nope"))
