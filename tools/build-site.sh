#!/bin/sh

# =========================================================
# Lunar Linux website generator - bash prototype
# =========================================================

set -eu

SCRIPT=$(readlink -f "$0")
PROJECT_ROOT=$(dirname "$(dirname "$SCRIPT")")

CONF="$PROJECT_ROOT/site.conf"

if [ ! -f "$CONF" ]; then
  printf 'missing config file: %s\n' "$CONF" >&2
  exit 1
fi

# Configuration precedence:
# exported environment > site.conf defaults > built-in defaults below
# shellcheck disable=SC1090
. "$CONF"

SITE_ROOT=${SITE_ROOT:-.}
MARKDOWN_DIR=${MARKDOWN_DIR:-src/markdown}
NEWS_DIR=${NEWS_DIR:-src/news}
TEMPLATES_DIR=${TEMPLATES_DIR:-templates}
TOOLS_DIR=${TOOLS_DIR:-tools}
COMPONENTS_DIR=${COMPONENTS_DIR:-components}
PUBLIC_DIR=${PUBLIC_DIR:-docs}
DATA_DIR=${DATA_DIR:-docs/data}
BUILD_DIR=${BUILD_DIR:-cache}
ARCHIVE_DIR=${ARCHIVE_DIR:-archive}
MOONBASE_STATS_JSON=${MOONBASE_STATS_JSON:-docs/data/moonbase-stats.json}
DAILY_ISO_JSON=${DAILY_ISO_JSON:-docs/data/daily-iso.json}
NEWS_JSON=${NEWS_JSON:-docs/data/news.json}
MOONBASE_NEWS_JSON=${MOONBASE_NEWS_JSON:-docs/data/moonbase-news.json}
COMMUNITY_NEWS_HTML=${COMMUNITY_NEWS_HTML:-$BUILD_DIR/community-news.html}
GENERATE_NEWS_JSON=${GENERATE_NEWS_JSON:-yes}
UPDATE_DYNAMIC_DATA=${UPDATE_DYNAMIC_DATA:-yes}
UPDATE_ARCHIVE=${UPDATE_ARCHIVE:-yes}

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
BUILD=$(abs_path "$BUILD_DIR")
ARCHIVE=$(abs_path "$ARCHIVE_DIR")
TEMPLATES=$(abs_path "$TEMPLATES_DIR")
TOOLS=$(abs_path "$TOOLS_DIR")
COMPONENTS=$(abs_path "$COMPONENTS_DIR")
HEADER="$TEMPLATES/header.html"
FOOTER="$TEMPLATES/footer.html"
RENDERER="$TOOLS/render-page.sh"
ARCHIVE_LINKS_COMPONENT="$COMPONENTS/archive-links.sh"
MOONBASE_STATS=$(abs_path "$MOONBASE_STATS_JSON")
DAILY_ISO=$(abs_path "$DAILY_ISO_JSON")
NEWS_OUT=$(abs_path "$NEWS_JSON")
MOONBASE_NEWS=$(abs_path "$MOONBASE_NEWS_JSON")
COMMUNITY_NEWS=$(abs_path "$COMMUNITY_NEWS_HTML")
ARCHIVE_COMMITS_HTML=${ARCHIVE_COMMITS_HTML:-$BUILD_DIR/archive-commits.html}
ARCHIVE_NEWS_HTML=${ARCHIVE_NEWS_HTML:-$BUILD_DIR/archive-news.html}
ARCHIVE_COMMITS=$(abs_path "$ARCHIVE_COMMITS_HTML")
ARCHIVE_NEWS=$(abs_path "$ARCHIVE_NEWS_HTML")

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
  printf '%s' "$1" | awk '
    BEGIN {
      first = 1
    }
    {
      if (!first)
        printf "\\n"
      first = 0

      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      gsub(/\t/, "\\t")
      gsub(/\r/, "\\r")

      printf "%s", $0
    }
  '
}

json_get_string() {
  key="$1"
  file="$2"

  [ -f "$file" ] || return 0

  awk -v key="$key" '
    function decode_json_string(raw,    out, i, c) {
      out = ""

      for (i = 1; i <= length(raw); i++) {
        c = substr(raw, i, 1)

        if (c != "\\") {
          out = out c
          continue
        }

        i++
        if (i > length(raw))
          return ""

        c = substr(raw, i, 1)

        if (c == "\"") {
          out = out "\""
        } else if (c == "\\") {
          out = out "\\"
        } else if (c == "/") {
          out = out "/"
        } else if (c == "n") {
          out = out "\n"
        } else if (c == "r") {
          out = out "\r"
        } else if (c == "t") {
          out = out "\t"
        } else {
          return ""
        }
      }

      return out
    }

    {
      line = $0
      pattern = "^[[:space:]]*\"" key "\"[[:space:]]*:[[:space:]]*\""

      if (line !~ pattern)
        next

      sub(pattern, "", line)

      raw = ""
      escaped = 0
      closed = 0

      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)

        if (escaped) {
          raw = raw "\\" c
          escaped = 0
          continue
        }

        if (c == "\\") {
          escaped = 1
          continue
        }

        if (c == "\"") {
          closed = 1
          rest = substr(line, i + 1)

          if (rest !~ /^[[:space:]]*,?[[:space:]]*$/)
            exit 2

          break
        }

        raw = raw c
      }

      if (!closed || escaped)
        exit 2

      value = decode_json_string(raw)

      if (raw != "" && value == "")
        exit 2

      found++
      result = value
    }

    END {
      if (found > 1)
        exit 2

      if (found == 1)
        print result
    }
  ' "$file"
}

json_get_number() {
  key="$1"
  file="$2"

  [ -f "$file" ] || return 0

  awk -v key="$key" '
    {
      line = $0
      pattern = "^[[:space:]]*\"" key "\"[[:space:]]*:[[:space:]]*"

      if (line !~ pattern)
        next

      sub(pattern, "", line)

      if (line !~ /^[0-9]+[[:space:]]*,?[[:space:]]*$/)
        exit 2

      sub(/[[:space:]]*,?[[:space:]]*$/, "", line)

      found++
      result = line
    }

    END {
      if (found > 1)
        exit 2

      if (found == 1)
        print result
    }
  ' "$file"
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

    function json_decode(s,    out, i, c) {
      out = ""

      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)

        if (c != "\\") {
          out = out c
          continue
        }

        i++
        if (i > length(s)) {
          out = out "\\"
          break
        }

        c = substr(s, i, 1)

        if (c == "\"") {
          out = out "\""
        } else if (c == "\\") {
          out = out "\\"
        } else if (c == "/") {
          out = out "/"
        } else if (c == "n") {
          out = out "\n"
        } else if (c == "r") {
          out = out "\r"
        } else if (c == "t") {
          out = out "\t"
        } else {
          # Preserve unsupported escapes such as \uXXXX verbatim.
          out = out "\\" c
        }
      }

      return out
    }

    function field(line, key,    pat, start, rest, raw, i, c) {
      pat = "\"" key "\":\""
      start = index(line, pat)
      if (!start) {
        return ""
      }

      rest = substr(line, start + length(pat))
      raw = ""

      for (i = 1; i <= length(rest); i++) {
        c = substr(rest, i, 1)

        if (c == "\\") {
          raw = raw c

          if (i < length(rest)) {
            i++
            raw = raw substr(rest, i, 1)
          }

          continue
        }

        if (c == "\"") {
          return json_decode(raw)
        }

        raw = raw c
      }

      return json_decode(raw)
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

prepare_archive_values() {
  archive_commits_file=$(mktemp)
  archive_news_file=$(mktemp)

  if [ -x "$TOOLS/build-archive-index.sh" ]; then
    ARCHIVE_ROOT="$ARCHIVE" \
    CACHE_DIR="$BUILD" \
      "$TOOLS/build-archive-index.sh" "$ARCHIVE_COMMITS" "$ARCHIVE_NEWS"
  fi

  if [ -f "$ARCHIVE_COMMITS" ]; then
    cat "$ARCHIVE_COMMITS" > "$archive_commits_file"
  else
    cat > "$archive_commits_file" <<EOF_ARCHIVE_COMMITS
      <div class="moonbase-journal empty">
        <p>No archived commits were found.</p>
      </div>
EOF_ARCHIVE_COMMITS
  fi

  if [ -f "$ARCHIVE_NEWS" ]; then
    cat "$ARCHIVE_NEWS" > "$archive_news_file"
  else
    cat > "$archive_news_file" <<EOF_ARCHIVE_NEWS
      <div class="community-news-journal empty">
        <p>No archived news entries were found.</p>
      </div>
EOF_ARCHIVE_NEWS
  fi
}


prepare_archive_link_values() {
  archive_news_actions_file=$(mktemp)
  archive_commits_actions_file=$(mktemp)

  ARCHIVE_LINKS_INDENT='      ' \
    "$ARCHIVE_LINKS_COMPONENT" \
      'Browse complete archive →|archive/news/' \
      'Return to Info|info.html' \
      > "$archive_news_actions_file"

  ARCHIVE_LINKS_INDENT='      ' \
    "$ARCHIVE_LINKS_COMPONENT" \
      'Browse complete archive →|archive/commits/' \
      'Return to Info|info.html' \
      > "$archive_commits_actions_file"

  info_news_archive_actions_file=$(mktemp)
  info_commits_archive_actions_file=$(mktemp)

  ARCHIVE_LINKS_INDENT='      ' \
  ARCHIVE_LINKS_FIRST_CLASS=secondary \
    "$ARCHIVE_LINKS_COMPONENT" \
      'News Archive →|news-archive.html' \
      > "$info_news_archive_actions_file"

  ARCHIVE_LINKS_INDENT='      ' \
  ARCHIVE_LINKS_FIRST_CLASS=secondary \
    "$ARCHIVE_LINKS_COMPONENT" \
      'Commit Archive →|commits-archive.html' \
      > "$info_commits_archive_actions_file"
}

cleanup_temp_files() {
  if [ -n "${moonbase_commits_file:-}" ]; then
    rm -f "$moonbase_commits_file"
  fi

  if [ -n "${community_news_file:-}" ]; then
    rm -f "$community_news_file"
  fi

  if [ -n "${archive_commits_file:-}" ]; then
    rm -f "$archive_commits_file"
  fi

  if [ -n "${archive_news_file:-}" ]; then
    rm -f "$archive_news_file"
  fi

  if [ -n "${archive_news_actions_file:-}" ]; then
    rm -f "$archive_news_actions_file"
  fi

  if [ -n "${archive_commits_actions_file:-}" ]; then
    rm -f "$archive_commits_actions_file"
  fi

  if [ -n "${info_news_archive_actions_file:-}" ]; then
    rm -f "$info_news_archive_actions_file"
  fi

  if [ -n "${info_commits_archive_actions_file:-}" ]; then
    rm -f "$info_commits_archive_actions_file"
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
    -v community_news_file="$community_news_file" \
    -v archive_commits_file="$archive_commits_file" \
    -v archive_news_file="$archive_news_file" \
    -v archive_news_actions_file="$archive_news_actions_file" \
    -v archive_commits_actions_file="$archive_commits_actions_file" \
    -v info_news_archive_actions_file="$info_news_archive_actions_file" \
    -v info_commits_archive_actions_file="$info_commits_archive_actions_file" '
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

        if ($0 ~ /\{\{[[:space:]]*archive_commits_html[[:space:]]*\}\}/) {
          while ((getline line < archive_commits_file) > 0) {
            print line
          }
          close(archive_commits_file)
          next
        }

        if ($0 ~ /\{\{[[:space:]]*archive_news_html[[:space:]]*\}\}/) {
          while ((getline line < archive_news_file) > 0) {
            print line
          }
          close(archive_news_file)
          next
        }

        if ($0 ~ /\{\{[[:space:]]*archive_news_actions_html[[:space:]]*\}\}/) {
          while ((getline line < archive_news_actions_file) > 0) {
            print line
          }
          close(archive_news_actions_file)
          next
        }

        if ($0 ~ /\{\{[[:space:]]*archive_commits_actions_html[[:space:]]*\}\}/) {
          while ((getline line < archive_commits_actions_file) > 0) {
            print line
          }
          close(archive_commits_actions_file)
          next
        }

        if ($0 ~ /\{\{[[:space:]]*info_news_archive_actions_html[[:space:]]*\}\}/) {
          while ((getline line < info_news_archive_actions_file) > 0) {
            print line
          }
          close(info_news_archive_actions_file)
          next
        }

        if ($0 ~ /\{\{[[:space:]]*info_commits_archive_actions_html[[:space:]]*\}\}/) {
          while ((getline line < info_commits_archive_actions_file) > 0) {
            print line
          }
          close(info_commits_archive_actions_file)
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

  sh "$RENDERER" \
    "$name" \
    "$expanded" \
    "$PROJECT_ROOT" \
    > "$rendered"

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

news_meta() {
  key="$1"
  file="$2"

  awk -v key="$key" '
    BEGIN {
      count = 0
    }

    /^[[:space:]]*$/ {
      exit
    }

    {
      prefix = key ":"

      if (index($0, prefix) != 1)
        next

      value = substr($0, length(prefix) + 1)
      sub(/^[[:space:]]*/, "", value)

      count++
      result = value
    }

    END {
      if (count > 1)
        exit 2

      if (count == 1)
        print result
    }
  ' "$file"
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
  value="$1"
  date_part=
  time_part=
  normalized=

  case "$value" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      date_part="$value"
      ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' '[0-9][0-9]:[0-9][0-9])
      date_part=${value% *}
      time_part=${value#* }
      ;;
    *)
      return 1
      ;;
  esac

  if [ -n "$time_part" ]; then
    normalized=$(
      date -d "$date_part $time_part:00" '+%F %H:%M' 2>/dev/null
    ) || return 1

    [ "$normalized" = "$value" ]
    return
  fi

  normalized=$(
    date -d "$date_part 00:00:00" '+%F' 2>/dev/null
  ) || return 1

  [ "$normalized" = "$date_part" ]
}

build_news_json() (
  out_dir=$(dirname -- "$NEWS_OUT")
  tmp=
  news_list=
  slug_list=

  cleanup_news_json() {
    rm -f "$tmp" "$news_list" "$slug_list"
  }

  trap cleanup_news_json EXIT HUP INT TERM

  mkdir -p "$out_dir"
  tmp=$(mktemp "$out_dir/.news-json.XXXXXX")

  printf '[
' > "$tmp"
  first=1

  if [ -d "$NEWS_SRC" ]; then
    news_list=$(mktemp "$out_dir/.news-list.XXXXXX")
    slug_list=$(mktemp "$out_dir/.news-slugs.XXXXXX")

    if ! find "$NEWS_SRC" -type f -name '*.md' > "$news_list"; then
      printf 'could not enumerate news sources: %s
' "$NEWS_SRC" >&2
      exit 1
    fi

    if ! sort -r "$news_list" -o "$news_list"; then
      printf 'could not sort news sources: %s
' "$NEWS_SRC" >&2
      exit 1
    fi

    while IFS= read -r md; do
      date=$(news_meta Date "$md")
      title=$(news_meta Title "$md")
      category=$(news_meta Category "$md")
      summary=$(news_summary "$md")
      slug=$(basename -- "$md" .md)

      if grep -Fqx -- "$slug" "$slug_list"; then
        printf 'duplicate generated news slug %s in %s
'           "$slug" "$(rel_from_project "$md")" >&2
        exit 1
      else
        grep_status=$?
        if [ "$grep_status" -ne 1 ]; then
          printf 'could not check generated news slug: %s
' "$slug" >&2
          exit 1
        fi
      fi

      printf '%s
' "$slug" >> "$slug_list"

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

      printf '  {"date":"%s","category":"%s","title":"%s","slug":"%s","summary":"%s"}'         "$(json_escape "$date")"         "$(json_escape "$category")"         "$(json_escape "$title")"         "$(json_escape "$slug")"         "$(json_escape "$summary")" >> "$tmp"
    done < "$news_list"
  fi

  printf '
]
' >> "$tmp"

  if ! mv "$tmp" "$NEWS_OUT"; then
    printf 'could not publish generated news JSON: %s
' "$NEWS_OUT" >&2
    exit 1
  fi

  tmp=

  printf 'generated %s
' "$(rel_from_project "$NEWS_OUT")"
)

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

update_archive() {
  if [ "$UPDATE_ARCHIVE" != "yes" ]; then
    return 0
  fi

  if [ ! -x "$TOOLS/archive.sh" ]; then
    printf 'archive: skipped, missing %s\n' "$(rel_from_project "$TOOLS/archive.sh")" >&2
    return 0
  fi

  printf 'updating archive...\n'
  ARCHIVE_ROOT="$ARCHIVE" \
  DATA_DIR="$DATA" \
  NEWS_DIR="$NEWS_SRC" \
    "$TOOLS/archive.sh" commits "$MOONBASE_NEWS"

  ARCHIVE_ROOT="$ARCHIVE" \
  DATA_DIR="$DATA" \
  NEWS_DIR="$NEWS_SRC" \
    "$TOOLS/archive.sh" news "$NEWS_SRC"
}

publish_archive_assets() {
  src="$ARCHIVE"
  dst="$PUBLIC/archive"

  [ -d "$src" ] || return 0

  rm -rf "$dst"
  mkdir -p "$dst"

  (cd "$src" && tar cf - .) | (cd "$dst" && tar xf -)
  printf 'published %s\n' "$(rel_from_project "$dst")"
}

write_redirect_page() {
  old_name="$1"
  new_target="$2"
  out="$PUBLIC/$old_name.html"

  cat > "$out" <<EOF_REDIRECT
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="0; url=$new_target">
  <link rel="canonical" href="$new_target">
  <title>Page moved | Lunar Linux</title>
</head>
<body>
  <p>This page has moved to <a href="$new_target">$new_target</a>.</p>
</body>
</html>
EOF_REDIRECT

  printf 'generated redirect %s -> %s\n' "$(rel_from_project "$out")" "$new_target"
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

  if [ ! -x "$ARCHIVE_LINKS_COMPONENT" ]; then
    printf 'missing component: %s\n' "$ARCHIVE_LINKS_COMPONENT" >&2
    exit 1
  fi

  update_dynamic_data

  if [ "$GENERATE_NEWS_JSON" = "yes" ]; then
    build_news_json
  fi

  update_archive
  publish_archive_assets

  load_dynamic_values
  prepare_moonbase_values
  prepare_community_values
  prepare_archive_values
  prepare_archive_link_values

  for md in "$SRC"/*.md; do
    [ -f "$md" ] || continue

    name=$(basename -- "$md" .md)

    case "$name" in
      news|archive)
        continue
        ;;
    esac

    write_page "$md"
  done

  write_redirect_page news info.html
  write_redirect_page archive info.html

  cleanup_temp_files
}

main "$@"
