# Test data

`testdata/golden/` holds IPC streams written by PyArrow 19. The Mojo tests decode each file and, for most of them, encode it again and decode the result. The checked-in bytes are the PyArrow bytes. They are not rewritten by this library.

| File | Columns |
| --- | --- |
| `pa-basic.arrows`, `pa-basic.arrow` | `int32`, `utf8`, `bool`, `float64`, including a null and a NaN. The `.arrow` file is the IPC file format. |
| `pa-list.arrows` | `list<int32>` with a null list. |
| `pa-struct.arrows` | `struct<x: int32, y: utf8>`. |
| `pa-map.arrows` | `map<utf8, int32>`. |
| `pa-dict.arrows` | Dictionary-encoded `utf8` with `int32` indexes. |
| `pa-dec.arrows` | `decimal128(10, 2)`. |
| `pa-d32.arrows`, `pa-d256.arrows` | `decimal32(5, 2)` and `decimal256(10, 2)`. |
| `pa-time.arrows` | `date32`, `timestamp[us, UTC]`, `duration[ms]`. |
| `pa-interval.arrows` | Month-day-nanosecond interval. |
| `pa-union.arrows` | Dense union of `int32` and `utf8`. |
| `pa-ree.arrows` | Run-end encoded `int32`. |
| `pa-view.arrows` | String view, including one string longer than 12 bytes. |
| `pa-lview.arrows` | List view of `int32`. |
| `pa-fsb.arrows` | Fixed-size binary of 3 bytes. |
| `tensor.arrows` | A 2×3 `int32` tensor message. |

`lz4-hello.lz4` and the `zstd-*.zst` files are codec frames. `zstd-dict.zst` is rejected because its dictionary id is not zero. `zstd-skip.zst` has a skippable frame in front of a Zstd frame. `zstd-checksum.zst` carries a content checksum.

`testdata/schema/message.json` is the JSON Schema document the code generator reads. `tests/generated/Message.mojo` is the checked-in output. `pixi run check-generated` fails if those two drift apart.

PyArrow is an oracle for local checks. The test programs in `tests/` do not import it, so continuous integration does not install it.
