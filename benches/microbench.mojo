from std.collections import List, Span
from std.time import perf_counter_ns

from runtime.model import TY_INT, TY_UTF8, ArrayRec, Columnar, FieldRec, put_width
from wire.ipc import decode_ipc_stream, encode_ipc_stream


def main() raises:
    var c = _table(32)
    var i = 0
    while i < 20:
        var warm = encode_ipc_stream(c)
        _ = decode_ipc_stream(Span(warm))
        i += 1
    var encode_ticks = 0
    var decode_ticks = 0
    var nbytes = 0
    i = 0
    while i < 50:
        var t0 = _ticks()
        var raw = encode_ipc_stream(c)
        var t1 = _ticks()
        var back = decode_ipc_stream(Span(raw))
        var t2 = _ticks()
        encode_ticks += t1 - t0
        decode_ticks += t2 - t1
        nbytes = len(raw)
        if len(back.batches) != 1:
            raise Error("bench")
        i += 1
    print("encode_ns", encode_ticks // 50)
    print("decode_ns", decode_ticks // 50)
    print("bytes", nbytes)


def _ticks() -> Int:
    return Int(perf_counter_ns())


def _table(n: Int) -> Columnar:
    var c = Columnar()
    var idf = FieldRec()
    idf.name = c.intern("id")
    idf.kind = TY_INT
    idf.bit_width = 64
    idf.is_signed = 1
    idf.nullable = 0
    var nf = FieldRec()
    nf.name = c.intern("name")
    nf.kind = TY_UTF8
    nf.nullable = 0
    var id_field = c.add_field(idf)
    var name_field = c.add_field(nf)
    c.add_top(id_field)
    c.add_top(name_field)
    var ids = List[Byte]()
    var off = List[Byte]()
    var data = List[Byte]()
    put_width(off, 0, 4)
    var i = 0
    while i < n:
        put_width(ids, i, 8)
        var text = String("item")
        var raw = text.as_bytes()
        var k = 0
        while k < len(raw):
            data.append(raw[k])
            k += 1
        put_width(off, len(data), 4)
        i += 1
    var id_arr = ArrayRec()
    id_arr.field = id_field
    id_arr.length = n
    id_arr.buf0 = len(c.abufs)
    id_arr.nbuf = 2
    c.abufs.append(c.add_empty_buf())
    c.abufs.append(c.add_buf(Span(ids)))
    var name_arr = ArrayRec()
    name_arr.field = name_field
    name_arr.length = n
    name_arr.buf0 = len(c.abufs)
    name_arr.nbuf = 3
    c.abufs.append(c.add_empty_buf())
    c.abufs.append(c.add_buf(Span(off)))
    c.abufs.append(c.add_buf(Span(data)))
    var cols = List[Int]()
    cols.append(c.push_array(id_arr))
    cols.append(c.push_array(name_arr))
    c.add_batch(n, cols)
    return c^
