import os
import unittest

import hlp
import hlp_text

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HLP = os.path.join(ROOT, "reference/win31/games/drive-c/castwind/castle1/CASTLE1.HLP")


@unittest.skipUnless(os.path.exists(HLP), "original CASTLE1.HLP not present")
class HlpTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.topics = hlp.read_topics(HLP)

    def test_has_keyboard_topic(self):
        self.assertTrue(any("Keyboard" in t.title for t in self.topics),
                        [t.title for t in self.topics][:40])

    def test_bestiary_mentions(self):
        text = "\n".join(t.text for t in self.topics)
        self.assertIn("Giant Rat", text)
        self.assertIn("Kobold", text)

    def test_text_is_clean(self):
        for t in self.topics:
            self.assertNotIn("\x00", t.text, t.title)
        text = "".join(t.text for t in self.topics)
        printable = sum(1 for c in text if c.isprintable() or c in "\n\t")
        self.assertGreaterEqual(printable / max(1, len(text)), 0.9)

    def test_keyboard_commands(self):
        kb = hlp_text.keyboard_commands(self.topics)
        by_key = {}
        for row in kb:
            by_key.setdefault(row["keys"], []).append(row["command"])
        self.assertEqual(by_key["k"], ["North"])
        self.assertEqual(by_key["8"], ["North"])
        self.assertEqual(by_key["7"], ["Northwest"])
        self.assertIn("Get Command", by_key["g"])
        self.assertIn("Rest until player is fully healed", by_key["r"])
        self.assertIn("Rest until player's mana is restored", by_key["R"])
        self.assertTrue(by_key["s"][0].startswith("Search"))
        self.assertTrue(all(r["source"] == "hlp" for r in kb))
        self.assertNotIn("Options", by_key)


if __name__ == "__main__":
    unittest.main()
