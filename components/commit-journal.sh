#!/bin/sh

# =========================================================
# Commit Journal component
# Render prepared five-field TSV Moonbase commit records.
# =========================================================

set -eu

if [ "$#" -ne 2 ]; then
  printf 'usage: %s current|archive prepared-commits.tsv\n' "$0" >&2
  exit 2
fi

variant=$1
input=$2
indent=${COMMIT_JOURNAL_INDENT:-}

case "$variant" in
  current|archive) ;;
  *)
    printf 'commit-journal: invalid variant: %s\n' "$variant" >&2
    exit 2
    ;;
esac

if [ ! -f "$input" ] || [ ! -r "$input" ]; then
  printf 'commit-journal: unreadable input file: %s\n' "$input" >&2
  exit 2
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT HUP INT TERM

if ! awk -v variant="$variant" -v indent="$indent" '
BEGIN {
  FS = "\t"
  valid = 1
}

function text_escape(s) {
  gsub(/&/, "\\&amp;", s)
  gsub(/</, "\\&lt;", s)
  gsub(/>/, "\\&gt;", s)
  return s
}

function attr_escape(s) {
  s = text_escape(s)
  gsub(/"/, "\\&quot;", s)
  gsub(/\047/, "\\&#39;", s)
  return s
}

{
  if (NF != 5) {
    printf "commit-journal: line %d: expected 5 tab-separated fields, found %d\n", NR, NF > "/dev/stderr"
    valid = 0
    next
  }

  for (i = 1; i <= 4; i++) {
    if ($i == "") {
      printf "commit-journal: line %d: field %d must not be empty\n", NR, i > "/dev/stderr"
      valid = 0
    }
  }

  commit[NR] = $1
  repository[NR] = $2
  module[NR] = $3
  summary[NR] = $4
  link_title[NR] = $5
  records = NR
}

END {
  if (!valid)
    exit 1

  i1 = indent
  i2 = indent "  "
  i3 = indent "    "
  i4 = indent "      "
  i5 = indent "        "

  if (variant == "current") {
    print i1 "<div class=\"moonbase-journal\">"
    print i2 "<table class=\"moonbase-table\">"
    print i3 "<colgroup>"
    print i4 "<col class=\"moonbase-col-commit\">"
    print i4 "<col class=\"moonbase-col-repository\">"
    print i4 "<col class=\"moonbase-col-module\">"
    print i4 "<col class=\"moonbase-col-comment\">"
    print i3 "</colgroup>"
    print i3 "<thead>"
    print i4 "<tr>"
    print i5 "<th>Commit</th>"
    print i5 "<th>Repository</th>"
    print i5 "<th>Module</th>"
    print i5 "<th>Comment</th>"
    print i4 "</tr>"
    print i3 "</thead>"
    print i3 "<tbody>"

    for (r = 1; r <= records; r++) {
      url = "https://github.com/lunar-linux/moonbase-" repository[r] "/commit/" commit[r]
      print i4 "<tr>"
      print i5 "<td class=\"commit-id\"><a href=\"" attr_escape(url) "\" target=\"_blank\" rel=\"noopener\">" text_escape(commit[r]) "</a></td>"
      print i5 "<td class=\"repository-name\">" text_escape(repository[r]) "</td>"
      print i5 "<td class=\"module-name\">" text_escape(module[r]) "</td>"
      print i5 "<td class=\"commit-comment\">" text_escape(summary[r]) "</td>"
      print i4 "</tr>"
    }

    print i3 "</tbody>"
    print i2 "</table>"

    if (records == 0)
      print i2 "<p>No Moonbase commits were found for the selected period.</p>"

    print i1 "</div>"
  }
  else {
    print i1 "<div class=\"moonbase-journal archive-journal\">"
    print i2 "<table class=\"moonbase-table archive-commits-table\">"
    print i3 "<thead><tr><th>Commit</th><th>Repository</th><th>Module</th><th>Comment</th></tr></thead>"
    print i3 "<tbody>"

    if (records == 0) {
      print i4 "<tr><td colspan=\"4\" class=\"commit-comment\">No archived commits were found.</td></tr>"
    }
    else {
      for (r = 1; r <= records; r++) {
        url = "https://github.com/lunar-linux/moonbase-" repository[r] "/commit/" commit[r]
        title_attr = ""
        if (link_title[r] != "")
          title_attr = " title=\"" attr_escape(link_title[r]) "\""

        print i4 "<tr><td class=\"commit-id\"><a href=\"" attr_escape(url) "\" target=\"_blank\" rel=\"noopener\"" title_attr ">" text_escape(commit[r]) "</a></td><td class=\"repository-name\">" text_escape(repository[r]) "</td><td class=\"module-name\">" text_escape(module[r]) "</td><td class=\"commit-comment\">" text_escape(summary[r]) "</td></tr>"
      }
    }

    print i3 "</tbody>"
    print i2 "</table>"
    print i1 "</div>"
  }
}
' "$input" > "$tmp"
then
  exit 1
fi

cat "$tmp"
