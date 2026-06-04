#!/bin/sh

# =========================================================
# Lunar Linux website generator - bash prototype
# =========================================================
# Converts Markdown sources from src/markdown/ into static HTML pages
# in public/. Also builds public/data/news.json from src/news/*.md.
#
# This script is intentionally small and dependency-light. It is meant
# as a readable prototype for a future Nim implementation.
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
SRC_DIR=${SRC_DIR:-src}
MARKDOWN_DIR=${MARKDOWN_DIR:-src/markdown}
NEWS_DIR=${NEWS_DIR:-src/news}
TEMPLATES_DIR=${TEMPLATES_DIR:-templates}
TOOLS_DIR=${TOOLS_DIR:-tools}
PUBLIC_DIR=${PUBLIC_DIR:-public}
DATA_DIR=${DATA_DIR:-public/data}
MOONBASE_STATS_JSON=${MOONBASE_STATS_JSON:-public/data/moonbase-stats.json}
DAILY_ISO_JSON=${DAILY_ISO_JSON:-public/data/daily-iso.json}
NEWS_JSON=${NEWS_JSON:-public/data/news.json}
GENERATE_NEWS_JSON=${GENERATE_NEWS_JSON:-yes}
UPDATE_DYNAMIC_DATA=${UPDATE_DYNAMIC_DATA:-yes}

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

SRC=$(abs_path "$MARKDOWN_DIR")
NEWS_SRC=$(abs_path "$NEWS_DIR")
PUBLIC=$(abs_path "$PUBLIC_DIR")
DATA=$(abs_path "$DATA_DIR")
TEMPLATES=$(abs_path "$TEMPLATES_DIR")
TOOLS=$(abs_path "$TOOLS_DIR")
HEADER="$TEMPLATES/header.html"
FOOTER="$TEMPLATES/footer.html"
PAGE_TEMPLATES="$TEMPLATES/pages"
MOONBASE_STATS=$(abs_path "$MOONBASE_STATS_JSON")
DAILY_ISO=$(abs_path "$DAILY_ISO_JSON")
NEWS_OUT=$(abs_path "$NEWS_JSON")

mkdir -p "$PUBLIC" "$DATA"

html_escape() {
  sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g'
}

html_attr_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/"/\&quot;/g' \
    -e "s/'/\&#39;/g" \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g'
}

json_escape() {
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e ':a;N;$!ba;s/\n/\\n/g'
}

json_get_string() {
  key="$1"
  file="$2"

  [ -f "$file" ] || return 0

  sed -n 's/^[[:space:]]*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" |
    head -n 1
}

json_get_number() {
  key="$1"
  file="$2"

  [ -f "$file" ] || return 0

  sed -n 's/^[[:space:]]*"'"$key"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$file" |
    head -n 1
}

get_meta() {
  key="$1"
  file="$2"

  awk -v key="$key" '
    BEGIN { in_fm = 0 }
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { exit }
    in_fm {
      split($0, a, ":")
      if (a[1] == key) {
        sub("^[^:]*:[[:space:]]*", "")
        print
        exit
      }
    }
  ' "$file"
}

load_dynamic_values() {
  latest_iso_file=$(json_get_string iso_file "$DAILY_ISO")
  latest_iso_url=$(json_get_string iso_url "$DAILY_ISO")
  latest_iso_date=$(json_get_string iso_date "$DAILY_ISO")
  moonbase_modules=$(json_get_number modules "$MOONBASE_STATS")

  [ -n "$latest_iso_file" ] || latest_iso_file="unavailable"
  [ -n "$latest_iso_url" ] || latest_iso_url="#"
  [ -n "$latest_iso_date" ] || latest_iso_date=$(json_get_string generated_at "$DAILY_ISO")
  [ -n "$latest_iso_date" ] || latest_iso_date="unavailable"
  [ -n "$moonbase_modules" ] || moonbase_modules="unavailable"
}

expand_variables() {
  file="$1"

  awk \
    -v latest_iso_file="$latest_iso_file" \
    -v latest_iso_url="$latest_iso_url" \
    -v latest_iso_date="$latest_iso_date" \
    -v moonbase_modules="$moonbase_modules" '
      {
        gsub(/\{\{[[:space:]]*latest_iso_file[[:space:]]*\}\}/, latest_iso_file)
        gsub(/\{\{[[:space:]]*latest_iso_url[[:space:]]*\}\}/, latest_iso_url)
        gsub(/\{\{[[:space:]]*latest_iso_date[[:space:]]*\}\}/, latest_iso_date)
        gsub(/\{\{[[:space:]]*moonbase_modules[[:space:]]*\}\}/, moonbase_modules)
        print
      }
    ' "$file"
}

render_markdown_body() {
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

    function close_blocks() {
      if (in_list) {
        print "      </ul>"
        in_list = 0
      }
      if (in_quote) {
        print "      </blockquote>"
        in_quote = 0
      }
    }

    BEGIN {
      in_fm = 0
      in_list = 0
      in_quote = 0
    }

    NR == 1 && $0 == "---" {
      in_fm = 1
      next
    }

    in_fm && $0 == "---" {
      in_fm = 0
      next
    }

    in_fm { next }

    /^[[:space:]]*$/ {
      close_blocks()
      next
    }

    /^### / {
      close_blocks()
      line = substr($0, 5)
      print "      <h3>" inline(line) "</h3>"
      next
    }

    /^## / {
      close_blocks()
      line = substr($0, 4)
      print "      <h2>" inline(line) "</h2>"
      next
    }

    /^# / {
      close_blocks()
      line = substr($0, 3)
      print "      <h1>" inline(line) "</h1>"
      next
    }

    /^- / {
      if (!in_list) {
        close_blocks()
        print "      <ul class=\"simple-list\">"
        in_list = 1
      }
      line = substr($0, 3)
      print "        <li>" inline(line) "</li>"
      next
    }

    /^> / {
      if (in_list) {
        print "      </ul>"
        in_list = 0
      }
      if (!in_quote) {
        print "      <blockquote class=\"quote-box\">"
        in_quote = 1
      }
      line = substr($0, 3)
      gsub(/[[:space:]]*  $/, "", line)
      print "        <p>" inline(line) "</p>"
      next
    }

    {
      close_blocks()
      print "      <p>" inline($0) "</p>"
    }

    END {
      close_blocks()
    }
  ' "$1"
}

write_html_head() {
  title="$1"
  description="$2"

  cat <<EOF_PAGE
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$(html_attr_escape "$title")</title>
  <meta name="description" content="$(html_attr_escape "$description")">

  <link rel="icon" href="assets/logo/favicon.ico">
  <link rel="stylesheet" href="css/style.css">
</head>
<body>
EOF_PAGE
}

expand_template_file() {
  file="$1"

  awk \
    -v latest_iso_file="$latest_iso_file" \
    -v latest_iso_url="$latest_iso_url" \
    -v latest_iso_date="$latest_iso_date" \
    -v moonbase_modules="$moonbase_modules" '
      {
        gsub(/\{\{[[:space:]]*latest_iso_file[[:space:]]*\}\}/, latest_iso_file)
        gsub(/\{\{[[:space:]]*latest_iso_url[[:space:]]*\}\}/, latest_iso_url)
        gsub(/\{\{[[:space:]]*latest_iso_date[[:space:]]*\}\}/, latest_iso_date)
        gsub(/\{\{[[:space:]]*moonbase_modules[[:space:]]*\}\}/, moonbase_modules)
        print
      }
    ' "$file"
}

write_page() {
  md="$1"
  name=$(basename -- "$md" .md)
  out="$PUBLIC/$name.html"
  expanded=$(mktemp)
  page_template="$PAGE_TEMPLATES/$name.html"

  title=$(get_meta title "$md")
  description=$(get_meta description "$md")

  [ -n "$title" ] || title="$name"
  [ -n "$description" ] || description="Lunar Linux website page."

  expand_variables "$md" > "$expanded"

  {
    write_html_head "$title" "$description"
    sed 's#{{root}}##g' "$HEADER"

    if [ -f "$page_template" ]; then
      expand_template_file "$page_template"
    else
      cat <<EOF_PAGE
<main class="page-main">
  <section class="content-section">
    <div class="container content-card wide generated-page">
EOF_PAGE

      render_markdown_body "$expanded"

      cat <<EOF_PAGE
    </div>
  </section>
</main>
EOF_PAGE
    fi

    cat "$FOOTER"

    cat <<EOF_PAGE
</body>
</html>
EOF_PAGE
  } > "$out"

  rm -f "$expanded"
  printf 'generated %s\n' "$(rel_from_project "$out")"
}

first_paragraph() {
  awk '
    BEGIN { in_fm = 0; body = 0 }
    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { in_fm = 0; body = 1; next }
    in_fm { next }
    body && /^[[:space:]]*$/ { if (p != "") { print p; exit }; next }
    body && p == "" { p = $0; next }
    body && p != "" { p = p " " $0 }
    END { if (p != "") print p }
  ' "$1"
}

build_news_json() {
  tmp="$NEWS_OUT.tmp"
  out_dir=$(dirname -- "$NEWS_OUT")

  mkdir -p "$out_dir"
  printf '[\n' > "$tmp"
  first=1

  if [ -d "$NEWS_SRC" ]; then
    find "$NEWS_SRC" -type f -name '*.md' | sort -r | while IFS= read -r md; do
      date=$(get_meta date "$md")
      title=$(get_meta title "$md")
      category=$(get_meta category "$md")
      summary=$(first_paragraph "$md")
      slug=$(basename -- "$md" .md)

      [ -n "$date" ] || date="unknown"
      [ -n "$title" ] || title="$slug"
      [ -n "$category" ] || category="News"

      if [ "$first" -eq 0 ]; then
        printf ',\n' >> "$tmp"
      fi
      first=0

      printf '  {"date":"%s","category":"%s","title":"%s","slug":"%s","summary":"%s"}' \
        "$(json_escape "$date")" \
        "$(json_escape "$category")" \
        "$(json_escape "$title")" \
        "$(json_escape "$slug")" \
        "$(json_escape "$summary")" >> "$tmp"
    done
  fi

  printf '\n]\n' >> "$tmp"
  mv "$tmp" "$NEWS_OUT"
  printf 'generated %s\n' "$(rel_from_project "$NEWS_OUT")"
}

update_dynamic_data() {
  if [ "$UPDATE_DYNAMIC_DATA" != "yes" ]; then
    return 0
  fi

  printf 'updating dynamic data...\n'
  "$TOOLS/count-moonbase.sh"
  "$TOOLS/get-iso-file-date.sh"
}

main() {
  if [ ! -d "$SRC" ]; then
    printf 'missing source directory: %s\n' "$SRC" >&2
    exit 1
  fi

  if [ ! -f "$HEADER" ]; then
    printf 'missing template: %s\n' "$HEADER" >&2
    exit 1
  fi

  if [ ! -f "$FOOTER" ]; then
    printf 'missing template: %s\n' "$FOOTER" >&2
    exit 1
  fi

  update_dynamic_data
  load_dynamic_values

  for md in "$SRC"/*.md; do
    [ -f "$md" ] || continue
    write_page "$md"
  done

  if [ "$GENERATE_NEWS_JSON" = "yes" ]; then
    build_news_json
  fi
}

main "$@"
