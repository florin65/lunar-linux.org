#!/bin/sh
# Archive Moonbase commit journal JSON incrementally.
# Input defaults to docs/data/moonbase-news.json.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/archive-lib.sh"

input=${1:-"$DATA_DIR/moonbase-news.json"}
[ -f "$input" ] || archive_die "missing input: $input"

tmpdir=$(mktemp -d)
output_tmp=

cleanup() {
  rm -rf "$tmpdir"
  rm -f "$output_tmp"
}

trap cleanup EXIT HUP INT TERM

valid_commit_date() {
  value=$1

  date -d "$value" '+%F' 2>/dev/null | grep -qxF "$value"
}

archive_sha256_stdin() {
  sha256sum | awk '{ print $1 }'
}

objects="$tmpdir/objects"
archive_json_objects "$input" > "$objects"

if [ ! -s "$objects" ]; then
  echo "archive-commits: no commit entries in $input"
  exit 0
fi

# Archive by the date carried by each commit entry, not by build date.
cut_dates="$tmpdir/dates"
input_keys="$tmpdir/input-keys"
: > "$cut_dates"
: > "$input_keys"

while IFS= read -r obj; do
  day=$(printf '%s\n' "$obj" | archive_json_field date | head -1)
  repository=$(printf '%s\n' "$obj" | archive_json_field repository | head -1)
  commit=$(printf '%s\n' "$obj" | archive_json_field commit | head -1)

  [ -n "$day" ] ||
    archive_die "commit entry has no date in input: $input"

  valid_commit_date "$day" ||
    archive_die "commit entry has invalid date '$day' in input: $input"

  [ -n "$repository" ] ||
    archive_die "commit entry has no repository in input: $input"
  [ -n "$commit" ] ||
    archive_die "commit entry has no commit in input: $input"

  case "$repository$commit" in
    *"	"*)
      archive_die "tabs are not allowed in commit keys: $input"
      ;;
  esac

  key=$(printf '%s\t%s' "$repository" "$commit")
  if grep -qxF "$key" "$input_keys"; then
    archive_die "duplicate commit entry in input: $repository $commit"
  fi

  printf '%s\n' "$key" >> "$input_keys"
  printf '%s\n' "$day" >> "$cut_dates"
done < "$objects"

sort -u "$cut_dates" > "$cut_dates.tmp"
mv "$cut_dates.tmp" "$cut_dates"

while IFS= read -r day; do
  [ -n "$day" ] || continue
  year=$(archive_year "$day")
  month=$(archive_month "$day")
  outdir="$ARCHIVE_ROOT/commits/$year/$month"
  outfile="$outdir/$day.json"
  archive_mkdir "$outdir"

  existing="$tmpdir/existing-$day"
  existing_raw="$tmpdir/existing-raw-$day"
  incoming="$tmpdir/incoming-$day"
  merged="$tmpdir/merged-$day"
  seen="$tmpdir/seen-$day"

  : > "$existing"
  : > "$existing_raw"

  if [ -f "$outfile" ] || [ -f "$outfile.xz" ]; then
    if ! archive_cat "$outfile" > "$existing_raw"; then
      archive_die "could not read archived commit file: $outfile"
    fi

    if ! archive_json_objects_from_cat < "$existing_raw" > "$existing"; then
      archive_die "could not parse archived commit file: $outfile"
    fi
  fi

  : > "$incoming"

  while IFS= read -r obj; do
    object_day=$(printf '%s\n' "$obj" | archive_json_field date | head -1)

    if [ "$object_day" = "$day" ]; then
      printf '%s\n' "$obj" >> "$incoming"
    fi
  done < "$objects"

  cat "$existing" > "$merged"
  : > "$seen"
  : > "$seen.fingerprints"

  while IFS= read -r obj; do
    existing_day=$(printf '%s\n' "$obj" | archive_json_field date | head -1)
    repository=$(printf '%s\n' "$obj" | archive_json_field repository | head -1)
    commit=$(printf '%s\n' "$obj" | archive_json_field commit | head -1)

    [ "$existing_day" = "$day" ] ||
      archive_die "archived commit entry has wrong date in $outfile"

    [ -n "$repository" ] ||
      archive_die "archived commit entry has no repository in $outfile"
    [ -n "$commit" ] ||
      archive_die "archived commit entry has no commit in $outfile"

    case "$repository$commit" in
      *"	"*)
        archive_die "tabs are not allowed in archived commit keys: $outfile"
        ;;
    esac

    key=$(printf '%s\t%s' "$repository" "$commit")
    if grep -qxF "$key" "$seen"; then
      archive_die "duplicate archived commit entry in $outfile: $repository $commit"
    fi

    printf '%s\n' "$key" >> "$seen"
    existing_fingerprint=$(printf '%s\n' "$obj" | archive_sha256_stdin)
    printf '%s\t%s\n' "$key" "$existing_fingerprint" >> "$seen.fingerprints"
  done < "$existing"

  added=0
  while IFS= read -r obj; do
    repository=$(printf '%s\n' "$obj" | archive_json_field repository | head -1)
    commit=$(printf '%s\n' "$obj" | archive_json_field commit | head -1)

    [ -n "$repository" ] ||
      archive_die "commit entry has no repository in input: $input"
    [ -n "$commit" ] ||
      archive_die "commit entry has no commit in input: $input"

    case "$repository$commit" in
      *"	"*)
        archive_die "tabs are not allowed in commit keys: $input"
        ;;
    esac

    key=$(printf '%s\t%s' "$repository" "$commit")

    if grep -qxF "$key" "$seen"; then
      incoming_fingerprint=$(printf '%s\n' "$obj" | archive_sha256_stdin)
      archived_fingerprint=$(awk -F '\t' -v key="$key" '
        $1 "\t" $2 == key {
          print $3
          exit
        }
      ' "$seen.fingerprints")

      if [ -z "$archived_fingerprint" ] ||
         [ "$incoming_fingerprint" != "$archived_fingerprint" ]; then
        archive_die "commit entry differs from archived record: $repository $commit"
      fi
    else
      printf '%s\n' "$obj" >> "$merged"
      printf '%s\n' "$key" >> "$seen"
      added=$((added + 1))
    fi
  done < "$incoming"

  sort -u "$seen" > "$seen.tmp" && mv "$seen.tmp" "$seen"

  if [ "$added" -gt 0 ]; then
    output_tmp=$(mktemp "$outdir/.commit-archive.XXXXXX")
    if ! archive_emit_json_array < "$merged" > "$output_tmp"; then
      archive_die "could not build archived commit file: $outfile"
    fi

    mv "$output_tmp" "$outfile"
    output_tmp=
    [ -f "$outfile.xz" ] && rm -f "$outfile.xz"

    echo "archive-commits: $day added $added new commit(s) -> $outfile"
  else
    # Do not recreate a plain file when only a compressed archive exists.
    if [ ! -f "$outfile" ] && [ ! -f "$outfile.xz" ]; then
      output_tmp=$(mktemp "$outdir/.commit-archive.XXXXXX")
      if ! archive_emit_json_array < "$merged" > "$output_tmp"; then
        archive_die "could not build archived commit file: $outfile"
      fi

      mv "$output_tmp" "$outfile"
      output_tmp=
    fi

    echo "archive-commits: $day no new commits"
  fi
done < "$cut_dates"
