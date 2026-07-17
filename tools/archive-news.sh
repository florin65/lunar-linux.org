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

cleanup() {
  rm -rf "$tmpdir"
  rm -f "$index_tmp"
}

trap cleanup EXIT HUP INT TERM

count=0
skipped=0

find "$src_dir" -type f -name '*.md' | sort | while IFS= read -r f; do
  date_line=$(sed -n 's/^Date:[[:space:]]*//p' "$f" | head -1)
  day=$(printf '%s\n' "$date_line" | awk '{ print $1 }')
  case "$day" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      archive_date=$date_line
      ;;
    *)
      day=$(date -r "$f" +%F)
      archive_date=$day
      ;;
  esac

  year=$(archive_year "$day")
  month=$(archive_month "$day")
  outdir="$ARCHIVE_ROOT/news/$year/$month"
  archive_mkdir "$outdir"

  hash=$(archive_sha256_file "$f")
  short=$(printf '%s' "$hash" | cut -c1-12)
  slug=$(basename -- "$f" .md)
  outfile="$outdir/$day-$short.md"
  index="$outdir/index.json"

  title=$(sed -n 's/^Title:[[:space:]]*//p' "$f" | head -1)
  category=$(sed -n 's/^Category:[[:space:]]*//p' "$f" | head -1)
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
      cp "$f" "$outfile"
      count=$((count + 1))
    fi

    # JSON escaping for generated metadata; news titles here are simple but escape anyway.
    esc_title=$(printf '%s' "$title" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    esc_cat=$(printf '%s' "$category" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    printf '{"id":"%s","date":"%s","category":"%s","title":"%s","slug":"%s","file":"%s"}\n' \
      "$hash" "$archive_date" "$esc_cat" "$esc_title" "$slug" "$(basename -- "$outfile")" >> "$merged"
  else
    skipped=$((skipped + 1))
  fi

  index_tmp=$(mktemp "$outdir/.index.json.XXXXXX")
  if archive_emit_json_array < "$merged" > "$index_tmp"; then
    mv "$index_tmp" "$index"
    index_tmp=
  else
    archive_die "could not build archived news index: $index"
  fi
done

echo "archive-news: archived Markdown news entries from $src_dir"
