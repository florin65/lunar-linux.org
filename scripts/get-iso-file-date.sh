#!/bin/sh

set -eu

URL="https://lunar.lart.ca/latest/"
#OUT="/path/to/site/data/daily-iso.json"
OUT="../data/daily-iso.json"
TMP="${OUT}.tmp"

HTML="$(mktemp)"
trap 'rm -f "$HTML"' EXIT

curl -fsSL "$URL" -o "$HTML"

ISO_URL=$(
  sed -n 's/.*href="\([^"]*lunar-[^"]*\.iso\)".*/\1/p' "$HTML" |
  head -n 1
)

ISO_FILE=$(basename "$ISO_URL")

SHA256=$(
  grep -Eo '[a-f0-9]{64}' "$HTML" |
  head -n 1
)

cat > "$TMP" <<EOF
{
  "iso_file": "$ISO_FILE",
  "iso_url": "$ISO_URL",
  "sha256": "$SHA256"
}
EOF

mv "$TMP" "$OUT"
