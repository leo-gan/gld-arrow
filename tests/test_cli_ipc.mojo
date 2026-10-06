from codegen.cli import _generate
from runtime.model import TY_INT, TY_UTF8, Columnar, FieldRec
from wire.ipc import encode_ipc_stream


def main() raises:
    var json = open("testdata/schema/message.json", "r").read_bytes()
    var from_json = _generate(json)
    if not _has(from_json, "struct Message"):
        raise Error("json title")
    if not _has(from_json, "var id: Int") or not _has(from_json, "var name: String"):
        raise Error("json fields")
    var c = Columnar()
    var idf = FieldRec()
    idf.name = c.intern("id")
    idf.kind = TY_INT
    idf.bit_width = 64
    idf.nullable = 0
    c.add_top(c.add_field(idf))
    var nf = FieldRec()
    nf.name = c.intern("name")
    nf.kind = TY_UTF8
    nf.nullable = 0
    c.add_top(c.add_field(nf))
    c.schema_meta0 = len(c.meta_k)
    c.meta_k.append(c.intern("title"))
    c.meta_v.append(c.intern("Message"))
    c.nschema_meta = 1
    var raw = encode_ipc_stream(c)
    var from_ipc = _generate(raw)
    if not _has(from_ipc, "struct Message"):
        raise Error("ipc title")
    if not _has(from_ipc, "var id: Int") or not _has(from_ipc, "var name: String"):
        raise Error("ipc fields")
    print("ok", len(raw))


def _has(text: String, needle: String) -> Bool:
    var raw = text.as_bytes()
    var n = needle.as_bytes()
    if len(n) == 0 or len(raw) < len(n):
        return False
    var i = 0
    while i + len(n) <= len(raw):
        var ok = True
        var k = 0
        while k < len(n):
            if raw[i + k] != n[k]:
                ok = False
            k += 1
        if ok:
            return True
        i += 1
    return False
