from std.collections import List

from runtime.error import DecodeError
from runtime.flatbuf import FBBuilder, FBReader


def main() raises:
    var b = FBBuilder()
    var name = b.write_string("a")
    b.start_table(2)
    b.add_i32(0, 32, 0)
    b.add_bool(1, True, False)
    var int_ty = b.end_table()
    b.start_table(7)
    b.add_offset(0, name)
    b.add_bool(1, True, False)
    b.add_u8(2, 2, 0)
    b.add_offset(3, int_ty)
    var field = b.end_table()
    var fields = List[Int]()
    fields.append(field)
    var vec = b.write_offset_vec(fields)
    b.start_table(4)
    b.add_offset(1, vec)
    var schema = b.end_table()
    var raw = b.finish(schema)
    var r = FBReader(raw^)
    var root = r.root()
    var fields_pos = r.field(root, 1)
    if r.vec_len(fields_pos) != 1:
        raise Error("field count")
    var data = r.vec_data(fields_pos)
    var fpos = data + list_rel(r, data)
    var got = r.string_at(r.field(fpos, 0))
    if got != "a":
        raise Error("name")
    if r.u8(r.field(fpos, 1)) != 1:
        raise Error("nullable")
    if r.u8(r.field(fpos, 2)) != 2:
        raise Error("union")
    var ty = r.follow(r.field(fpos, 3))
    if r.i32(r.field(ty, 0)) != 32:
        raise Error("width")
    if r.u8(r.field(ty, 1)) != 1:
        raise Error("signed")
    print("ok")


def list_rel(r: FBReader, pos: Int) raises DecodeError -> Int:
    return r.u32(pos)
