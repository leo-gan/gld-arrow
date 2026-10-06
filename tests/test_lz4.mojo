from std.collections import List, Span

from compress.lz4 import lz4_frame_compress, lz4_frame_decompress
from compress.xxh import xxh32


def main() raises:
    var empty = List[Byte]()
    if Int(xxh32(Span(empty))) != 0x02CC5D05:
        raise Error("xxh")
    _round("hello hello hello hello")
    _round("abc")
    _round("")
    var raw = open("testdata/golden/lz4-hello.lz4", "r").read_bytes()
    var got = lz4_frame_decompress(raw)
    var expect = String("hello hello hello hello hello")
    if String(unsafe_from_utf8=Span(got)) != expect:
        raise Error("pyarrow")
    print("ok", len(got))


def _round(text: String) raises:
    var src = List[Byte]()
    var raw = text.as_bytes()
    var i = 0
    while i < len(raw):
        src.append(raw[i])
        i += 1
    var comp = lz4_frame_compress(src)
    var back = lz4_frame_decompress(comp)
    if len(back) != len(src):
        raise Error("len")
    i = 0
    while i < len(src):
        if back[i] != src[i]:
            raise Error("byte")
        i += 1
