"""Build assets/original/manifest.json: icon names plus generated base terrain tiles.

The original draws open terrain as flat palette colours and uses the 32×32
transition bitmaps (19–54) for the diagonal edges between them, so the base
tiles here are solid fills in those exact palette colours.

Usage: python3 -I tools/extract/manifest.py --names tools/extract/icon_names.json --out-root .
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I drops the script dir

import png
from contact_sheet import read_png

# source: exe — colours sampled from transition bitmaps 19–54.
BASE_TILES = {
    "tile.floor": (255, 255, 255),
    "tile.wall": (128, 128, 128),
    "tile.stone": (192, 192, 192),
    "tile.building": (192, 192, 192),
    "tile.grass": (0, 128, 0),
    "tile.dirt": (128, 128, 0),
    "tile.water": (0, 0, 255),
}

# source: exe — transition bitmaps, named <a>.<b>.<corner the first terrain fills>.
TRANSITIONS = {
    "stone.floor": (19, 22), "stone.floor_lit": (23, 26), "stone.dirt": (27, 30),
    "dirt.grass": (31, 34), "grass.water": (35, 38), "wall.grass": (39, 40),
    "wall.floor": (41, 48), "dirt.wall": (49, 52), "wall.grass_edge": (53, 54),
}


def build(names_path, out_root):
    art = os.path.join(out_root, "assets/original")
    with open(names_path) as f:
        sprites = {k: v for k, v in json.load(f).items() if not k.startswith("_")}
    tiles = os.path.join(art, "tiles")
    os.makedirs(tiles, exist_ok=True)
    for name, rgb in BASE_TILES.items():
        path = f"tiles/{name.split('.', 1)[1]}.png"
        png.write(os.path.join(art, path), 32, 32, bytes((*rgb, 255)) * 1024)
        sprites[name] = path
    # source: exe — the palisade tile is the leftmost 32×32 of the hamlet fence bitmap.
    w, h, px = read_png(os.path.join(art, "bitmaps/193.png"))
    crop = b"".join(px[y * w * 4:(y * w + 32) * 4] for y in range(32))
    png.write(os.path.join(art, "tiles/palisade.png"), 32, 32, crop)
    sprites["tile.palisade"] = "tiles/palisade.png"
    # The hamlet's farmland border: green with furrows, after the hatched fields in the original.
    rows = []
    for y in range(32):
        rgb = {0: (60, 100, 20), 1: (0, 112, 0)}.get(y % 3, (0, 128, 0))
        rows.append(bytes((*rgb, 255)) * 32)
    png.write(os.path.join(art, "tiles/farmland.png"), 32, 32, b"".join(rows))
    sprites["tile.farmland"] = "tiles/farmland.png"
    for name, (first, last) in TRANSITIONS.items():
        for i, bm in enumerate(range(first, last + 1)):
            sprites[f"edge.{name}.{i}"] = f"bitmaps/{bm}.png"
    missing = [p for p in sprites.values() if not os.path.exists(os.path.join(art, p))]
    if missing:
        sys.exit(f"missing files: {missing}")
    manifest = {"tile_size": 32, "sprites": dict(sorted(sprites.items()))}
    with open(os.path.join(art, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")
    return manifest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--names", required=True)
    ap.add_argument("--out-root", default=".")
    args = ap.parse_args()
    print(f"manifest: {len(build(args.names, args.out_root)['sprites'])} sprites")


if __name__ == "__main__":
    main()
