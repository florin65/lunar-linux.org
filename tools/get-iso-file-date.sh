#!/bin/sh

# =========================================================
# Fetch latest Lunar daily ISO metadata
# =========================================================
# Reads URL/output paths from site.conf and writes daily-iso.json.
# =========================================================

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONF="$PROJECT_ROOT/site.conf"

if [ ! -f "$CONF" ]; then
  printf 'missing config file: %s\n' "$CONF" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$CONF"

SITE_ROOT=${SITE_ROOT:-.}
ISO_BASE_URL=${ISO_BASE_URL:-https://lunar.lart.ca/latest}
DAILY_ISO_JSON=${DAILY_ISO_JSON:-public/data/daily-iso.json}

abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$PROJECT_ROOT/$SITE_ROOT" "$1" ;;
  esac
}

json_escape() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g'
}

ensure_trailing_slash() {
  case "$1" in
    */) printf '%s\n' "$1" ;;
    *)  printf '%s/\n' "$1" ;;
  esac
}

OUT=$(abs_path "$DAILY_ISO_JSON")
OUT_DIR=$(dirname -- "$OUT")
TMP="$OUT.tmp"
HTML=$(mktemp)
trap 'rm -f "$HTML"' EXIT

URL=$(ensure_trailing_slash "$ISO_BASE_URL")
mkdir -p "$OUT_DIR"

curl -fsSL "$URL" -o "$HTML"

ISO_URL=$(
  sed -n 's/.*href="\([^"]*lunar-[^"]*\.iso\)".*/\1/p' "$HTML" |
  head -n 1
)

if [ -z "$ISO_URL" ]; then
  printf 'could not find lunar ISO link at %s\n' "$URL" >&2
  exit 1
fi

case "$ISO_URL" in
  http://*|https://*) FULL_ISO_URL="$ISO_URL" ;;
  /*) FULL_ISO_URL="$(printf '%s' "$URL" | sed 's#^\(https\?://[^/]*\).*#\1#')$ISO_URL" ;;
  *) FULL_ISO_URL="$URL$ISO_URL" ;;
esac

ISO_FILE=$(basename -- "$ISO_URL")

SHA256=$(
  grep -Eo '[a-fA-F0-9]{64}' "$HTML" | head -n 1 || true
)

ISO_DATE=$(
  printf '%s\n' "$ISO_FILE" |
  sed -n 's/.*\([0-9][0-9][0-9][0-9][-]\?[0-9][0-9][-]\?[0-9][0-9]\).*/\1/p' |
  head -n 1
)

case "$ISO_DATE" in
  ????????)
    ISO_DATE=$(printf '%s' "$ISO_DATE" | sed 's/^\(....\)\(..\)\(..\)$/\1-\2-\3/')
    ;;
esac

GENERATED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

cat > "$TMP" <<EOF_JSON
{
  "iso_file": "$(json_escape "$ISO_FILE")",
  "iso_url": "$(json_escape "$FULL_ISO_URL")",
  "sha256": "$(json_escape "$SHA256")",
  "iso_date": "$(json_escape "$ISO_DATE")",
  "generated_at": "$(json_escape "$GENERATED_AT")"
}
EOF_JSON

mv "$TMP" "$OUT"
printf 'generated %s\n' "${OUT#$PROJECT_ROOT/}"
