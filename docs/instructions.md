# Instructions

The package name is `mojo-arrow`. The Mojo import is `arrow`. The code generator command is `gld-arrowgen-mojo`.

## Develop from this repository

Mojo is pinned to 1.1.0. Pixi installs it from the Modular channel. If that channel returns 401, put `PREFIX_API_KEY` in a local `.env` file and run the setup script again. Do not commit `.env`.

```bash
git clone https://github.com/leo-gan/gld-arrow.git
cd gld-arrow
bash scripts/ci-setup.sh
pixi run test
```

`pixi run test` compiles every file in `tests/`. `pixi run check-generated` regenerates `tests/generated/` and diffs it. `pixi run precompile` writes `.mojoc` packages under `/tmp/mojo-arrow-pkg`.

## Published package

The linux-64 package is on the prefix.dev channel `leo-gan/leo-gan`.

```bash
pixi add --channel https://prefix.dev/leo-gan/leo-gan mojo-arrow
```

That install provides `arrow.mojoc` and `gld-arrowgen-mojo`. It needs `mojo-compiler` 1.1.

## Generate a struct

`testdata/schema/message.json` is a JSON Schema object. The generator also accepts an Arrow integration schema whose top-level key is `fields`, and an IPC stream or file whose schema message is the input. A schema metadata entry named `title` names the generated struct. Without that entry the name is `Root`.

```bash
pixi run mojo run -I src src/codegen/cli.mojo -- \
  --schema testdata/schema/message.json --out tests/generated
```

The struct `Message` has `encoded_len`, `encode_to`, and `decode_from`. `encode_bytes` returns one IPC stream that holds a single row.
