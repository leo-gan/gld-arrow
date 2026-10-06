from std.collections import List, Span

from compress.frame import frame_compress, frame_decompress
from runtime.buf import put_i64, put_u32
from runtime.error import DecodeError
from runtime.flatbuf import FBBuilder, FBReader
from runtime.model import (
    TY_BINARY,
    TY_BINARY_VIEW,
    TY_FIXED_LIST,
    TY_LARGE_BINARY,
    TY_LARGE_LIST,
    TY_LARGE_LIST_VIEW,
    TY_LARGE_UTF8,
    TY_LIST,
    TY_LIST_VIEW,
    TY_MAP,
    TY_NULL,
    TY_RUN_END,
    TY_STRUCT,
    TY_UNION,
    TY_UTF8,
    TY_UTF8_VIEW,
    MAX_DEPTH,
    ArrayRec,
    Columnar,
    DictRec,
    FieldRec,
    byte_width_of,
    is_variadic,
    read_width,
    swap_fixed,
)
from wire.schema_fb import decode_schema, schema_token
from wire.tensor import read_tensor


def encode_ipc_stream(c: Columnar) raises DecodeError -> List[Byte]:
    var out = List[Byte]()
    _write_stream(c, out, False)
    return out^


def encode_ipc_file(c: Columnar) raises DecodeError -> List[Byte]:
    var out = List[Byte]()
    out.append(Byte(0x41))
    out.append(Byte(0x52))
    out.append(Byte(0x52))
    out.append(Byte(0x4F))
    out.append(Byte(0x57))
    out.append(Byte(0x31))
    out.append(Byte(0))
    out.append(Byte(0))
    var blocks_off = List[Int]()
    var blocks_meta = List[Int]()
    var blocks_body = List[Int]()
    var blocks_kind = List[Int]()
    _write_stream_tracked(c, out, blocks_off, blocks_meta, blocks_body, blocks_kind)
    var footer = _footer(c, blocks_off, blocks_meta, blocks_body, blocks_kind)
    var i = 0
    while i < len(footer):
        out.append(footer[i])
        i += 1
    put_u32(out, len(footer))
    out.append(Byte(0x41))
    out.append(Byte(0x52))
    out.append(Byte(0x52))
    out.append(Byte(0x4F))
    out.append(Byte(0x57))
    out.append(Byte(0x31))
    return out^


def decode_ipc_stream[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> Columnar:
    var c = Columnar()
    _ingest(c, raw, 0, len(raw))
    return c^


def decode_ipc_file[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> Columnar:
    if len(raw) < 10:
        raise DecodeError(DecodeError.KIND_EOF, 0)
    if not _magic_at(raw, 0) or not _magic_at(raw, len(raw) - 6):
        raise DecodeError(DecodeError.KIND_SYNTAX, 0)
    var flen = _u32(raw, len(raw) - 10)
    var footer_at = len(raw) - 10 - flen
    if flen < 8 or footer_at < 8:
        raise DecodeError(DecodeError.KIND_SYNTAX, footer_at)
    var c = Columnar()
    _ingest(c, raw, 8, footer_at)
    return c^


def _magic_at[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) -> Bool:
    if i < 0 or i + 6 > len(raw):
        return False
    return (
        Int(raw[i]) == 0x41
        and Int(raw[i + 1]) == 0x52
        and Int(raw[i + 2]) == 0x52
        and Int(raw[i + 3]) == 0x4F
        and Int(raw[i + 4]) == 0x57
        and Int(raw[i + 5]) == 0x31
    )


def _u32[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    if i < 0 or i + 4 > len(raw):
        raise DecodeError(DecodeError.KIND_EOF, i)
    return Int(raw[i]) | (Int(raw[i + 1]) << 8) | (Int(raw[i + 2]) << 16) | (Int(raw[i + 3]) << 24)


def _write_stream(c: Columnar, mut out: List[Byte], file_pad: Bool) raises DecodeError:
    var a = List[Int]()
    var b = List[Int]()
    var d = List[Int]()
    var e = List[Int]()
    _write_stream_tracked(c, out, a, b, d, e)


def _write_stream_tracked(
    c: Columnar,
    mut out: List[Byte],
    mut blocks_off: List[Int],
    mut blocks_meta: List[Int],
    mut blocks_body: List[Int],
    mut blocks_kind: List[Int],
) raises DecodeError:
    var schema_meta = _message_bytes(c, 1, -1, 0)
    _append_encapsulated(out, schema_meta, List[Byte]())
    var di = 0
    var bi = 0
    while bi < len(c.batches):
        while di < len(c.dicts) and c.dicts[di].batch_index == bi:
            _write_dict(c, c.dicts[di], out, blocks_off, blocks_meta, blocks_body, blocks_kind)
            di += 1
        _write_batch(c, bi, out, blocks_off, blocks_meta, blocks_body, blocks_kind)
        bi += 1
    while di < len(c.dicts):
        _write_dict(c, c.dicts[di], out, blocks_off, blocks_meta, blocks_body, blocks_kind)
        di += 1
    put_u32(out, 0xFFFFFFFF)
    put_u32(out, 0)


def _write_dict(
    c: Columnar,
    d: DictRec,
    mut out: List[Byte],
    mut blocks_off: List[Int],
    mut blocks_meta: List[Int],
    mut blocks_body: List[Int],
    mut blocks_kind: List[Int],
) raises DecodeError:
    var nodes_l = List[Int]()
    var nodes_n = List[Int]()
    var order = List[Int]()
    var variadic = List[Int]()
    var f = c.fields[c.arrays[d.array].field]
    _emit_array(c, f, d.array, True, nodes_l, nodes_n, order, variadic, 0)
    var body = List[Byte]()
    var boff = List[Int]()
    var blen = List[Int]()
    _pack_body(c, order, c.codec, body, boff, blen)
    var batch_tok_buf = _batch_message(c, c.arrays[d.array].length, nodes_l, nodes_n, boff, blen, variadic, c.codec, len(body), 2, d)
    _record_block(out, batch_tok_buf, body, 2, blocks_off, blocks_meta, blocks_body, blocks_kind)


def _write_batch(
    c: Columnar,
    bi: Int,
    mut out: List[Byte],
    mut blocks_off: List[Int],
    mut blocks_meta: List[Int],
    mut blocks_body: List[Int],
    mut blocks_kind: List[Int],
) raises DecodeError:
    var batch = c.batches[bi]
    var nodes_l = List[Int]()
    var nodes_n = List[Int]()
    var order = List[Int]()
    var variadic = List[Int]()
    var i = 0
    while i < batch.ncol:
        var aid = c.batch_cols[batch.col0 + i]
        var f = c.fields[c.arrays[aid].field]
        _emit_array(c, f, aid, False, nodes_l, nodes_n, order, variadic, 0)
        i += 1
    var codec = batch.codec
    if codec < 0:
        codec = c.codec
    var body = List[Byte]()
    var boff = List[Int]()
    var blen = List[Int]()
    _pack_body(c, order, codec, body, boff, blen)
    var meta = _batch_message(c, batch.length, nodes_l, nodes_n, boff, blen, variadic, codec, len(body), 3, DictRec(-1, -1, 0, 0))
    _record_block(out, meta, body, 3, blocks_off, blocks_meta, blocks_body, blocks_kind)


def _batch_message(
    c: Columnar,
    length: Int,
    nodes_l: List[Int],
    nodes_n: List[Int],
    boff: List[Int],
    blen: List[Int],
    variadic: List[Int],
    codec: Int,
    body_len: Int,
    header_kind: Int,
    d: DictRec,
) raises DecodeError -> List[Byte]:
    var b = FBBuilder()
    var nodes = List[Byte]()
    var i = 0
    while i < len(nodes_l):
        put_i64(nodes, nodes_l[i])
        put_i64(nodes, nodes_n[i])
        i += 1
    var bufs = List[Byte]()
    i = 0
    while i < len(boff):
        put_i64(bufs, boff[i])
        put_i64(bufs, blen[i])
        i += 1
    var ntok = b.write_struct_vec(nodes, 16)
    var btok = b.write_struct_vec(bufs, 16)
    var ctok = -1
    if codec >= 0:
        b.start_table(2)
        b.add_u8(0, codec, 0)
        ctok = b.end_table()
    var vtok = -1
    if len(variadic) > 0:
        vtok = b.write_u64_vec(variadic)
    b.start_table(5)
    b.add_i64(0, length, -1)
    b.add_offset(1, ntok)
    b.add_offset(2, btok)
    if ctok >= 0:
        b.add_offset(3, ctok)
    if vtok >= 0:
        b.add_offset(4, vtok)
    var batch = b.end_table()
    var header = batch
    var hkind = header_kind
    if header_kind == 2:
        b.start_table(3)
        b.add_i64(0, d.id, -1)
        b.add_offset(1, batch)
        b.add_bool(2, d.is_delta != 0, False)
        header = b.end_table()
        hkind = 2
    var schema_hold = -1
    if header_kind == 1:
        schema_hold = header
    var msg = _message(b, hkind, header, body_len)
    _ = schema_hold
    return b.finish(msg)


def _message_bytes(c: Columnar, kind: Int, header_unused: Int, body_len: Int) raises DecodeError -> List[Byte]:
    var b = FBBuilder()
    var header = schema_token(b, c)
    var msg = _message(b, kind, header, body_len)
    return b.finish(msg)


def _message(mut b: FBBuilder, kind: Int, header: Int, body_len: Int) -> Int:
    b.start_table(5)
    b.add_u16(0, 4, 0)
    b.add_u8(1, kind, 0)
    b.add_offset(2, header)
    b.add_i64(3, body_len, 0)
    return b.end_table()


def _pack_body(
    c: Columnar,
    order: List[Int],
    codec: Int,
    mut body: List[Byte],
    mut boff: List[Int],
    mut blen: List[Int],
) raises DecodeError:
    var i = 0
    while i < len(order):
        var id = order[i]
        var src = c.buf_copy(id)
        if len(src) == 0:
            boff.append(0)
            blen.append(0)
        else:
            while len(body) % 8 != 0:
                body.append(Byte(0))
            var payload = src.copy()
            if codec >= 0:
                payload = _wrap_compress(codec, src)
            boff.append(len(body))
            blen.append(len(payload))
            var k = 0
            while k < len(payload):
                body.append(payload[k])
                k += 1
        i += 1
    while len(body) % 8 != 0:
        body.append(Byte(0))


def _wrap_compress(codec: Int, raw: List[Byte]) raises DecodeError -> List[Byte]:
    var comp = frame_compress(codec, raw)
    var out = List[Byte]()
    if len(comp) >= len(raw):
        put_i64(out, -1)
        var i = 0
        while i < len(raw):
            out.append(raw[i])
            i += 1
    else:
        put_i64(out, len(raw))
        var i = 0
        while i < len(comp):
            out.append(comp[i])
            i += 1
    return out^


def _append_encapsulated(mut out: List[Byte], meta: List[Byte], body: List[Byte]):
    var m = meta.copy()
    while len(m) % 8 != 0:
        m.append(Byte(0))
    put_u32(out, 0xFFFFFFFF)
    put_u32(out, len(m))
    var i = 0
    while i < len(m):
        out.append(m[i])
        i += 1
    i = 0
    while i < len(body):
        out.append(body[i])
        i += 1


def _record_block(
    mut out: List[Byte],
    meta: List[Byte],
    body: List[Byte],
    kind: Int,
    mut blocks_off: List[Int],
    mut blocks_meta: List[Int],
    mut blocks_body: List[Int],
    mut blocks_kind: List[Int],
):
    var start = len(out)
    var m = meta.copy()
    while len(m) % 8 != 0:
        m.append(Byte(0))
    blocks_off.append(start)
    blocks_meta.append(8 + len(m))
    blocks_body.append(len(body))
    blocks_kind.append(kind)
    _append_encapsulated(out, meta, body)


def _footer(
    c: Columnar,
    blocks_off: List[Int],
    blocks_meta: List[Int],
    blocks_body: List[Int],
    blocks_kind: List[Int],
) raises DecodeError -> List[Byte]:
    var b = FBBuilder()
    var schema = schema_token(b, c)
    var dicts = _block_vec(b, blocks_off, blocks_meta, blocks_body, blocks_kind, 2)
    var batches = _block_vec(b, blocks_off, blocks_meta, blocks_body, blocks_kind, 3)
    b.start_table(5)
    b.add_u16(0, 4, 0)
    b.add_offset(1, schema)
    b.add_offset(2, dicts)
    b.add_offset(3, batches)
    var footer = b.end_table()
    var raw = b.finish(footer)
    while len(raw) % 8 != 0:
        raw.append(Byte(0))
    return raw^


def _block_vec(
    mut b: FBBuilder,
    blocks_off: List[Int],
    blocks_meta: List[Int],
    blocks_body: List[Int],
    blocks_kind: List[Int],
    want: Int,
) -> Int:
    var raw = List[Byte]()
    var i = 0
    while i < len(blocks_off):
        if blocks_kind[i] == want:
            put_i64(raw, blocks_off[i])
            var meta = blocks_meta[i]
            raw.append(Byte(meta & 255))
            raw.append(Byte((meta >> 8) & 255))
            raw.append(Byte((meta >> 16) & 255))
            raw.append(Byte((meta >> 24) & 255))
            raw.append(Byte(0))
            raw.append(Byte(0))
            raw.append(Byte(0))
            raw.append(Byte(0))
            put_i64(raw, blocks_body[i])
        i += 1
    return b.write_struct_vec(raw, 24)


def _emit_array(
    c: Columnar,
    f: FieldRec,
    aid: Int,
    as_values: Bool,
    mut nodes_l: List[Int],
    mut nodes_n: List[Int],
    mut order: List[Int],
    mut variadic: List[Int],
    depth: Int,
) raises DecodeError:
    if depth > MAX_DEPTH:
        raise DecodeError(DecodeError.KIND_DEPTH, depth)
    var a = c.arrays[aid]
    if f.dict_id >= 0 and not as_values:
        nodes_l.append(a.length)
        nodes_n.append(a.null_count)
        var i = 0
        while i < a.nbuf:
            order.append(c.abufs[a.buf0 + i])
            i += 1
        return
    nodes_l.append(a.length)
    nodes_n.append(a.null_count)
    var local = _local_bufs(f)
    var i = 0
    while i < local and i < a.nbuf:
        order.append(c.abufs[a.buf0 + i])
        i += 1
    if is_variadic(f.kind):
        variadic.append(a.nbuf - local)
        while i < a.nbuf:
            order.append(c.abufs[a.buf0 + i])
            i += 1
    var ch = 0
    while ch < a.nchild and ch < f.nchild:
        var cf = c.fields[c.kids[f.child0 + ch]]
        _emit_array(c, cf, c.achilds[a.child0 + ch], False, nodes_l, nodes_n, order, variadic, depth + 1)
        ch += 1


def _local_bufs(f: FieldRec) -> Int:
    var k = f.kind
    if k == TY_NULL or k == TY_RUN_END:
        return 0
    if k == TY_STRUCT or k == TY_FIXED_LIST:
        return 1
    if k == TY_UNION:
        if f.union_mode == 1:
            return 2
        return 1
    if k == TY_LIST or k == TY_LARGE_LIST or k == TY_MAP:
        return 2
    if k == TY_LIST_VIEW or k == TY_LARGE_LIST_VIEW:
        return 3
    if k == TY_BINARY or k == TY_UTF8 or k == TY_LARGE_BINARY or k == TY_LARGE_UTF8:
        return 3
    if k == TY_BINARY_VIEW or k == TY_UTF8_VIEW:
        return 2
    return 2


def _ingest[origin: ImmOrigin](mut c: Columnar, raw: Span[Byte, origin], begin: Int, end: Int) raises DecodeError:
    var i = begin
    while i + 4 <= end:
        var cont = _u32(raw, i)
        if cont == 0:
            return
        if cont != 0xFFFFFFFF:
            raise DecodeError(DecodeError.KIND_SYNTAX, i)
        if i + 8 > end:
            raise DecodeError(DecodeError.KIND_EOF, i)
        var mlen = _u32(raw, i + 4)
        if mlen == 0:
            return
        if mlen < 0 or i + 8 + mlen > end:
            raise DecodeError(DecodeError.KIND_RANGE, i)
        var meta = List[Byte]()
        var k = 0
        while k < mlen:
            meta.append(raw[i + 8 + k])
            k += 1
        var r = FBReader(meta^)
        var table = r.root()
        var ver_p = r.field(table, 0)
        var ver = 0
        if ver_p >= 0:
            ver = r.u16(ver_p)
        if ver != 3 and ver != 4:
            raise DecodeError(DecodeError.KIND_VERSION, i)
        var ht_p = r.field(table, 1)
        var hd_p = r.field(table, 2)
        if ht_p < 0 or hd_p < 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, i)
        var hkind = r.u8(ht_p)
        var header = r.follow(hd_p)
        var bl_p = r.field(table, 3)
        var body_len = 0
        if bl_p >= 0:
            body_len = r.i64(bl_p)
        var body_at = i + 8 + mlen
        if body_len < 0 or body_at + body_len > end:
            raise DecodeError(DecodeError.KIND_RANGE, body_at)
        var body = List[Byte]()
        k = 0
        while k < body_len:
            body.append(raw[body_at + k])
            k += 1
        if hkind == 1:
            decode_schema(r, header, c)
        elif hkind == 2:
            _read_dictionary(c, r, header, body)
        elif hkind == 3:
            _read_batch(c, r, header, body)
        elif hkind == 4:
            read_tensor(c, r, header, body, False)
        elif hkind == 5:
            read_tensor(c, r, header, body, True)
        else:
            raise DecodeError(DecodeError.KIND_TYPE, hkind)
        i = body_at + body_len


def _read_dictionary(mut c: Columnar, r: FBReader, table: Int, body: List[Byte]) raises DecodeError:
    var id = 0
    var ip = r.field(table, 0)
    if ip >= 0:
        id = r.i64(ip)
    var delta = 0
    var dp = r.field(table, 2)
    if dp >= 0 and r.u8(dp) != 0:
        delta = 1
    var bp = r.field(table, 1)
    if bp < 0:
        raise DecodeError(DecodeError.KIND_SCHEMA, table)
    var field_id = _field_for_dict(c, id)
    var aid = _read_one_array(c, r, r.follow(bp), body, field_id, True, 0)
    c.dicts.append(DictRec(id, aid, delta, len(c.batches)))


def _field_for_dict(c: Columnar, id: Int) raises DecodeError -> Int:
    var i = 0
    while i < len(c.fields):
        if c.fields[i].dict_id == id:
            return i
        i += 1
    raise DecodeError(DecodeError.KIND_SCHEMA, id)


def _read_batch(mut c: Columnar, r: FBReader, table: Int, body: List[Byte]) raises DecodeError:
    var length = 0
    var lp = r.field(table, 0)
    if lp >= 0:
        length = r.i64(lp)
    var cols = List[Int]()
    var i = 0
    var state = _BatchState()
    _load_batch_vectors(r, table, state)
    while i < len(c.top):
        var aid = _read_array_state(c, body, c.top[i], False, state, 0)
        cols.append(aid)
        i += 1
    var codec = state.codec
    c.add_batch(length, cols)
    if codec >= 0:
        var b = c.batches[len(c.batches) - 1]
        b.codec = codec
        c.batches[len(c.batches) - 1] = b
        c.codec = codec
        c.features = c.features | 2


struct _BatchState:
    var node_l: List[Int]
    var node_n: List[Int]
    var buf_off: List[Int]
    var buf_len: List[Int]
    var variadic: List[Int]
    var node_i: Int
    var buf_i: Int
    var var_i: Int
    var codec: Int

    def __init__(out self):
        self.node_l = List[Int]()
        self.node_n = List[Int]()
        self.buf_off = List[Int]()
        self.buf_len = List[Int]()
        self.variadic = List[Int]()
        self.node_i = 0
        self.buf_i = 0
        self.var_i = 0
        self.codec = -1


def _load_batch_vectors(r: FBReader, table: Int, mut st: _BatchState) raises DecodeError:
    var np = r.field(table, 1)
    if np >= 0:
        var n = r.vec_len(np)
        var data = r.vec_data(np)
        var i = 0
        while i < n:
            st.node_l.append(r.i64(data + i * 16))
            st.node_n.append(r.i64(data + i * 16 + 8))
            i += 1
    var bp = r.field(table, 2)
    if bp >= 0:
        var n = r.vec_len(bp)
        var data = r.vec_data(bp)
        var i = 0
        while i < n:
            st.buf_off.append(r.i64(data + i * 16))
            st.buf_len.append(r.i64(data + i * 16 + 8))
            i += 1
    var cp = r.field(table, 3)
    if cp >= 0:
        var comp = r.follow(cp)
        var codec = 0
        var cpos = r.field(comp, 0)
        if cpos >= 0:
            codec = r.u8(cpos)
        st.codec = codec
    var vp = r.field(table, 4)
    if vp >= 0:
        var n = r.vec_len(vp)
        var data = r.vec_data(vp)
        var i = 0
        while i < n:
            st.variadic.append(r.i64(data + i * 8))
            i += 1


def _read_one_array(
    mut c: Columnar, r: FBReader, batch_table: Int, body: List[Byte], field_id: Int, as_values: Bool, depth: Int
) raises DecodeError -> Int:
    var st = _BatchState()
    _load_batch_vectors(r, batch_table, st)
    return _read_array_state(c, body, field_id, as_values, st, depth)


def _read_array_state(
    mut c: Columnar, body: List[Byte], field_id: Int, as_values: Bool, mut st: _BatchState, depth: Int
) raises DecodeError -> Int:
    if depth > MAX_DEPTH:
        raise DecodeError(DecodeError.KIND_DEPTH, depth)
    if st.node_i >= len(st.node_l):
        raise DecodeError(DecodeError.KIND_SCHEMA, st.node_i)
    var f = c.fields[field_id]
    var length = st.node_l[st.node_i]
    var null_count = st.node_n[st.node_i]
    st.node_i += 1
    var a = ArrayRec()
    a.field = field_id
    a.length = length
    a.null_count = null_count
    a.buf0 = len(c.abufs)
    if f.dict_id >= 0 and not as_values:
        _take_n(c, body, st, 2, 0)
        a.nbuf = 2
        a.dict = _latest_dict(c, f.dict_id)
        return c.push_array(a)
    var local = _local_bufs(f)
    var swap_w = 0
    if c.endian != 0:
        swap_w = byte_width_of(f)
    _take_n(c, body, st, local, swap_w)
    var extra = 0
    if is_variadic(f.kind):
        if st.var_i >= len(st.variadic):
            raise DecodeError(DecodeError.KIND_SCHEMA, st.var_i)
        extra = st.variadic[st.var_i]
        st.var_i += 1
        _take_n(c, body, st, extra, 0)
    a.nbuf = local + extra
    var direct = List[Int]()
    var ch = 0
    while ch < f.nchild:
        direct.append(_read_array_state(c, body, c.kids[f.child0 + ch], False, st, depth + 1))
        ch += 1
    a.child0 = len(c.achilds)
    ch = 0
    while ch < len(direct):
        c.achilds.append(direct[ch])
        ch += 1
    a.nchild = len(direct)
    return c.push_array(a)


def _latest_dict(c: Columnar, id: Int) -> Int:
    var i = len(c.dicts) - 1
    var repl = -1
    while i >= 0:
        if c.dicts[i].id == id and c.dicts[i].is_delta == 0:
            repl = c.dicts[i].array
            break
        i -= 1
    if repl < 0 and len(c.dicts) > 0:
        i = len(c.dicts) - 1
        while i >= 0:
            if c.dicts[i].id == id:
                return c.dicts[i].array
            i -= 1
    return repl


def _take_n(mut c: Columnar, body: List[Byte], mut st: _BatchState, n: Int, swap_w: Int) raises DecodeError:
    var i = 0
    while i < n:
        if st.buf_i >= len(st.buf_off):
            raise DecodeError(DecodeError.KIND_SCHEMA, st.buf_i)
        var off = st.buf_off[st.buf_i]
        var ln = st.buf_len[st.buf_i]
        st.buf_i += 1
        var bytes = _slice_body(body, off, ln, st.codec)
        if swap_w > 1 and i == 1 and len(bytes) > 0:
            swap_fixed(bytes, swap_w)
        if len(bytes) == 0:
            c.abufs.append(c.add_empty_buf())
        else:
            c.abufs.append(c.add_buf_list(bytes))
        i += 1


def _slice_body(body: List[Byte], off: Int, n: Int, codec: Int) raises DecodeError -> List[Byte]:
    if n == 0:
        return List[Byte]()
    if off < 0 or n < 0 or off + n > len(body):
        raise DecodeError(DecodeError.KIND_RANGE, off)
    var raw = List[Byte]()
    var i = 0
    while i < n:
        raw.append(body[off + i])
        i += 1
    if codec < 0:
        return raw^
    if len(raw) < 8:
        raise DecodeError(DecodeError.KIND_COMPRESSION, off)
    var un = read_width(raw, 0, 8, True)
    var rest = List[Byte]()
    i = 8
    while i < len(raw):
        rest.append(raw[i])
        i += 1
    if un < 0:
        return rest^
    var got = frame_decompress(codec, rest)
    if len(got) != un:
        raise DecodeError(DecodeError.KIND_COMPRESSION, off)
    return got^
