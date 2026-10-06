# Techniques

## IPC messages

Each message starts with the continuation `0xFFFFFFFF` and a little-endian metadata length. The metadata is a FlatBuffer `Message` padded to 8 bytes. The body length in that message includes the padding that follows the body, so the next message stays aligned.

An IPC file starts with the six bytes `ARROW1` and two zero bytes. The embedded stream, including the end-of-stream mark, follows. The footer is a FlatBuffer. A little-endian footer length and a second `ARROW1` finish the file. Each footer block stores the file offset of a dictionary or record-batch message, the metadata length including the 8-byte prefix, and the body length.

The FlatBuffer tables are written by `src/runtime/flatbuf.mojo`. Field identifiers match `Schema.fbs`, `Message.fbs`, `File.fbs`, `Tensor.fbs`, and `SparseTensor.fbs` from Arrow 25.0.1. There is no dependency on another FlatBuffers package.

## Arrays

Integer, floating-point, decimal, and temporal values are little-endian in memory, even when a file declared big-endian. The reader swaps those buffers once while it copies them. Validity bits are packed with the least significant bit first. A null count of zero omits the validity bytes and still records a zero-length buffer.

Dictionary columns store index buffers in the record batch. The dictionary values travel in an earlier `DictionaryBatch`. A later batch with `isDelta` false replaces that dictionary. Nested field children are stored in a side list so a child struct's own children do not become children of the parent.

## Compression and limits

| Codec value | Frame |
| --- | --- |
| 0 | LZ4 frame, magic `04 22 4D 18` |
| 1 | Zstd frame, magic `28 B5 2F FD`. The writer emits raw blocks and RLE blocks. The reader accepts Huffman literals and FSE sequences. |

A compressed buffer starts with the uncompressed length as a little-endian `int64`. The value `-1` means the following bytes are already uncompressed. Empty buffers stay empty and omit that prefix.

| Limit | Value |
| --- | --- |
| Nesting depth | 64 |
| One buffer | 256 MiB |

A deeper tree or a larger slice raises `DecodeError`. The kind numbers are `EOF`, `SYNTAX`, `RANGE`, `UTF8`, `TYPE`, `DEPTH`, `SCHEMA`, `VERSION`, `COMPRESSION`, and `FLIGHT`.

## C data interface

`export_array` fills an `ArrowSchema` (72 bytes) and an `ArrowArray` (80 bytes) on linux-64. Format strings follow the C data interface. `release` is null because the `Columnar` value still owns the bytes. `export_device` copies that array into an `ArrowDeviceArray` and sets the device type. CPU uses device type 1 and device id `-1`.
