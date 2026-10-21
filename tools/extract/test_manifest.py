import json
import os
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "assets/original")

REQUIRED = [
    "player.male", "player.female",
    "tile.floor", "tile.wall", "tile.door.closed", "tile.door.open", "tile.stairs.down", "tile.stairs.up",
    "tile.grass", "tile.dirt", "tile.building", "tile.town.gate", "tile.palisade", "tile.mine.entrance", "tile.farmland", "tile.sign",
    "item.gold", "item.dagger", "item.short_sword", "item.club", "item.leather_armor", "item.small_shield",
    "item.helmet", "item.cloak", "item.boots", "item.gauntlets", "item.ring", "item.amulet", "item.belt",
    "item.pack",
]


class ManifestTest(unittest.TestCase):
    def setUp(self):
        with open(os.path.join(ART, "manifest.json")) as f:
            self.manifest = json.load(f)

    def test_required_names_present(self):
        sprites = self.manifest["sprites"]
        missing = [n for n in REQUIRED if n not in sprites]
        self.assertEqual(missing, [])
        for name, path in sprites.items():
            self.assertTrue(os.path.exists(os.path.join(ART, path)), f"{name} → {path}")
        self.assertEqual(self.manifest["tile_size"], 32)

    def test_monster_sprites_cover_data(self):
        monsters_json = os.path.join(ROOT, "data/monsters.json")
        if not os.path.exists(monsters_json):
            self.skipTest("monsters.json not extracted yet")
        with open(monsters_json) as f:
            monsters = json.load(f)
        for m in monsters:
            self.assertIn(m["sprite"], self.manifest["sprites"], m["id"])


if __name__ == "__main__":
    unittest.main()
