# mojo-arrow

mojo-arrow is a from-scratch [Apache Arrow](https://arrow.apache.org/docs/format/index.html) library for [Mojo](https://www.modular.com/mojo) 1.1.

The runtime reads and writes the Arrow columnar format, the IPC stream, the IPC file, tensors, and the Flight protocol messages. A code generator turns a JSON Schema document or an Arrow schema into a Mojo struct. None of this code wraps a C, C++, or Rust Arrow library.

| Page | What it explains |
| --- | --- |
| [Why Arrow](why-arrow.md) | Columnar values, IPC, and Flight. |
| [Instructions](instructions.md) | Install, import, and run the tests. |
| [Examples](examples.md) | A record batch and a generated struct. |
| [Techniques](techniques.md) | Layout, alignment, compression, and limits. |
| [Test data](test-data.md) | The streams checked into this repository. |
