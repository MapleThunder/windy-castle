class_name Actor
extends RefCounted
## The player or a monster on a level.

var id: int = 0
var kind: String = ""  # "player" or a monster id
var pos: Vector2i = Vector2i.ZERO
var hp: int = 1
var max_hp: int = 1
var speed: int = 100
var energy: int = 0
var data: Dictionary = {}


func is_player() -> bool:
	return kind == "player"


func to_dict() -> Dictionary:
	return {"id": id, "kind": kind, "pos": [pos.x, pos.y], "hp": hp, "max_hp": max_hp,
		"speed": speed, "energy": energy, "data": data}


static func from_dict(d: Dictionary) -> Actor:
	var a := Actor.new()
	a.id = int(d["id"])
	a.kind = d["kind"]
	a.pos = Vector2i(int(d["pos"][0]), int(d["pos"][1]))
	a.hp = int(d["hp"])
	a.max_hp = int(d["max_hp"])
	a.speed = int(d["speed"])
	a.energy = int(d["energy"])
	a.data = d["data"]
	return a
