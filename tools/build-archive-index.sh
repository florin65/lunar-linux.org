#!/bin/sh

# Build small HTML fragments for the Lunar archive page.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/archive-lib.sh"

CACHE_DIR=${CACHE_DIR:-$PROJECT_ROOT/cache}
PUBLIC_DIR=${PUBLIC_DIR:-$PROJECT_ROOT/docs}
NEWS_ARTICLE_RENDERER=${NEWS_ARTICLE_RENDERER:-$SCRIPT_DIR/render-news-article.sh}
commits_out=${1:-$CACHE_DIR/archive-commits.html}
news_out=${2:-$CACHE_DIR/archive-news.html}

archive_mkdir "$CACHE_DIR"

if [ ! -x "$NEWS_ARTICLE_RENDERER" ]; then
  printf 'missing news article renderer: %s\n' "$NEWS_ARTICLE_RENDERER" >&2
  exit 1
fi

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g'
}

tab=$(printf '\t')

# ---------------------------------------------------------
# Commits archive fragment
# ---------------------------------------------------------

build_commits_fragment() {
  tmp=$(mktemp)

  find "$ARCHIVE_ROOT/commits" -type f \( -name '*.json' -o -name '*.json.xz' \) 2>/dev/null | sort |
    while IFS= read -r f; do
      archive_cat "$f" | archive_json_objects_from_cat |
        while IFS= read -r obj; do
          date=$(printf '%s\n' "$obj" | archive_json_field date | head -1)
          repo=$(printf '%s\n' "$obj" | archive_json_field repository | head -1)
          module=$(printf '%s\n' "$obj" | archive_json_field module | head -1)
          commit=$(printf '%s\n' "$obj" | archive_json_field commit | head -1)
          summary=$(printf '%s\n' "$obj" | archive_json_field summary | head -1)
          title=$(printf '%s\n' "$obj" | archive_json_field title | head -1)

          [ -n "$date" ] || continue
          [ -n "$commit" ] || continue
          [ -n "$summary" ] || summary=$title
          [ -n "$module" ] || module=$title

          printf '%s\t%s\t%s\t%s\t%s\n' "$date" "$commit" "$repo" "$module" "$summary" >> "$tmp"
        done
    done

  {
    echo '      <div class="moonbase-journal archive-journal">'
    echo '        <table class="moonbase-table archive-commits-table">'
    echo '          <colgroup>'
    echo '            <col class="moonbase-col-commit">'
    echo '            <col class="moonbase-col-repository">'
    echo '            <col class="moonbase-col-module">'
    echo '            <col class="moonbase-col-comment">'
    echo '          </colgroup>'
    echo '          <thead>'
    echo '            <tr>'
    echo '              <th>Commit</th>'
    echo '              <th>Repository</th>'
    echo '              <th>Module</th>'
    echo '              <th>Comment</th>'
    echo '            </tr>'
    echo '          </thead>'
    echo '          <tbody>'

    if [ -s "$tmp" ]; then
      sort -r "$tmp" | while IFS="$tab" read -r date commit repo module summary; do
        repo_e=$(html_escape "$repo")
        module_e=$(html_escape "$module")
        summary_e=$(html_escape "$summary")
        commit_e=$(html_escape "$commit")
        date_e=$(html_escape "$date")
        url="https://github.com/lunar-linux/moonbase-$repo/commit/$commit"
        url_e=$(html_escape "$url")

        echo '            <tr>'
        printf '              <td class="commit-id"><a href="%s" target="_blank" rel="noopener" title="%s">%s</a></td>\n' "$url_e" "$date_e" "$commit_e"
        printf '              <td class="repository-name">%s</td>\n' "$repo_e"
        printf '              <td class="module-name">%s</td>\n' "$module_e"
        printf '              <td class="commit-comment">%s</td>\n' "$summary_e"
        echo '            </tr>'
      done
    else
      echo '            <tr>'
      echo '              <td colspan="4" class="commit-comment">No archived commits were found.</td>'
      echo '            </tr>'
    fi

    echo '          </tbody>'
    echo '        </table>'
    echo '      </div>'
  } > "$commits_out"

  rm -f "$tmp"
}

# ---------------------------------------------------------
# News archive fragment
# ---------------------------------------------------------

build_news_fragment() {
  tmp=$(mktemp)

  find "$ARCHIVE_ROOT/news" -type f \( -name 'index.json' -o -name 'index.json.xz' \) 2>/dev/null | sort |
    while IFS= read -r f; do
      base_dir=$(dirname -- "$f")
      archive_cat "$f" | archive_json_objects_from_cat |
        while IFS= read -r obj; do
          id=$(printf '%s\n' "$obj" | archive_json_field id | head -1)
          date=$(printf '%s\n' "$obj" | archive_json_field date | head -1)
          category=$(printf '%s\n' "$obj" | archive_json_field category | head -1)
          title=$(printf '%s\n' "$obj" | archive_json_field title | head -1)
          slug=$(printf '%s\n' "$obj" | archive_json_field slug | head -1)
          file=$(printf '%s\n' "$obj" | archive_json_field file | head -1)

          [ -n "$date" ] || continue
          [ -n "$id" ] || continue
          [ -n "$file" ] || continue

          source_file="$base_dir/$file"
          if [ ! -f "$source_file" ] && [ -f "$source_file.xz" ]; then
            source_file="$source_file.xz"
          fi
          [ -f "$source_file" ] || continue

          rel_dir=${base_dir#"$ARCHIVE_ROOT"/}
          html_file=${file%.md}.html
          public_dir="$PUBLIC_DIR/archive/$rel_dir"
          public_file="$public_dir/$html_file"
          public_rel="archive/$rel_dir/$html_file"

          archive_mkdir "$public_dir"
          news_source=$(mktemp)
          archive_cat "$source_file" > "$news_source"

          if "$NEWS_ARTICLE_RENDERER" \
            "$news_source" \
            "$public_file" \
            "../../../../" \
            "../../../../news-archive.html" \
            "Back to News Archive"; then
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
              "$date" "$category" "$title" "$slug" "$id" "$public_rel" >> "$tmp"
          else
            printf 'warning: could not render archived news source %s\n' "$source_file" >&2
          fi

          rm -f "$news_source"
        done
    done

  {
    echo '      <div class="community-news-journal archive-journal">'
    echo '        <table class="community-news-table archive-news-table">'
    echo '          <colgroup>'
    echo '            <col class="community-news-col-meta">'
    echo '            <col class="community-news-col-content">'
    echo '          </colgroup>'
    echo '          <thead>'
    echo '            <tr>'
    echo '              <th>Date</th>'
    echo '              <th>News</th>'
    echo '            </tr>'
    echo '          </thead>'
    echo '          <tbody>'

    if [ -s "$tmp" ]; then
      sort -r "$tmp" | while IFS="$tab" read -r date category title slug id rel; do
        date_e=$(html_escape "$date")
        category_e=$(html_escape "$category")
        title_e=$(html_escape "$title")
        id_e=$(html_escape "$id")
        rel_e=$(html_escape "$rel")
        short_id=$(printf '%s' "$id" | cut -c1-12)
        short_id_e=$(html_escape "$short_id")

        echo '            <tr>'
        echo '              <td class="news-meta">'
        printf '                <time datetime="%s">%s</time>\n' "$date_e" "$date_e"
        printf '                <span>%s</span>\n' "$category_e"
        echo '              </td>'
        echo '              <td class="news-content">'
        printf '                <a class="news-title-link" href="%s">%s</a>\n' "$rel_e" "$title_e"
        printf '                <p>Archive id: <code>%s</code></p>\n' "$short_id_e"
        echo '              </td>'
        echo '            </tr>'
      done
    else
      echo '            <tr>'
      echo '              <td colspan="2" class="news-content">No archived news entries were found.</td>'
      echo '            </tr>'
    fi

    echo '          </tbody>'
    echo '        </table>'
    echo '      </div>'
  } > "$news_out"

  rm -f "$tmp"
}

build_commits_fragment
build_news_fragment

echo "generated ${commits_out#$PROJECT_ROOT/}"
echo "generated ${news_out#$PROJECT_ROOT/}"
