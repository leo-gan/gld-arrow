#!/usr/bin/env bash
# Precompile published packages into /tmp/mojo-arrow-pkg.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
out="${MOJO_ARROW_PKG:-/tmp/mojo-arrow-pkg}"
mkdir -p "$out"
if command -v pixi >/dev/null 2>&1; then
  MOJO=(pixi run mojo)
elif command -v mojo >/dev/null 2>&1; then
  MOJO=(mojo)
else
  echo "mojo not found; run scripts/ci-setup.sh" >&2
  exit 1
fi
"${MOJO[@]}" precompile -I src src/runtime -o "$out/runtime.mojoc"
"${MOJO[@]}" precompile -I src src/compress -o "$out/compress.mojoc"
"${MOJO[@]}" precompile -I src src/schema -o "$out/schema.mojoc"
"${MOJO[@]}" precompile -I src src/wire -o "$out/wire.mojoc"
"${MOJO[@]}" precompile -I src src/cabi -o "$out/cabi.mojoc"
if compgen -G "src/flight/*.mojo" >/dev/null; then
  "${MOJO[@]}" precompile -I src src/flight -o "$out/flight.mojoc"
fi
"${MOJO[@]}" precompile -I src src/arrow -o "$out/arrow.mojoc"
"${MOJO[@]}" build -I src src/codegen/cli.mojo -o "$out/gld-arrowgen-mojo"
echo "wrote $out"
