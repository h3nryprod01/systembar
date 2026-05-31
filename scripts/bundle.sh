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

# Prefer the stable self-signed identity (so TCC permissions survive rebuilds);
# fall back to ad-hoc if it hasn't been created yet.
IDENTITY="SystemBar Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "▸ Signing with \"$IDENTITY\"…"
    codesign --force --deep --options runtime --sign "$IDENTITY" "$APP"
else
    echo "▸ Ad-hoc signing (run scripts/make-signing-identity.sh once so permissions persist)…"
    codesign --force --deep --sign - "$APP"
fi

echo "✓ Built $APP"
echo "  Run with: open \"$APP\"   (or relaunch after rebuild: killall SystemBar; open \"$APP\")"
