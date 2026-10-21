class_name Inventory
extends RefCounted
## Worn equipment, the pack's contents and coins.
## source: hlp (Containers). A pack holds up to its max weight (g) and bulk (cc).
## ASSUMED: total carried weight (worn + pack) is limited to strength × CARRY_PER_STRENGTH grams.
## The HLP only says strength "lets you carry more stuff".

const SLOTS := ["weapon", "shield", "armor", "helmet", "cloak", "bracers", "gauntlets", "boots", "belt",
	"ring_left", "ring_right", "amulet", "pack", "purse"]
const CARRY_PER_STRENGTH := 1000
const TWO_HAND_MSG := "Can't use both a Two Handed Sword and a Shield"  # source: exe

var equipped: Dictionary = {}  # slot -> item instance or null
var pack: Array = []  # item instances inside the worn pack
var gold: int = 0  # gold pieces
var strength: int = 50


func _init() -> void:
	for s in SLOTS:
		equipped[s] = null


func _def(item: Dictionary, db: GameData) -> Dictionary:
	return db.item(item["id"])


func capacity(db: GameData) -> Dictionary:
	var p: Variant = equipped["pack"]
	if p == null:
		return {"weight": 0, "bulk": 0}
	var cap: Dictionary = _def(p, db)["capacity"]
	return {"weight": int(cap["weight"]), "bulk": int(cap["bulk"])}


func carry_limit() -> int:
	return strength * CARRY_PER_STRENGTH


func total_bulk(db: GameData) -> int:
	return pack.reduce(func(acc, it): return acc + int(_def(it, db)["bulk"]) * int(it["qty"]), 0)


func _pack_weight(db: GameData) -> int:
	return pack.reduce(func(acc, it): return acc + int(_def(it, db)["weight"]) * int(it["qty"]), 0)


func total_weight(db: GameData) -> int:
	var worn := 0
	for s in SLOTS:
		if equipped[s] != null:
			worn += int(_def(equipped[s], db)["weight"])
	return worn + _pack_weight(db)


func can_add(item: Dictionary, db: GameData) -> String:
	if item["id"] == "gold":
		return ""
	if equipped["pack"] == null:
		return "You have no pack."
	var d := _def(item, db)
	var pack_name: String = _def(equipped["pack"], db)["name"]
	var cap := capacity(db)
	var qty := int(item["qty"])
	if total_weight(db) + int(d["weight"]) * qty > carry_limit():
		return "You can't carry that much."
	if _pack_weight(db) + int(d["weight"]) * qty > int(cap["weight"]):
		return "It's too heavy for your %s." % pack_name  # source: exe
	if total_bulk(db) + int(d["bulk"]) * qty > int(cap["bulk"]):
		return "There's no room in your %s." % pack_name  # source: exe
	return ""


func add(item: Dictionary, db: GameData) -> bool:
	if can_add(item, db) != "":
		return false
	if item["id"] == "gold":
		gold += int(item["qty"])
	else:
		pack.append(item)
	return true


func find(uid: int) -> int:
	for i in pack.size():
		if int(pack[i]["uid"]) == uid:
			return i
	return -1


func remove(uid: int) -> Dictionary:
	var i := find(uid)
	return pack.pop_at(i) if i >= 0 else {}


func _fits_slot(d: Dictionary, slot: String) -> bool:
	if d["slot"] == "ring":
		return slot == "ring_left" or slot == "ring_right"
	return d["slot"] == slot


func equip(uid: int, slot: String, db: GameData) -> String:
	var i := find(uid)
	if i < 0:
		return "You aren't carrying that."
	var item: Dictionary = pack[i]
	var d := _def(item, db)
	if not slot in equipped or not _fits_slot(d, slot):
		return "You can't wear the %s there." % d["name"]
	if slot == "pack" and equipped["pack"] != null:
		return "Take off your %s first." % _def(equipped["pack"], db)["name"]
	if slot == "shield" and equipped["weapon"] != null and int(_def(equipped["weapon"], db)["hands"]) == 2:
		return TWO_HAND_MSG
	if slot == "weapon" and int(d["hands"]) == 2 and equipped["shield"] != null:
		return TWO_HAND_MSG
	pack.remove_at(i)
	var old: Variant = equipped[slot]
	equipped[slot] = item
	if old != null:
		var why := can_add(old, db)
		if why != "":
			equipped[slot] = old
			pack.insert(i, item)
			return why
		pack.append(old)
	return ""


func unequip(slot: String, db: GameData) -> String:
	var item: Variant = equipped.get(slot)
	if item == null:
		return "You have nothing there."
	if slot == "pack":
		return "It's not empty!" if not pack.is_empty() else "You have nowhere to put it."
	equipped[slot] = null
	var why := can_add(item, db)
	if why != "":
		equipped[slot] = item
		return why
	pack.append(item)
	return ""


func to_dict() -> Dictionary:
	return {"equipped": equipped.duplicate(), "pack": pack.duplicate(), "gold": gold, "strength": strength}


static func from_dict(d: Dictionary) -> Inventory:
	var inv := Inventory.new()
	for s in SLOTS:
		var it: Variant = d["equipped"].get(s)
		inv.equipped[s] = Level.item_from_dict(it) if it != null else null
	inv.pack = d["pack"].map(Level.item_from_dict)
	inv.gold = int(d["gold"])
	inv.strength = int(d["strength"])
	return inv
