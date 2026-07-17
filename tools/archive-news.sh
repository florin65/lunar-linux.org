#!/bin/sh
# Archive editorial news Markdown entries by content hash.
# Source defaults to src/news/*.md. A monthly index.json is maintained.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/archive-lib.sh"

src_dir=${1:-"$NEWS_DIR"}
[ -d "$src_dir" ] || archive_die "missing news source directory: $src_dir"

tmpdir=$(mktemp -d)
index_tmp=
source_tmp=

cleanup() {
  rm -rf "$tmpdir"
  rm -f "$index_tmp" "$source_tmp"
}

trap cleanup EXIT HUP INT TERM

json_escape() {
  printf '%s' "$1" | awk '
    BEGIN {
      ORS = ""
    }

    {
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)

        if (c == "\\") {
          printf "\\\\"
        } else if (c == "\"") {
          printf "\\\""
        } else if (c == "\t") {
          printf "\\t"
        } else if (c == "\r") {
          printf "\\r"
        } else {
          printf "%s", c
        }
      }
    }
  '
}

valid_news_date() {
  value=$1
  day=${value%% *}
  hour=
  minute=

  case "$value" in
    "$day "*)
      time_part=${value#"$day "}
      hour=${time_part%:*}
      minute=${time_part#*:}
      ;;
  esac

  if ! date -d "$day" '+%F' 2>/dev/null | grep -qxF "$day"; then
    return 1
  fi

  if [ -n "$hour" ]; then
    case "$hour" in
      0[0-9]|1[0-9]|2[0-3]) ;;
      *) return 1 ;;
    esac

    case "$minute" in
      [0-5][0-9]) ;;
      *) return 1 ;;
    esac
  fi

  return 0
}

count=0
skipped=0

find "$src_dir" -type f -name '*.md' | sort | while IFS= read -r f; do
  metadata="$tmpdir/news-metadata"
  awk '
    /^[[:space:]]*$/ {
      exit
    }

    {
      print
    }
  ' "$f" > "$metadata"

  date_line=$(sed -n 's/^Date:[[:space:]]*//p' "$metadata" | head -1)

  if valid_news_date "$date_line"; then
    archive_date=$date_line
    day=${date_line%% *}
  else
    day=$(date -r "$f" +%F)
    archive_date=$day
  fi

  year=$(archive_year "$day")
  month=$(archive_month "$day")
  outdir="$ARCHIVE_ROOT/news/$year/$month"
  archive_mkdir "$outdir"

  hash=$(archive_sha256_file "$f")
  short=$(printf '%s' "$hash" | cut -c1-12)
  slug=$(basename -- "$f" .md)
  outfile="$outdir/$day-$short.md"
  index="$outdir/index.json"
  source_is_new=0

  title=$(sed -n 's/^Title:[[:space:]]*//p' "$metadata" | head -1)
  category=$(sed -n 's/^Category:[[:space:]]*//p' "$metadata" | head -1)
  [ -n "$title" ] || title="$slug"
  [ -n "$category" ] || category="News"

  existing="$tmpdir/news-existing"
  merged="$tmpdir/news-merged"
  seen="$tmpdir/news-seen"
  index_raw="$tmpdir/news-index-raw"
  : > "$existing"
  : > "$index_raw"

  if [ -f "$index" ] || [ -f "$index.xz" ]; then
    if ! archive_cat "$index" > "$index_raw"; then
      archive_die "could not read archived news index: $index"
    fi

    if ! archive_json_objects_from_cat < "$index_raw" > "$existing"; then
      archive_die "could not parse archived news index: $index"
    fi
  fi

  cp "$existing" "$merged"
  sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$existing" | sort -u > "$seen"

  if ! grep -qxF "$hash" "$seen"; then
    if [ -f "$outfile" ] || [ -f "$outfile.xz" ]; then
      skipped=$((skipped + 1))
    else
      source_tmp=$(mktemp "$outdir/.news-source.XXXXXX")
      if ! cat "$f" > "$source_tmp"; then
        archive_die "could not stage archived news source: $f"
      fi
      source_is_new=1
    fi

    archive_file=$(basename -- "$outfile")
    esc_hash=$(json_escape "$hash")
    esc_date=$(json_escape "$archive_date")
    esc_category=$(json_escape "$category")
    esc_title=$(json_escape "$title")
    esc_slug=$(json_escape "$slug")
    esc_file=$(json_escape "$archive_file")

    printf '{"id":"%s","date":"%s","category":"%s","title":"%s","slug":"%s","file":"%s"}\n' \
      "$esc_hash" "$esc_date" "$esc_category" "$esc_title" "$esc_slug" "$esc_file" >> "$merged"
  else
    skipped=$((skipped + 1))
  fi

  index_tmp=$(mktemp "$outdir/.index.json.XXXXXX")
  if ! archive_emit_json_array < "$merged" > "$index_tmp"; then
    archive_die "could not build archived news index: $index"
  fi

  if [ "${source_is_new:-0}" -eq 1 ]; then
    mv "$source_tmp" "$outfile"
    source_tmp=
    count=$((count + 1))
  fi

  mv "$index_tmp" "$index"
  index_tmp=
done

echo "archive-news: archived Markdown news entries from $src_dir"
