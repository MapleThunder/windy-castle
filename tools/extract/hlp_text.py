"""Write help topics and the keyboard command table from a CotW .HLP file.

Usage: python3 -I tools/extract/hlp_text.py --hlp <CASTLE1.HLP> --out-root .
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I drops the script dir

import hlp


def _is_key(segment):
    return len(segment) == 1 and not segment.isspace()


def keyboard_commands(topics):
    topic = next(t for t in topics if t.title == "Keyboard")
    rows = []
    for para in topic.paragraphs:
        if para[:3] == ["Direction", "Alphabetic", "Numeric"]:
            cells = para[3:]
            for i in range(0, len(cells) - 2, 3):
                direction, alpha, numeric = cells[i:i + 3]
                for key in (alpha, numeric):
                    rows.append({"keys": key, "command": direction, "group": "movement", "source": "hlp"})
            continue
        # Command tables alternate "description", "key".
        for desc, key in zip(para, para[1:]):
            if _is_key(key) and not _is_key(desc) and len(desc) > 3:
                rows.append({"keys": key, "command": desc, "group": "command", "source": "hlp"})
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hlp", required=True)
    ap.add_argument("--out-root", default=".")
    args = ap.parse_args()
    topics = hlp.read_topics(args.hlp)
    kb = keyboard_commands(topics)
    if len(topics) < 100 or len(kb) < 20:
        sys.exit(f"sanity check failed: {len(topics)} topics, {len(kb)} key bindings")
    data = os.path.join(args.out_root, "data")
    os.makedirs(data, exist_ok=True)
    for name, obj in (("help.json", [{"title": t.title, "text": t.text} for t in topics]),
                      ("keyboard.json", kb)):
        with open(os.path.join(data, name), "w", encoding="utf-8") as f:
            json.dump(obj, f, indent=1, ensure_ascii=False)
            f.write("\n")
    print(f"wrote {len(topics)} topics, {len(kb)} key bindings")


if __name__ == "__main__":
    main()
