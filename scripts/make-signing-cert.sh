#!/bin/bash
# Generates a self-signed code-signing certificate (valid 10 years) for Flipio releases.
# Using the same certificate for every release gives the app a stable designated
# requirement, so macOS keeps the Accessibility permission after updates.
#
# Output: flipio-signing.p12. Keep it safe: losing it means users must re-grant
# the permission once when a new certificate is introduced.
set -euo pipefail

NAME="Flipio Self-Signed"
PASS="${1:-$(openssl rand -base64 18)}"
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT

cat > "$DIR/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$DIR/key.pem" -out "$DIR/cert.pem" -config "$DIR/openssl.cnf"
openssl pkcs12 -export -legacy -inkey "$DIR/key.pem" -in "$DIR/cert.pem" \
  -name "$NAME" -out flipio-signing.p12 -passout "pass:$PASS"

echo "Created flipio-signing.p12"
echo "SIGNING_CERT_PASSWORD=$PASS"
echo "Next: base64 -i flipio-signing.p12 | pbcopy   # paste as SIGNING_CERT_P12_BASE64 secret"
