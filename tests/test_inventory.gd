extends TestCase

var db := GameData.load_default()
var _uid := 0


func _it(id: String, qty: int = 1) -> Dictionary:
	_uid += 1
	return {"uid": _uid, "id": id, "qty": qty}


func _with_pack(pack_id: String = "small_pack") -> Inventory:
	var inv := Inventory.new()
	inv.strength = 50
	inv.equipped["pack"] = _it(pack_id)
	return inv


func _snapshot(inv: Inventory) -> String:
	return JSON.stringify(inv.to_dict())


func test_equip_valid_slot() -> void:
	var inv := _with_pack()
	var dagger := _it("dagger")
	assert_true(inv.add(dagger, db))
	assert_eq(inv.equip(dagger["uid"], "weapon", db), "")
	assert_eq(inv.equipped["weapon"]["id"], "dagger")
	assert_true(inv.pack.is_empty())


func test_equip_swaps_old_item_into_pack() -> void:
	var inv := _with_pack()
	var a := _it("dagger")
	var b := _it("club")
	inv.add(a, db)
	inv.add(b, db)
	inv.equip(a["uid"], "weapon", db)
	assert_eq(inv.equip(b["uid"], "weapon", db), "")
	assert_eq(inv.equipped["weapon"]["id"], "club")
	assert_eq(inv.pack.map(func(x): return x["id"]), ["dagger"])


func test_ring_fits_either_hand() -> void:
	var inv := _with_pack()
	var r := _it("ring")
	inv.add(r, db)
	assert_eq(inv.equip(r["uid"], "ring_right", db), "")


func test_equip_wrong_slot_rejected_state_unchanged() -> void:
	var inv := _with_pack()
	var dagger := _it("dagger")
	inv.add(dagger, db)
	var before := _snapshot(inv)
	assert_true(inv.equip(dagger["uid"], "helmet", db) != "")
	assert_eq(_snapshot(inv), before)


func test_equip_unknown_uid_rejected() -> void:
	var inv := _with_pack()
	assert_true(inv.equip(999, "weapon", db) != "")


func test_two_handed_blocks_shield() -> void:
	var inv := _with_pack("large_pack")
	inv.strength = 100
	var sword := _it("two_handed_sword")
	var shield := _it("small_wooden_shield")
	inv.add(sword, db)
	inv.add(shield, db)
	inv.equip(sword["uid"], "weapon", db)
	var before := _snapshot(inv)
	assert_eq(inv.equip(shield["uid"], "shield", db), "Can't use both a Two Handed Sword and a Shield")
	assert_eq(_snapshot(inv), before)


func test_shield_blocks_two_handed() -> void:
	var inv := _with_pack("large_pack")
	inv.strength = 100
	var sword := _it("two_handed_sword")
	var shield := _it("small_wooden_shield")
	inv.add(sword, db)
	inv.add(shield, db)
	inv.equip(shield["uid"], "shield", db)
	assert_eq(inv.equip(sword["uid"], "weapon", db), "Can't use both a Two Handed Sword and a Shield")


func test_over_weight_rejected_state_unchanged() -> void:
	var inv := _with_pack()  # small pack: 12000 g / 50000 cc
	assert_true(inv.add(_it("chain_mail"), db))  # 10000 g
	var before := _snapshot(inv)
	assert_eq(inv.can_add(_it("leather_armor"), db), "It's too heavy for your Small Pack.")
	assert_false(inv.add(_it("leather_armor"), db))
	assert_eq(_snapshot(inv), before)


func test_over_bulk_rejected() -> void:
	var inv := _with_pack()
	assert_true(inv.add(_it("leather_armor"), db))  # 24000 cc
	assert_true(inv.add(_it("leather_armor"), db))  # 48000 cc, 10000 g
	assert_eq(inv.can_add(_it("cloak"), db), "There's no room in your Small Pack.")


func test_strength_limits_total_carry() -> void:
	var inv := _with_pack("large_pack")
	inv.strength = 10  # ASSUMED limit: strength × 1000 g
	inv.equipped["armor"] = _it("plate_mail")  # 15000 g already worn
	assert_eq(inv.can_add(_it("dagger"), db), "You can't carry that much.")


func test_no_pack_means_hands_only() -> void:
	var inv := Inventory.new()
	assert_eq(inv.can_add(_it("dagger"), db), "You have no pack.")


func test_unequip_nonempty_pack_rejected() -> void:
	var inv := _with_pack()
	inv.add(_it("dagger"), db)
	assert_eq(inv.unequip("pack", db), "It's not empty!")


func test_unequip_returns_to_pack() -> void:
	var inv := _with_pack()
	var d := _it("dagger")
	inv.add(d, db)
	inv.equip(d["uid"], "weapon", db)
	assert_eq(inv.unequip("weapon", db), "")
	assert_eq(inv.equipped["weapon"], null)
	assert_eq(inv.pack.size(), 1)
	assert_true(inv.unequip("weapon", db) != "", "nothing to unequip")


func test_gold_adds_without_bulk() -> void:
	var inv := _with_pack()
	assert_true(inv.add(_it("gold", 25), db))
	assert_eq(inv.gold, 25)
	assert_eq(inv.total_bulk(db), 0)
	assert_true(inv.pack.is_empty())


func test_totals() -> void:
	var inv := _with_pack()
	inv.add(_it("dagger"), db)
	inv.equipped["armor"] = _it("leather_armor")
	assert_eq(inv.total_bulk(db), 500, "pack contents only")
	assert_eq(inv.total_weight(db), 500 + 5000 + 1000, "contents + worn + the pack itself")
	assert_eq(inv.capacity(db), {"weight": 12000, "bulk": 50000})


func test_roundtrip() -> void:
	var inv := _with_pack()
	inv.add(_it("dagger"), db)
	inv.add(_it("gold", 3), db)
	var copy := Inventory.from_dict(JSON.parse_string(JSON.stringify(inv.to_dict())))
	assert_eq(_snapshot(copy), _snapshot(inv))
	assert_eq(typeof(copy.pack[0]["uid"]), TYPE_INT)
	assert_eq(copy.gold, 3)
