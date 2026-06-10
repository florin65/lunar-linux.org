#!/bin/sh
# Common helpers for Lunar Linux archive tools.
# Keep this file POSIX-ish and dependency-light.

set -eu

SCRIPT_DIR=${SCRIPT_DIR:-$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)}
PROJECT_ROOT=${PROJECT_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}

: "${ARCHIVE_ROOT:=$PROJECT_ROOT/archive}"
: "${DATA_DIR:=$PROJECT_ROOT/docs/data}"
: "${NEWS_DIR:=$PROJECT_ROOT/src/news}"

archive_die() {
  printf '%s\n' "$*" >&2
  exit 1
}

archive_today() {
  date +%F
}

archive_year() {
  printf '%s\n' "$1" | cut -c1-4
}

archive_month() {
  printf '%s\n' "$1" | cut -c6-7
}

archive_mkdir() {
  mkdir -p "$1"
}

archive_cat() {
  f=$1
  if [ -f "$f" ]; then
    cat "$f"
  elif [ -f "$f.xz" ]; then
    xzcat "$f.xz"
  else
    return 1
  fi
}

archive_sha256_file() {
  sha256sum "$1" | awk '{ print $1 }'
}

archive_write_atomic() {
  target=$1
  tmp="$target.$$"
  cat > "$tmp"
  mv "$tmp" "$target"
}

archive_compress_file() {
  f=$1
  [ -f "$f" ] || return 0
  [ ! -f "$f.xz" ] || return 0
  xz -T0 -9e "$f"
}

archive_close_day_tree() {
  root=$1
  today=$(archive_today)
  [ -d "$root" ] || return 0

  find "$root" -type f ! -name '*.xz' | while IFS= read -r f; do
    base=$(basename -- "$f")
    case "$base" in
      "$today"*) continue ;;
      *) archive_compress_file "$f" ;;
    esac
  done
}

archive_json_objects() {
  # Print one compact JSON object per line from a generated JSON array where
  # each object is already stored on one line.
  sed -n '/^[[:space:]]*{/p' "$1" |
    sed 's/^[[:space:]]*//' |
    sed 's/,[[:space:]]*$//'
}

archive_json_objects_from_cat() {
  sed -n '/^[[:space:]]*{/p' |
    sed 's/^[[:space:]]*//' |
    sed 's/,[[:space:]]*$//'
}

archive_json_field() {
  field=$1
  sed -n 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

archive_emit_json_array() {
  # Reads object lines from stdin, writes valid JSON array.
  first=1
  printf '[\n'
  while IFS= read -r obj; do
    [ -n "$obj" ] || continue
    if [ "$first" -eq 0 ]; then
      printf ',\n'
    fi
    first=0
    printf '  %s' "$obj"
  done
  printf '\n]\n'
}
