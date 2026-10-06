from std.collections import List, Span

from runtime.model import TY_BOOL, TY_FLOAT, TY_INT, TY_LIST, TY_STRUCT, TY_UTF8, ArrayRec, Columnar, FieldRec, put_width
from runtime.rows import rows_from_batch, text_at, child_at
from wire.ipc import decode_ipc_stream, encode_ipc_stream


struct Message:
    var id: Int
    var name: String

    def __init__(out self):
        self.id = 0
        self.name = String()

    def encoded_len(self) raises -> Int:
        return len(self.encode_bytes())

    def encode_to(self, mut buf: List[Byte]) raises:
        var raw = self.encode_bytes()
        var i = 0
        while i < len(raw):
            buf.append(raw[i])
            i += 1

    def encode_bytes(self) raises -> List[Byte]:
        var c = Columnar()
        var cols = List[Int]()
        var f0 = FieldRec()
        f0.name = c.intern("id")
        f0.kind = TY_INT
        f0.nullable = 0
        f0.bit_width = 64
        f0.is_signed = 1
        f0.unit = 0
        var id0 = c.add_field(f0)
        c.add_top(id0)
        cols.append(_emit_TY_INT(c, id0, self.id))
        var f1 = FieldRec()
        f1.name = c.intern("name")
        f1.kind = TY_UTF8
        f1.nullable = 0
        f1.bit_width = 0
        f1.is_signed = 1
        f1.unit = 0
        var id1 = c.add_field(f1)
        c.add_top(id1)
        cols.append(_emit_TY_UTF8(c, id1, self.name))
        c.add_batch(1, cols)
        return encode_ipc_stream(c)

    @staticmethod
    def decode_from[origin: ImmOrigin](raw: Span[Byte, origin]) raises -> Message:
        var c = decode_ipc_stream(raw)
        var doc = rows_from_batch(c, 0)
        var out = Message()
        var n0 = child_at(doc, doc.rows[0], 0)
        out.id = doc.nodes[n0].a
        var n1 = child_at(doc, doc.rows[0], 1)
        out.name = text_at(doc, n1)
        return out^


def _emit_TY_INT(mut c: Columnar, field: Int, value: Int) -> Int:
    var vals = List[Byte]()
    put_width(vals, value, 8)
    var a = ArrayRec()
    a.field = field
    a.length = 1
    a.buf0 = len(c.abufs)
    a.nbuf = 2
    c.abufs.append(c.add_empty_buf())
    c.abufs.append(c.add_buf(Span(vals)))
    return c.push_array(a)


def _emit_TY_BOOL(mut c: Columnar, field: Int, value: Bool) -> Int:
    var bits = List[Byte]()
    var b = 0
    if value:
        b = 1
    bits.append(Byte(b))
    var a = ArrayRec()
    a.field = field
    a.length = 1
    a.buf0 = len(c.abufs)
    a.nbuf = 2
    c.abufs.append(c.add_empty_buf())
    c.abufs.append(c.add_buf(Span(bits)))
    return c.push_array(a)


def _emit_TY_UTF8(mut c: Columnar, field: Int, value: String) -> Int:
    var raw = value.as_bytes()
    var off = List[Byte]()
    put_width(off, 0, 4)
    put_width(off, len(raw), 4)
    var data = List[Byte]()
    var i = 0
    while i < len(raw):
        data.append(raw[i])
        i += 1
    var a = ArrayRec()
    a.field = field
    a.length = 1
    a.buf0 = len(c.abufs)
    a.nbuf = 3
    c.abufs.append(c.add_empty_buf())
    c.abufs.append(c.add_buf(Span(off)))
    c.abufs.append(c.add_buf(Span(data)))
    return c.push_array(a)


def _emit_TY_FLOAT(mut c: Columnar, field: Int, value: Float64) -> Int:
    var vals = List[Byte]()
    put_width(vals, Int(UInt64(value.to_bits())), 8)
    var a = ArrayRec()
    a.field = field
    a.length = 1
    a.buf0 = len(c.abufs)
    a.nbuf = 2
    c.abufs.append(c.add_empty_buf())
    c.abufs.append(c.add_buf(Span(vals)))
    return c.push_array(a)


def _emit_TY_LIST(mut c: Columnar, field: Int, value: Int) -> Int:
    return _emit_TY_INT(c, field, value)


def _emit_TY_STRUCT(mut c: Columnar, field: Int, value: Int) -> Int:
    return _emit_TY_INT(c, field, value)
