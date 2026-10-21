"""Render every extracted icon in a labelled grid, to help name them.

Usage: python3 -I tools/extract/contact_sheet.py --icons assets/original/icons --out sheet.png [--start N --count N]
"""
import argparse
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I drops the script dir

import png

DIGITS = {  # 3x5 bitmap font
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
    "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001001001",
    "8": "111101111101111", "9": "111101111001111",
}


def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    pos, idat, w, h = 8, b"", 0, 0
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        if kind == b"IHDR":
            w, h = struct.unpack(">II", data[pos + 8:pos + 16])
        elif kind == b"IDAT":
            idat += data[pos + 8:pos + 8 + n]
        pos += 12 + n
    raw = zlib.decompress(idat)
    return w, h, b"".join(raw[y * (w * 4 + 1) + 1:(y + 1) * (w * 4 + 1)] for y in range(h))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--icons", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--count", type=int, default=10_000)
    ap.add_argument("--cols", type=int, default=12)
    ap.add_argument("--scale", type=int, default=2)
    args = ap.parse_args()
    ids = sorted(int(f[:-4]) for f in os.listdir(args.icons) if f.endswith(".png"))
    ids = ids[args.start:args.start + args.count]
    s = args.scale
    cw, ch = 32 * s + 6, 32 * s + 18
    rows = (len(ids) + args.cols - 1) // args.cols
    W, H = args.cols * cw, rows * ch
    canvas = bytearray(bytes((40, 40, 48, 255)) * (W * H))

    def put(x, y, rgb):
        if 0 <= x < W and 0 <= y < H:
            canvas[(y * W + x) * 4:(y * W + x) * 4 + 4] = bytes((*rgb, 255))

    for n, icon_id in enumerate(ids):
        ox, oy = (n % args.cols) * cw + 3, (n // args.cols) * ch + 2
        w, h, px = read_png(os.path.join(args.icons, f"{icon_id}.png"))
        for y in range(h * s):
            for x in range(w * s):
                i = ((y // s) * w + x // s) * 4
                if px[i + 3]:
                    put(ox + x, oy + y, px[i:i + 3])
                elif (x // 8 + y // 8) % 2:
                    put(ox + x, oy + y, (60, 60, 70))
        for k, ch_ in enumerate(str(icon_id)):
            for b, bit in enumerate(DIGITS[ch_]):
                if bit == "1":
                    for dy in range(2):
                        for dx in range(2):
                            put(ox + k * 8 + (b % 3) * 2 + dx, oy + 32 * s + 3 + (b // 3) * 2 + dy, (255, 230, 120))
    png.write(args.out, W, H, bytes(canvas))
    print(f"{args.out}: {len(ids)} icons ({ids[0]}..{ids[-1]})")


if __name__ == "__main__":
    main()
