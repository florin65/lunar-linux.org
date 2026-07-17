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
TOOLS_DIR=${TOOLS_DIR:-tools}
PUBLIC_DIR=${PUBLIC_DIR:-docs}
BUILD_DIR=${BUILD_DIR:-cache}
COMMUNITY_NEWS_HTML=${COMMUNITY_NEWS_HTML:-$BUILD_DIR/community-news.html}
COMMUNITY_NEWS_MANIFEST=${COMMUNITY_NEWS_MANIFEST:-$BUILD_DIR/community-news-pages.list}
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

NEWS_SRC=$(abs_path "$NEWS_DIR")
TOOLS=$(abs_path "$TOOLS_DIR")
OUT=$(abs_path "$COMMUNITY_NEWS_HTML")
MANIFEST=$(abs_path "$COMMUNITY_NEWS_MANIFEST")
NEWS_PAGES=$(abs_path "$NEWS_ARTICLES_DIR")
NEWS_ARTICLE_RENDERER="$TOOLS/render-news-article.sh"

if [ ! -x "$NEWS_ARTICLE_RENDERER" ]; then
  printf 'missing news article renderer: %s\n' "$(rel_from_project "$NEWS_ARTICLE_RENDERER")" >&2
  exit 1
fi

mkdir -p "$(dirname -- "$OUT")" "$(dirname -- "$MANIFEST")" "$NEWS_PAGES"

rows=$(mktemp)
new_manifest=$(mktemp)
trap 'rm -f "$rows" "$new_manifest"' EXIT HUP INT TERM

: > "$rows"
: > "$new_manifest"

publish_news_manifest() {
  manifest_tmp="$MANIFEST.tmp.$$"

  if [ -f "$MANIFEST" ]; then
    while IFS= read -r generated; do
      [ -n "$generated" ] || continue

      if ! printf '%s\n' "$generated" | grep -Eq '^[a-z0-9][a-z0-9-]*\.html$'; then
        printf 'warning: ignoring unsafe community news manifest entry: %s\n' "$generated" >&2
        continue
      fi

      if ! grep -qxF "$generated" "$new_manifest"; then
        rm -f "$NEWS_PAGES/$generated"
        printf 'removed stale %s\n' "$(rel_from_project "$NEWS_PAGES/$generated")"
      fi
    done < "$MANIFEST"
  fi

  sort -u "$new_manifest" > "$manifest_tmp"
  mv "$manifest_tmp" "$MANIFEST"
}

if [ ! -d "$NEWS_SRC" ]; then
  cat > "$OUT" <<EOF_EMPTY
      <div class="community-news-journal empty">
        <p>No community or project news entries were found.</p>
      </div>
EOF_EMPTY
  publish_news_manifest
  printf 'generated %s\n' "$(rel_from_project "$OUT")"
  printf 'generated %s\n' "$(rel_from_project "$MANIFEST")"
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

  "$NEWS_ARTICLE_RENDERER" \
    "$file" \
    "$out_file" \
    "../" \
    "../news.html" \
    "Back to News"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$date" \
    "$date_short" \
    "$category" \
    "$title" \
    "$summary" \
    "$href" >> "$rows"

  printf '%s\n' "$slug.html" >> "$new_manifest"

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
publish_news_manifest
printf 'generated %s\n' "$(rel_from_project "$OUT")"
printf 'generated %s\n' "$(rel_from_project "$MANIFEST")"
