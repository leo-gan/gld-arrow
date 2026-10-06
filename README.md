# mojo-arrow

A from-scratch Apache Arrow implementation for [Mojo](https://www.modular.com/mojo).
The runtime and the code generator are written in Mojo. They do not wrap, link,
or vendor the Arrow C++ library, arrow-rs, or any other C, C++, or Rust Arrow
library.

PyArrow is a **test oracle** only. It is not required to encode or decode at
runtime.

This repository is a standalone library. It is not part of any other project.

Documentation: [Why Arrow](https://leo-gan.github.io/gld-arrow/why-arrow/),
[Instructions](https://leo-gan.github.io/gld-arrow/instructions/),
[Examples](https://leo-gan.github.io/gld-arrow/examples/),
[Techniques](https://leo-gan.github.io/gld-arrow/techniques/),
[Test data](https://leo-gan.github.io/gld-arrow/test-data/).

## Install

Published package (linux-64) on [prefix.dev/leo-gan/leo-gan](https://prefix.dev/leo-gan/leo-gan):

```bash
pixi add --channel https://prefix.dev/leo-gan/leo-gan mojo-arrow
```

That installs `arrow.mojoc` and the `gld-arrowgen-mojo` CLI. It needs
`mojo-compiler` 1.1. After install, `from arrow import …` resolves with no
extra `-I`.

From a git checkout (development):

```bash
git clone https://github.com/leo-gan/gld-arrow.git
cd gld-arrow
pixi install
pixi run test
```

Local precompile (no conda install):

```bash
pixi run precompile
```

`from arrow import …` then resolves from `/tmp/mojo-arrow-pkg`
(`mojo run -I /tmp/mojo-arrow-pkg …`).

The recipe is `conda.recipe/recipe.yaml`. A GitHub Release on this repo builds
it and uploads it to the channel above.

## What it reads and writes

| Surface | Behavior |
| --- | --- |
| IPC stream and file | Schema, dictionary batches, record batches, and the file footer. Metadata version V4 and V5 are accepted. The writer emits V5. |
| Types | The Arrow 25 logical types, including views, list views, decimals, unions, dictionaries, and run-end encoding. |
| Compression | LZ4 frame and Zstd body compression, implemented in Mojo. |
| Tensors | Dense tensor messages, plus sparse COO, CSX, and CSF messages. |
| Flight | Flight protobuf messages and an in-memory HTTP/2 service. |
| Schema | JSON Schema objects and Arrow schema JSON. `gld-arrowgen-mojo` emits structs with `encoded_len`, `encode_to`, and `decode_from`. |

The writer uses little-endian buffers and 8-byte alignment. Two encodes of the
same value match when the options match. Nulls, field order, and schema
metadata are kept.

## Layout

`src/arrow` is the public package. `src/runtime` holds the columnar arena and
the FlatBuffer codec. `src/wire` holds IPC, tensors, and the file footer.
`src/compress` holds LZ4 and Zstd. `src/cabi` exports C data interface views.
`src/schema` and `src/codegen` turn a schema into Mojo.

Requires **Mojo 1.1.0**.

## License

MIT. Copyright (c) 2026 Leonid Ganeline.
