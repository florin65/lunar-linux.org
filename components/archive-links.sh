#!/bin/sh

# =========================================================
# Archive Links component
# Render a prepared sequence of label|url pairs as HTML.
# =========================================================

set -eu

indent=${ARCHIVE_LINKS_INDENT:-}
first_class=${ARCHIVE_LINKS_FIRST_CLASS:-primary}

case "$first_class" in
  primary|secondary)
    ;;
  *)
    printf 'archive-links: invalid first class: %s\n' "$first_class" >&2
    exit 1
    ;;
esac

html_text_escape() {
  printf '%s' "$1" | sed \
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

[ "$#" -gt 0 ] || exit 0

printf '%s<div class="hero-actions archive-section-actions archive-links">\n' "$indent"

position=0

for item do
  case "$item" in
    *'|'*)
      label=${item%%|*}
      url=${item#*|}
      ;;
    *)
      printf 'archive-links: invalid item: %s\n' "$item" >&2
      exit 1
      ;;
  esac

  if [ -z "$label" ] || [ -z "$url" ]; then
    printf 'archive-links: label and URL must not be empty: %s\n' "$item" >&2
    exit 1
  fi

  position=$((position + 1))

  if [ "$position" -eq 1 ]; then
    class="button $first_class"
  else
    class='button secondary'
  fi

  printf '%s  <a class="%s" href="%s">%s</a>\n' \
    "$indent" \
    "$class" \
    "$(html_attr_escape "$url")" \
    "$(html_text_escape "$label")"
done

printf '%s</div>\n' "$indent"
