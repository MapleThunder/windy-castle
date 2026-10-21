"""Write 8-bit RGBA PNG files with the stdlib only."""
import struct
import zlib


def _chunk(kind, body):
    return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))


def write(path, width, height, rgba):
    if len(rgba) != width * height * 4:
        raise ValueError(f"expected {width * height * 4} bytes, got {len(rgba)}")
    stride = width * 4
    raw = b"".join(b"\0" + rgba[y * stride:(y + 1) * stride] for y in range(height))
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        f.write(_chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(_chunk(b"IEND", b""))
