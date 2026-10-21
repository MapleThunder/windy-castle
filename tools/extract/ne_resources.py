"""Extract icons, bitmaps, menus, dialogs and story text from a Castle of the Winds EXE.

Usage: python3 -I tools/extract/ne_resources.py --exe <CASTLE1.EXE> --out-root .
"""
import argparse
import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # python3 -I drops the script dir

import pe_ne
import png

MF_POPUP, MF_END = 0x10, 0x80
DIALOG_CLASSES = {0x80: "button", 0x81: "edit", 0x82: "static", 0x83: "listbox",
                  0x84: "scrollbar", 0x85: "combobox"}


def dib_bpp(data):
    size = struct.unpack_from("<I", data, 0)[0]
    return struct.unpack_from("<H", data, 10 if size == 12 else 14)[0]


def _dib_header(data):
    size = struct.unpack_from("<I", data, 0)[0]
    if size == 12:
        w, h, _, bpp = struct.unpack_from("<HHHH", data, 4)
        return size, w, h, bpp, 3, 1 << bpp
    w, h, _, bpp = struct.unpack_from("<iiHH", data, 4)
    used = struct.unpack_from("<I", data, 32)[0]
    return size, w, h, bpp, 4, used or (1 << bpp if bpp <= 8 else 0)


def _decode_pixels(data, offset, w, h, bpp, palette):
    """Bottom-up indexed DIB → list of rows (top-down) of (r, g, b)."""
    stride = ((w * bpp + 31) // 32) * 4
    rows = []
    for y in range(h):
        row = data[offset + (h - 1 - y) * stride:offset + (h - y) * stride]
        px = []
        for x in range(w):
            bit = x * bpp
            byte = row[bit // 8]
            idx = (byte >> (8 - bpp - bit % 8)) & ((1 << bpp) - 1)
            px.append(palette[idx])
        rows.append(px)
    return rows, offset + h * stride


def _palette(data, hsize, entry, count):
    return [(data[hsize + i * entry + 2], data[hsize + i * entry + 1], data[hsize + i * entry])
            for i in range(count)]


def decode_icon(data):
    hsize, w, h2, bpp, entry, count = _dib_header(data)
    h = h2 // 2
    pal = _palette(data, hsize, entry, count)
    color, off = _decode_pixels(data, hsize + entry * count, w, h, bpp, pal)
    mask, _ = _decode_pixels(data, off, w, h, 1, [(0, 0, 0), (255, 255, 255)])
    out = bytearray()
    for y in range(h):
        for x in range(w):
            transparent = mask[y][x][0] == 255
            r, g, b = color[y][x]
            out += bytes((r, g, b, 0 if transparent else 255))
    return w, h, bytes(out)


def _decode_rle4(data, offset, w, h, palette):
    """BI_RLE4 → top-down rows of (r, g, b). Unset pixels take palette index 0."""
    idx = [[0] * w for _ in range(h)]
    x = y = 0
    p = offset
    while p + 1 < len(data):
        count, value = data[p], data[p + 1]
        p += 2
        if count:
            for i in range(count):
                if x < w and y < h:
                    idx[y][x] = value >> 4 if i % 2 == 0 else value & 0xF
                x += 1
        elif value == 0:
            x, y = 0, y + 1
        elif value == 1:
            break
        elif value == 2:
            x, y = x + data[p], y + data[p + 1]
            p += 2
        else:
            for i in range(value):
                b = data[p + i // 2]
                if x < w and y < h:
                    idx[y][x] = b >> 4 if i % 2 == 0 else b & 0xF
                x += 1
            p += ((value + 3) // 4) * 2
    return [[palette[i] for i in row] for row in reversed(idx)]


def decode_bitmap(data):
    hsize, w, h, bpp, entry, count = _dib_header(data)
    compression = struct.unpack_from("<I", data, 16)[0] if hsize == 40 else 0
    pal = _palette(data, hsize, entry, count)
    if compression == 2:
        rows = _decode_rle4(data, hsize + entry * count, w, h, pal)
    elif compression == 0 and bpp <= 8:
        rows, _ = _decode_pixels(data, hsize + entry * count, w, h, bpp, pal)
    else:
        raise ValueError(f"unsupported bitmap: {bpp} bpp, compression {compression}")
    return w, h, b"".join(bytes((r, g, b, 255)) for row in rows for (r, g, b) in row)


def _cstr(data, p):
    end = data.index(b"\0", p)
    return data[p:end].decode("cp1252"), end + 1


def _label(raw):
    text, _, shortcut = raw.partition("\t")
    mnemonic = ""
    if "&" in text:
        i = text.index("&")
        mnemonic = text[i + 1:i + 2].upper()
    entry = {"label": text.replace("&", "").rstrip("!").strip(), "mnemonic": mnemonic}
    if shortcut:
        entry["shortcut"] = shortcut
    return entry


def parse_menu(data):
    p = 4  # MENUITEMTEMPLATEHEADER: version, offset

    def items():
        nonlocal p
        out = []
        while True:
            flags = struct.unpack_from("<H", data, p)[0]
            p += 2
            if flags & MF_POPUP:
                text, p = _cstr(data, p)
                entry = _label(text)
                entry["items"] = items()
            else:
                cmd = struct.unpack_from("<H", data, p)[0]
                p += 2
                text, p = _cstr(data, p)
                entry = _label(text) if text else {"separator": True}
                if text:
                    entry["id"] = cmd
            out.append(entry)
            if flags & MF_END:
                return out

    return items()


def parse_dialog(data):
    style, count, x, y, cx, cy = struct.unpack_from("<IBHHHH", data, 0)
    p = 13
    if data[p] == 0xFF:
        p += 3
    else:
        _, p = _cstr(data, p)
    _, p = _cstr(data, p)  # class
    caption, p = _cstr(data, p)
    dlg = {"caption": caption, "rect": [x, y, cx, cy], "controls": []}
    if style & 0x40:  # DS_SETFONT
        point = struct.unpack_from("<H", data, p)[0]
        face, p = _cstr(data, p + 2)
        dlg["font"] = [face, point]
    for _ in range(count):
        ix, iy, icx, icy, cid, cstyle = struct.unpack_from("<HHHHHI", data, p)
        p += 14
        if data[p] >= 0x80:
            cls = DIALOG_CLASSES.get(data[p], hex(data[p]))
            p += 1
        else:
            cls, p = _cstr(data, p)
        if data[p] == 0xFF:
            text = f"#{struct.unpack_from('<H', data, p + 1)[0]}"
            p += 3
        else:
            text, p = _cstr(data, p)
        p += 1 + data[p]
        dlg["controls"].append({"class": cls, "id": cid, "text": text,
                                "rect": [ix, iy, icx, icy], "style": cstyle})
    return dlg


def extract(exe, out_root):
    ne = pe_ne.read(exe)
    icons = os.path.join(out_root, "assets/original/icons")
    bitmaps = os.path.join(out_root, "assets/original/bitmaps")
    data_dir = os.path.join(out_root, "data")
    for d in (icons, bitmaps, data_dir):
        os.makedirs(d, exist_ok=True)

    n_icons = 0
    for r in ne.resources[pe_ne.RT_ICON]:
        if dib_bpp(r.data) != 4:
            continue  # monochrome duplicates
        png.write(os.path.join(icons, f"{r.id}.png"), *decode_icon(r.data))
        n_icons += 1
    for r in ne.resources[pe_ne.RT_BITMAP]:
        png.write(os.path.join(bitmaps, f"{r.id}.png"), *decode_bitmap(r.data))

    def dump(name, obj):
        with open(os.path.join(data_dir, name), "w", encoding="utf-8") as f:
            json.dump(obj, f, indent=1, ensure_ascii=False)
            f.write("\n")

    dump("menus.json", [{"id": r.id, "items": parse_menu(r.data)} for r in ne.resources[pe_ne.RT_MENU]])
    dump("dialogs.json", [{"id": r.id, **parse_dialog(r.data)} for r in ne.resources[pe_ne.RT_DIALOG]])
    dump("story.json", [{"id": r.id, "text": r.data.split(b"\0")[0].decode("cp1252").lstrip("#")}
                        for r in ne.resources[pe_ne.RT_STORY]])
    return n_icons, len(ne.resources[pe_ne.RT_BITMAP])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", required=True)
    ap.add_argument("--out-root", default=".")
    args = ap.parse_args()
    n_icons, n_bitmaps = extract(args.exe, args.out_root)
    print(f"wrote {n_icons} icons, {n_bitmaps} bitmaps")


if __name__ == "__main__":
    sys.exit(main())
