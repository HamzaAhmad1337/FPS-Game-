#!/usr/bin/env bash
# Fetch the pinned Godot build into .tools/ (gitignored). Idempotent.
set -euo pipefail

GODOT_VERSION="4.4.1-stable"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="$ROOT/.tools"
BIN="$DEST/godot"

if [[ -x "$BIN" ]] && "$BIN" --headless --version 2>/dev/null | grep -q "4.4.1"; then
  echo "godot already present: $("$BIN" --headless --version)"
  exit 0
fi

mkdir -p "$DEST"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
echo "downloading $URL"
curl -fsSL --retry 3 -o "$DEST/godot.zip" "$URL"
unzip -o -q "$DEST/godot.zip" -d "$DEST"
mv "$DEST/Godot_v${GODOT_VERSION}_linux.x86_64" "$BIN"
chmod +x "$BIN"
rm -f "$DEST/godot.zip"
echo "installed: $("$BIN" --headless --version)"
