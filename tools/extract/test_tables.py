import json
import os
import re
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DICE = re.compile(r"^\d+d\d+(\+\d+)?$")
SUBSET = ["giant_rat", "kobold", "large_snake", "wild_dog", "giant_bat", "goblin", "hobgoblin", "gray_wolf"]
MONSTER_KEYS = {"id": str, "name": str, "level": int, "hp": str, "speed": int, "attack": dict, "armor": int,
                "flags": list, "min_depth": int, "sprite": str, "source": str}
ITEM_KEYS = {"id": str, "name": str, "kind": str, "slot": (str, type(None)), "hands": int, "damage": (str, type(None)),
             "armor": int, "weight": int, "bulk": int, "value": int, "sprite": str, "source": str}


def load(name):
    with open(os.path.join(ROOT, "data", name)) as f:
        return json.load(f)


class TablesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.monsters = {m["id"]: m for m in load("monsters.json")}
        cls.items = {i["id"]: i for i in load("items.json")}

    def test_schema(self):
        for m in self.monsters.values():
            for k, t in MONSTER_KEYS.items():
                self.assertIsInstance(m[k], t, f"{m['id']}.{k}")
            self.assertRegex(m["hp"], DICE)
            self.assertRegex(m["attack"]["damage"], DICE)
            self.assertIsInstance(m["attack"]["to_hit"], int)
        for i in self.items.values():
            for k, t in ITEM_KEYS.items():
                self.assertIsInstance(i[k], t, f"{i['id']}.{k}")
            if i["damage"] is not None:
                self.assertRegex(i["damage"], DICE)
            self.assertIn(i["source"], ("exe", "hlp", "dosbox", "assumed"))

    def test_subset_present(self):
        for mid in SUBSET:
            self.assertIn(mid, self.monsters)
        for iid in ("dagger", "short_sword", "club", "leather_armor", "small_wooden_shield", "leather_helmet",
                    "cloak", "boots", "gauntlets", "ring", "amulet", "small_pack", "belt"):
            self.assertIn(iid, self.items)

    def test_known_values(self):
        # source: CASTLE1.HLP "Objects" and "Containers" tables.
        self.assertEqual((self.items["dagger"]["weight"], self.items["dagger"]["bulk"]), (500, 500))
        la = self.items["leather_armor"]
        self.assertEqual((la["armor"], la["weight"], la["bulk"], la["slot"]), (6, 5000, 24000, "armor"))
        self.assertEqual(self.items["small_pack"]["capacity"], {"weight": 12000, "bulk": 50000})
        self.assertEqual(self.items["two_handed_sword"]["hands"], 2)
        self.assertEqual(self.items["dagger"]["weapon_class"], 2)
        # source: CASTLE1.EXE string table.
        self.assertEqual(self.monsters["giant_rat"]["name"], "Giant Rat")
        self.assertEqual(self.monsters["gray_wolf"]["name"], "Gray Wolf")


if __name__ == "__main__":
    unittest.main()
