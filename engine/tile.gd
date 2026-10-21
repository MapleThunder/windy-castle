class_name Tile
extends RefCounted
## Terrain types and their movement, sight and sprite rules.

enum T { WALL, FLOOR, DOOR_CLOSED, DOOR_OPEN, SECRET_DOOR, STAIRS_DOWN, STAIRS_UP, GRASS, DIRT, TREE, BUILDING, TOWN_GATE, PALISADE, FARMLAND, MOUNTAIN, SNOW }

const _PASSABLE := [T.FLOOR, T.DOOR_OPEN, T.STAIRS_DOWN, T.STAIRS_UP, T.GRASS, T.DIRT]
const _OPAQUE := [T.WALL, T.SECRET_DOOR, T.DOOR_CLOSED, T.TREE, T.BUILDING, T.PALISADE]
const _SPRITES := {
	T.WALL: "tile.wall",
	T.FLOOR: "tile.floor",
	T.DOOR_CLOSED: "tile.door.closed",
	T.DOOR_OPEN: "tile.door.open",
	T.SECRET_DOOR: "tile.wall",  # indistinguishable from rock until found
	T.STAIRS_DOWN: "tile.stairs.down",
	T.STAIRS_UP: "tile.stairs.up",
	T.GRASS: "tile.grass",
	T.DIRT: "tile.dirt",
	T.TREE: "tile.grass",  # CotW1 has no tree art
	T.BUILDING: "tile.building",
	T.TOWN_GATE: "tile.town.gate",  # source: exe ("The gate is too heavy to open.")
	T.PALISADE: "tile.palisade",  # source: exe ("A wooden palisade")
	T.FARMLAND: "tile.farmland",  # source: exe ("farmland"), the hamlet's border fields
	T.MOUNTAIN: "tile.wall",  # grey rock, as in the original's outdoor map
	T.SNOW: "tile.floor",  # white snowfields on the peaks
}


static func passable(t: int) -> bool:
	return t in _PASSABLE


static func opaque(t: int) -> bool:
	return t in _OPAQUE


static func sprite(t: int) -> String:
	return _SPRITES.get(t, "tile.wall")


static func by_name(name: String) -> int:
	return T[name.to_upper()]
