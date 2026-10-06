from arrow import Columnar, DecodeError, decode_ipc_stream, encode_ipc_stream
from runtime.model import TY_INT, ArrayRec, FieldRec, put_width
from std.collections import List, Span


def main() raises:
    var c = Columnar()
    var f = FieldRec()
    f.name = c.intern("n")
    f.kind = TY_INT
    f.bit_width = 32
    f.is_signed = 1
    var fid = c.add_field(f)
    c.add_top(fid)
    var vals = List[Byte]()
    put_width(vals, 1, 4)
    var a = ArrayRec()
    a.field = fid
    a.length = 1
    a.null_count = 0
    a.buf0 = len(c.abufs)
    a.nbuf = 2
    c.abufs.append(c.add_empty_buf())
    c.abufs.append(c.add_buf(Span(vals)))
    var cols = List[Int]()
    cols.append(c.push_array(a))
    c.add_batch(1, cols)
    var raw = encode_ipc_stream(c)
    var back = decode_ipc_stream(Span(raw))
    if len(back.batches) != 1:
        raise Error("import decode failed")
    print("arrow import ok", DecodeError.KIND_EOF)
