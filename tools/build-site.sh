#!/bin/sh

# =========================================================
# Lunar Linux website generator - bash prototype
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
PUBLIC_DIR=${PUBLIC_DIR:-docs}
DATA_DIR=${DATA_DIR:-docs/data}
MOONBASE_STATS_JSON=${MOONBASE_STATS_JSON:-docs/data/moonbase-stats.json}
DAILY_ISO_JSON=${DAILY_ISO_JSON:-docs/data/daily-iso.json}
NEWS_JSON=${NEWS_JSON:-docs/data/news.json}
MOONBASE_NEWS_JSON=${MOONBASE_NEWS_JSON:-docs/data/moonbase-news.json}
COMMUNITY_NEWS_HTML=${COMMUNITY_NEWS_HTML:-cache/community-news.html}
NEWS_ARTICLES_DIR=${NEWS_ARTICLES_DIR:-docs/news}
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
RENDERER="$TOOLS/render-page.sh"
MOONBASE_STATS=$(abs_path "$MOONBASE_STATS_JSON")
DAILY_ISO=$(abs_path "$DAILY_ISO_JSON")
NEWS_OUT=$(abs_path "$NEWS_JSON")
MOONBASE_NEWS=$(abs_path "$MOONBASE_NEWS_JSON")
COMMUNITY_NEWS=$(abs_path "$COMMUNITY_NEWS_HTML")

mkdir -p "$PUBLIC" "$DATA"

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

  latest_iso_display=$(
    printf '%s\n' "$latest_iso_file" |
    sed -n 's/.*\(daily-[0-9]\{8\}\).*/\1/p'
  )

  [ -n "$latest_iso_display" ] || latest_iso_display="$latest_iso_file"
}

expand_variables() {
  file="$1"

  awk \
    -v latest_iso_file="$latest_iso_file" \
    -v latest_iso_display="$latest_iso_display" \
    -v latest_iso_url="$latest_iso_url" \
    -v latest_iso_date="$latest_iso_date" \
    -v moonbase_modules="$moonbase_modules" '
      {
        gsub(/\{\{[[:space:]]*latest_iso_file[[:space:]]*\}\}/, latest_iso_file)
        gsub(/\{\{[[:space:]]*latest_iso_display[[:space:]]*\}\}/, latest_iso_display)
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

    NR == 1 && $0 == "---" { in_fm = 1; next }
    in_fm && $0 == "---" { in_fm = 0; next }
    in_fm { next }

    /^[[:space:]]*$/ { close_blocks(); next }

    /^### / { close_blocks(); line = substr($0, 5); print "      <h3>" inline(line) "</h3>"; next }
    /^## /  { close_blocks(); line = substr($0, 4); print "      <h2>" inline(line) "</h2>"; next }
    /^# /   { close_blocks(); line = substr($0, 3); print "      <h1>" inline(line) "</h1>"; next }

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
      print "        <p>" inline(line) "</p>"
      next
    }

    { close_blocks(); print "      <p>" inline($0) "</p>" }

    END { close_blocks() }
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


prepare_moonbase_values() {
  moonbase_commits_count=0
  moonbase_repositories_changed=0
  moonbase_modules_changed=0
  moonbase_version_bumps=0
  moonbase_other_commits=0

  moonbase_commits_file=$(mktemp)

  if [ ! -f "$MOONBASE_NEWS" ]; then
    cat > "$moonbase_commits_file" <<EOF_MOONBASE
      <div class="moonbase-journal empty">
        <p>No Moonbase commits were found for the selected period.</p>
      </div>
EOF_MOONBASE
    return 0
  fi

  moonbase_commits_count=$(
    grep -c '"category":"Moonbase"' "$MOONBASE_NEWS" 2>/dev/null || true
  )

  moonbase_repositories_changed=$(
    sed -n 's/.*"repository":"\([^"]*\)".*/\1/p' "$MOONBASE_NEWS" |
      awk 'NF && !seen[$0]++ { count++ } END { print count + 0 }'
  )

  moonbase_modules_changed=$(
    sed -n 's/.*"module":"\([^"]*\)".*/\1/p' "$MOONBASE_NEWS" |
      awk 'NF && !seen[$0]++ { count++ } END { print count + 0 }'
  )

  moonbase_version_bumps=$(
    sed -n 's/.*"summary":"\([^"]*\)".*/\1/p' "$MOONBASE_NEWS" |
      awk 'BEGIN { IGNORECASE = 1 } /version bumped to|bump to/ { count++ } END { print count + 0 }'
  )

  moonbase_other_commits=$((moonbase_commits_count - moonbase_version_bumps))
  [ "$moonbase_other_commits" -ge 0 ] || moonbase_other_commits=0

  awk '
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      return s
    }

    function attr(s) {
      s = esc(s)
      gsub(/"/, "\\&quot;", s)
      return s
    }

    function field(line, key,    pat, start, rest, end) {
      pat = "\"" key "\":\""
      start = index(line, pat)
      if (!start) {
        return ""
      }

      rest = substr(line, start + length(pat))
      end = index(rest, "\"")

      if (!end) {
        return rest
      }

      return substr(rest, 1, end - 1)
    }

    BEGIN {
      count = 0
      print "      <div class=\"moonbase-journal\">"
      print "        <table class=\"moonbase-table\">"
      print "          <colgroup>"
      print "            <col class=\"moonbase-col-commit\">"
      print "            <col class=\"moonbase-col-repository\">"
      print "            <col class=\"moonbase-col-module\">"
      print "            <col class=\"moonbase-col-comment\">"
      print "          </colgroup>"
      print "          <thead>"
      print "            <tr>"
      print "              <th>Commit</th>"
      print "              <th>Repository</th>"
      print "              <th>Module</th>"
      print "              <th>Comment</th>"
      print "            </tr>"
      print "          </thead>"
      print "          <tbody>"
    }

    /"category":"Moonbase"/ {
      repo = field($0, "repository")
      module = field($0, "module")
      commit = field($0, "commit")
      summary = field($0, "summary")

      if (module == "") {
        title = field($0, "title")
        module = title
        sub(/:.*/, "", module)
      }

      url = "https://github.com/lunar-linux/moonbase-" repo "/commit/" commit

      print "            <tr>"
      print "              <td class=\"commit-id\"><a href=\"" attr(url) "\" target=\"_blank\" rel=\"noopener\">" esc(commit) "</a></td>"
      print "              <td class=\"repository-name\">" esc(repo) "</td>"
      print "              <td class=\"module-name\">" esc(module) "</td>"
      print "              <td class=\"commit-comment\">" esc(summary) "</td>"
      print "            </tr>"

      count++
    }

    END {
      print "          </tbody>"
      print "        </table>"

      if (count == 0) {
        print "        <p>No Moonbase commits were found for the selected period.</p>"
      }

      print "      </div>"
    }
  ' "$MOONBASE_NEWS" > "$moonbase_commits_file"
}


prepare_community_values() {
  community_news_file=$(mktemp)

  if [ -f "$COMMUNITY_NEWS" ]; then
    cat "$COMMUNITY_NEWS" > "$community_news_file"
  else
    cat > "$community_news_file" <<EOF_COMMUNITY
      <div class="community-news-journal empty">
        <p>No community or project news entries were found.</p>
      </div>
EOF_COMMUNITY
  fi
}

cleanup_temp_files() {
  if [ -n "${moonbase_commits_file:-}" ]; then
    rm -f "$moonbase_commits_file"
  fi

  if [ -n "${community_news_file:-}" ]; then
    rm -f "$community_news_file"
  fi
}


expand_template_file() {
  file="$1"

  awk \
    -v latest_iso_file="$latest_iso_file" \
    -v latest_iso_display="$latest_iso_display" \
    -v latest_iso_url="$latest_iso_url" \
    -v latest_iso_date="$latest_iso_date" \
    -v moonbase_modules="$moonbase_modules" \
    -v moonbase_commits_count="$moonbase_commits_count" \
    -v moonbase_repositories_changed="$moonbase_repositories_changed" \
    -v moonbase_modules_changed="$moonbase_modules_changed" \
    -v moonbase_version_bumps="$moonbase_version_bumps" \
    -v moonbase_other_commits="$moonbase_other_commits" \
    -v moonbase_commits_file="$moonbase_commits_file" \
    -v community_news_file="$community_news_file" '
      {
        if ($0 ~ /\{\{[[:space:]]*moonbase_commits_html[[:space:]]*\}\}/) {
          while ((getline line < moonbase_commits_file) > 0) {
            print line
          }
          close(moonbase_commits_file)
          next
        }

        if ($0 ~ /\{\{[[:space:]]*community_news_html[[:space:]]*\}\}/) {
          while ((getline line < community_news_file) > 0) {
            print line
          }
          close(community_news_file)
          next
        }

        gsub(/\{\{[[:space:]]*latest_iso_file[[:space:]]*\}\}/, latest_iso_file)
        gsub(/\{\{[[:space:]]*latest_iso_display[[:space:]]*\}\}/, latest_iso_display)
        gsub(/\{\{[[:space:]]*latest_iso_url[[:space:]]*\}\}/, latest_iso_url)
        gsub(/\{\{[[:space:]]*latest_iso_date[[:space:]]*\}\}/, latest_iso_date)
        gsub(/\{\{[[:space:]]*moonbase_modules[[:space:]]*\}\}/, moonbase_modules)
        gsub(/\{\{[[:space:]]*moonbase_commits_count[[:space:]]*\}\}/, moonbase_commits_count)
        gsub(/\{\{[[:space:]]*moonbase_repositories_changed[[:space:]]*\}\}/, moonbase_repositories_changed)
        gsub(/\{\{[[:space:]]*moonbase_modules_changed[[:space:]]*\}\}/, moonbase_modules_changed)
        gsub(/\{\{[[:space:]]*moonbase_version_bumps[[:space:]]*\}\}/, moonbase_version_bumps)
        gsub(/\{\{[[:space:]]*moonbase_other_commits[[:space:]]*\}\}/, moonbase_other_commits)
        print
      }
    ' "$file"
}

write_page() {
  md="$1"
  name=$(basename -- "$md" .md)
  out="$PUBLIC/$name.html"
  expanded=$(mktemp)
  rendered=$(mktemp)

  title=$(get_meta title "$md")
  description=$(get_meta description "$md")

  [ -n "$title" ] || title="$name"
  [ -n "$description" ] || description="Lunar Linux website page."

  expand_variables "$md" > "$expanded"
  sh "$RENDERER" "$name" "$expanded" > "$rendered"

  {
    write_html_head "$title" "$description"
    sed 's#{{root}}##g' "$HEADER"
    expand_template_file "$rendered"
    cat "$FOOTER"

    cat <<EOF_PAGE
</body>
</html>
EOF_PAGE
  } > "$out"

  rm -f "$expanded" "$rendered"
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


news_meta() {
  key="$1"
  file="$2"

  sed -n 's/^'"$key"':[[:space:]]*//p' "$file" | head -n 1
}

news_summary() {
  file="$1"

  awk '
    BEGIN { body = 0 }
    body && NF {
      print
      exit
    }
    /^[[:space:]]*$/ {
      body = 1
      next
    }
  ' "$file"
}

news_has_body() {
  file="$1"

  awk '
    BEGIN { body = 0; ok = 1 }
    body && NF { ok = 0; exit }
    /^[[:space:]]*$/ { body = 1; next }
    END { exit ok }
  ' "$file"
}

valid_news_date() {
  printf '%s
' "$1" |
    grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}([[:space:]][0-9]{2}:[0-9]{2})?$'
}

build_news_json() {
  tmp="$NEWS_OUT.tmp"
  out_dir=$(dirname -- "$NEWS_OUT")

  mkdir -p "$out_dir"
  printf '[
' > "$tmp"
  first=1

  if [ -d "$NEWS_SRC" ]; then
    find "$NEWS_SRC" -type f -name '*.md' | sort -r | while IFS= read -r md; do
      date=$(news_meta Date "$md")
      title=$(news_meta Title "$md")
      category=$(news_meta Category "$md")
      summary=$(news_summary "$md")
      slug=$(basename -- "$md" .md)

      if [ -z "$date" ] || [ -z "$title" ] || [ -z "$category" ]; then
        printf 'warning: rejecting invalid news file %s: missing Date, Category or Title
' "$(rel_from_project "$md")" >&2
        continue
      fi

      if ! valid_news_date "$date"; then
        printf 'warning: rejecting invalid news file %s: invalid Date format
' "$(rel_from_project "$md")" >&2
        continue
      fi

      if ! news_has_body "$md"; then
        printf 'warning: rejecting invalid news file %s: empty body
' "$(rel_from_project "$md")" >&2
        continue
      fi

      if [ "$first" -eq 0 ]; then
        printf ',
' >> "$tmp"
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

  printf '
]
' >> "$tmp"
  mv "$tmp" "$NEWS_OUT"
  printf 'generated %s
' "$(rel_from_project "$NEWS_OUT")"
}

update_dynamic_data() {
  if [ "$UPDATE_DYNAMIC_DATA" != "yes" ]; then
    return 0
  fi

  printf 'updating dynamic data...\n'
  "$TOOLS/count-moonbase.sh"
  "$TOOLS/get-iso-file-date.sh"
  "$TOOLS/build-moonbase-logs.sh"
  "$TOOLS/build-moonbase-news.sh"
  "$TOOLS/build-community-news.sh"
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

  if [ ! -f "$RENDERER" ]; then
    printf 'missing renderer: %s\n' "$RENDERER" >&2
    exit 1
  fi

  update_dynamic_data
  load_dynamic_values
  prepare_moonbase_values
  prepare_community_values

  for md in "$SRC"/*.md; do
    [ -f "$md" ] || continue
    write_page "$md"
  done

  cleanup_temp_files

  if [ "$GENERATE_NEWS_JSON" = "yes" ]; then
    build_news_json
  fi
}

main "$@"
