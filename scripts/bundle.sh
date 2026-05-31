#!/bin/bash
# Build SystemBar and assemble it into a runnable .app bundle.
#
#   ./scripts/bundle.sh          # release build → build/SystemBar.app
#   ./scripts/bundle.sh debug    # debug build
#
# Accessibility (and later Screen Recording) require a real .app bundle that is
# code-signed. We ad-hoc sign here, which is enough for local use.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/SystemBar.app"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG" --package-path "$ROOT"

BIN="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)/SystemBar"

echo "▸ Assembling bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SystemBar"
cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"

echo "▸ Ad-hoc signing…"
codesign --force --deep --sign - "$APP"

echo "✓ Built $APP"
echo "  Run with: open \"$APP\"   (or relaunch after rebuild: killall SystemBar; open \"$APP\")"
