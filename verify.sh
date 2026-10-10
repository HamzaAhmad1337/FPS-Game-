#!/usr/bin/env bash
# Full verification gate: reimport, logic tests, then every visual capture.
# Run this before every commit. Nothing is "done" until this exits 0 and the
# contact sheets under artifacts/ have been looked at.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"
FAILED=0

step() { printf '\n=== %s ===\n' "$1"; }

step "engine"
bash "$ROOT/tools/verify/get_godot.sh" || exit 127

# Global class_name registration lives in .godot/, which is regenerated on
# import. Skipping this makes newly added class_name scripts invisible and
# produces confusing parse errors.
step "import"
timeout 300 xvfb-run -a "$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1
echo "project reimported"

step "logic tests"
bash "$ROOT/tools/test/run_tests.sh" || FAILED=1

# scene | name | frames | every | input script
CAPTURES=(
  "res://scenes/smoke/SmokeTest.tscn|smoke|120|6|res://tools/verify/inputs/smoke_move_and_jump.json"
)

step "visual captures"
for entry in "${CAPTURES[@]}"; do
  IFS='|' read -r scene name frames every inputs <<<"$entry"
  bash "$ROOT/tools/verify/run_capture.sh" "$scene" "$name" "$frames" "$every" "$inputs" || FAILED=1
done

step "result"
if [[ $FAILED -ne 0 ]]; then
  echo "VERIFY FAILED"
  exit 1
fi
echo "VERIFY PASSED - review contact sheets in artifacts/*/sheet.png"
