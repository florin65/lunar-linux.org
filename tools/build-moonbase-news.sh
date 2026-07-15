#!/bin/sh

# =========================================================
# Build Moonbase news JSON from cached git logs
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
BUILD_DIR=${BUILD_DIR:-cache}
PUBLIC_DIR=${PUBLIC_DIR:-docs}
DATA_DIR=${DATA_DIR:-$PUBLIC_DIR/data}
MOONBASE_LOG_DIR=${MOONBASE_LOG_DIR:-$BUILD_DIR/moonbase-logs}
MOONBASE_NEWS_JSON=${MOONBASE_NEWS_JSON:-$DATA_DIR/moonbase-news.json}

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
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e ':a;N;$!ba;s/\n/\\n/g'
}

LOG_DIR=$(abs_path "$MOONBASE_LOG_DIR")
OUT=$(abs_path "$MOONBASE_NEWS_JSON")
OUT_DIR=$(dirname -- "$OUT")
TMP="$OUT.tmp"

mkdir -p "$OUT_DIR"

printf '[\n' > "$TMP"
first=1

if [ -d "$LOG_DIR" ]; then
  find "$LOG_DIR" -type f -name '*.log' | sort | while IFS= read -r log; do
    repo=$(basename -- "$log" .log)

    while IFS='|' read -r date commit subject || [ -n "$date$commit$subject" ]; do
      [ -n "$date" ] || continue
      [ -n "$subject" ] || continue

      module=""
      version=""
      title="$subject"
      summary="$subject"

      case "$subject" in
        *": version bumped to "*|*": Version bumped to "*)
          module=${subject%%:*}
          version=$(printf '%s\n' "$subject" | sed -n 's/^[^:]*: [Vv]ersion bumped to[[:space:]]*\(.*\)$/\1/p')
          title="$module updated to $version"
          summary="version bumped to $version"
          ;;
        *": Bump to "*|*": bump to "*)
          module=${subject%%:*}
          version=$(printf '%s\n' "$subject" | sed -n 's/^[^:]*: [Bb]ump to[[:space:]]*\(.*\)$/\1/p')
          title="$module updated to $version"
          summary="bump to $version"
          ;;
      esac

      if [ "$first" -eq 0 ]; then
        printf ',\n' >> "$TMP"
      fi
      first=0

      printf '  {"date":"%s","category":"Moonbase","repository":"%s","module":"%s","version":"%s","commit":"%s","title":"%s","summary":"%s"}' \
        "$(json_escape "$date")" \
        "$(json_escape "$repo")" \
        "$(json_escape "$module")" \
        "$(json_escape "$version")" \
        "$(json_escape "$commit")" \
        "$(json_escape "$title")" \
        "$(json_escape "$summary")" >> "$TMP"
    done < "$log"
  done
fi

printf '\n]\n' >> "$TMP"
mv "$TMP" "$OUT"

printf 'generated %s\n' "$(rel_from_project "$OUT")"
