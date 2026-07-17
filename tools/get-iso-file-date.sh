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
PUBLIC_DIR=${PUBLIC_DIR:-docs}
DATA_DIR=${DATA_DIR:-$PUBLIC_DIR/data}
ISO_BASE_URL=${ISO_BASE_URL:-https://lunar.lart.ca/latest}
DAILY_ISO_JSON=${DAILY_ISO_JSON:-$DATA_DIR/daily-iso.json}

abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$PROJECT_ROOT/$SITE_ROOT" "$1" ;;
  esac
}

rel_from_project() {
  case "$1" in
    "$PROJECT_ROOT"/*) printf '%s\n' "${1#$PROJECT_ROOT/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

json_escape() {
  printf '%s' "$1" | awk '
    BEGIN {
      first = 1
    }
    {
      if (!first)
        printf "\\n"
      first = 0

      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      gsub(/\t/, "\\t")
      gsub(/\r/, "\\r")

      printf "%s", $0
    }
  '
}

ensure_trailing_slash() {
  case "$1" in
    */) printf '%s\n' "$1" ;;
    *)  printf '%s/\n' "$1" ;;
  esac
}

OUT=$(abs_path "$DAILY_ISO_JSON")
OUT_DIR=$(dirname -- "$OUT")
HTML=
OUT_TMP=

cleanup() {
  rm -f "$HTML" "$OUT_TMP"
}

trap cleanup EXIT HUP INT TERM

URL=$(ensure_trailing_slash "$ISO_BASE_URL")
mkdir -p "$OUT_DIR"

HTML=$(mktemp)
OUT_TMP=$(mktemp "$OUT_DIR/.daily-iso.XXXXXX")

curl -fsSL "$URL" -o "$HTML"

ISO_URL=$(
  awk '
    {
      line = $0

      while (match(line, /href="[^"]*lunar-[^"]*\.iso"/)) {
        value = substr(line, RSTART + 6, RLENGTH - 7)
        links[value] = 1
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END {
      for (value in links) {
        selected = value
        count++
      }

      if (count != 1)
        exit 1

      print selected
    }
  ' "$HTML"
) || {
  printf 'expected exactly one distinct lunar ISO link at %s\n' \
    "$URL" >&2
  exit 1
}

case "$ISO_URL" in
  http://*|https://*) FULL_ISO_URL="$ISO_URL" ;;
  /*) FULL_ISO_URL="$(printf '%s' "$URL" | sed 's#^\(https\?://[^/]*\).*#\1#')$ISO_URL" ;;
  *) FULL_ISO_URL="$URL$ISO_URL" ;;
esac

ISO_FILE=$(basename -- "$ISO_URL")

SHA256=$(
  awk '
    {
      line = $0
      while (match(line, /[[:xdigit:]]{64}/)) {
        value = substr(line, RSTART, RLENGTH)
        print tolower(value)
        found++
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END {
      if (found != 1)
        exit 1
    }
  ' "$HTML"
) || {
  printf 'expected exactly one SHA256 value at %s\n' "$URL" >&2
  exit 1
}

ISO_DATE=$(
  awk '
    match($0, /[0-9][0-9][0-9][0-9]-?[0-9][0-9]-?[0-9][0-9]/) {
      print substr($0, RSTART, RLENGTH)
      exit
    }
  ' <<EOF_ISO_FILE
$ISO_FILE
EOF_ISO_FILE
)

case "$ISO_DATE" in
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
    ISO_DATE=$(
      awk -v value="$ISO_DATE" 'BEGIN {
        print substr(value, 1, 4) "-" \
              substr(value, 5, 2) "-" \
              substr(value, 7, 2)
      }'
    )
    ;;
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
    ;;
  *)
    printf 'could not extract ISO date from file name: %s\n' \
      "$ISO_FILE" >&2
    exit 1
    ;;
esac

NORMALIZED_ISO_DATE=$(
  date -d "$ISO_DATE 00:00:00" '+%F' 2>/dev/null
) || {
  printf 'invalid ISO date in file name: %s\n' "$ISO_DATE" >&2
  exit 1
}

if [ "$NORMALIZED_ISO_DATE" != "$ISO_DATE" ]; then
  printf 'invalid ISO date in file name: %s\n' "$ISO_DATE" >&2
  exit 1
fi

GENERATED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

cat > "$OUT_TMP" <<EOF_JSON
{
  "iso_file": "$(json_escape "$ISO_FILE")",
  "iso_url": "$(json_escape "$FULL_ISO_URL")",
  "sha256": "$(json_escape "$SHA256")",
  "iso_date": "$(json_escape "$ISO_DATE")",
  "generated_at": "$(json_escape "$GENERATED_AT")"
}
EOF_JSON

if ! mv "$OUT_TMP" "$OUT"; then
  printf 'could not publish daily ISO metadata: %s\n' "$OUT" >&2
  exit 1
fi

OUT_TMP=

printf 'generated %s\n' "$(rel_from_project "$OUT")"
