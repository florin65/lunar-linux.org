#!/bin/sh

# =========================================================
# Build editorial community/project news
# =========================================================
# Input format for src/news/*.md:
#
# Date: YYYY-MM-DD HH:MM
# Category: Community
# Title: Example title
#
# Body text starts after the first empty line.
#
# Files missing Date, Category, Title, or body are rejected.
# =========================================================

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONF="$PROJECT_ROOT/site.conf"

if [ ! -f "$CONF" ]; then
  printf 'missing config file: %s\n' "$CONF" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$CONF"

SITE_ROOT=${SITE_ROOT:-.}
NEWS_DIR=${NEWS_DIR:-src/news}
TEMPLATES_DIR=${TEMPLATES_DIR:-templates}
PUBLIC_DIR=${PUBLIC_DIR:-docs}
BUILD_DIR=${BUILD_DIR:-cache}
COMMUNITY_NEWS_HTML=${COMMUNITY_NEWS_HTML:-$BUILD_DIR/community-news.html}
NEWS_ARTICLES_DIR=${NEWS_ARTICLES_DIR:-$PUBLIC_DIR/news}

abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$PROJECT_ROOT/$SITE_ROOT" "$1" ;;
  esac
}

rel_from_project() {
  case "$1" in
    "$PROJECT_ROOT"/*) printf '%s\n' "${1#$PROJECT_ROOT/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

html_attr_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g" \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g'
}

slugify() {
  printf '%s' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed \
      -e 's/[^a-z0-9][^a-z0-9]*/-/g' \
      -e 's/^-//' \
      -e 's/-$//'
}

render_body() {
  awk '
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      return s
    }

    function inline(s,    out, pre, label, url, rest, p1, p2, code) {
      s = esc(s)
      out = ""

      while (match(s, /`[^`]+`/)) {
        pre = substr(s, 1, RSTART - 1)
        code = substr(s, RSTART + 1, RLENGTH - 2)
        out = out pre "<code>" code "</code>"
        s = substr(s, RSTART + RLENGTH)
      }
      s = out s
      out = ""

      while (match(s, /\[[^]]+\]\([^)]+\)/)) {
        pre = substr(s, 1, RSTART - 1)
        p1 = index(substr(s, RSTART), "](")
        label = substr(s, RSTART + 1, p1 - 2)
        rest = substr(s, RSTART + p1 + 1)
        p2 = index(rest, ")")
        url = substr(rest, 1, p2 - 1)
        out = out pre "<a href=\"" url "\">" label "</a>"
        s = substr(rest, p2 + 1)
      }
      s = out s

      while (match(s, /\*\*[^*]+\*\*/)) {
        s = substr(s, 1, RSTART - 1) "<strong>" substr(s, RSTART + 2, RLENGTH - 4) "</strong>" substr(s, RSTART + RLENGTH)
      }

      while (match(s, /\*[^*]+\*/)) {
        s = substr(s, 1, RSTART - 1) "<em>" substr(s, RSTART + 1, RLENGTH - 2) "</em>" substr(s, RSTART + RLENGTH)
      }

      return s
    }

    function close_list() {
      if (in_list) {
        print "          </ul>"
        in_list = 0
      }
    }

    /^[[:space:]]*$/ {
      close_list()
      next
    }

    /^### / {
      close_list()
      print "          <h3>" inline(substr($0, 5)) "</h3>"
      next
    }

    /^## / {
      close_list()
      print "          <h2>" inline(substr($0, 4)) "</h2>"
      next
    }

    /^# / {
      close_list()
      print "          <h2>" inline(substr($0, 3)) "</h2>"
      next
    }

    /^- / {
      if (!in_list) {
        print "          <ul class=\"simple-list\">"
        in_list = 1
      }
      print "            <li>" inline(substr($0, 3)) "</li>"
      next
    }

    {
      close_list()
      print "          <p>" inline($0) "</p>"
    }

    END {
      close_list()
    }
  ' "$1"
}

NEWS_SRC=$(abs_path "$NEWS_DIR")
TEMPLATES=$(abs_path "$TEMPLATES_DIR")
PUBLIC=$(abs_path "$PUBLIC_DIR")
OUT=$(abs_path "$COMMUNITY_NEWS_HTML")
NEWS_PAGES=$(abs_path "$NEWS_ARTICLES_DIR")

HEADER="$TEMPLATES/header.html"
FOOTER="$TEMPLATES/footer.html"

mkdir -p "$(dirname -- "$OUT")" "$NEWS_PAGES"

rows=$(mktemp)
trap 'rm -f "$rows"' EXIT

: > "$rows"

if [ ! -d "$NEWS_SRC" ]; then
  cat > "$OUT" <<EOF_EMPTY
      <div class="community-news-journal empty">
        <p>No community or project news entries were found.</p>
      </div>
EOF_EMPTY
  printf 'generated %s\n' "$(rel_from_project "$OUT")"
  exit 0
fi

for file in "$NEWS_SRC"/*.md; do
  [ -f "$file" ] || continue

  date=$(sed -n 's/^Date:[[:space:]]*//p' "$file" | head -n 1)
  category=$(sed -n 's/^Category:[[:space:]]*//p' "$file" | head -n 1)
  title=$(sed -n 's/^Title:[[:space:]]*//p' "$file" | head -n 1)

  body=$(mktemp)
  awk '
    BEGIN { body = 0 }
    body { print; next }
    /^[[:space:]]*$/ { body = 1; next }
  ' "$file" > "$body"

  if [ -z "$date" ] || [ -z "$category" ] || [ -z "$title" ]; then
    printf 'warning: rejecting invalid news file %s: missing Date, Category or Title\n' "$(rel_from_project "$file")" >&2
    rm -f "$body"
    continue
  fi

  if ! printf '%s\n' "$date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]][0-9]{2}:[0-9]{2})?$'; then
    printf 'warning: rejecting invalid news file %s: invalid Date format\n' "$(rel_from_project "$file")" >&2
    rm -f "$body"
    continue
  fi

  if ! grep -q '[^[:space:]]' "$body"; then
    printf 'warning: rejecting invalid news file %s: empty body\n' "$(rel_from_project "$file")" >&2
    rm -f "$body"
    continue
  fi

  slug=$(basename -- "$file" .md)
  slug=$(slugify "$slug")
  [ -n "$slug" ] || slug=$(slugify "$title")

  out_file="$NEWS_PAGES/$slug.html"
  href="news/$slug.html"
  date_short=$(printf '%s\n' "$date" | awk '{ print $1 }')
  summary=$(
    awk 'NF { print; exit }' "$body" |
      sed 's/[[:space:]][[:space:]]*/ /g'
  )

  {
    cat <<EOF_PAGE
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$(html_attr_escape "$title")</title>
  <meta name="description" content="$(html_attr_escape "$summary")">

  <link rel="icon" href="../assets/logo/favicon.ico">
  <link rel="stylesheet" href="../css/style.css">
</head>
<body>
EOF_PAGE

    sed 's#{{root}}#../#g' "$HEADER"

    cat <<EOF_PAGE
<main class="page-main">
  <section class="page-hero">
    <div class="container">
      <p class="meta-line">$(html_attr_escape "$category") · $(html_attr_escape "$date")</p>
      <h1>$(html_attr_escape "$title")</h1>
    </div>
  </section>

  <section class="content-section">
    <div class="container content-card wide generated-page news-article-page">
EOF_PAGE

    render_body "$body"

    cat <<EOF_PAGE
      <div class="hero-actions">
        <a class="button secondary" href="../news.html">Back to News</a>
      </div>
    </div>
  </section>
</main>
EOF_PAGE

    sed 's#{{root}}#../#g' "$FOOTER"

    cat <<EOF_PAGE
</body>
</html>
EOF_PAGE
  } > "$out_file"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$date" \
    "$date_short" \
    "$category" \
    "$title" \
    "$summary" \
    "$href" >> "$rows"

  rm -f "$body"
  printf 'generated %s\n' "$(rel_from_project "$out_file")"
done

tmp=$(mktemp)

{
  printf '      <div class="community-news-journal">\n'
  printf '        <table class="community-news-table compact-news-table">\n'
  printf '          <colgroup>\n'
  printf '            <col class="community-news-col-meta">\n'
  printf '            <col class="community-news-col-content">\n'
  printf '          </colgroup>\n'
  printf '          <thead>\n'
  printf '            <tr>\n'
  printf '              <th>Date</th>\n'
  printf '              <th>News</th>\n'
  printf '            </tr>\n'
  printf '          </thead>\n'
  printf '          <tbody>\n'

  if [ -s "$rows" ]; then
    sort -r "$rows" | while IFS='	' read -r date date_short category title summary href; do
      printf '            <tr>\n'
      printf '              <td class="news-meta">\n'
      printf '                <time datetime="%s">%s</time>\n' \
        "$(html_attr_escape "$date")" \
        "$(html_attr_escape "$date")"
      printf '                <span>%s</span>\n' \
        "$(html_attr_escape "$category")"
      printf '              </td>\n'
      printf '              <td class="news-content">\n'
      printf '                <a class="news-title-link" href="%s">%s</a>\n' \
        "$(html_attr_escape "$href")" \
        "$(html_attr_escape "$title")"
      printf '                <p>%s</p>\n' \
        "$(html_attr_escape "$summary")"
      printf '              </td>\n'
      printf '            </tr>\n'
    done
  fi

  printf '          </tbody>\n'
  printf '        </table>\n'

  if [ ! -s "$rows" ]; then
    printf '        <p>No valid community or project news entries were found.</p>\n'
  fi

  printf '      </div>\n'
} > "$tmp"

mv "$tmp" "$OUT"
printf 'generated %s\n' "$(rel_from_project "$OUT")"
