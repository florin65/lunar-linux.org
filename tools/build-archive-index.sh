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
archive_mkdir "$(dirname -- "$commits_out")"
archive_mkdir "$(dirname -- "$news_out")"

if [ ! -x "$NEWS_ARTICLE_RENDERER" ]; then
  printf 'missing news article renderer: %s\n' "$NEWS_ARTICLE_RENDERER" >&2
  exit 1
fi

commits_data_tmp=
commits_fragment_tmp=
news_data_tmp=
news_fragment_tmp=
news_source_tmp=

cleanup() {
  rm -f \
    "$commits_data_tmp" \
    "$commits_fragment_tmp" \
    "$news_data_tmp" \
    "$news_fragment_tmp" \
    "$news_source_tmp"
}

trap cleanup EXIT HUP INT TERM

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
  commits_output_dir=$(dirname -- "$commits_out")
  commits_data_tmp=$(mktemp "$commits_output_dir/.archive-commits-data.XXXXXX")
  commits_fragment_tmp=$(mktemp "$commits_output_dir/.archive-commits.XXXXXX")

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

          printf '%s\t%s\t%s\t%s\t%s\n' "$date" "$commit" "$repo" "$module" "$summary" >> "$commits_data_tmp"
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

    if [ -s "$commits_data_tmp" ]; then
      sort -r "$commits_data_tmp" | while IFS="$tab" read -r date commit repo module summary; do
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
  } > "$commits_fragment_tmp"

  mv "$commits_fragment_tmp" "$commits_out"
  commits_fragment_tmp=
  rm -f "$commits_data_tmp"
  commits_data_tmp=
}

# ---------------------------------------------------------
# News archive fragment
# ---------------------------------------------------------

build_news_fragment() {
  news_output_dir=$(dirname -- "$news_out")
  news_data_tmp=$(mktemp "$news_output_dir/.archive-news-data.XXXXXX")
  news_fragment_tmp=$(mktemp "$news_output_dir/.archive-news.XXXXXX")

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

          if [ -z "$date" ] || [ -z "$id" ] || [ -z "$file" ]; then
            printf 'invalid archived news entry in %s: missing date, id or file\n' "$f" >&2
            exit 1
          fi

          case "$file" in
            */*|.*|*..*|*.md.md|*[!A-Za-z0-9._-]*)
              printf 'invalid archived news file in %s: %s\n' "$f" "$file" >&2
              exit 1
              ;;
            *.md)
              ;;
            *)
              printf 'invalid archived news file in %s: expected a safe .md basename, got %s\n' "$f" "$file" >&2
              exit 1
              ;;
          esac

          source_file="$base_dir/$file"
          if [ ! -f "$source_file" ] && [ -f "$source_file.xz" ]; then
            source_file="$source_file.xz"
          fi
          if [ ! -f "$source_file" ]; then
            printf 'missing archived news source referenced by %s: %s\n' "$f" "$file" >&2
            exit 1
          fi

          rel_dir=${base_dir#"$ARCHIVE_ROOT"/}
          html_file=${file%.md}.html
          public_dir="$PUBLIC_DIR/archive/$rel_dir"
          public_file="$public_dir/$html_file"
          public_rel="archive/$rel_dir/$html_file"
          public_dir_rel="archive/$rel_dir"
          root_prefix=$(printf '%s\n' "$public_dir_rel" | awk -F/ '
            {
              for (i = 1; i <= NF; i++) {
                if ($i != "") {
                  printf "../"
                }
              }
            }
          ')

          archive_mkdir "$public_dir"
          news_source_tmp=$(mktemp)
          archive_cat "$source_file" > "$news_source_tmp"

          if "$NEWS_ARTICLE_RENDERER" \
            "$news_source_tmp" \
            "$public_file" \
            "$root_prefix" \
            "${root_prefix}news-archive.html" \
            "Back to News Archive"; then
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
              "$date" "$category" "$title" "$slug" "$id" "$public_rel" >> "$news_data_tmp"
          else
            printf 'could not render archived news source %s\n' "$source_file" >&2
            exit 1
          fi

          rm -f "$news_source_tmp"
          news_source_tmp=
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

    if [ -s "$news_data_tmp" ]; then
      sort -r "$news_data_tmp" | while IFS="$tab" read -r date category title slug id rel; do
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
  } > "$news_fragment_tmp"

  mv "$news_fragment_tmp" "$news_out"
  news_fragment_tmp=
  rm -f "$news_data_tmp"
  news_data_tmp=
}

build_commits_fragment
build_news_fragment

echo "generated ${commits_out#$PROJECT_ROOT/}"
echo "generated ${news_out#$PROJECT_ROOT/}"
