#!/bin/sh
# Archive editorial news Markdown entries by content hash.
# Source defaults to src/news/*.md. A monthly index.json is maintained.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/archive-lib.sh"

src_dir=${1:-"$NEWS_DIR"}
[ -d "$src_dir" ] || archive_die "missing news source directory: $src_dir"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

count=0
skipped=0

find "$src_dir" -type f -name '*.md' | sort | while IFS= read -r f; do
  date_line=$(sed -n 's/^Date:[[:space:]]*//p' "$f" | head -1)
  day=$(printf '%s\n' "$date_line" | awk '{ print $1 }')
  case "$day" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) day=$(date -r "$f" +%F) ;;
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

  if [ -f "$outfile" ] || [ -f "$outfile.xz" ]; then
    skipped=$((skipped + 1))
  else
    cp "$f" "$outfile"
    count=$((count + 1))
  fi

  title=$(sed -n 's/^Title:[[:space:]]*//p' "$f" | head -1)
  category=$(sed -n 's/^Category:[[:space:]]*//p' "$f" | head -1)
  [ -n "$title" ] || title="$slug"
  [ -n "$category" ] || category="News"

  existing="$tmpdir/news-existing"
  merged="$tmpdir/news-merged"
  seen="$tmpdir/news-seen"
  : > "$existing"

  if archive_cat "$index" >/dev/null 2>&1; then
    archive_cat "$index" | archive_json_objects_from_cat > "$existing"
  fi

  cp "$existing" "$merged"
  sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$existing" | sort -u > "$seen"

  if ! grep -qxF "$hash" "$seen"; then
    # JSON escaping for generated metadata; news titles here are simple but escape anyway.
    esc_title=$(printf '%s' "$title" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    esc_cat=$(printf '%s' "$category" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    printf '{"id":"%s","date":"%s","category":"%s","title":"%s","slug":"%s","file":"%s"}\n' \
      "$hash" "$date_line" "$esc_cat" "$esc_title" "$slug" "$(basename -- "$outfile")" >> "$merged"
  fi

  archive_emit_json_array < "$merged" > "$index"
done

echo "archive-news: archived Markdown news entries from $src_dir"
