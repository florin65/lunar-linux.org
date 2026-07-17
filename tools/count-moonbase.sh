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

rel_from_project() {
  case "$1" in
    "$PROJECT_ROOT"/*) printf '%s\n' "${1#$PROJECT_ROOT/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

MOONBASE_PATH=$(abs_path "$MOONBASE_DIR")
OUT=$(abs_path "$MOONBASE_STATS_JSON")
OUT_DIR=$(dirname -- "$OUT")
MODULE_LIST=
OUT_TMP=

cleanup() {
  rm -f "$MODULE_LIST" "$OUT_TMP"
}

trap cleanup EXIT HUP INT TERM

if [ ! -d "$MOONBASE_PATH" ]; then
  printf 'missing Moonbase directory: %s\n' "$MOONBASE_PATH" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

MODULE_LIST=$(mktemp)

if ! find "$MOONBASE_PATH" \
  -path '*/zlocal' -prune -o \
  -path '*/zlocal/*' -prune -o \
  -type f -name DETAILS -print > "$MODULE_LIST"; then
  printf 'could not enumerate Moonbase modules: %s\n' \
    "$MOONBASE_PATH" >&2
  exit 1
fi

COUNT=$(wc -l < "$MODULE_LIST")
COUNT=$(printf '%s' "$COUNT" | tr -d '[:space:]')

case "$COUNT" in
  ''|*[!0-9]*)
    printf 'invalid Moonbase module count: %s\n' "$COUNT" >&2
    exit 1
    ;;
esac

OUT_TMP=$(mktemp "$OUT_DIR/.moonbase-stats.XXXXXX")

cat > "$OUT_TMP" <<EOF_JSON
{
  "modules": $COUNT
}
EOF_JSON

if ! mv "$OUT_TMP" "$OUT"; then
  printf 'could not publish Moonbase statistics: %s\n' "$OUT" >&2
  exit 1
fi

OUT_TMP=

printf 'generated %s\n' "$(rel_from_project "$OUT")"
