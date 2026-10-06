from std.collections import List, Span

from wire.ipc import decode_ipc_stream, encode_ipc_stream


def main() raises:
    var names = List[String]()
    names.append("basic")
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
        var out = encode_ipc_stream(c)
        var back = decode_ipc_stream(Span(out))
        if len(back.batches) != len(c.batches):
            raise Error(names[i])
        var dest = "/tmp/out-" + names[i] + ".arrows"
        var f = open(dest, "w")
        f.write_bytes(Span(out))
        f.close()
        print(names[i], len(out))
        i += 1
    print("ok")
