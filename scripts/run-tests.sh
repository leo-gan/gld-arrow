#!/usr/bin/env bash
# Compile and run every tests/test_*.mojo file.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if command -v pixi >/dev/null 2>&1; then
  MOJO=(pixi run mojo)
elif command -v mojo >/dev/null 2>&1; then
  MOJO=(mojo)
else
  echo "mojo not found; run scripts/ci-setup.sh" >&2
  exit 1
fi

shopt -s nullglob
fail=0
for f in "$root"/tests/test_*.mojo; do
  base="$(basename "$f")"
  echo "=== tests/${base} ==="
  if ! "${MOJO[@]}" run -I src -I tests/generated "$f"; then
    fail=1
  fi
done
if [[ "$fail" -ne 0 ]]; then
  echo "one or more unit tests failed" >&2
  exit 1
fi
echo "all test files passed"
