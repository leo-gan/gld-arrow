#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
if command -v pixi >/dev/null 2>&1; then
  exec pixi run mojo run -I src benches/microbench.mojo
fi
exec mojo run -I src benches/microbench.mojo
