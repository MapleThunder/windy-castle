extends TestCase


func _fighter(to_hit: int, damage: String, bonus: int, armor: int, hp: int = 1000) -> Actor:
	var a := Actor.new()
	a.kind = "kobold"
	a.hp = hp
	a.max_hp = hp
	a.data = {"combat": {"to_hit": to_hit, "damage": damage, "damage_bonus": bonus, "armor": armor}}
	return a


func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


func test_damage_in_weapon_range() -> void:
	var rng := _rng(1)
	var db := GameData.load_default()
	var att := _fighter(0, "1d6", 1, 0)
	var lo := 99
	var hi := 0
	for i in 500:
		var def := _fighter(0, "1d2", 0, 0)
		var r := Combat.melee(att, def, rng, db)
		if r["hit"]:
			lo = mini(lo, r["damage"])
			hi = maxi(hi, r["damage"])
			assert_eq(def.hp, 1000 - int(r["damage"]))
	assert_eq(lo, 2)
	assert_eq(hi, 7)


func test_armor_reduces_hit_rate() -> void:
	var db := GameData.load_default()
	var hits := [0, 0]
	for k in 2:
		var rng := _rng(7)
		for i in 2000:
			var r := Combat.melee(_fighter(0, "1d4", 0, 0), _fighter(0, "1d4", 0, [0, 40][k]), rng, db)
			hits[k] += 1 if r["hit"] else 0
	assert_true(hits[0] > hits[1] + 400, "armor 40 should deflect far more: %s" % [hits])


func test_hit_chance_clamped() -> void:
	assert_eq(Combat.hit_chance(0, 1000), Combat.MIN_HIT)
	assert_eq(Combat.hit_chance(1000, 0), Combat.MAX_HIT)


func test_kill_sets_flag_and_hp_zero() -> void:
	var rng := _rng(3)
	var db := GameData.load_default()
	var def := _fighter(0, "1d2", 0, 0, 1)
	var r := {}
	for i in 50:
		r = Combat.melee(_fighter(100, "5d6", 0, 0), def, rng, db)
		if r["hit"]:
			break
	assert_true(r["killed"])
	assert_eq(def.hp, 0)


func test_deterministic() -> void:
	var db := GameData.load_default()
	var a := _rng(11)
	var b := _rng(11)
	for i in 30:
		assert_eq(Combat.melee(_fighter(0, "1d8", 0, 5), _fighter(0, "1d8", 0, 5), a, db),
			Combat.melee(_fighter(0, "1d8", 0, 5), _fighter(0, "1d8", 0, 5), b, db))


func test_monster_profile_from_db() -> void:
	var db := GameData.load_default()
	var p := Combat.monster_profile(db.monster("kobold"))
	assert_eq(p["damage"], "1d4")
	assert_eq(p["armor"], 2)
	var a := Actor.new()
	a.kind = "kobold"
	a.hp = 5
	assert_eq(Combat.profile(a, db)["damage"], "1d4", "falls back to the db when data has no combat block")


func test_player_profile_uses_stats_and_weapon() -> void:
	var db := GameData.load_default()
	var avg := Combat.player_profile({"str": 50, "int": 50, "con": 50, "dex": 50}, "dagger", 0, db)
	assert_eq(avg["damage"], db.item("dagger")["damage"])
	assert_eq(avg["damage_bonus"], 0)
	var strong := Combat.player_profile({"str": 80, "int": 50, "con": 50, "dex": 70}, "", 6, db)
	assert_eq(strong["damage"], Combat.UNARMED_DAMAGE)
	assert_eq(strong["damage_bonus"], 3)
	assert_eq(strong["to_hit"], 2)
	assert_eq(strong["armor"], 6 + 2)
