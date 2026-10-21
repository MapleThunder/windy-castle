class_name RngUtil
extends RefCounted
## Dice notation ("NdM" or "NdM+K") and percentage rolls on the game's RNG.


static func roll(rng: RandomNumberGenerator, dice: String) -> int:
	var plus := dice.split("+")
	var bonus := int(plus[1]) if plus.size() > 1 else 0
	var parts := plus[0].split("d")
	var total := bonus
	for i in int(parts[0]):
		total += rng.randi_range(1, int(parts[1]))
	return total


static func chance(rng: RandomNumberGenerator, percent: int) -> bool:
	return rng.randi_range(1, 100) <= percent
