#!/bin/sh
# Lunar archive dispatcher.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/archive-lib.sh"

cmd=${1:-help}
shift || true

case "$cmd" in
  commits)
    "$SCRIPT_DIR/archive-commits.sh" "$@"
    ;;
  news)
    "$SCRIPT_DIR/archive-news.sh" "$@"
    ;;
  all)
    "$SCRIPT_DIR/archive-commits.sh"
    "$SCRIPT_DIR/archive-news.sh"
    ;;
  close-day)
    archive_close_day_tree "$ARCHIVE_ROOT/commits" 2>/dev/null || true
    archive_close_day_tree "$ARCHIVE_ROOT/news" 2>/dev/null || true
    echo "archive: closed old plain files with xz"
    ;;
  list)
    section=${1:-}
    year=${2:-}
    month=${3:-}
    [ -n "$section" ] || archive_die "usage: archive.sh list <commits|news> [year] [month]"
    path="$ARCHIVE_ROOT/$section"
    [ -n "$year" ] && path="$path/$year"
    [ -n "$month" ] && path="$path/$month"
    find "$path" -type f 2>/dev/null | sort
    ;;
  search)
    pattern=${1:-}
    [ -n "$pattern" ] || archive_die "usage: archive.sh search <pattern>"
    find "$ARCHIVE_ROOT" -type f | sort | while IFS= read -r f; do
      case "$f" in
        *.xz) xzcat "$f" 2>/dev/null | grep -Hn -- "$pattern" /dev/stdin | sed "s#/dev/stdin#$f#" || true ;;
        *) grep -Hn -- "$pattern" "$f" || true ;;
      esac
    done
    ;;
  help|*)
    cat <<USAGE
usage: tools/archive.sh <command> [args]

commands:
  commits [json]       archive commit journal JSON
  news [src-dir]       archive Markdown news files
  all                  archive commits and news using defaults
  close-day            compress old archive files with xz
  list SECTION [Y M]   list archived files
  search PATTERN       search archive, including .xz files

variables:
  ARCHIVE_ROOT=archive
  DATA_DIR=docs/data
  ARCHIVE_DATE=YYYY-MM-DD
USAGE
    ;;
esac
