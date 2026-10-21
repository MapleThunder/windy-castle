class_name Game
extends RefCounted
## The rules engine's front door: take one player action, resolve it and every monster turn
## that follows, and return the events in order. The view never changes state directly.

const MAX_MESSAGES := 500
const SIGHT_TOWN := 20  # daylight
const SIGHT_MINE := 7  # ASSUMED: torch radius
const REGEN_TURNS := 10  # ASSUMED: 1 hp per 10 turns
const SEARCH_PCT := 33  # ASSUMED: the HLP only says you may have to search more than once
const REST_LIMIT := 2000

var db: GameData
var rng := RandomNumberGenerator.new()
var spec: Dictionary
var stats: Dictionary
var level: Level
var levels: Dictionary = {}  # depth -> Level, so revisited levels keep their state
var player: Actor
var inventory := Inventory.new()
var turn := 0
var messages: Array[String] = []
var visible: Dictionary = {}
var dead := false
var next_id := 1
var next_uid := 1


static func new_game(character: Dictionary, seed: int, data: GameData) -> Game:
	var g := Game.new()
	g.db = data
	g.rng.seed = seed
	g.spec = character
	g.stats = character["stats"].duplicate()
	g.player = Actor.new()
	g.player.id = g._claim_id()
	g.player.kind = "player"
	var d := Character.derived(g.stats)
	g.player.max_hp = d["max_hp"]
	g.player.hp = d["max_hp"]
	g.player.speed = d["speed"]
	g.player.energy = Scheduler.ACTION_COST
	g.inventory.strength = int(g.stats["str"])
	for slot in Character.STARTING_KIT:
		g.inventory.equipped[slot] = g.new_item(Character.STARTING_KIT[slot])
	g.refresh_player()
	g.enter_level(Town.build(), Town.player_start())
	g._log("You arrive in %s." % g.level.name)
	return g


# --- setup helpers (also used by tests) ---------------------------------------------------

func _claim_id() -> int:
	next_id += 1
	return next_id - 1


func new_item(id: String, qty: int = 1) -> Dictionary:
	next_uid += 1
	return {"uid": next_uid - 1, "id": id, "qty": qty}


func add_actor(a: Actor) -> void:
	if a.id == 0:
		a.id = _claim_id()
	level.actors.append(a)


## Make `l` the current level with the player at `at`. New levels get their ids and uids here.
func enter_level(l: Level, at: Vector2i) -> void:
	if level != null and level != l:
		level.actors.erase(player)
		levels[level.depth] = level
	for a in l.actors:
		if a.id == 0:
			a.id = _claim_id()
	for p in l.floor_items:
		for it in l.floor_items[p]:
			if int(it["uid"]) == 0:
				it["uid"] = new_item(it["id"])["uid"]
	level = l
	levels[l.depth] = l
	if not l.actors.has(player):
		l.actors.append(player)
	player.pos = at
	_update_view()


func refresh_player() -> void:
	var armor := 0
	for slot in Inventory.SLOTS:
		var it: Variant = inventory.equipped[slot]
		if it != null:
			armor += int(db.item(it["id"])["armor"])
	var weapon: Variant = inventory.equipped["weapon"]
	player.data["combat"] = Combat.player_profile(stats, weapon["id"] if weapon != null else "", armor, db)


func monster_name(a: Actor) -> String:
	return "you" if a.is_player() else "the " + db.monster(a.kind)["name"]


# --- the action loop ---------------------------------------------------------------------

func perform(action: Dictionary, options: Dictionary = {}) -> Array:
	if dead:
		return [_msg("You are dead.")]
	var result: Array = _player_action(action, options)
	var events: Array = result[0]
	if result[1]:
		_end_player_turn(events)
	return events


## Returns [events, took_turn].
func _player_action(action: Dictionary, options: Dictionary) -> Array:
	match action.get("type", ""):
		"move":
			return _act_move(action["dir"], options)
		"wait":
			return [[], true]
		"search":
			return _act_search()
		"pickup":
			return _act_pickup()
		"drop":
			return _act_drop(int(action["uid"]))
		"equip":
			return _act_inventory(inventory.equip(int(action["uid"]), action["slot"], db))
		"unequip":
			return _act_inventory(inventory.unequip(action["slot"], db))
		"open":
			return _act_door(action["dir"], Tile.T.DOOR_CLOSED, Tile.T.DOOR_OPEN, "door_opened")
		"close":
			return _act_door(action["dir"], Tile.T.DOOR_OPEN, Tile.T.DOOR_CLOSED, "door_closed")
		"stairs_down":
			return _act_stairs(Tile.T.STAIRS_DOWN, 1)
		"stairs_up":
			return _act_stairs(Tile.T.STAIRS_UP, -1)
		"rest":
			return [_act_rest(), false]
	return [[_msg("You can't do that.")], false]


func _end_player_turn(events: Array) -> void:
	turn += 1
	Scheduler.spend(player)
	if turn % REGEN_TURNS == 0 and player.hp < player.max_hp:
		player.hp += 1
		events.append({"type": "stats_changed"})
	while not dead:
		var a := Scheduler.next_actor(level)
		if a == player:  # monsters that are equally ready move before control returns
			var waiting := level.actors.filter(func(o): return o != player and o.energy >= Scheduler.ACTION_COST)
			if waiting.is_empty():
				break
			a = waiting[0]
		events.append_array(AI.take_turn(self, a))
		Scheduler.spend(a)
	_update_view()


func _update_view() -> void:
	visible = FOV.compute(level, player.pos, SIGHT_TOWN if level.depth == 0 else SIGHT_MINE)
	for p in visible:
		level.explored[level.index(p)] = 1


# --- shared mechanics (also used by AI) ----------------------------------------------------

func move_actor(a: Actor, to: Vector2i) -> Array:
	var from := a.pos
	a.pos = to
	return [{"type": "moved", "actor_id": a.id, "from": from, "to": to}]


func melee(attacker: Actor, defender: Actor) -> Array:
	var r := Combat.melee(attacker, defender, rng, db)
	var events := []
	var att := monster_name(attacker).capitalize() if not attacker.is_player() else "You"
	var def_name := monster_name(defender)
	if r["hit"]:
		events.append({"type": "attacked", "attacker_id": attacker.id, "target_id": defender.id, "damage": r["damage"]})
		events.append(_msg("%s %s %s." % [att, "hit" if attacker.is_player() else "hits", def_name]))
	else:
		events.append({"type": "missed", "attacker_id": attacker.id, "target_id": defender.id})
		events.append(_msg("%s %s %s!" % [att, "miss" if attacker.is_player() else "misses", def_name]))
	if r["killed"]:
		if defender.is_player():
			dead = true
			events.append({"type": "died", "actor_id": defender.id})
			events.append(_msg("You have died."))
			events.append({"type": "player_died", "cause": db.monster(attacker.kind)["name"]})
		else:
			level.actors.erase(defender)
			events.append({"type": "died", "actor_id": defender.id})
			events.append(_msg("You kill %s!" % def_name))
	if defender.is_player():
		events.append({"type": "stats_changed"})
	return events


func _msg(text: String) -> Dictionary:
	_log(text)
	return {"type": "message", "text": text}


func _log(text: String) -> void:
	messages.append(text)
	if messages.size() > MAX_MESSAGES:
		messages.pop_front()


# --- player actions ----------------------------------------------------------------------

func _act_move(dir: Vector2i, options: Dictionary) -> Array:
	var to := player.pos + dir
	var target := level.actor_at(to)
	if target != null:
		return [melee(player, target), true]
	var t := level.get_tile(to)
	if t == Tile.T.DOOR_CLOSED:
		level.set_tile(to, Tile.T.DOOR_OPEN)
		return [[{"type": "door_opened", "pos": to}], true]
	if level.signs.has(to):
		return [[_msg(level.signs[to])], false]
	if t == Tile.T.TOWN_GATE:
		return [[_msg("The gate is too heavy to open.")], false]  # source: exe
	if not Tile.passable(t):
		return [[_msg("You can't go that way.")], false]
	var events := move_actor(player, to)
	if options.get("auto_pickup_gold", false):
		events.append_array(_pickup_where(func(it): return it["id"] == "gold"))
	var here := level.items_at(to)
	if not here.is_empty():
		events.append(_msg("You see: " + ", ".join(here.map(_item_label))))  # source: exe ("You see:")
	return [events, true]


func _item_label(it: Dictionary) -> String:
	if it["id"] == "gold":
		return "%d gold" % int(it["qty"])
	return db.item(it["id"])["name"]


func _pickup_where(pred: Callable) -> Array:
	var events := []
	var left := []
	for it in level.items_at(player.pos):
		if not pred.call(it):
			left.append(it)
			continue
		var why := inventory.can_add(it, db)
		if why != "":
			left.append(it)
			events.append(_msg(why))
		else:
			inventory.add(it, db)
			if it["id"] == "gold":
				events.append({"type": "gold_picked", "amount": int(it["qty"])})
			else:
				events.append({"type": "item_picked", "uid": it["uid"]})
			events.append(_msg("You pick up %s." % _item_label(it)))
	if left.is_empty():
		level.floor_items.erase(player.pos)
	else:
		level.floor_items[player.pos] = left
	return events


func _act_pickup() -> Array:
	if level.items_at(player.pos).is_empty():
		return [[_msg("There's nothing here.")], false]
	var events := _pickup_where(func(_it): return true)
	var took := events.any(func(e): return e["type"] in ["item_picked", "gold_picked"])
	if took:
		events.append({"type": "stats_changed"})
	return [events, took]


func _act_drop(uid: int) -> Array:
	var it := inventory.remove(uid)
	if it.is_empty():
		return [[_msg("You aren't carrying that.")], false]
	var pile: Array = level.floor_items.get(player.pos, [])
	pile.append(it)
	level.floor_items[player.pos] = pile
	return [[{"type": "item_dropped", "uid": uid, "pos": player.pos}, {"type": "stats_changed"},
		_msg("You drop %s." % _item_label(it))], true]


func _act_inventory(why: String) -> Array:
	if why != "":
		return [[_msg(why)], false]
	refresh_player()
	return [[{"type": "stats_changed"}], true]


func _act_door(dir: Vector2i, from: int, to: int, event: String) -> Array:
	var p := player.pos + dir
	if level.get_tile(p) != from:
		return [[_msg("There's no door there.")], false]
	if level.actor_at(p) != null or not level.items_at(p).is_empty():
		return [[_msg("Something is in the way.")], false]
	level.set_tile(p, to)
	return [[{"type": event, "pos": p}], true]


func _act_search() -> Array:
	var events := []
	for d in AI.DIRS:
		var p: Vector2i = player.pos + d
		if level.get_tile(p) == Tile.T.SECRET_DOOR and RngUtil.chance(rng, SEARCH_PCT):
			level.set_tile(p, Tile.T.DOOR_CLOSED)
			events.append({"type": "secret_found", "pos": p})
			events.append(_msg("You found a secret door!"))
	return [events, true]


func _act_stairs(tile: int, delta: int) -> Array:
	if level.get_tile(player.pos) != tile:
		return [[_msg("No stairs here")], false]  # source: exe
	var depth := level.depth + delta
	if depth < 0:
		return [[_msg("No stairs here")], false]
	var dest: Level = levels.get(depth)
	if dest == null:
		dest = Town.build() if depth == 0 else LevelGen.generate_mine(depth, rng, db)
	var arrive := dest.find_tile(Tile.T.STAIRS_UP if delta > 0 else Tile.T.STAIRS_DOWN)
	player.energy = Scheduler.ACTION_COST
	enter_level(dest, arrive)
	return [[{"type": "level_changed", "depth": depth}, _msg(dest.name)], false]


func _act_rest() -> Array:
	var events := []
	for i in REST_LIMIT:
		if dead or player.hp >= player.max_hp:
			break
		if level.actors.any(func(a): return not a.is_player() and visible.has(a.pos)):
			events.append(_msg("You are interrupted!"))  # source: exe
			break
		_end_player_turn(events)
	return events
