class_name Combat
extends RefCounted
## Melee resolution.
##
## source: hlp (Glossary). Strength raises damage per hit. Dexterity improves AV and to-hit.
## A higher Armor Value deflects more attacks. Above-average statistics give bonuses.
## ASSUMED: the exact numbers. Hit% = clamp(BASE_HIT + 3*to_hit - AV, MIN_HIT, MAX_HIT).
## Damage = weapon dice + damage bonus, at least 1. Stat bonus = (stat - 50) / 10 for stats above
## average (50 on the HLP's 1–100 scale), otherwise 0.

const BASE_HIT := 75
const MIN_HIT := 5
const MAX_HIT := 95
const UNARMED_DAMAGE := "1d2"
const AVERAGE_STAT := 50


static func hit_chance(to_hit: int, armor: int) -> int:
	return clampi(BASE_HIT + 3 * to_hit - armor, MIN_HIT, MAX_HIT)


static func stat_bonus(value: int) -> int:
	return maxi(0, (value - AVERAGE_STAT) / 10)


static func monster_profile(m: Dictionary) -> Dictionary:
	return {"to_hit": int(m["attack"]["to_hit"]), "damage": m["attack"]["damage"], "damage_bonus": 0,
		"armor": int(m["armor"])}


static func player_profile(stats: Dictionary, weapon_id: String, armor_value: int, db: GameData) -> Dictionary:
	var damage: String = db.item(weapon_id)["damage"] if weapon_id != "" else UNARMED_DAMAGE
	return {"to_hit": stat_bonus(int(stats["dex"])), "damage": damage,
		"damage_bonus": stat_bonus(int(stats["str"])), "armor": armor_value + stat_bonus(int(stats["dex"]))}


static func profile(actor: Actor, db: GameData) -> Dictionary:
	if actor.data.has("combat"):
		return actor.data["combat"]
	return monster_profile(db.monster(actor.kind))


static func melee(attacker: Actor, defender: Actor, rng: RandomNumberGenerator, db: GameData) -> Dictionary:
	var att := profile(attacker, db)
	var def := profile(defender, db)
	if not RngUtil.chance(rng, hit_chance(int(att["to_hit"]), int(def["armor"]))):
		return {"hit": false, "damage": 0, "killed": false}
	var damage := maxi(1, RngUtil.roll(rng, att["damage"]) + int(att["damage_bonus"]))
	defender.hp = maxi(0, defender.hp - damage)
	return {"hit": true, "damage": damage, "killed": defender.hp == 0}
