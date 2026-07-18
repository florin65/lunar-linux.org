#!/bin/sh
# Final maintenance and report normalization for the Website build.
# Removes only outputs that have an associated generator signature.

set -eu

PROJECT_ROOT=${PROJECT_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
SRC=${SRC:-$PROJECT_ROOT/src/markdown}
NEWS_SRC=${NEWS_SRC:-$PROJECT_ROOT/src/news}
PUBLIC=${PUBLIC:-$PROJECT_ROOT/docs}
BUILD=${BUILD:-$PROJECT_ROOT/cache}
BUILD_REPORT_FILE=${BUILD_REPORT_FILE:-$BUILD/build-report.txt}
PAGE_SIGNATURE_DIR=${PAGE_SIGNATURE_DIR:-$BUILD/page-signatures}
NEWS_SIGNATURE_DIR=${NEWS_SIGNATURE_DIR:-$BUILD/news-signatures}
ARCHIVE_NEWS_SIGNATURE_DIR=${ARCHIVE_NEWS_SIGNATURE_DIR:-$BUILD/archive-news-signatures}
STRICT_BUILD=${STRICT_BUILD:-no}

removed_outputs=0
removed_signatures=0
maintenance_warnings=0

report_problem() {
  maintenance_warnings=$((maintenance_warnings + 1))
  printf '  maintenance: %s\n' "$1" >> "$BUILD_REPORT_FILE"
  printf 'maintenance warning: %s\n' "$1" >&2
}

remove_owned_pair() {
  signature=$1
  output=$2

  if [ -f "$output" ]; then
    rm -f "$output"
    removed_outputs=$((removed_outputs + 1))
    printf 'removed stale output %s\n' "${output#$PROJECT_ROOT/}"
  fi

  if [ -f "$signature" ]; then
    rm -f "$signature"
    removed_signatures=$((removed_signatures + 1))
  fi
}

clean_page_state() {
  [ -d "$PAGE_SIGNATURE_DIR" ] || return 0

  find "$PAGE_SIGNATURE_DIR" -type f -name '*.sha256' | sort |
  while IFS= read -r signature; do
    rel=${signature#"$PAGE_SIGNATURE_DIR"/}
    rel_no_ext=${rel%.sha256}
    source="$SRC/$rel_no_ext.md"
    output="$PUBLIC/$rel_no_ext.html"

    if [ ! -f "$source" ]; then
      remove_owned_pair "$signature" "$output"
    elif [ ! -f "$output" ]; then
      rm -f "$signature"
      removed_signatures=$((removed_signatures + 1))
    fi
  done
}

clean_news_state() {
  [ -d "$NEWS_SIGNATURE_DIR" ] || return 0

  find "$NEWS_SIGNATURE_DIR" -type f -name '*.sha256' | sort |
  while IFS= read -r signature; do
    rel=${signature#"$NEWS_SIGNATURE_DIR"/}
    key=${rel%.sha256}
    source="$NEWS_SRC/${key#news/}.md"
    output="$PUBLIC/news/${key#news/}.html"

    if [ ! -f "$source" ]; then
      remove_owned_pair "$signature" "$output"
    elif [ ! -f "$output" ]; then
      rm -f "$signature"
      removed_signatures=$((removed_signatures + 1))
    fi
  done
}

clean_archive_signature_state() {
  [ -d "$ARCHIVE_NEWS_SIGNATURE_DIR" ] || return 0

  find "$ARCHIVE_NEWS_SIGNATURE_DIR" -type f -name '*.sha256' | sort |
  while IFS= read -r signature; do
    rel=${signature#"$ARCHIVE_NEWS_SIGNATURE_DIR"/}
    output_rel=${rel%.sha256}.html
    output="$PUBLIC/archive/$output_rel"

    if [ ! -f "$output" ]; then
      rm -f "$signature"
      removed_signatures=$((removed_signatures + 1))
    fi
  done
}

normalize_problem_section() {
  [ -f "$BUILD_REPORT_FILE" ] || return 0

  tmp=$(mktemp "$BUILD/.build-report-normalize.XXXXXX")

  awk '
    BEGIN {
      in_problems = 0
      problem_count = 0
    }

    /^Problems$/ {
      in_problems = 1
      print
      next
    }

    in_problems && /^[A-Za-z][A-Za-z ]*$/ {
      if (problem_count == 0)
        print "  none"
      in_problems = 0
      print
      next
    }

    in_problems && /^  / {
      problem_count++
      print
      next
    }

    {
      print
    }

    END {
      if (in_problems && problem_count == 0)
        print "  none"
    }
  ' "$BUILD_REPORT_FILE" > "$tmp"

  mv "$tmp" "$BUILD_REPORT_FILE"
}

append_maintenance_report() {
  {
    printf '\nMaintenance\n'
    printf '  stale outputs removed: %s\n' "$removed_outputs"
    printf '  stale signatures removed: %s\n' "$removed_signatures"
    printf '  warnings: %s\n' "$maintenance_warnings"
  } >> "$BUILD_REPORT_FILE"
}

strict_report_failed() {
  [ "$STRICT_BUILD" = "yes" ] || return 1

  awk '
    /^[[:space:]]*(failed|warnings|skipped):[[:space:]]*[1-9][0-9]*[[:space:]]*$/ {
      bad = 1
    }

    /^Status:[[:space:]]*completed with warnings[[:space:]]*$/ {
      bad = 1
    }

    END {
      exit bad ? 0 : 1
    }
  ' "$BUILD_REPORT_FILE"
}

clean_page_state
clean_news_state
clean_archive_signature_state
append_maintenance_report
normalize_problem_section

if strict_report_failed; then
  printf 'STRICT_BUILD=yes: build report contains failures, warnings, or skipped items\n' >&2
  exit 1
fi

exit 0
