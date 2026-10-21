class_name Scheduler
extends RefCounted
## Energy-based turn order. Each tick every actor gains `speed` energy; whoever reaches ACTION_COST acts.
# ASSUMED: speed 100 = normal, one action costs 100. CotW keeps a game clock in seconds
# ("Time to Cast: 5 seconds"), but its per-action timings are not yet recovered.

const ACTION_COST := 100


static func next_actor(level: Level) -> Actor:
	if level.actors.is_empty():
		return null
	while true:
		var ready: Actor = null
		for a in level.actors:
			if a.energy >= ACTION_COST and (ready == null or a.energy > ready.energy \
					or (a.energy == ready.energy and a.id < ready.id)):
				ready = a
		if ready != null:
			return ready
		for a in level.actors:
			a.energy += maxi(1, a.speed)
	return null


static func spend(actor: Actor, cost: int = ACTION_COST) -> void:
	actor.energy -= cost
