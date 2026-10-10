#!/usr/bin/env bash
# Headless logic tests. No rendering, no display required.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"

if [[ ! -x "$GODOT" ]]; then
  echo "godot not found at $GODOT - run tools/verify/get_godot.sh" >&2
  exit 127
fi

OUT=$("$GODOT" --headless --path "$ROOT" --script res://tools/test/test_runner.gd 2>&1)
RC=$?
echo "$OUT"
if grep -qE "SCRIPT ERROR|USER ERROR" <<<"$OUT"; then
  echo "FAIL script errors during tests" >&2
  exit 1
fi
exit $RC
