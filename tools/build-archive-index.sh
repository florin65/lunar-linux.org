#!/bin/sh
# Build archive HTML fragments and archived news pages.
# Archive news entries are processed independently: valid entries are updated,
# while broken entries preserve previously published HTML where possible.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$SCRIPT_DIR/archive-lib.sh"

CACHE_DIR=${CACHE_DIR:-$PROJECT_ROOT/cache}
PUBLIC_DIR=${PUBLIC_DIR:-$PROJECT_ROOT/docs}
NEWS_DIR=${NEWS_DIR:-$PROJECT_ROOT/src/news}
BUILD_REPORT=${BUILD_REPORT:-$CACHE_DIR/build-report.txt}
NEWS_ARTICLE_RENDERER=${NEWS_ARTICLE_RENDERER:-$SCRIPT_DIR/render-news-article.sh}

commits_out=${1:-$CACHE_DIR/archive-commits.html}
news_out=${2:-$CACHE_DIR/archive-news.html}

archive_mkdir "$CACHE_DIR"
archive_mkdir "$PUBLIC_DIR"
archive_mkdir "$(dirname -- "$commits_out")"
archive_mkdir "$(dirname -- "$news_out")"
archive_mkdir "$(dirname -- "$BUILD_REPORT")"

[ -x "$NEWS_ARTICLE_RENDERER" ] ||
  archive_die "missing news article renderer: $NEWS_ARTICLE_RENDERER"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

tab=$(printf '\t')

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g'
}

find_current_news_source() (
  wanted_id=$1

  [ -d "$NEWS_DIR" ] || exit 1

  find "$NEWS_DIR" -type f -name '*.md' | sort |
  while IFS= read -r candidate; do
    candidate_id=$(archive_sha256_file "$candidate")
    if [ "$candidate_id" = "$wanted_id" ]; then
      printf '%s\n' "$candidate"
      exit 0
    fi
  done

  exit 1
)

report_problem() {
  printf '  %s\n' "$1" >> "$BUILD_REPORT"
  printf 'archive warning: %s\n' "$1" >&2
}

build_commits_fragment() {
  data="$tmpdir/commits.data"
  fragment="$tmpdir/commits.html"
  raw="$tmpdir/commits.raw"
  objects="$tmpdir/commits.objects"
  files="$tmpdir/commits.files"
  : > "$data"

  find "$ARCHIVE_ROOT/commits" -type f \
    \( -name '*.json' -o -name '*.json.xz' \) 2>/dev/null |
    sort > "$files"

  while IFS= read -r archive_file; do
    if ! archive_cat "$archive_file" > "$raw"; then
      report_problem "$archive_file: could not read archived commits file"
      continue
    fi

    archive_json_objects_from_cat < "$raw" > "$objects"

    while IFS= read -r obj; do
      date=$(printf '%s\n' "$obj" | archive_json_field date | head -1)
      repo=$(printf '%s\n' "$obj" | archive_json_field repository | head -1)
      module=$(printf '%s\n' "$obj" | archive_json_field module | head -1)
      commit=$(printf '%s\n' "$obj" | archive_json_field commit | head -1)
      summary=$(printf '%s\n' "$obj" | archive_json_field summary | head -1)
      title=$(printf '%s\n' "$obj" | archive_json_field title | head -1)

      if [ -z "$date" ] || [ -z "$commit" ]; then
        report_problem "$archive_file: invalid commit entry; missing date or commit"
        continue
      fi

      [ -n "$summary" ] || summary=$title
      [ -n "$module" ] || module=$title

      if printf '%s\n%s\n%s\n%s\n' \
        "$date" "$commit" "$repo" "$module" | grep -q "$tab"; then
        report_problem "$archive_file: invalid tab in commit entry"
        continue
      fi

      summary=$(printf '%s' "$summary" | tr "$tab" ' ')
      printf '%s\t%s\t%s\t%s\t%s\n' \
        "$date" "$commit" "$repo" "$module" "$summary" >> "$data"
    done < "$objects"
  done < "$files"

  {
    echo '      <div class="moonbase-journal archive-journal">'
    echo '        <table class="moonbase-table archive-commits-table">'
    echo '          <thead><tr><th>Commit</th><th>Repository</th><th>Module</th><th>Comment</th></tr></thead>'
    echo '          <tbody>'

    if [ -s "$data" ]; then
      sort -r "$data" |
      while IFS="$tab" read -r date commit repo module summary; do
        url="https://github.com/lunar-linux/moonbase-$repo/commit/$commit"
        printf '            <tr><td class="commit-id"><a href="%s" target="_blank" rel="noopener" title="%s">%s</a></td><td class="repository-name">%s</td><td class="module-name">%s</td><td class="commit-comment">%s</td></tr>\n' \
          "$(html_escape "$url")" "$(html_escape "$date")" \
          "$(html_escape "$commit")" "$(html_escape "$repo")" \
          "$(html_escape "$module")" "$(html_escape "$summary")"
      done
    else
      echo '            <tr><td colspan="4" class="commit-comment">No archived commits were found.</td></tr>'
    fi

    echo '          </tbody>'
    echo '        </table>'
    echo '      </div>'
  } > "$fragment"

  mv "$fragment" "$commits_out"
}

build_news_fragment() {
  data="$tmpdir/news.data"
  fragment="$tmpdir/news.html"
  raw="$tmpdir/news.raw"
  objects="$tmpdir/news.objects"
  files="$tmpdir/news.files"
  source_tmp="$tmpdir/news-source.md"
  stage="$tmpdir/news-pages"

  archive_mkdir "$stage"
  : > "$data"

  generated=0
  preserved=0
  skipped=0
  warnings=0

  find "$ARCHIVE_ROOT/news" -type f \
    \( -name 'index.json' -o -name 'index.json.xz' \) 2>/dev/null |
    sort > "$files"

  while IFS= read -r index_file; do
    base_dir=$(dirname -- "$index_file")

    if ! archive_cat "$index_file" > "$raw"; then
      report_problem "$index_file: could not read news index"
      warnings=$((warnings + 1))
      continue
    fi

    archive_json_objects_from_cat < "$raw" > "$objects"

    while IFS= read -r obj; do
      id=$(printf '%s\n' "$obj" | archive_json_field id | head -1)
      date=$(printf '%s\n' "$obj" | archive_json_field date | head -1)
      category=$(printf '%s\n' "$obj" | archive_json_field category | head -1)
      title=$(printf '%s\n' "$obj" | archive_json_field title | head -1)
      slug=$(printf '%s\n' "$obj" | archive_json_field slug | head -1)
      file=$(printf '%s\n' "$obj" | archive_json_field file | head -1)

      if [ -z "$date" ] || [ -z "$id" ] || [ -z "$file" ]; then
        report_problem "$index_file: invalid news entry; missing date, id or file"
        warnings=$((warnings + 1))
        skipped=$((skipped + 1))
        continue
      fi

      case "$file" in
        */*|.*|*..*|*.md.md|*[!A-Za-z0-9._-]*)
          report_problem "$index_file: unsafe archived news filename: $file"
          warnings=$((warnings + 1))
          skipped=$((skipped + 1))
          continue
          ;;
        *.md) ;;
        *)
          report_problem "$index_file: archived news filename is not Markdown: $file"
          warnings=$((warnings + 1))
          skipped=$((skipped + 1))
          continue
          ;;
      esac

      rel_dir=${base_dir#"$ARCHIVE_ROOT"/}
      html_file=${file%.md}.html
      public_dir="$PUBLIC_DIR/archive/$rel_dir"
      public_file="$public_dir/$html_file"
      staged_dir="$stage/$rel_dir"
      staged_file="$staged_dir/$html_file"
      public_rel="archive/$rel_dir/$html_file"
      public_dir_rel="archive/$rel_dir"

      source_file="$base_dir/$file"
      if [ ! -f "$source_file" ] && [ -f "$source_file.xz" ]; then
        source_file="$source_file.xz"
      fi

      problem=
      if [ ! -f "$source_file" ]; then
        problem="missing archived news source: $file"
      elif ! archive_cat "$source_file" > "$source_tmp"; then
        problem="could not read archived news source: $file"
      else
        actual_id=$(archive_sha256_file "$source_tmp")
        if [ "$actual_id" != "$id" ]; then
          problem="hash mismatch for archived news source: $file"
        fi
      fi

      if [ -n "$problem" ]; then
        warnings=$((warnings + 1))
        report_problem "$index_file: $problem"

        current_source=
        if current_source=$(find_current_news_source "$id"); then
          if [ -n "$current_source" ] && [ -f "$current_source" ]; then
            if cat "$current_source" > "$source_tmp"; then
              report_problem "$index_file: using matching current news source: ${current_source#$PROJECT_ROOT/}"
              problem=
            fi
          fi
        fi

        if [ -n "$problem" ]; then
          if [ -f "$public_file" ]; then
            preserved=$((preserved + 1))
            report_problem "$index_file: preserved previous HTML for $file"
            printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
              "$date" "$category" "$title" "$slug" "$id" "$public_rel" >> "$data"
          else
            skipped=$((skipped + 1))
            report_problem "$index_file: no matching current source or previous HTML for $file"
          fi
          continue
        fi
      fi

      root_prefix=$(printf '%s\n' "$public_dir_rel" | awk -F/ '
        {
          for (i = 1; i <= NF; i++)
            if ($i != "") printf "../"
        }
      ')

      archive_mkdir "$staged_dir"

      if "$NEWS_ARTICLE_RENDERER" \
        "$source_tmp" "$staged_file" "$root_prefix" \
        "${root_prefix}news-archive.html" "Back to News Archive"
      then
        generated=$((generated + 1))
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$date" "$category" "$title" "$slug" "$id" "$public_rel" >> "$data"
      else
        warnings=$((warnings + 1))
        report_problem "$index_file: renderer failed for $file"

        if [ -f "$public_file" ]; then
          preserved=$((preserved + 1))
          printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$date" "$category" "$title" "$slug" "$id" "$public_rel" >> "$data"
        else
          skipped=$((skipped + 1))
        fi
      fi
    done < "$objects"
  done < "$files"

  {
    echo '      <div class="community-news-journal archive-journal">'
    echo '        <table class="community-news-table archive-news-table">'
    echo '          <thead><tr><th>Date</th><th>News</th></tr></thead>'
    echo '          <tbody>'

    if [ -s "$data" ]; then
      sort -r "$data" |
      while IFS="$tab" read -r date category title slug id rel; do
        short_id=$(printf '%s' "$id" | cut -c1-12)
        echo '            <tr>'
        printf '              <td class="news-meta"><time datetime="%s">%s</time><span>%s</span></td>\n' \
          "$(html_escape "$date")" "$(html_escape "$date")" "$(html_escape "$category")"
        printf '              <td class="news-content"><a class="news-title-link" href="%s">%s</a><p>Archive id: <code>%s</code></p></td>\n' \
          "$(html_escape "$rel")" "$(html_escape "$title")" "$(html_escape "$short_id")"
        echo '            </tr>'
      done
    else
      echo '            <tr><td colspan="2" class="news-content">No valid archived news entries were found.</td></tr>'
    fi

    echo '          </tbody>'
    echo '        </table>'
    echo '      </div>'
  } > "$fragment"

  find "$stage" -type f | sort |
  while IFS= read -r staged_file; do
    staged_rel=${staged_file#"$stage"/}
    public_file="$PUBLIC_DIR/archive/$staged_rel"
    archive_mkdir "$(dirname -- "$public_file")"
    mv "$staged_file" "$public_file"
  done

  mv "$fragment" "$news_out"

  {
    printf '\nArchive\n'
    printf '  generated: %s\n' "$generated"
    printf '  preserved: %s\n' "$preserved"
    printf '  skipped: %s\n' "$skipped"
    printf '  warnings: %s\n' "$warnings"
  } >> "$BUILD_REPORT"

  printf 'archive news: generated=%s preserved=%s skipped=%s warnings=%s\n' \
    "$generated" "$preserved" "$skipped" "$warnings"

  [ "$warnings" -eq 0 ]
}

build_commits_fragment

if build_news_fragment; then
  echo "generated ${commits_out#$PROJECT_ROOT/}"
  echo "generated ${news_out#$PROJECT_ROOT/}"
  exit 0
fi

echo "generated ${commits_out#$PROJECT_ROOT/}"
echo "generated ${news_out#$PROJECT_ROOT/} with warnings"
exit 2
