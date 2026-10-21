"""Minimal reader for Win16 New Executable (NE) files: segments and resources."""
import struct
from dataclasses import dataclass

RT_CURSOR, RT_BITMAP, RT_ICON, RT_MENU, RT_DIALOG = 1, 2, 3, 4, 5
RT_STORY, RT_METAFILE = 0x104, 0x105  # CotW custom types (story text, WMF pictures)


@dataclass
class Segment:
    index: int
    data: bytes
    is_data: bool


@dataclass
class Resource:
    id: int
    data: bytes


@dataclass
class NEFile:
    segments: list
    resources: dict


def read(path):
    with open(path, "rb") as f:
        d = f.read()
    ne = struct.unpack_from("<I", d, 0x3C)[0]
    if d[ne:ne + 2] != b"NE":
        raise ValueError(f"{path}: not an NE executable")
    nseg = struct.unpack_from("<H", d, ne + 0x1C)[0]
    seg_table = ne + struct.unpack_from("<H", d, ne + 0x22)[0]
    res_table = ne + struct.unpack_from("<H", d, ne + 0x24)[0]
    align = struct.unpack_from("<H", d, ne + 0x32)[0]

    segments = []
    for i in range(nseg):
        off, length, flags, _ = struct.unpack_from("<HHHH", d, seg_table + i * 8)
        length = length or 0x10000
        start = off << align
        segments.append(Segment(i + 1, d[start:start + length], bool(flags & 1)))

    shift = struct.unpack_from("<H", d, res_table)[0]
    resources = {}
    p = res_table + 2
    while True:
        rtype = struct.unpack_from("<H", d, p)[0]
        if rtype == 0:
            break
        count = struct.unpack_from("<H", d, p + 2)[0]
        p += 8
        for _ in range(count):
            off, length, _flags, rid = struct.unpack_from("<HHHH", d, p)
            p += 12
            start = off << shift
            resources.setdefault(rtype & 0x7FFF, []).append(
                Resource(rid & 0x7FFF, d[start:start + (length << shift)]))
    return NEFile(segments, resources)
