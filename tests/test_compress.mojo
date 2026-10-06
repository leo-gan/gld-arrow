from std.collections import List

from compress.frame import frame_compress, frame_decompress
from runtime.error import DecodeError


def main() raises:
    _round(0)
    _round(1)
    _file(0, "testdata/golden/lz4-hello.lz4", _text("hello hello hello hello hello"))
    _file(1, "testdata/golden/zstd-empty.zst", List[Byte]())
    _file(1, "testdata/golden/zstd-a.zst", _text("a"))
    _file(1, "testdata/golden/zstd-hello.zst", _text("hello"))
    _file(1, "testdata/golden/zstd-rep.zst", _text("hello hello hello hello hello"))
    _file(1, "testdata/golden/zstd-abc.zst", _repeat_text("abc", 100))
    _file(1, "testdata/golden/zstd-zeros.zst", _fill(0, 1000))
    _file(1, "testdata/golden/zstd-text.zst", _repeat_text("The quick brown fox jumps over the lazy dog. ", 40))
    _file(1, "testdata/golden/zstd-random.zst", _mod(256, 1024))
    _file(1, "testdata/golden/zstd-mix.zst", _mod(17, 5000))
    _file(1, "testdata/golden/zstd-checksum.zst", _text("hello"))
    _file(1, "testdata/golden/zstd-skip.zst", _text("hello"))
    var rejected = 0
    try:
        _file(1, "testdata/golden/zstd-dict.zst", List[Byte]())
    except DecodeError:
        rejected = 1
    if rejected == 0:
        raise Error("dict")
    var zeros = _fill(0, 4000)
    var raw = frame_compress(1, zeros)
    if len(raw) >= len(zeros):
        raise Error("rle size")
    print("ok")


def _round(codec: Int) raises:
    var empty = List[Byte]()
    _one(codec, empty)
    _one(codec, _text("a"))
    _one(codec, _text("hello"))
    _one(codec, _fill(97, 400))
    _one(codec, _fill(0, 180))
    _one(codec, _pattern(360))
    _one(codec, _repeat_text("abc", 80))


def _one(codec: Int, raw: List[Byte]) raises:
    var comp = frame_compress(codec, raw)
    var back = frame_decompress(codec, comp)
    _eq(back, raw)


def _file(codec: Int, path: String, expect: List[Byte]) raises:
    var raw = _load(path)
    var got = frame_decompress(codec, raw)
    _eq(got, expect)


def _eq(got: List[Byte], expect: List[Byte]) raises:
    if len(got) != len(expect):
        raise Error("len")
    var i = 0
    while i < len(expect):
        if got[i] != expect[i]:
            raise Error("byte")
        i += 1


def _load(path: String) raises -> List[Byte]:
    var file = open(path, "r").read_bytes()
    var raw = List[Byte]()
    var i = 0
    while i < len(file):
        raw.append(file[i])
        i += 1
    return raw^


def _text(text: String) -> List[Byte]:
    var raw = List[Byte]()
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        raw.append(b[i])
        i += 1
    return raw^


def _repeat_text(text: String, n: Int) -> List[Byte]:
    var raw = List[Byte]()
    var b = text.as_bytes()
    var k = 0
    while k < n:
        var i = 0
        while i < len(b):
            raw.append(b[i])
            i += 1
        k += 1
    return raw^


def _fill(value: Int, n: Int) -> List[Byte]:
    var raw = List[Byte]()
    raw.resize(n, Byte(value))
    return raw^


def _pattern(n: Int) -> List[Byte]:
    var raw = List[Byte]()
    var i = 0
    while i < n:
        raw.append(Byte((i * 17 + 3) & 255))
        i += 1
    return raw^


def _mod(base: Int, n: Int) -> List[Byte]:
    var raw = List[Byte]()
    var i = 0
    while i < n:
        raw.append(Byte(i % base))
        i += 1
    return raw^
