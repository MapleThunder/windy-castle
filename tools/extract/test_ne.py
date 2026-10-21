import os
import struct
import tempfile
import unittest
import zlib

import pe_ne
import png
import ne_resources

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EXE = os.path.join(ROOT, "reference/win31/games/drive-c/castwind/castle1/CASTLE1.EXE")


def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, idat, w, h = 8, b"", 0, 0
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h = struct.unpack(">II", body[:8])
        elif kind == b"IDAT":
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    rows = [raw[y * (w * 4 + 1) + 1:(y + 1) * (w * 4 + 1)] for y in range(h)]
    return w, h, b"".join(rows)


class PngTest(unittest.TestCase):
    def test_png_roundtrip(self):
        rgba = bytes([255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 0, 0, 0, 0])
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "t.png")
            png.write(p, 2, 2, rgba)
            self.assertEqual(read_png(p), (2, 2, rgba))


@unittest.skipUnless(os.path.exists(EXE), "original CASTLE1.EXE not present")
class NETest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ne = pe_ne.read(EXE)

    def test_resource_counts(self):
        res = self.ne.resources
        self.assertEqual(len(res[3]), 457)
        self.assertEqual(len(res[2]), 98)
        self.assertEqual(len(res[4]), 3)
        self.assertNotIn(9, res)

    def test_icon_decodes_with_alpha(self):
        icons = [r for r in self.ne.resources[3] if ne_resources.dib_bpp(r.data) == 4]
        decoded = [ne_resources.decode_icon(r.data) for r in icons]
        self.assertTrue(all((w, h, len(px)) == (32, 32, 4096) for w, h, px in decoded))
        transparent = [px for _, _, px in decoded if 0 in px[3::4]]
        self.assertGreaterEqual(len(transparent), 200)  # sprites carry an AND mask
        self.assertTrue(all(255 in px[3::4] for _, _, px in decoded))

    def test_menu_parse(self):
        menus = [ne_resources.parse_menu(r.data) for r in self.ne.resources[4]]
        titles = [m["label"] for m in menus[0]]
        self.assertEqual(titles, ["File", "Character", "Inventory", "Map", "Spells",
                                  "Activate", "Verbs", "Window", "Help"])
        self.assertIn("mnemonic", menus[0][0])

        def labels(items):
            for it in items:
                yield it["label"]
                yield from labels(it.get("items", []))

        self.assertIn("Sort Pack", list(labels(menus[1])))

    def test_all_bitmaps_decode(self):
        for r in self.ne.resources[2]:
            w, h, px = ne_resources.decode_bitmap(r.data)
            self.assertEqual(len(px), w * h * 4, f"bitmap {r.id}")

    def test_segments(self):
        self.assertEqual(len(self.ne.segments), 32)
        self.assertTrue(self.ne.segments[31].is_data)
        self.assertIn(b"Giant Rat", self.ne.segments[12].data)


if __name__ == "__main__":
    unittest.main()
