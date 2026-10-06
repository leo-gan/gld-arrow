from runtime.model import TY_BOOL, TY_FLOAT, TY_INT, TY_UTF8, Columnar, bit_get, read_width
from wire.ipc import decode_ipc_file, decode_ipc_stream


def main() raises:
    var stream = open("testdata/golden/pa-basic.arrows", "r").read_bytes()
    _verify(decode_ipc_stream(stream), "stream")
    var file = open("testdata/golden/pa-basic.arrow", "r").read_bytes()
    _verify(decode_ipc_file(file), "file")
    print("ok")


def _verify(c: Columnar, label: String) raises:
    if len(c.batches) != 1 or c.batches[0].ncol != 4:
        raise Error("shape")
    var i_id = c.batch_cols[0]
    var s_id = c.batch_cols[1]
    var b_id = c.batch_cols[2]
    var f_id = c.batch_cols[3]
    if c.fields[c.arrays[i_id].field].kind != TY_INT:
        raise Error("int kind")
    var iv = c.buf_copy(c.abufs[c.arrays[i_id].buf0 + 1])
    if read_width(iv, 0, 4, True) != 1 or read_width(iv, 8, 4, True) != 3:
        raise Error("int values")
    if c.fields[c.arrays[s_id].field].kind != TY_UTF8:
        raise Error("utf8")
    var off = c.buf_copy(c.abufs[c.arrays[s_id].buf0 + 1])
    var data = c.buf_copy(c.abufs[c.arrays[s_id].buf0 + 2])
    var o0 = read_width(off, 0, 4, True)
    var o1 = read_width(off, 4, 4, True)
    if o1 - o0 != 1 or Int(data[o0]) != 97:
        raise Error("string a")
    if c.fields[c.arrays[b_id].field].kind != TY_BOOL:
        raise Error("bool")
    var bits = c.buf_copy(c.abufs[c.arrays[b_id].buf0 + 1])
    if not bit_get(bits, 0) or bit_get(bits, 1):
        raise Error("bool bits")
    if c.fields[c.arrays[f_id].field].kind != TY_FLOAT:
        raise Error("float")
    var fv = c.buf_copy(c.abufs[c.arrays[f_id].buf0 + 1])
    if read_width(fv, 0, 8, True) == 0:
        raise Error("float bits")
    print(label, "ok", c.fields[c.arrays[f_id].field].unit)
