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

# Sign with a STABLE identity so macOS keeps the granted TCC permissions across
# rebuilds. Ad-hoc signing changes the cdhash every build and wipes them.
# Priority:
#   1) SYSTEMBAR_IDENTITY env var (explicit override)
#   2) the machine's "Apple Development" identity (already present, Apple-trusted)
#   3) a self-signed "SystemBar Dev" identity if it exists
#   4) ad-hoc fallback (permissions will reset each build)
IDENTITY="${SYSTEMBAR_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -m1 "Apple Development" | sed -E 's/.*"(.*)"/\1/')"
fi
if [ -z "$IDENTITY" ] && security find-identity -v -p codesigning 2>/dev/null | grep -q "SystemBar Dev"; then
    IDENTITY="SystemBar Dev"
fi

if [ -n "$IDENTITY" ]; then
    echo "▸ Signing with \"$IDENTITY\"…"
    codesign --force --deep --sign "$IDENTITY" "$APP"
else
    echo "▸ Ad-hoc signing (no stable identity found; permissions will reset each build)…"
    codesign --force --deep --sign - "$APP"
fi

echo "✓ Built $APP"
echo "  Run with: open \"$APP\"   (or relaunch after rebuild: killall SystemBar; open \"$APP\")"
