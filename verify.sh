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

# scene | name | frames | every | input script | resolution | start frame | cols
# Ranges are tuned to frame the moment each capture is meant to prove, rather
# than dumping a whole run and downscaling it into something unreadable.
CAPTURES=(
  "res://levels/Arena01.tscn|gait|92|3|res://tools/verify/inputs/run_cycle.json|560x420|62|5"
  "res://levels/Arena01.tscn|jump_arc|104|4|res://tools/verify/inputs/jump_arc.json|480x360|34|6"
  "res://levels/Arena01.tscn|dodge_iframes|52|2|res://tools/verify/inputs/dodge_iframes.json|480x360|20|6"
)

step "visual captures"
for entry in "${CAPTURES[@]}"; do
  IFS='|' read -r scene name frames every inputs res start cols <<<"$entry"
  bash "$ROOT/tools/verify/run_capture.sh" \
    "$scene" "$name" "$frames" "$every" "$inputs" "$res" "$start" "$cols" || FAILED=1
done

step "result"
if [[ $FAILED -ne 0 ]]; then
  echo "VERIFY FAILED"
  exit 1
fi
echo "VERIFY PASSED - review contact sheets in artifacts/*/sheet.png"
