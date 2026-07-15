#!/bin/sh

# =========================================================
# Count Lunar Moonbase modules
# =========================================================
# Reads paths from site.conf and writes moonbase-stats.json.
# The local zlocal repository/directory is intentionally ignored.
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
MOONBASE_DIR=${MOONBASE_DIR:-../moonbase}
MOONBASE_STATS_JSON=${MOONBASE_STATS_JSON:-$DATA_DIR/moonbase-stats.json}

abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$PROJECT_ROOT/$SITE_ROOT" "$1" ;;
  esac
}

MOONBASE_PATH=$(abs_path "$MOONBASE_DIR")
OUT=$(abs_path "$MOONBASE_STATS_JSON")
OUT_DIR=$(dirname -- "$OUT")
TMP="$OUT.tmp"

if [ ! -d "$MOONBASE_PATH" ]; then
  printf 'missing Moonbase directory: %s\n' "$MOONBASE_PATH" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

COUNT=$(
  find "$MOONBASE_PATH" \
    -path '*/zlocal' -prune -o \
    -path '*/zlocal/*' -prune -o \
    -type f -name DETAILS -print | wc -l | tr -d '[:space:]'
)

cat > "$TMP" <<EOF_JSON
{
  "modules": $COUNT
}
EOF_JSON

mv "$TMP" "$OUT"
printf 'generated %s\n' "${OUT#$PROJECT_ROOT/}"
