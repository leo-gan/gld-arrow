from std.collections import List, Span

from Message import Message


def main() raises:
    var row = Message()
    row.id = 7
    row.name = "a"
    var raw = row.encode_bytes()
    var back = Message.decode_from(Span(raw))
    if back.id != 7 or back.name != "a":
        raise Error("generated round trip")
    if row.encoded_len() != len(raw):
        raise Error("encoded_len")
    var buf = List[Byte]()
    row.encode_to(buf)
    if len(buf) != len(raw):
        raise Error("encode_to")
    print("ok")
