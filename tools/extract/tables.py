"""Build data/items.json and data/monsters.json.

Items come from the CASTLE1.HLP "Objects" and "Containers" tables (armour
value, weapon class, weight in grams, bulk in cc). Monster names come from the
EXE's string table (segment 13).

Monster stats: not recovered. The EXE keeps every string literal in one pool
(segment 13) behind a pointer table, and the code reads them by computed index.
The monster records are built in code rather than stored as data tables, so no
name-indexed struct array exists in the data segment. Recovering the real
numbers needs a proper disassembly (for example in Ghidra). Until then every
monster stat below is ASSUMED, scaled to the HLP's depth order, and the rows
carry "source": "assumed".

Usage: python3 -I tools/extract/tables.py --exe <CASTLE1.EXE> --out-root .  (reads CASTLE1.HLP beside the EXE)
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I drops the script dir

import hlp
import pe_ne

STRING_SEGMENT = 13

# ASSUMED: stats for the slice's early-depth monsters (see module docstring).
MONSTERS = [
    # id, level, hp, speed, to_hit, damage, armor, flags, min_depth, icon
    ("giant_rat", 1, "1d4+1", 100, 0, "1d3", 0, ["animal"], 1, 381),
    ("kobold", 1, "1d8", 100, 0, "1d4", 2, [], 1, 379),
    ("large_snake", 1, "2d4", 80, 0, "1d4", 2, ["animal"], 1, 383),
    ("giant_bat", 1, "1d6", 150, 1, "1d3", 0, ["animal", "flying", "erratic"], 1, 405),
    ("wild_dog", 2, "2d6", 120, 1, "1d6", 1, ["animal"], 2, 387),
    ("goblin", 2, "2d6", 100, 1, "1d6", 4, [], 2, 427),
    ("hobgoblin", 3, "3d6", 100, 2, "1d8", 6, [], 3, 429),
    ("gray_wolf", 3, "3d6", 130, 2, "1d6+1", 3, ["animal"], 3, 431),
]

# Table header (first cell) → item kind and equipment slot.
TABLES = {
    "Armor Type": ("armor", "armor"),
    "Helmet Type": ("armor", "helmet"),
    "Shield Type": ("armor", "shield"),
    "Weapon Type": ("weapon", "weapon"),
}
MISC_SLOTS = {"Boots": "boots", "Gauntlets": "gauntlets", "Bracers": "bracers", "Cloak": "cloak",
              "Ring": "ring", "Amulet": "amulet"}
MISC_KIND = {"Potion": "potion", "Scroll or Book": "scroll", "Staff": "staff"}
TWO_HANDED = {"Two Handed Sword"}  # source: exe ("Can't use both a Two Handed Sword and a Shield")

WEAPON_SPRITES = [("dagger", "item.dagger"), ("club", "item.club"), ("axe", "item.axe"), ("mace", "item.mace"),
                  ("morningstar", "item.mace"), ("flail", "item.mace"), ("hammer", "item.mace"),
                  ("staff", "item.staff"), ("short sword", "item.short_sword"), ("sword", "item.long_sword"),
                  ("spear", "item.long_sword")]


def snake(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def weapon_damage(weapon_class):
    # ASSUMED: the HLP only says higher classes do more damage. 1d(2c+2) keeps that order.
    return f"1d{2 * weapon_class + 2}"


def exe_strings(exe):
    seg = pe_ne.read(exe).segments[STRING_SEGMENT - 1].data
    return {s.decode("latin1") for s in seg.split(b"\0") if s}


def _rows(cells, width):
    return [cells[i:i + width] for i in range(0, len(cells) - width + 1, width)]


def items_from_help(topics):
    objects = next(t for t in topics if t["title"] == "Objects")
    containers = next(t for t in topics if t["title"] == "Containers")
    items = []

    def add(name, kind, slot, armor=0, weight=0, bulk=0, **extra):
        item = {"id": snake(name), "name": name, "kind": kind, "slot": slot, "hands": 1, "damage": None,
                "armor": armor, "weight": weight, "bulk": bulk, "value": 0, "sprite": "", "source": "hlp"}
        item.update(extra)
        items.append(item)
        return item

    paras = objects["paragraphs"]
    for header, body in zip(paras, paras[1:]):
        if header[0] in TABLES:
            kind, slot = TABLES[header[0]]
            for name, stat, weight, bulk in _rows(body, 4):
                if kind == "weapon":
                    add(name, kind, slot, weight=int(weight), bulk=int(bulk), weapon_class=int(stat),
                        damage=weapon_damage(int(stat)), hands=2 if name in TWO_HANDED else 1)
                else:
                    add(name, kind, slot, armor=int(stat), weight=int(weight), bulk=int(bulk))
        elif header[0] == "Misc. Object Type":
            for name, weight, bulk in _rows(body, 3):
                kind = MISC_KIND.get(name, "armor")
                add(name, kind, MISC_SLOTS.get(name), weight=int(weight), bulk=int(bulk))

    cparas = containers["paragraphs"]
    header = next(i for i, p in enumerate(cparas) if p[0] == "Container")
    for name, wt, bulk, wmax, bmax, wfx, bfx in _rows(cparas[header + 1], 7):
        slot = "pack" if "Pack" in name else None
        add(name, "container", slot, weight=int(wt), bulk=int(bulk),
            capacity={"weight": int(wmax), "bulk": int(bmax)}, fixed={"weight": int(wfx), "bulk": int(bfx)})

    # ASSUMED: belts and purses appear in-game (exe strings) but not in the HLP tables.
    add("Belt", "container", "belt", weight=300, bulk=500, capacity={"weight": 5000, "bulk": 5000},
        fixed={"weight": 0, "bulk": 0}, source="assumed")
    add("Purse", "container", "purse", weight=100, bulk=100, capacity={"weight": 10000, "bulk": 2000},
        fixed={"weight": 0, "bulk": 0}, source="assumed")
    return items


def item_sprite(item, sprites):
    direct = f"item.{item['id']}"
    if direct in sprites:
        return direct
    name = item["name"].lower()
    if item["kind"] == "weapon":
        return next((s for key, s in WEAPON_SPRITES if key in name), "item.long_sword")
    by_slot = {"armor": "item.chain_mail" if "mail" in name or "plate" in name else "item.leather_armor",
               "helmet": "item.helmet", "shield": "item.small_shield", "pack": "item.pack", "belt": "item.belt",
               "purse": "item.purse"}
    if item["slot"] in by_slot:
        return by_slot[item["slot"]]
    if item["kind"] == "container":
        return "item.chest" if "chest" in name else "item.pack"
    return {"potion": "item.potion", "scroll": "item.scroll", "staff": "item.staff"}.get(item["kind"], "item.ring")


def monsters_from_exe(strings, help_titles):
    out = []
    for mid, level, hp, speed, to_hit, damage, armor, flags, depth, icon in MONSTERS:
        name = " ".join(w.capitalize() for w in mid.split("_"))
        if name not in strings:
            sys.exit(f"monster name {name!r} not in the EXE string table")
        out.append({"id": mid, "name": name, "level": level, "hp": hp, "speed": speed,
                    "attack": {"to_hit": to_hit, "damage": damage}, "armor": armor, "flags": flags,
                    "min_depth": depth, "sprite": f"monster.{mid}", "icon": f"icons/{icon}.png",
                    "described_in_help": name.upper() in help_titles, "source": "assumed"})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", required=True)
    ap.add_argument("--names", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "icon_names.json"))
    ap.add_argument("--out-root", default=".")
    args = ap.parse_args()
    hlp_path = os.path.join(os.path.dirname(args.exe), "CASTLE1.HLP")
    topics = [{"title": t.title, "paragraphs": t.paragraphs} for t in hlp.read_topics(hlp_path)]
    help_titles = {t["title"].upper() for t in topics} | {p[0] for t in topics for p in t["paragraphs"][:1]}

    with open(args.names) as f:
        names = json.load(f)
    items = items_from_help(topics)
    for item in items:
        item["sprite"] = item_sprite(item, names)
    monsters = monsters_from_exe(exe_strings(args.exe), help_titles)
    for m in monsters:  # keep icon_names.json in step with the monster list
        names[m["sprite"]] = m.pop("icon")
    with open(args.names, "w") as f:
        json.dump(names, f, indent="\t")
        f.write("\n")

    data = os.path.join(args.out_root, "data")
    for name, rows in (("items.json", items), ("monsters.json", monsters)):
        with open(os.path.join(data, name), "w") as f:
            json.dump(rows, f, indent=1)
            f.write("\n")
    print(f"wrote {len(items)} items, {len(monsters)} monsters")


if __name__ == "__main__":
    main()
