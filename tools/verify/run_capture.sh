#!/usr/bin/env bash
# Run a scene headlessly, drive scripted input, and write a contact sheet.
#
#   tools/verify/run_capture.sh <scene> <name> [frames] [every] [input_json] [WxH]
#
# Exits non-zero if Godot logged any error, or if no frames were captured.
# This is the gate: a feature is not done until this passes and the sheet has
# been looked at.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-$ROOT/.tools/godot}"

SCENE="${1:?usage: run_capture.sh <res://scene.tscn> <name> [frames] [every] [input_json]}"
NAME="${2:?missing capture name}"
FRAMES="${3:-120}"
EVERY="${4:-6}"
INPUTS="${5:-}"
RES="${6:-480x270}"
START="${7:-0}"
COLS="${8:-6}"

OUT_DIR="$ROOT/artifacts/$NAME"
SHEET="$OUT_DIR/sheet.png"
LOG="$OUT_DIR/godot.log"
rm -rf "$OUT_DIR"; mkdir -p "$OUT_DIR/frames"

if [[ ! -x "$GODOT" ]]; then
  echo "godot not found at $GODOT - run tools/verify/get_godot.sh" >&2
  exit 127
fi

ARGS=(
  --scene="$SCENE"
  --frames="$FRAMES"
  --every="$EVERY"
  --out="$SHEET"
  --dump-dir="$OUT_DIR/frames"
  --start="$START"
  --cols="$COLS"
)
[[ -n "$INPUTS" ]] && ARGS+=(--inputs="$INPUTS")

# gl_compatibility + llvmpipe is the only renderer available in CI//container.
# Geometry, animation and gameplay are identical to the shipping Forward+
# build; only lighting fidelity differs.
timeout 300 xvfb-run -a "$GODOT" \
  --path "$ROOT" \
  --rendering-method gl_compatibility \
  --rendering-driver opengl3 \
  --audio-driver Dummy \
  --fixed-fps 60 \
  --resolution "$RES" \
  res://tools/verify/CaptureHarness.tscn \
  -- "${ARGS[@]}" >"$LOG" 2>&1
RC=$?

# Godot reports script failures on stdout/stderr rather than via exit code, so
# the log is the real signal.
if grep -qE "SCRIPT ERROR|USER ERROR|^ERROR:" "$LOG"; then
  echo "FAIL [$NAME] godot logged errors:" >&2
  grep -nE "SCRIPT ERROR|USER ERROR|^ERROR:" "$LOG" | head -20 >&2
  exit 1
fi
if [[ $RC -ne 0 ]]; then
  echo "FAIL [$NAME] godot exited $RC" >&2
  tail -20 "$LOG" >&2
  exit "$RC"
fi
if [[ ! -s "$SHEET" ]]; then
  echo "FAIL [$NAME] no contact sheet produced" >&2
  tail -20 "$LOG" >&2
  exit 1
fi

echo "PASS [$NAME] -> $SHEET ($(find "$OUT_DIR/frames" -name '*.png' | wc -l) frames)"
