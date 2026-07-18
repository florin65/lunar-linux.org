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
  if [ -f "$1" ]; then
    cat "$1"
  elif [ -f "$1.xz" ]; then
    xzcat "$1.xz"
  else
    return 1
  fi
}

archive_sha256_file() {
  sha256sum "$1" | awk '{ print $1 }'
}

archive_write_atomic() (
  target=$1
  tmp="$target.$$"
  cat > "$tmp"
  mv "$tmp" "$target"
)

archive_compress_file() (
  f=$1
  compressed="$f.xz"

  [ -f "$f" ] || exit 0

  if [ -f "$compressed" ]; then
    rm -f "$compressed"
  fi

  xz -T0 -9e "$f"
)

archive_close_day_tree() (
  root=${1%/}
  today=$(archive_today)
  current_year=$(archive_year "$today")
  current_month=$(archive_month "$today")
  current_month_dir="$root/$current_year/$current_month"

  [ -d "$root" ] || exit 0

  find "$root" -type f ! -name '*.xz' | while IFS= read -r f; do
    base=$(basename -- "$f")
    dir=$(dirname -- "$f")

    case "$base" in
      "$today"*)
        continue
        ;;
      index.json)
        [ "$dir" = "$current_month_dir" ] && continue
        ;;
    esac

    archive_compress_file "$f"
  done
)

archive_json_objects() {
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
  awk -v key="$1" '
    function json_decode(s,    out, i, c) {
      out = ""

      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)

        if (c != "\\") {
          out = out c
          continue
        }

        i++
        if (i > length(s)) {
          out = out "\\"
          break
        }

        c = substr(s, i, 1)

        if (c == "\"") {
          out = out "\""
        } else if (c == "\\") {
          out = out "\\"
        } else if (c == "/") {
          out = out "/"
        } else if (c == "n") {
          out = out "\n"
        } else if (c == "r") {
          out = out "\r"
        } else if (c == "t") {
          out = out "\t"
        } else {
          out = out "\\" c
        }
      }

      return out
    }

    function field_value(line, key,    pat, rest, raw, i, c) {
      pat = "\"" key "\"[[:space:]]*:[[:space:]]*\""

      if (!match(line, pat)) {
        return ""
      }

      rest = substr(line, RSTART + RLENGTH)
      raw = ""

      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)

        if (c == "\\") {
          raw = raw c

          if (i < length(rest)) {
            i++
            raw = raw substr(rest, i, 1)
          }

          continue
        }

        if (c == "\"") {
          return json_decode(raw)
        }

        raw = raw c
      }

      return json_decode(raw)
    }

    {
      value = field_value($0, key)
      if (value != "") {
        print value
        exit
      }
    }
  '
}

archive_emit_json_array() (
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
)
