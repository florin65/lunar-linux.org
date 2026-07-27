#!/bin/sh

# =========================================================
# News Journal component
# Render prepared six-field TSV news records as HTML.
# =========================================================

set -eu

if [ "$#" -ne 2 ]; then
  printf 'usage: %s current|archive prepared-news.tsv\n' "$0" >&2
  exit 2
fi

variant=$1
input=$2
indent=${NEWS_JOURNAL_INDENT:-}

case "$variant" in
  current|archive) ;;
  *)
    printf 'news-journal: invalid variant: %s\n' "$variant" >&2
    exit 2
    ;;
esac

if [ ! -f "$input" ] || [ ! -r "$input" ]; then
  printf 'news-journal: unreadable input file: %s\n' "$input" >&2
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
  if (NF != 6) {
    printf "news-journal: line %d: expected 6 tab-separated fields, found %d\n", NR, NF > "/dev/stderr"
    valid = 0
    next
  }

  for (i = 1; i <= 6; i++) {
    if ($i == "") {
      printf "news-journal: line %d: field %d must not be empty\n", NR, i > "/dev/stderr"
      valid = 0
    }
  }

  date_display[NR] = $1
  date_datetime[NR] = $2
  category[NR] = $3
  title[NR] = $4
  href[NR] = $5
  secondary[NR] = $6
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
  i6 = indent "          "
  i7 = indent "            "
  i8 = indent "              "
  i9 = indent "                "

  if (variant == "current") {
    print i1 "<div class=\"community-news-journal\">"
    print i2 "<table class=\"community-news-table compact-news-table\">"
    print i3 "<colgroup>"
    print i4 "<col class=\"community-news-col-meta\">"
    print i4 "<col class=\"community-news-col-content\">"
    print i3 "</colgroup>"
    print i3 "<thead>"
    print i4 "<tr>"
    print i5 "<th>Date</th>"
    print i5 "<th>News</th>"
    print i4 "</tr>"
    print i3 "</thead>"
    print i3 "<tbody>"

    for (r = 1; r <= records; r++) {
      print i4 "<tr>"
      print i5 "<td class=\"news-meta\">"
      print i6 "<time datetime=\"" attr_escape(date_datetime[r]) "\">" text_escape(date_display[r]) "</time>"
      print i6 "<span>" text_escape(category[r]) "</span>"
      print i5 "</td>"
      print i5 "<td class=\"news-content\">"
      print i6 "<a class=\"news-title-link\" href=\"" attr_escape(href[r]) "\">" text_escape(title[r]) "</a>"
      print i6 "<p>" text_escape(secondary[r]) "</p>"
      print i5 "</td>"
      print i4 "</tr>"
    }

    print i3 "</tbody>"
    print i2 "</table>"

    if (records == 0)
      print i2 "<p>No valid community or project news entries were found.</p>"

    print i1 "</div>"
  }
  else {
    print i1 "<div class=\"community-news-journal archive-journal\">"
    print i2 "<table class=\"community-news-table archive-news-table\">"
    print i3 "<thead><tr><th>Date</th><th>News</th></tr></thead>"
    print i3 "<tbody>"

    if (records == 0) {
      print i4 "<tr><td colspan=\"2\" class=\"news-content\">No valid archived news entries were found.</td></tr>"
    }
    else {
      for (r = 1; r <= records; r++) {
        print i4 "<tr>"
        print i5 "<td class=\"news-meta\"><time datetime=\"" attr_escape(date_datetime[r]) "\">" text_escape(date_display[r]) "</time><span>" text_escape(category[r]) "</span></td>"
        print i5 "<td class=\"news-content\"><a class=\"news-title-link\" href=\"" attr_escape(href[r]) "\">" text_escape(title[r]) "</a><p>Archive id: <code>" text_escape(secondary[r]) "</code></p></td>"
        print i4 "</tr>"
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
