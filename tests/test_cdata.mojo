from std.collections import List, Span

from cabi.export import (
    ARRAY_BYTES,
    DEVICE_BYTES,
    FLAG_NULLABLE,
    cstring_at,
    export_array,
    export_device,
    format_of,
    load_i64,
)
from runtime.model import TY_INT, ArrayRec, Columnar, FieldRec, bitmap_bytes, put_width


def main() raises:
    var c = Columnar()
    var f = FieldRec()
    f.name = c.intern("a")
    f.kind = TY_INT
    f.bit_width = 32
    f.is_signed = 1
    f.nullable = 1
    if format_of(f) != "i":
        raise Error("fmt")
    var fid = c.add_field(f)
    c.add_top(fid)
    var nulls = List[Int]()
    nulls.append(0)
    nulls.append(1)
    var bm = bitmap_bytes(2, nulls)
    var vals = List[Byte]()
    put_width(vals, 7, 4)
    put_width(vals, 0, 4)
    var a = ArrayRec()
    a.field = fid
    a.length = 2
    a.null_count = 1
    a.buf0 = len(c.abufs)
    a.nbuf = 2
    c.abufs.append(c.add_buf(Span(bm)))
    c.abufs.append(c.add_buf(Span(vals)))
    var aid = c.push_array(a)
    var ex = export_array(c, aid)
    var schema = ex.schema_addr()
    var fmt = cstring_at(load_i64(schema))
    if fmt != "i":
        raise Error("format ptr")
    if cstring_at(load_i64(schema + 8)) != "a":
        raise Error("name ptr")
    if load_i64(schema + 24) != FLAG_NULLABLE:
        raise Error("flags")
    var arr = ex.array_addr()
    if load_i64(arr) != 2 or load_i64(arr + 8) != 1 or load_i64(arr + 24) != 2:
        raise Error("array header")
    var bufs = load_i64(arr + 40)
    var values = load_i64(bufs + 8)
    var b0 = load_i64(values)
    if b0 != 7:
        raise Error("value")
    var dev = export_device(c, aid, 1, -1)
    if len(dev.bytes) < DEVICE_BYTES or ARRAY_BYTES != 80:
        raise Error("size")
    var d = dev.array_addr()
    if load_i64(d + 80) != -1 or load_i64(d) != 2:
        raise Error("device")
    print("ok")
