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

valid_log_date() {
  value=$1

  date -d "$value" '+%F' 2>/dev/null | grep -qxF "$value"
}

LOG_DIR=$(abs_path "$MOONBASE_LOG_DIR")
OUT=$(abs_path "$MOONBASE_NEWS_JSON")
OUT_DIR=$(dirname -- "$OUT")
ROWS=$(mktemp)
SORTED_ROWS=$(mktemp)
LOG_FILES=$(mktemp)
DUPLICATE_KEYS=
DUPLICATE_KEYS_SORTED=
OUT_TMP=

cleanup() {
  rm -f     "$ROWS"     "$SORTED_ROWS"     "$LOG_FILES"     "$LOG_FILES.unsorted"     "$DUPLICATE_KEYS"     "$DUPLICATE_KEYS_SORTED"     "$OUT_TMP"
}

trap cleanup EXIT HUP INT TERM

mkdir -p "$OUT_DIR"
OUT_TMP=$(mktemp "$OUT_DIR/.moonbase-news.XXXXXX")
: > "$ROWS"

if [ -d "$LOG_DIR" ]; then
  if ! find "$LOG_DIR" -type f -name '*.log' > "$LOG_FILES.unsorted"; then
    printf 'could not enumerate Moonbase log files: %s\n' "$LOG_DIR" >&2
    exit 1
  fi

  if ! LC_ALL=C sort "$LOG_FILES.unsorted" > "$LOG_FILES"; then
    printf 'could not sort Moonbase log files: %s\n' "$LOG_DIR" >&2
    exit 1
  fi

  rm -f "$LOG_FILES.unsorted"

  while IFS= read -r log; do
    [ -n "$log" ] || continue
    repo=$(basename -- "$log" .log)

    [ -n "$repo" ] ||
      {
        printf 'empty repository name for log: %s\n' "$log" >&2
        exit 1
      }

    case "$repo" in
      *"	"*)
        printf 'tab in repository name for log: %s\n' "$log" >&2
        exit 1
        ;;
    esac

    line_number=0
    while IFS='|' read -r date commit subject || [ -n "$date$commit$subject" ]; do
      line_number=$((line_number + 1))

      [ -n "$date" ] ||
        {
          printf 'missing date in %s:%s\n' "$log" "$line_number" >&2
          exit 1
        }

      valid_log_date "$date" ||
        {
          printf 'invalid date in %s:%s: %s\n' \
            "$log" "$line_number" "$date" >&2
          exit 1
        }

      [ -n "$commit" ] ||
        {
          printf 'missing commit in %s:%s\n' "$log" "$line_number" >&2
          exit 1
        }

      case "$commit" in
        *[!0-9a-f]*)
          printf 'invalid commit hash in %s:%s: %s\n' \
            "$log" "$line_number" "$commit" >&2
          exit 1
          ;;
      esac

      [ -n "$subject" ] ||
        {
          printf 'missing subject in %s:%s\n' "$log" "$line_number" >&2
          exit 1
        }

      case "$date$commit" in
        *"	"*)
          printf 'tab in commit log key at %s:%s\n' \
            "$log" "$line_number" >&2
          exit 1
          ;;
      esac

      subject=$(printf '%s' "$subject" | tr '\t\r' '  ')

      printf '%s\t%s\t%s\t%s\n' \
        "$date" "$repo" "$commit" "$subject" >> "$ROWS"
    done < "$log"
  done < "$LOG_FILES"
fi

TAB=$(printf '\t')
LC_ALL=C sort -t "$TAB" -k1,1r -k2,2 -k3,3 "$ROWS" > "$SORTED_ROWS"

DUPLICATE_KEYS=$(mktemp)
DUPLICATE_KEYS_SORTED=$(mktemp)

if ! cut -f2,3 "$SORTED_ROWS" > "$DUPLICATE_KEYS"; then
  printf 'could not extract Moonbase commit keys\n' >&2
  exit 1
fi

if ! LC_ALL=C sort "$DUPLICATE_KEYS" > "$DUPLICATE_KEYS_SORTED"; then
  printf 'could not sort Moonbase commit keys\n' >&2
  exit 1
fi

if ! uniq -d "$DUPLICATE_KEYS_SORTED" > "$DUPLICATE_KEYS"; then
  printf 'could not detect duplicate Moonbase commit keys\n' >&2
  exit 1
fi

if [ -s "$DUPLICATE_KEYS" ]; then
  while IFS='	' read -r repo commit; do
    printf 'duplicate Moonbase commit entry: %s %s\n' \
      "$repo" "$commit" >&2
  done < "$DUPLICATE_KEYS"

  exit 1
fi

printf '[\n' > "$OUT_TMP"
first=1

while IFS='	' read -r date repo commit subject || [ -n "$date$repo$commit$subject" ]; do
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
    printf ',\n' >> "$OUT_TMP"
  fi
  first=0

  printf '  {"date":"%s","category":"Moonbase","repository":"%s","module":"%s","version":"%s","commit":"%s","title":"%s","summary":"%s"}' \
    "$(json_escape "$date")" \
    "$(json_escape "$repo")" \
    "$(json_escape "$module")" \
    "$(json_escape "$version")" \
    "$(json_escape "$commit")" \
    "$(json_escape "$title")" \
    "$(json_escape "$summary")" >> "$OUT_TMP"
done < "$SORTED_ROWS"

printf '\n]\n' >> "$OUT_TMP"
mv "$OUT_TMP" "$OUT"
OUT_TMP=

printf 'generated %s\n' "$(rel_from_project "$OUT")"
