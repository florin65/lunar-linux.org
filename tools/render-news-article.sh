#!/bin/sh

# =========================================================
# Render one editorial news Markdown file as an HTML page
# =========================================================
# Usage:
#   render-news-article.sh SOURCE OUTPUT ROOT_PREFIX BACK_HREF BACK_LABEL
#
# ROOT_PREFIX points from the generated page to the public site root.
# =========================================================

set -eu

SOURCE=${1:-}
OUTPUT=${2:-}
ROOT_PREFIX=${3:-}
BACK_HREF=${4:-}
BACK_LABEL=${5:-Back to News}

[ -n "$SOURCE" ] || {
  printf 'usage: %s SOURCE OUTPUT ROOT_PREFIX BACK_HREF [BACK_LABEL]\n' "$0" >&2
  exit 1
}

[ -n "$OUTPUT" ] || {
  printf 'usage: %s SOURCE OUTPUT ROOT_PREFIX BACK_HREF [BACK_LABEL]\n' "$0" >&2
  exit 1
}

[ -f "$SOURCE" ] || {
  printf 'missing news source: %s\n' "$SOURCE" >&2
  exit 1
}

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONF="$PROJECT_ROOT/site.conf"

if [ ! -f "$CONF" ]; then
  printf 'missing config file: %s\n' "$CONF" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$CONF"

SITE_ROOT=${SITE_ROOT:-.}
TEMPLATES_DIR=${TEMPLATES_DIR:-templates}

abs_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)  printf '%s/%s\n' "$PROJECT_ROOT/$SITE_ROOT" "$1" ;;
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

render_body() {
  awk '
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      return s
    }

    function attr(s) {
      gsub(/"/, "\\&quot;", s)
      gsub(/\047/, "\\&#39;", s)
      return s
    }

    function safe_url(url) {
      if (url ~ /^#/) return 1
      if (url ~ /^\// && url !~ /^\/\//) return 1
      if (url ~ /^\.\.?\//) return 1
      if (url ~ /^https?:\/\//) return 1
      if (url ~ /^mailto:/) return 1
      if (url !~ /:/ && url !~ /^\/\//) return 1
      return 0
    }

    function style(s) {
      while (match(s, /\*\*[^*]+\*\*/)) {
        s = substr(s, 1, RSTART - 1) "<strong>" substr(s, RSTART + 2, RLENGTH - 4) "</strong>" substr(s, RSTART + RLENGTH)
      }

      while (match(s, /\*[^*]+\*/)) {
        s = substr(s, 1, RSTART - 1) "<em>" substr(s, RSTART + 1, RLENGTH - 2) "</em>" substr(s, RSTART + RLENGTH)
      }

      return s
    }

    function replace_token(s, token, value,    p) {
      p = index(s, token)
      while (p) {
        s = substr(s, 1, p - 1) value substr(s, p + length(token))
        p = index(s, token)
      }
      return s
    }

    function inline(s,    i, marker, token, pre, label, url, rest, p1, p2, code) {
      for (i = 1; i <= code_count; i++) {
        delete code_value[i]
      }
      for (i = 1; i <= link_count; i++) {
        delete link_value[i]
      }
      code_count = 0
      link_count = 0
      marker = sprintf("%c", 29)

      s = esc(s)

      while (match(s, /`[^`]+`/)) {
        pre = substr(s, 1, RSTART - 1)
        code = substr(s, RSTART + 1, RLENGTH - 2)
        code_count++
        code_value[code_count] = "<code>" code "</code>"
        token = marker "C" code_count marker
        s = pre token substr(s, RSTART + RLENGTH)
      }

      while (match(s, /\[[^]]+\]\([^)]+\)/)) {
        pre = substr(s, 1, RSTART - 1)
        p1 = index(substr(s, RSTART), "](")
        label = substr(s, RSTART + 1, p1 - 2)
        rest = substr(s, RSTART + p1 + 1)
        p2 = index(rest, ")")
        url = substr(rest, 1, p2 - 1)
        if (!safe_url(url)) {
          printf "unsafe link URL in news body: %s\n", url > "/dev/stderr"
          exit 2
        }
        link_count++
        link_value[link_count] = "<a href=\"" attr(url) "\">" style(label) "</a>"
        token = marker "L" link_count marker
        s = pre token substr(rest, p2 + 1)
      }

      s = style(s)

      for (i = 1; i <= link_count; i++) {
        token = marker "L" i marker
        s = replace_token(s, token, link_value[i])
      }
      for (i = 1; i <= code_count; i++) {
        token = marker "C" i marker
        s = replace_token(s, token, code_value[i])
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

TEMPLATES=$(abs_path "$TEMPLATES_DIR")
HEADER="$TEMPLATES/header.html"
FOOTER="$TEMPLATES/footer.html"

[ -f "$HEADER" ] || {
  printf 'missing template: %s\n' "$HEADER" >&2
  exit 1
}

[ -f "$FOOTER" ] || {
  printf 'missing template: %s\n' "$FOOTER" >&2
  exit 1
}

date=$(sed -n 's/^Date:[[:space:]]*//p' "$SOURCE" | head -n 1)
category=$(sed -n 's/^Category:[[:space:]]*//p' "$SOURCE" | head -n 1)
title=$(sed -n 's/^Title:[[:space:]]*//p' "$SOURCE" | head -n 1)

output_dir=$(dirname -- "$OUTPUT")
mkdir -p "$output_dir"

body=$(mktemp)
tmp=$(mktemp "$output_dir/.render-news-article.XXXXXX")
trap 'rm -f "$body" "$tmp"' EXIT HUP INT TERM

awk '
  BEGIN { body = 0 }
  body { print; next }
  /^[[:space:]]*$/ { body = 1; next }
' "$SOURCE" > "$body"

if [ -z "$date" ] || [ -z "$category" ] || [ -z "$title" ]; then
  printf 'invalid news source %s: missing Date, Category or Title\n' "$SOURCE" >&2
  exit 1
fi

if printf '%s\n%s\n' "$category" "$title" | grep -q '	'; then
  printf 'invalid news source %s: tab character in Category or Title\n' "$SOURCE" >&2
  exit 1
fi

if ! printf '%s\n' "$date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}( [0-9]{2}:[0-9]{2})?$'; then
  printf 'invalid news source %s: invalid Date format\n' "$SOURCE" >&2
  exit 1
fi

if ! valid_news_date "$date"; then
  printf 'invalid news source %s: impossible Date value: %s\n' "$SOURCE" "$date" >&2
  exit 1
fi

if ! grep -q '[^[:space:]]' "$body"; then
  printf 'invalid news source %s: empty body\n' "$SOURCE" >&2
  exit 1
fi

summary=$(
  awk 'NF { print; exit }' "$body" |
    tr '\t' ' ' |
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

  <link rel="icon" href="${ROOT_PREFIX}assets/logo/favicon.ico">
  <link rel="stylesheet" href="${ROOT_PREFIX}css/style.css">
</head>
<body>
EOF_PAGE

  sed "s#{{root}}#$(printf '%s' "$ROOT_PREFIX" | sed 's/[&]/\\&/g')#g" "$HEADER"

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
        <a class="button secondary" href="$(html_attr_escape "$BACK_HREF")">$(html_attr_escape "$BACK_LABEL")</a>
      </div>
    </div>
  </section>
</main>
EOF_PAGE

  sed "s#{{root}}#$(printf '%s' "$ROOT_PREFIX" | sed 's/[&]/\\&/g')#g" "$FOOTER"

  cat <<EOF_PAGE
</body>
</html>
EOF_PAGE
} > "$tmp"

mv "$tmp" "$OUTPUT"
