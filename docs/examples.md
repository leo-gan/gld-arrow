# Examples

## One integer column

`examples/encode_batch.mojo` builds a nullable `int32` column and writes an IPC stream.

```bash
pixi run mojo run -I src examples/encode_batch.mojo
```

The program prints the stream length. The first message is the schema. The second message is the record batch. Eight `0xFF` bytes and a zero metadata length end the stream.

## A generated row

`tests/generated/Message.mojo` comes from `testdata/schema/message.json`. `id` is an `int64` column and `name` is a `utf8` column.

```mojo
from Message import Message

var row = Message()
row.id = 7
row.name = "a"
var raw = row.encode_bytes()
var back = Message.decode_from(Span(raw))
```

Compile that program with `-I src -I tests/generated`.

## Read a stream from disk

```mojo
from wire.ipc import decode_ipc_stream

var raw = open("testdata/golden/pa-list.arrows", "r").read_bytes()
var table = decode_ipc_stream(raw)
```

`table.batches` holds one batch. `table.fields` holds the list field and its `int32` child. `rows_from_batch` in `runtime.rows` turns that batch into one struct node per row.
