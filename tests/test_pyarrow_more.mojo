from std.collections import List

from runtime.model import Columnar
from wire.ipc import decode_ipc_stream


def main() raises:
    var names = List[String]()
    names.append("list")
    names.append("struct")
    names.append("map")
    names.append("dict")
    names.append("dec")
    names.append("time")
    names.append("union")
    names.append("ree")
    names.append("view")
    names.append("lview")
    names.append("fsb")
    names.append("d32")
    names.append("d256")
    names.append("interval")
    var i = 0
    while i < len(names):
        var path = "testdata/golden/pa-" + names[i] + ".arrows"
        var raw = open(path, "r").read_bytes()
        var c = decode_ipc_stream(raw)
        _summary(names[i], c)
        i += 1
    print("ok")


def _summary(name: String, c: Columnar) raises:
    if len(c.batches) < 1:
        raise Error(name)
    var b = c.batches[0]
    print(name, "cols", b.ncol, "rows", b.length, "fields", len(c.fields), "dicts", len(c.dicts))
