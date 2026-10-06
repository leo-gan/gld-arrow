from std.collections import Span

from runtime.model import read_width
from wire.ipc import decode_ipc_stream
from wire.tensor import encode_tensor_stream


def main() raises:
    var raw = open("testdata/golden/tensor.arrows", "r").read_bytes()
    var c = decode_ipc_stream(raw)
    if len(c.tensors) != 1:
        raise Error("count")
    var t = c.tensors[0]
    if t.nshape != 2:
        raise Error("ndim")
    if c.shapes[t.shape0] != 2 or c.shapes[t.shape0 + 1] != 3:
        raise Error("shape")
    if c.strides[t.stride0] != 12 or c.strides[t.stride0 + 1] != 4:
        raise Error("stride")
    var data = c.buf_copy(t.data_buf)
    if read_width(data, 0, 4, True) != 0 or read_width(data, 20, 4, True) != 5:
        raise Error("values")
    var out = encode_tensor_stream(c)
    var f = open("/tmp/our-tensor.bin", "w")
    f.write_bytes(Span(out))
    f.close()
    var back = decode_ipc_stream(Span(out))
    if back.tensors[0].nshape != 2:
        raise Error("re")
    print("ok", len(out))
