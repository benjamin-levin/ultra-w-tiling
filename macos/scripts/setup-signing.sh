#!/usr/bin/env bash
set -euo pipefail

# Creates a self-signed code-signing identity in a dedicated keychain so every
# build has the same designated requirement and macOS keeps the Accessibility
# and Input Monitoring grants across rebuilds. Ad-hoc signatures change on
# every build, which silently revokes those grants.

CERT_NAME="${CERT_NAME:-Ultra-W Tiling Local Signing}"
SIGNING_DIR="${SIGNING_DIR:-$HOME/.config/ultrawtiling}"
KEYCHAIN="$SIGNING_DIR/signing.keychain-db"
PASSWORD_FILE="$SIGNING_DIR/keychain-password"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must run on macOS." >&2
  exit 1
fi

# codesign only finds identities in keychains on the user search list.
add_to_search_list() {
  local existing=()
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%\"}"
    line="${line#\"}"
    [[ "$line" == "$KEYCHAIN" ]] && return 0
    existing+=("$line")
  done < <(security list-keychains -d user)
  security list-keychains -d user -s "${existing[@]}" "$KEYCHAIN"
}

if [[ -f "$KEYCHAIN" && -f "$PASSWORD_FILE" ]]; then
  security unlock-keychain -p "$(cat "$PASSWORD_FILE")" "$KEYCHAIN"
  if security find-certificate -c "$CERT_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    add_to_search_list
    echo "Signing identity already set up in $KEYCHAIN"
    exit 0
  fi
fi

mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

openssl rand -hex 24 > "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"
password="$(cat "$PASSWORD_FILE")"

cat > "$work/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $CERT_NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$work/cert.cnf" -keyout "$work/key.pem" -out "$work/cert.pem" 2>/dev/null
openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
  -name "$CERT_NAME" -out "$work/identity.p12" -passout "pass:$password"

rm -f "$KEYCHAIN"
security create-keychain -p "$password" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"
security unlock-keychain -p "$password" "$KEYCHAIN"
security import "$work/identity.p12" -k "$KEYCHAIN" -P "$password" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$KEYCHAIN" >/dev/null
add_to_search_list

echo "Created signing identity \"$CERT_NAME\" in $KEYCHAIN"
