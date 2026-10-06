from std.collections import List, Span

from runtime.model import TY_INT, ArrayRec, Columnar, FieldRec, bitmap_bytes, put_width
from wire.ipc import encode_ipc_stream


def main() raises:
    var c = Columnar()
    var field = FieldRec()
    field.name = c.intern("a")
    field.kind = TY_INT
    field.bit_width = 32
    field.is_signed = 1
    field.nullable = 1
    var fid = c.add_field(field)
    c.add_top(fid)
    var nulls = List[Int]()
    nulls.append(0)
    nulls.append(1)
    nulls.append(0)
    var bitmap = bitmap_bytes(3, nulls)
    var values = List[Byte]()
    put_width(values, 1, 4)
    put_width(values, 0, 4)
    put_width(values, 3, 4)
    var column = ArrayRec()
    column.field = fid
    column.length = 3
    column.null_count = 1
    column.buf0 = len(c.abufs)
    column.nbuf = 2
    c.abufs.append(c.add_buf(Span(bitmap)))
    c.abufs.append(c.add_buf(Span(values)))
    var cols = List[Int]()
    cols.append(c.push_array(column))
    c.add_batch(3, cols)
    var raw = encode_ipc_stream(c)
    print("stream bytes", len(raw))
