from std.collections import List, Span

from runtime.model import (
    TY_INT,
    ArrayRec,
    Columnar,
    FieldRec,
    bitmap_bytes,
    put_width,
    read_width,
)
from wire.ipc import decode_ipc_file, decode_ipc_stream, encode_ipc_file, encode_ipc_stream


def main() raises:
    var c = _sample()
    var stream = encode_ipc_stream(c)
    var back = decode_ipc_stream(Span(stream))
    _check(back)
    var file = encode_ipc_file(c)
    var back_file = decode_ipc_file(Span(file))
    _check(back_file)
    var f = open("/tmp/gld-arrow-int.arrows", "w")
    f.write_bytes(Span(stream))
    f.close()
    var g = open("/tmp/gld-arrow-int.arrow", "w")
    g.write_bytes(Span(file))
    g.close()
    _compressed()
    print("ok", len(stream), len(file))


def _sample() -> Columnar:
    var c = Columnar()
    var f = FieldRec()
    f.name = c.intern("a")
    f.kind = TY_INT
    f.bit_width = 32
    f.is_signed = 1
    f.nullable = 1
    var fid = c.add_field(f)
    c.add_top(fid)
    var nulls = List[Int]()
    nulls.append(0)
    nulls.append(1)
    nulls.append(0)
    var bm = bitmap_bytes(3, nulls)
    var vals = List[Byte]()
    put_width(vals, 1, 4)
    put_width(vals, 0, 4)
    put_width(vals, 3, 4)
    var a = ArrayRec()
    a.field = fid
    a.length = 3
    a.null_count = 1
    a.buf0 = len(c.abufs)
    a.nbuf = 2
    c.abufs.append(c.add_buf(Span(bm)))
    c.abufs.append(c.add_buf(Span(vals)))
    var cols = List[Int]()
    cols.append(c.push_array(a))
    c.add_batch(3, cols)
    return c^


def _compressed() raises:
    var plain = _zeros()
    var bare = encode_ipc_stream(plain)
    var lz = _zeros()
    lz.codec = 0
    var lz_bytes = encode_ipc_stream(lz)
    var lz_back = decode_ipc_stream(Span(lz_bytes))
    if lz_back.codec != 0 or len(lz_bytes) >= len(bare):
        raise Error("lz4 ipc")
    _zero_value(lz_back)
    var zs = _zeros()
    zs.codec = 1
    var zs_bytes = encode_ipc_stream(zs)
    var zs_back = decode_ipc_stream(Span(zs_bytes))
    if zs_back.codec != 1 or len(zs_bytes) >= len(bare):
        raise Error("zstd ipc")
    _zero_value(zs_back)
    if (zs_back.features & 2) == 0:
        raise Error("feature")
    var zf = open("/tmp/gld-arrow-zstd.arrows", "w")
    zf.write_bytes(Span(zs_bytes))
    zf.close()
    var lf = open("/tmp/gld-arrow-lz4.arrows", "w")
    lf.write_bytes(Span(lz_bytes))
    lf.close()


def _zeros() -> Columnar:
    var c = Columnar()
    var f = FieldRec()
    f.name = c.intern("z")
    f.kind = TY_INT
    f.bit_width = 32
    f.is_signed = 1
    f.nullable = 0
    var fid = c.add_field(f)
    c.add_top(fid)
    var vals = List[Byte]()
    var i = 0
    while i < 64:
        put_width(vals, 0, 4)
        i += 1
    var a = ArrayRec()
    a.field = fid
    a.length = 64
    a.null_count = 0
    a.buf0 = len(c.abufs)
    a.nbuf = 2
    var empty = List[Byte]()
    c.abufs.append(c.add_buf(Span(empty)))
    c.abufs.append(c.add_buf(Span(vals)))
    var cols = List[Int]()
    cols.append(c.push_array(a))
    c.add_batch(64, cols)
    return c^


def _zero_value(c: Columnar) raises:
    var aid = c.batch_cols[0]
    var values = c.buf_copy(c.abufs[c.arrays[aid].buf0 + 1])
    if read_width(values, 0, 4, True) != 0 or read_width(values, 252, 4, True) != 0:
        raise Error("zero value")


def _check(c: Columnar) raises:
    if len(c.top) != 1:
        raise Error("top")
    if len(c.batches) != 1:
        raise Error("batches")
    if c.strings[c.fields[c.top[0]].name] != "a":
        raise Error("name")
    var aid = c.batch_cols[0]
    var arr = c.arrays[aid]
    if arr.length != 3 or arr.null_count != 1:
        raise Error("len")
    var values = c.buf_copy(c.abufs[arr.buf0 + 1])
    if read_width(values, 0, 4, True) != 1:
        raise Error("v0")
    if read_width(values, 8, 4, True) != 3:
        raise Error("v2")
