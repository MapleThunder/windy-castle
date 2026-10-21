"""Reader for WinHelp 3.x .HLP files: internal file system, LZ77, phrases, topic text."""
import struct
from dataclasses import dataclass, field

MAGIC = 0x00035F3F


@dataclass
class Topic:
    title: str
    text: str
    paragraphs: list = field(default_factory=list)  # each paragraph as its \0-separated segments


def lz77(data, limit=None):
    out = bytearray()
    p = 0
    while p < len(data):
        flags = data[p]
        p += 1
        for bit in range(8):
            if p >= len(data):
                break
            if flags & (1 << bit):
                if p + 1 >= len(data):
                    break
                w = data[p] | (data[p + 1] << 8)
                p += 2
                dist, length = (w & 0xFFF) + 1, (w >> 12) + 3
                for _ in range(length):
                    out.append(out[-dist] if dist <= len(out) else 0x20)
            else:
                out.append(data[p])
                p += 1
            if limit is not None and len(out) >= limit:
                return bytes(out[:limit])
    return bytes(out)


class HelpFile:
    def __init__(self, path):
        with open(path, "rb") as f:
            self.data = f.read()
        magic, dir_start = struct.unpack_from("<II", self.data, 0)
        if magic != MAGIC:
            raise ValueError(f"{path}: not a WinHelp file")
        self.files = self._read_directory(dir_start)

    def _internal(self, offset):
        _reserved, used, _flags = struct.unpack_from("<IIB", self.data, offset)
        return self.data[offset + 9:offset + 9 + used]

    @staticmethod
    def _btree_leaves(tree):
        """Yield the raw bytes of each leaf page's entries, in key order, with their count."""
        magic, _flags, page_size = struct.unpack_from("<HHH", tree, 0)
        if magic != 0x293B:
            raise ValueError("bad B+ tree")
        root, _neg1, _total, levels = struct.unpack_from("<HhHH", tree, 26)
        pages = tree[38:]
        page = root
        for _ in range(levels - 1):  # descend to the leftmost leaf
            page = struct.unpack_from("<H", pages, page * page_size + 6)[0]
        while page != 0xFFFF:
            base = page * page_size
            _unused, count, _prev, nxt = struct.unpack_from("<HHhH", pages, base)
            yield pages[base + 8:base + page_size], count
            page = nxt

    def _read_directory(self, offset):
        files = {}
        for body, count in self._btree_leaves(self._internal(offset)):
            p = 0
            for _ in range(count):
                end = body.index(b"\0", p)
                files[body[p:end].decode("cp1252")] = struct.unpack_from("<I", body, end + 1)[0]
                p = end + 5
        return files

    def titles(self):
        """Topic titles from |TTLBTREE, in topic order."""
        if "|TTLBTREE" not in self.files:
            return []
        out = []
        for body, count in self._btree_leaves(self.file("|TTLBTREE")):
            p = 0
            for _ in range(count):
                end = body.index(b"\0", p + 4)
                out.append(body[p + 4:end].decode("cp1252"))
                p = end + 1
        return out

    def file(self, name):
        return self._internal(self.files[name])

    def system(self):
        s = self.file("|SYSTEM")
        _magic, minor, _major, _date, flags = struct.unpack_from("<HHHIH", s, 0)
        return minor, flags

    def phrases(self):
        if "|Phrases" not in self.files:
            return []
        raw = self.file("|Phrases")
        count, _hundred = struct.unpack_from("<HH", raw, 0)
        minor, _ = self.system()
        if minor <= 16:
            offsets = struct.unpack_from(f"<{count + 1}H", raw, 4)
            blob = raw[4:]  # offsets count from the end of the 4-byte header
            base = 0
        else:
            size = struct.unpack_from("<I", raw, 4)[0]
            offsets = struct.unpack_from(f"<{count + 1}H", raw, 8)
            start = 8 + (count + 1) * 2
            blob = lz77(raw[start:], size)
            base = offsets[0]
        return [blob[offsets[i] - base:offsets[i + 1] - base].decode("cp1252") for i in range(count)]

    def topic_stream(self):
        """Decompressed |TOPIC contents and a TOPICPOS → stream-offset function."""
        minor, flags = self.system()
        compressed = minor > 16 and flags in (4, 8)
        block_size = 2048 if (minor <= 16 or flags == 8) else 4096
        raw = self.file("|TOPIC")
        stream = bytearray()
        starts = []
        for b in range(0, len(raw), block_size):
            body = raw[b + 12:b + block_size]
            starts.append(len(stream))
            stream += lz77(body, 0x4000 - 12) if compressed else body
        if compressed:
            def locate(pos):
                return starts[pos >> 14] + (pos & 0x3FFF) - 12
        else:
            def locate(pos):
                return (pos // block_size) * (block_size - 12) + (pos % block_size) - 12
        first = struct.unpack_from("<I", raw, 4)[0]
        return bytes(stream), locate, first


def _expand(data, phrases):
    out = []
    i = 0
    while i < len(data):
        c = data[i]
        if 1 <= c <= 9 and i + 1 < len(data) and phrases:
            d = data[i + 1]
            index = 128 * (c - 1) + d // 2
            out.append(phrases[index] if index < len(phrases) else "")
            if d & 1:
                out.append(" ")
            i += 2
        else:
            out.append(bytes([c]).decode("cp1252", errors="replace"))
            i += 1
    return "".join(out)


TEXT_RECORDS = (0x01, 0x20, 0x23)  # 3.0 text, 3.1 text, 3.1 table
TOPIC_HEADER = 0x02


def _records(hf):
    """Yield (record_type, linkdata2_text) for every TOPICLINK in order."""
    phrases = hf.phrases()
    stream, locate, first = hf.topic_stream()
    minor, _ = hf.system()
    off = 0 if minor <= 16 else locate(first)
    seen = set()
    while 0 <= off and off + 21 <= len(stream) and off not in seen:
        seen.add(off)
        block, len2, _prev, nxt, len1, rtype = struct.unpack_from("<IIIIIB", stream, off)
        if block < 21:
            break
        link2 = stream[off + len1:off + block]
        text = _expand(link2, phrases) if len2 > len(link2) else link2.decode("cp1252", errors="replace")
        yield rtype, text
        if minor <= 16:
            off += block
            chunk = 2048 - 12
            if chunk - off % chunk < 21:  # a link header never straddles a block
                off += chunk - off % chunk
        elif nxt in (0xFFFFFFFF,):
            break
        else:
            off = locate(nxt)


def read_topics(path):
    hf = HelpFile(path)
    topics = []
    for rtype, text in _records(hf):
        if rtype == TOPIC_HEADER:
            topics.append(Topic("", ""))
        elif rtype in TEXT_RECORDS and topics:
            para = _paragraph(text)
            if para:
                topics[-1].text += para + "\n"
                topics[-1].paragraphs.append([p.strip() for p in text.split("\0") if p.strip()])
    for t in topics:
        t.text = t.text.strip()
    topics = [t for t in topics if t.text]
    titles = hf.titles()
    for i, t in enumerate(topics):
        if len(titles) == len(topics):
            t.title = titles[i]
        else:
            t.title = t.text.split("\n", 1)[0][:80]
    return topics


def _paragraph(text):
    parts = [p for p in text.split("\0")]
    return " ".join(p.strip() for p in parts if p.strip())
