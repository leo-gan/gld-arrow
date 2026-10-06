# Design

mojo-arrow is a standalone Mojo 1.1 library. It implements the Apache Arrow
format documented for version 25.0.1. PyArrow is a test oracle. The library
does not link a C, C++, or Rust Arrow implementation, and it does not depend
on `mojo-flatbuffers`.

## Decisions

| Topic | Choice |
| --- | --- |
| Surfaces | Columnar arrays, IPC stream, IPC file, tensor, sparse tensor, the C data interface, the C device interface, and Flight. |
| Types | Every logical type in the Arrow 25 columnar format. Extension types keep their storage type and their metadata keys. |
| Compression | LZ4 frame and Zstd, written in Mojo. |
| API | `Columnar` arrays, a `RowDoc` tree, and `gld-arrowgen-mojo`. |
| Schemas | Arrow integration JSON, an IPC schema message, and the JSON Schema subset used by the other gld libraries, plus `x-arrow-type`. |
| Bytes | Logical values round-trip. Two encodes with the same options match. Padding may differ from PyArrow. |
| IPC metadata | Hand-written FlatBuffers for the Arrow tables only. |
| Endianness | The writer emits little-endian. The reader accepts a big-endian schema and swaps fixed-width values into little-endian memory. |
| Metadata version | The writer emits V5. The reader accepts V4 and V5. |

## Layout

`Columnar` is an arena. Field records, buffers, and arrays are integer indexes
into side lists. Nested children are appended after the recursive call so a
struct's children are not also children of its parent. That rule is what makes
`map<utf8, int32>` line up with the depth-first IPC node order.

`RowDoc` is a second arena. A batch becomes one struct node per row. Dictionary
indexes are resolved to logical values when the row is built.

The code generator emits a struct whose fields are the properties of a JSON
Schema object. `encode_bytes` builds a one-row IPC stream. `decode_from` reads
that stream back through `RowDoc`.

## Ship path

Version `0.1.0` is the first commit on `main`. A later speed change lands
through a pull request. `0.2.0` is the release published to prefix.dev channel
`leo-gan/leo-gan`. The required checks are named `Mojo tests` and `Docs build`.
