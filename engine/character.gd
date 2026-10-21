class_name Character
extends RefCounted
## Character creation: four statistics on a 1–100 scale (source: hlp "Statistics").
## Points move between a shared pool and the stats (source: hlp "Create Character").
## ASSUMED: the base value, pool size, initial limits, derived formulas and starting kit.

const STATS := ["str", "int", "con", "dex"]
const BASE_STAT := 40
const START_POOL := 40
const MIN_STAT := 20
const MAX_STAT := 80
const STARTING_KIT := {"pack": "small_pack", "weapon": "dagger", "armor": "leather_armor"}


static func default_stats() -> Dictionary:
	var s := {"pool": START_POOL}
	for k in STATS:
		s[k] = BASE_STAT
	return s


static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var s := default_stats()
	while s["pool"] > 0:
		var k: String = STATS[rng.randi() % STATS.size()]
		var next := adjust(s, "pool", k, mini(5, s["pool"]))
		if next != s:
			s = next
	return s


## Move `amount` points from `from_stat` to `to_stat` ("pool" is the unspent points).
## Returns the stats unchanged if the move breaks a limit.
static func adjust(stats: Dictionary, from_stat: String, to_stat: String, amount: int) -> Dictionary:
	if amount <= 0:
		return stats
	var out := stats.duplicate()
	out[from_stat] -= amount
	out[to_stat] += amount
	for k in STATS:
		if out[k] < MIN_STAT or out[k] > MAX_STAT:
			return stats
	if out["pool"] < 0:
		return stats
	return out


static func derived(stats: Dictionary) -> Dictionary:
	return {"max_hp": 8 + int(stats["con"]) / 5, "max_mp": int(stats["int"]) / 10, "speed": 100}
