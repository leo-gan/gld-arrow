from runtime.model import TY_INT, TY_LIST, TY_UTF8
from runtime.rows import child_at, rows_from_batch, text_at
from wire.ipc import decode_ipc_stream


def main() raises:
    var raw = open("testdata/golden/pa-list.arrows", "r").read_bytes()
    var c = decode_ipc_stream(raw)
    var doc = rows_from_batch(c, 0)
    if len(doc.rows) != 3:
        raise Error("rows")
    var row0 = doc.nodes[doc.rows[0]]
    if row0.kind != TY_LIST and doc.nodes[child_at(doc, doc.rows[0], 0)].kind != TY_LIST:
        raise Error("kind")
    var list_node = child_at(doc, doc.rows[0], 0)
    var ln = doc.nodes[list_node]
    if ln.is_null != 0 or ln.nchild != 2:
        raise Error("list len")
    var v0 = doc.nodes[child_at(doc, list_node, 0)]
    if v0.kind != TY_INT or v0.a != 1:
        raise Error("v0")
    var v1 = doc.nodes[child_at(doc, list_node, 1)]
    if v1.a != 2:
        raise Error("v1")
    var row1 = doc.nodes[child_at(doc, doc.rows[1], 0)]
    if row1.is_null == 0:
        raise Error("null row")
    var sraw = open("testdata/golden/pa-basic.arrows", "r").read_bytes()
    var sc = decode_ipc_stream(sraw)
    var sd = rows_from_batch(sc, 0)
    var s0 = child_at(sd, sd.rows[0], 1)
    if sd.nodes[s0].kind != TY_UTF8 or text_at(sd, s0) != "a":
        raise Error("text")
    print("ok")
