from std.collections import List, Span

from flight.hpack import Hpack, huffman_bytes
from flight.proto import (
    encode_action,
    encode_descriptor_cmd,
    encode_descriptor_path,
    encode_endpoint,
    encode_flight_data,
    encode_handshake,
    encode_option_entry,
    encode_option_int,
    encode_option_string,
    encode_set_options,
    encode_ticket,
    f64_of,
    find_bytes,
    find_fixed,
    find_string,
    find_varint,
    has_field,
    parse_fields,
    put_msg,
    slice_of,
)
from flight.service import FlightMem, flight_call
from runtime.error import DecodeError


def main() raises:
    _huffman()
    _hpack_round()
    _proto_fixed()
    var mem = FlightMem()
    mem.schema = _text("schema-bytes")
    mem.batch = _text("batch-bytes")
    _handshake(mem)
    _list_and_get(mem)
    _poll_schema_get(mem)
    _put_exchange(mem)
    _actions(mem)
    _session(mem)
    _missing(mem)
    print("ok")


def _huffman() raises:
    var got = huffman_bytes("www.example.com")
    var expect = _hex("f1e3c2e5f23a6ba0ab90f4ff")
    _eq(got, expect)
    var hp = Hpack()
    var back = hp._huff_decode(got, 0, len(got))
    if back != "www.example.com":
        raise Error("huffman decode")


def _hpack_round() raises:
    var enc = Hpack()
    var block = List[Byte]()
    enc.encode_indexed(block, 3)
    enc.encode_indexed(block, 8)
    enc.encode_literal(block, "te", "trailers", 1)
    enc.encode_named(block, 31, "application/grpc")
    var dec = Hpack()
    var names = List[String]()
    var values = List[String]()
    dec.decode(block, names, values)
    if len(names) != 4:
        raise Error("hpack count")
    if values[0] != "POST" or values[1] != "200":
        raise Error("hpack static")
    if names[2] != "te" or values[2] != "trailers":
        raise Error("hpack literal")
    if names[3] != "content-type" or values[3] != "application/grpc":
        raise Error("hpack named")
    var again = dec.lookup(62)
    var n = String("")
    var v = String("")
    n, v = again
    if n != "te" or v != "trailers":
        raise Error("dynamic")


def _proto_fixed() raises:
    var opt = encode_option_int(-7)
    var fields = parse_fields(opt, 0, len(opt))
    if has_field(fields, 3) == 0:
        raise Error("sfixed")
    var u = find_fixed(fields, 3)
    if u != UInt64(-7):
        raise Error("sfixed bits")


def _handshake(mut mem: FlightMem) raises:
    var payload = _text("tok")
    var req = encode_handshake(1, payload)
    var reply = flight_call(mem, "Handshake", req, "")
    if reply.status != 0 or len(reply.lens) != 1:
        raise Error("handshake status")
    var msg = slice_of(reply.bodies, 0, reply.lens[0])
    var fields = parse_fields(msg, 0, len(msg))
    if find_varint(fields, 1, 0) != 1:
        raise Error("handshake version")
    _eq(find_bytes(msg, fields, 2), payload)


def _list_and_get(mut mem: FlightMem) raises:
    var empty = List[Byte]()
    var listed = flight_call(mem, "ListFlights", empty, "")
    if listed.status != 0 or len(listed.lens) != 1:
        raise Error("list")
    _check_info(slice_of(listed.bodies, 0, listed.lens[0]), mem)
    var path = List[String]()
    path.append("orders")
    var got = flight_call(mem, "GetFlightInfo", encode_descriptor_path(path), "")
    if got.status != 0:
        raise Error("get info")
    _check_info(slice_of(got.bodies, 0, got.lens[0]), mem)
    var cmd = flight_call(mem, "GetFlightInfo", encode_descriptor_cmd(_text("orders")), "")
    if cmd.status != 0:
        raise Error("cmd info")
    var missing = flight_call(mem, "GetFlightInfo", encode_descriptor_cmd(_text("nope")), "")
    if missing.status != 5:
        raise Error("missing info")


def _poll_schema_get(mut mem: FlightMem) raises:
    var path = List[String]()
    path.append("orders")
    var desc = encode_descriptor_path(path)
    var polled = flight_call(mem, "PollFlightInfo", desc, "")
    if polled.status != 0:
        raise Error("poll")
    var msg = slice_of(polled.bodies, 0, polled.lens[0])
    var fields = parse_fields(msg, 0, len(msg))
    if has_field(fields, 2) != 0:
        raise Error("poll done")
    if f64_of(find_fixed(fields, 3)) != Float64(1.0):
        raise Error("progress")
    var ts = find_bytes(msg, fields, 4)
    var tfields = parse_fields(ts, 0, len(ts))
    if find_varint(tfields, 1, 0) != 1700000000:
        raise Error("expiry")
    var schema = flight_call(mem, "GetSchema", desc, "")
    var smsg = slice_of(schema.bodies, 0, schema.lens[0])
    var sfields = parse_fields(smsg, 0, len(smsg))
    _eq(find_bytes(smsg, sfields, 1), mem.schema)
    var got = flight_call(mem, "DoGet", encode_ticket(_text("t1")), "")
    if got.status != 0:
        raise Error("doget")
    var dmsg = slice_of(got.bodies, 0, got.lens[0])
    var dfields = parse_fields(dmsg, 0, len(dmsg))
    _eq(find_bytes(dmsg, dfields, 1000), mem.batch)
    if find_string(dmsg, dfields, 3) != "ok":
        raise Error("doget meta")
    var bad = flight_call(mem, "DoGet", encode_ticket(_text("other")), "")
    if bad.status != 5:
        raise Error("ticket")


def _put_exchange(mut mem: FlightMem) raises:
    var header = List[Byte]()
    var meta = _text("put-meta")
    var put = flight_call(mem, "DoPut", encode_flight_data(header, mem.batch, meta), "")
    var pmsg = slice_of(put.bodies, 0, put.lens[0])
    var pfields = parse_fields(pmsg, 0, len(pmsg))
    _eq(find_bytes(pmsg, pfields, 1), meta)
    var echo = flight_call(mem, "DoExchange", encode_flight_data(header, _text("ping"), header), "")
    var emsg = slice_of(echo.bodies, 0, echo.lens[0])
    var efields = parse_fields(emsg, 0, len(emsg))
    _eq(find_bytes(emsg, efields, 1000), _text("ping"))


def _actions(mut mem: FlightMem) raises:
    var listed = flight_call(mem, "ListActions", List[Byte](), "")
    if listed.status != 0 or len(listed.lens) != 5:
        raise Error("actions")
    var off = 0
    var i = 0
    var saw = 0
    while i < len(listed.lens):
        var msg = slice_of(listed.bodies, off, listed.lens[i])
        var fields = parse_fields(msg, 0, len(msg))
        var kind = find_string(msg, fields, 1)
        if kind == "CancelFlightInfo" or kind == "RenewFlightEndpoint" or kind == "CloseSession":
            saw += 1
        if kind == "SetSessionOptions" or kind == "GetSessionOptions":
            saw += 1
        off += listed.lens[i]
        i += 1
    if saw != 5:
        raise Error("action names")
    var cancel = flight_call(mem, "DoAction", encode_action("CancelFlightInfo", List[Byte]()), "")
    var cmsg = slice_of(cancel.bodies, 0, cancel.lens[0])
    var cfields = parse_fields(cmsg, 0, len(cmsg))
    var cbody = find_bytes(cmsg, cfields, 1)
    var cinner = parse_fields(cbody, 0, len(cbody))
    if find_varint(cinner, 1, 0) != 1:
        raise Error("cancel")
    var ticket = _text("t1")
    var endpoint = encode_endpoint(ticket, "arrow-flight-reuse-connection://?")
    var req = List[Byte]()
    put_msg(req, 1, endpoint)
    var renewed = flight_call(mem, "DoAction", encode_action("RenewFlightEndpoint", req), "")
    var rmsg = slice_of(renewed.bodies, 0, renewed.lens[0])
    var rfields = parse_fields(rmsg, 0, len(rmsg))
    _eq(find_bytes(rmsg, rfields, 1), endpoint)
    var unknown = flight_call(mem, "DoAction", encode_action("Nope", List[Byte]()), "")
    if unknown.status != 12:
        raise Error("unimplemented")


def _session(mut mem: FlightMem) raises:
    var packed = List[Byte]()
    var lens = List[Int]()
    var s = encode_option_entry("name", encode_option_string("ada"))
    var n = encode_option_entry("n", encode_option_int(-7))
    _add(packed, lens, s)
    _add(packed, lens, n)
    var body = encode_set_options(packed, lens)
    var set = flight_call(mem, "DoAction", encode_action("SetSessionOptions", body), "")
    if set.status != 0 or set.cookie != "arrow_flight_session_id=s1":
        raise Error("set cookie")
    var got = flight_call(mem, "DoAction", encode_action("GetSessionOptions", List[Byte]()), set.cookie)
    if got.status != 0:
        raise Error("get session")
    var msg = slice_of(got.bodies, 0, got.lens[0])
    var fields = parse_fields(msg, 0, len(msg))
    if len(fields) != 2:
        raise Error("option count")
    var bare = flight_call(mem, "DoAction", encode_action("GetSessionOptions", List[Byte]()), "")
    if bare.status != 5:
        raise Error("no cookie")
    var closed = flight_call(mem, "DoAction", encode_action("CloseSession", List[Byte]()), set.cookie)
    if closed.status != 0:
        raise Error("close")
    var cmsg = slice_of(closed.bodies, 0, closed.lens[0])
    var cfields = parse_fields(cmsg, 0, len(cmsg))
    var cbody = find_bytes(cmsg, cfields, 1)
    var cinner = parse_fields(cbody, 0, len(cbody))
    if find_varint(cinner, 1, 0) != 1:
        raise Error("closed status")
    var after = flight_call(mem, "DoAction", encode_action("GetSessionOptions", List[Byte]()), set.cookie)
    if after.status != 5:
        raise Error("closed session")


def _missing(mut mem: FlightMem) raises:
    var reply = flight_call(mem, "Unknown", List[Byte](), "")
    if reply.status != 12:
        raise Error("unknown method")


def _check_info(msg: List[Byte], mem: FlightMem) raises:
    var fields = parse_fields(msg, 0, len(msg))
    _eq(find_bytes(msg, fields, 1), mem.schema)
    if find_varint(fields, 4, 0) != 3:
        raise Error("records")
    if find_varint(fields, 6, 0) != 1:
        raise Error("ordered")
    var endpoint = find_bytes(msg, fields, 3)
    var efields = parse_fields(endpoint, 0, len(endpoint))
    var loc = find_bytes(endpoint, efields, 2)
    var lfields = parse_fields(loc, 0, len(loc))
    if find_string(loc, lfields, 1) != "arrow-flight-reuse-connection://?":
        raise Error("location")


def _add(mut packed: List[Byte], mut lens: List[Int], msg: List[Byte]):
    var i = 0
    while i < len(msg):
        packed.append(msg[i])
        i += 1
    lens.append(len(msg))


def _text(text: String) -> List[Byte]:
    var out = List[Byte]()
    var b = text.as_bytes()
    var i = 0
    while i < len(b):
        out.append(b[i])
        i += 1
    return out^


def _hex(text: String) -> List[Byte]:
    var raw = text.as_bytes()
    var out = List[Byte]()
    var i = 0
    while i + 1 < len(raw):
        out.append(Byte((_nyb(Int(raw[i])) << 4) | _nyb(Int(raw[i + 1]))))
        i += 2
    return out^


def _nyb(c: Int) -> Int:
    if c >= 48 and c <= 57:
        return c - 48
    return c - 87


def _eq(got: List[Byte], expect: List[Byte]) raises:
    if len(got) != len(expect):
        raise Error("len")
    var i = 0
    while i < len(expect):
        if got[i] != expect[i]:
            raise Error("byte")
        i += 1
