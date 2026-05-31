#!/bin/bash
# Create a stable self-signed code-signing identity for SystemBar (run ONCE).
#
# Why: macOS ties Screen Recording / Accessibility permissions to the app's code
# signature. Ad-hoc signing (`codesign --sign -`) produces a new identity on
# every build, so each rebuild wipes the granted permissions. Signing with a
# persistent self-signed certificate keeps the identity — and the permissions —
# stable across rebuilds.
#
#   ./scripts/make-signing-identity.sh
#
# After running this once, ./scripts/bundle.sh automatically signs with it.
set -euo pipefail

IDENTITY="SystemBar Dev"

if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "✓ Signing identity \"$IDENTITY\" already exists."
    exit 0
fi

echo "▸ Creating self-signed code-signing identity \"$IDENTITY\"…"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# OpenSSL config with the codesigning extended key usage.
cat > "$TMP/cfg" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $IDENTITY
[ ext ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# Use the system LibreSSL (/usr/bin/openssl): it produces a PKCS#12 that macOS's
# `security import` accepts. Homebrew's OpenSSL 3 emits a MAC that fails import.
SSL=/usr/bin/openssl

"$SSL" req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -config "$TMP/cfg" >/dev/null 2>&1

# LibreSSL ignores -passout and prompts; feed it two empty lines instead.
printf '\n\n' | "$SSL" pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/identity.p12" -name "$IDENTITY" >/dev/null 2>&1

# Import into the login keychain and allow codesign to use it without prompting.
security import "$TMP/identity.p12" -k ~/Library/Keychains/login.keychain-db \
    -P "" -T /usr/bin/codesign >/dev/null 2>&1

# Trust the cert for code signing.
security add-trusted-cert -d -r trustAsRoot \
    -p codeSign -k ~/Library/Keychains/login.keychain-db "$TMP/cert.pem" >/dev/null 2>&1 || true

# Let codesign read the key without an interactive prompt.
security set-key-partition-list -S apple-tool:,apple:,codesign: \
    -s -k "" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1 || true

echo "✓ Created \"$IDENTITY\". Now run ./scripts/bundle.sh — permissions will persist across rebuilds."
echo "  (You may be asked to grant Screen Recording one more time for the new identity.)"
