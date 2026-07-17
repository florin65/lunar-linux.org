#!/bin/sh

# =========================================================
# Lunar Linux page renderer
# shell + awk renderer for src/markdown/*.md
# =========================================================

set -eu

if [ "$#" -ne 3 ]; then
  printf 'usage: %s page-name markdown-file project-root\n' "$0" >&2
  exit 1
fi

page_name="$1"
markdown_file="$2"
project_root="$3"

awk \
    -v page="$page_name" \
    -v project_root="$project_root" '

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

function slug_id(s,    t) {
  t = s
  while (match(t, /\[[^]]+\]\([^)]+\)/)) {
    t = substr(t, 1, RSTART - 1) substr(t, RSTART + 1, index(substr(t, RSTART), "]") - 2) substr(t, RSTART + RLENGTH)
  }
  gsub(/`/, "", t)
  gsub(/\*/, "", t)
  t = tolower(t)
  gsub(/[^a-z0-9]+/, "-", t)
  gsub(/^-+/, "", t)
  gsub(/-+$/, "", t)
  if (t == "") t = "section"
  return t
}


function inline(s,    out, pos, len, kind_name, pre, token, label, url, rest, p1, p2, content, p) {
  out = ""

  while (s != "") {
    pos = 0
    len = 0
    kind_name = ""

    if (match(s, /`[^`]+`/)) {
      pos = RSTART
      len = RLENGTH
      kind_name = "code"
    }

    if (match(s, /\[[^]]+\]\([^)]+\)/)) {
      if (pos == 0 || RSTART < pos) {
        pos = RSTART
        len = RLENGTH
        kind_name = "link"
      }
    }

    if (match(s, /\*\*[^*]+\*\*/)) {
      if (pos == 0 || RSTART < pos) {
        pos = RSTART
        len = RLENGTH
        kind_name = "strong"
      }
    }

    if (match(s, /\*[^*]+\*/)) {
      if (pos == 0 || RSTART < pos) {
        pos = RSTART
        len = RLENGTH
        kind_name = "em"
      }
    }

    if (pos == 0) {
      out = out esc(s)
      break
    }

    pre = substr(s, 1, pos - 1)
    out = out esc(pre)
    token = substr(s, pos, len)

    if (kind_name == "code") {
      content = substr(token, 2, length(token) - 2)
      out = out "<code>" esc(content) "</code>"
    } else if (kind_name == "link") {
      p1 = index(token, "](")
      label = substr(token, 2, p1 - 2)
      rest = substr(token, p1 + 2)
      p2 = length(rest) - 1
      url = substr(rest, 1, p2)

      out = out "<a href=\"" attr(url) "\">" inline(label) "</a>"
    } else if (kind_name == "strong") {
      content = substr(token, 3, length(token) - 4)
      out = out "<strong>" inline(content) "</strong>"
    } else if (kind_name == "em") {
      content = substr(token, 2, length(token) - 2)
      out = out "<em>" inline(content) "</em>"
    }

    s = substr(s, pos + len)
  }

  return out
}

function add(k, v) {
  n++
  kind[n] = k
  val[n] = v
}

function is_block_start(s) {
    return s ~ /^(# |## |### |- |> |\[|```|@@HTML|@@INCLUDE:|<!-- HTML_BLOCK_BEGIN -->)/
}

function join_lines(arr, count,    i, s) {
  s = ""
  for (i = 1; i <= count; i++) {
    if (s != "") s = s SEP
    s = s arr[i]
  }
  return s
}

function split_items(s, arr) {
  return split(s, arr, SEP)
}

function is_taxonomy(s,    t) {
  t = trim(s)
  return (t == "general" || t == "installation" || t == "development" || t == "documentation")
}

function first_h1(    i) {
  for (i = 1; i <= n; i++) if (kind[i] == "h1") return val[i]
  return "Page"
}

function first_p_in_range(a, b,    i) {
  for (i = a; i <= b; i++) if (kind[i] == "p") return val[i]
  return ""
}

function first_p(    i) {
  for (i = 1; i <= n; i++) if (kind[i] == "p") return val[i]
  return ""
}

function first_quote_in_range(a, b,    i) {
  for (i = a; i <= b; i++) if (kind[i] == "quote") return val[i]
  return ""
}

function first_links_in_range(a, b,    i) {
  for (i = a; i <= b; i++) if (kind[i] == "links") return val[i]
  return ""
}

function first_links_global(    i) {
  for (i = 1; i <= n; i++) if (kind[i] == "links") return val[i]
  return ""
}

function first_ul_global(    i) {
  for (i = 1; i <= n; i++) if (kind[i] == "ul") return val[i]
  return ""
}

function section_index(title,    i) {
  for (i = 1; i <= n; i++) {
    if (kind[i] == "h2" && val[i] == title) return i
  }
  return 0
}

function section_end(idx,    i) {
  if (!idx) return 0
  for (i = idx + 1; i <= n; i++) {
    if (kind[i] == "h2") return i - 1
  }
  return n
}

function next_section_index(idx,    i) {
  for (i = idx + 1; i <= n; i++) if (kind[i] == "h2") return i
  return 0
}

function first_section(    i) {
  for (i = 1; i <= n; i++) if (kind[i] == "h2") return i
  return 0
}

function section_count(    i, c) {
  c = 0
  for (i = 1; i <= n; i++) if (kind[i] == "h2") c++
  return c
}

function section_at(pos,    i, c) {
  c = 0
  for (i = 1; i <= n; i++) {
    if (kind[i] == "h2") {
      c++
      if (c == pos) return i
    }
  }
  return 0
}

function last_section(    i, last) {
  last = 0
  for (i = 1; i <= n; i++) if (kind[i] == "h2") last = i
  return last
}

function has_subsections(a, b,    i) {
  for (i = a; i <= b; i++) if (kind[i] == "h3") return 1
  return 0
}

function render_blocks(a, b, indent, skip_quote, skip_links,    i, items, c, j) {
  for (i = a; i <= b; i++) {
    if (skip_quote && kind[i] == "quote") continue
    if (skip_links && kind[i] == "links") continue

    if (kind[i] == "h1")
      print indent "<h1>" inline(val[i]) "</h1>"
    else if (kind[i] == "h2")
      print indent "<h2 id=\"" slug_id(val[i]) "\">" inline(val[i]) "</h2>"
    else if (kind[i] == "h3")
      print indent "<h3 id=\"" slug_id(val[i]) "\">" inline(val[i]) "</h3>"
    else if (kind[i] == "h4")
      print indent "<h4 id=\"" slug_id(val[i]) "\">" inline(val[i]) "</h4>"
    else if (kind[i] == "h5")
      print indent "<h5 id=\"" slug_id(val[i]) "\">" inline(val[i]) "</h5>"
    else if (kind[i] == "h6")
      print indent "<h6 id=\"" slug_id(val[i]) "\">" inline(val[i]) "</h6>"
    else if (kind[i] == "p") {
      if (is_taxonomy(val[i])) continue
      print indent "<p>" inline(val[i]) "</p>"
    }
    else if (kind[i] == "ul") {
      c = split_items(val[i], items)
      if (i > 1 && kind[i - 1] == "h2" && val[i - 1] == "On This Page")
        print indent "<ul class=\"simple-list local-toc\">"
      else
        print indent "<ul class=\"simple-list\">"
      for (j = 1; j <= c; j++)
        print indent "  <li>" inline(items[j]) "</li>"
      print indent "</ul>"
    }
    else if (kind[i] == "ol") {
      c = split_items(val[i], items)
      print indent "<ol class=\"simple-list ordered-list\">"
      for (j = 1; j <= c; j++)
        print indent "  <li>" inline(items[j]) "</li>"
      print indent "</ol>"
    }
    else if (kind[i] == "quote") {
      c = split_items(val[i], items)
      print indent "<blockquote class=\"quote-box\">"
      if (c >= 1) print indent "  <p>" inline(items[1]) "</p>"
      for (j = 2; j <= c; j++)
        print indent "  <span>" inline(items[j]) "</span>"
      print indent "</blockquote>"
    }
    else if (kind[i] == "links") {
      render_actions(val[i], indent)
    }
    else if (kind[i] == "code") {
      printf "%s<pre><code>%s</code></pre>\n",
         indent,
         esc(val[i])
    }
    else if (kind[i] == "html") {
        print val[i]
    }
  }
}

function render_actions(s, indent,    items, c, j, label, url, p, cls) {
  c = split_items(s, items)

  print indent "<div class=\"hero-actions\">"
  for (j = 1; j <= c; j++) {
    p = index(items[j], LINKSEP)
    label = substr(items[j], 1, p - 1)
    url = substr(items[j], p + length(LINKSEP))
    gsub(/^pages\//, "", url)
    cls = (j == 1 ? "button primary" : "button secondary")
    print indent "  <a class=\"" cls "\" href=\"" attr(url) "\">" inline(label) "</a>"
  }
  print indent "</div>"
}

function render_hero(title, desc, extra_class,    section_class) {
  section_class = "page-hero"
  if (extra_class != "")
    section_class = section_class " " extra_class

  print "  <section class=\"" section_class "\">"
  print "    <div class=\"container\">"
  print "      <h1>" inline(title) "</h1>"
  print "      <p class=\"hero-description\">" inline(desc) "</p>"
  print "    </div>"
  print "  </section>"
}

function render_news_section(title, desc, section_class, content_html, actions_html) {
  print "  <section class=\"" section_class "\">"
  print "    <div class=\"container\">"
  print "      <h2 class=\"section-title\">" inline(title) "</h2>"
  print "      <p class=\"hero-description\">" inline(desc) "</p>"
  print content_html
  print actions_html
  print "    </div>"
  print "  </section>"
}

function render_content_grid(first_pos, max_cards,    pos, idx, end, count, wide) {
  print "  <section class=\"content-section\">"
  print "    <div class=\"container content-grid\">"

  count = 0
  pos = first_pos
  while (pos && count < max_cards) {
    count++
    end = section_end(pos)
    wide = (count == 1 && max_cards > 1 ? " wide" : "")
    print "      <article class=\"content-card" wide "\">"
    print "        <h2>" inline(val[pos]) "</h2>"
    render_blocks(pos + 1, end, "        ", 1, 1)
    print "      </article>"
    pos = next_section_index(pos)
  }

  print "    </div>"
  print "  </section>"
}

function render_feature_grid(title, a, b, muted,    i, nxt, seccls) {
  seccls = muted ? "content-section muted-section" : "content-section"

  print "  <section class=\"" seccls "\">"
  print "    <div class=\"container\">"
  print "      <h2 id=\"" slug_id(title) "\" class=\"section-title\">" inline(title) "</h2>"

  firstcard = 0

  for (i = a; i <= b; i++) {
    if (kind[i] == "h3") {
        firstcard = i
        break
    }
  }

  if (firstcard && firstcard > a)
    render_blocks(a, firstcard - 1, "      ", 1, 1)

  if (title == "Viewing and Browsing")
    print "      <div class=\"feature-grid stacked-grid\">"
  else
    print "      <div class=\"feature-grid\">"

  for (i = a; i <= b; i++) {
    if (kind[i] != "h3") continue
    nxt = next_h3_or_end(i, b)

    wide = (inline(val[i]) == "Community support" ? " feature-card-wide" : "")

    print "        <article class=\"feature-card" wide "\">"
    print "          <h3>" inline(val[i]) "</h3>"
    render_blocks(i + 1, nxt, "          ", 1, 1)
    print "        </article>"

    i = nxt
  }

  print "      </div>"
  print "    </div>"
  print "  </section>"
}

function next_h3_or_end(idx, b,    i) {
  for (i = idx + 1; i <= b; i++) {
    if (kind[i] == "h3") return i - 1
  }
  return b
}

function render_split_section(title, a, b, cls,    quote, i, items, c, j) {
  if (cls == "") cls = "content-section"

  quote = first_quote_in_range(a, b)

  print "  <section class=\"" cls "\">"
  print "    <div class=\"container split-content\">"
  print "      <article>"
  print "        <h2 id=\"" slug_id(title) "\">" inline(title) "</h2>"
  render_blocks(a, b, "        ", 1, 1)
  print "      </article>"

  if (quote != "") {
    c = split_items(quote, items)
    print "      <aside class=\"quote-box\">"
    if (c >= 1) print "        <p>" inline(items[1]) "</p>"
    for (j = 2; j <= c; j++)
      print "        <span>" inline(items[j]) "</span>"
    print "      </aside>"
  }

  print "    </div>"
  print "  </section>"
}

function render_closing_banner(title, a, b, muted,    seccls) {
  seccls = muted ? "content-section muted-section" : "content-section"

  print "  <section class=\"" seccls "\">"
  print "    <div class=\"container closing-banner\">"
  print "      <h2 id=\"" slug_id(title) "\">" inline(title) "</h2>"
  render_blocks(a, b, "      ", 0, 1)
  print "    </div>"
  print "  </section>"
}

function render_index(    title, meta, offer, closing, actions, latest, facts, items, c, j, p, date, txt, sec_end) {
  title = first_h1()
  meta = first_p()
  offer = first_ul_global()
  actions = first_links_global()

  # Last paragraph before the first section is the closing line.
  closing = ""
  for (j = 1; j <= n; j++) {
    if (kind[j] == "h2") break
    if (kind[j] == "p") closing = val[j]
  }

  print "<main>"
  print "  <section class=\"frontpage\">"
  print "    <div class=\"container frontpage-grid\">"
  print "      <article class=\"intro-panel\">"
  print "        <p class=\"meta-line\">" inline(meta) "</p>"
  print "        <h1>" inline(title) "</h1>"
  print "        <ul class=\"offer-list\">"

  c = split_items(offer, items)
  for (j = 1; j <= c; j++)
    print "          <li>" inline(items[j]) "</li>"

  print "        </ul>"
  print "        <p class=\"closing-line\">" inline(closing) "</p>"
  render_actions(actions, "        ")
  print "      </article>"
  print "      <aside class=\"side-panels\">"
  print "        <article class=\"info-box\">"
  print "          <h2>Latest News</h2>"
  print "          <ul class=\"dated-list\">"

  latest = section_index("Latest News")
  if (latest) {
    sec_end = section_end(latest)
    for (j = latest + 1; j <= sec_end; j++) {
      if (kind[j] == "ul") {
        c = split_items(val[j], items)
        for (p = 1; p <= c; p++) {
          date = ""
          txt = items[p]
          if (index(items[p], "—")) {
            split(items[p], tmp, "—")
            date = trim(tmp[1])
            txt = trim(tmp[2])
          }
          print "            <li><span>" inline(date) "</span> " inline(txt) "</li>"
        }
      }
    }
  }

  print "          </ul>"
  print "        </article>"
  print "        <article class=\"info-box compact\">"
  print "          <h2>Latest Updates</h2>"
  print "          <ul class=\"update-list\">"
  print "            <li><span>date</span> {{ latest_iso_date }}</li>"
  print "            <li><span>modules</span> {{ moonbase_modules }}</li>"
  print "            <li><span>repos</span> {{ moonbase_repositories_changed }}</li>"
  print "            <li><span>commits</span> {{ moonbase_commits_count }}</li>"
  print "            <li><span>daily ISO</span> {{ latest_iso_display }}</li>"
  print "          </ul>"
  print "        </article>"
  print "      </aside>"
  print "    </div>"
  print "  </section>"

  facts = section_index("Quick facts")
  if (facts) {

    print "  <section class=\"quickfacts\">"
    print "    <div class=\"container\">"
    print "      <h2 id=\"quick-facts\">Quick facts</h2>"
    print "    </div>"
    print "    <div class=\"container facts\">"

    sec_end = section_end(facts)
    for (j = facts + 1; j <= sec_end; j++) {
      if (kind[j] == "ul") {
        c = split_items(val[j], items)
        for (p = 1; p <= c; p++)
          print "      <div>" inline(items[p]) "</div>"
      }
    }
    print "    </div>"
    print "    </div>"
    print "  </section>"
  }

  print "</main>"
}

function render_download( title, intro_start, daily, quick, why, before, nexts, links, e) {
  title = first_h1()

  print "<main class=\"page-main\">"
  print "  <section class=\"content-section download-section\">"
  print "    <div class=\"container download-main download-stacked\">"
  print "      <article class=\"download-card primary-download\">"
  print "        <h1>" inline(title) "</h1>"

  # intro paragraphs before first section
  for (e = 1; e <= n; e++) {
    if (kind[e] == "h2") break
    if (kind[e] == "p") print "        <p>" inline(val[e]) "</p>"
  }

  print "        <h2>Daily Build</h2>"
  print "        <div class=\"download-info\">"
  print "          <p><strong>ISO: </strong><span>{{ latest_iso_file }}</span></p>"
  print "        </div>"

  daily = section_index("Daily Build")
  if (daily) {
    links = first_links_in_range(daily + 1, section_end(daily))
    if (links != "") render_actions(links, "        ")
  }

  print "      </article>"

  quick = section_index("Quick notes")
  print "      <aside class=\"download-card quick-notes-card\">"
  print "        <h2>Quick notes</h2>"
  if (quick) render_blocks(quick + 1, section_end(quick), "        ", 0, 1)
  print "      </aside>"

  print "    </div>"
  print "  </section>"

  why = section_index("Why a Daily Build?")
  if (why) render_feature_grid("Why a Daily Build?", why + 1, section_end(why), 1)

  before = section_index("Before you install")
  if (before) render_split_section("Before you install", before + 1, section_end(before), "content-section")

  nexts = section_index("What comes next?")
  if (nexts) render_feature_grid("What comes next?", nexts + 1, section_end(nexts), 1)

  print "</main>"
}

function render_news(    title, desc, community, moonbase, community_desc, moonbase_desc) {
  title = first_h1()
  desc = first_p()

  community = section_index("Community and project news")
  moonbase = section_index("Moonbase commits journal")

  community_desc = community ? first_p_in_range(community + 1, section_end(community)) : ""
  moonbase_desc = moonbase ? first_p_in_range(moonbase + 1, section_end(moonbase)) : ""

  if (community_desc == "") community_desc = "Community announcements and project news written in src/news/."
  if (moonbase_desc == "") moonbase_desc = "Commits journal in the last 24 hours for the Moonbase repositories."

  print "<main class=\"page-main news-main\">"
  render_hero(title, desc, "news-compact-hero")

  render_news_section("Community and project news", community_desc, "content-section community-news-section", "{{ community_news_html }}", "{{ info_news_archive_actions_html }}")

  render_news_section("Moonbase commits journal", moonbase_desc, "content-section muted-section moonbase-section", "{{ moonbase_commits_html }}", "{{ info_commits_archive_actions_html }}")
  print "</main>"
}

function render_about(    s, e, why, expect, closing) {

  print "<main class=\"page-main\">"
  render_hero(first_h1(), first_p())

  render_content_grid(first_section(), 3)

  why = section_index("Why choose Lunar Linux?")
  if (why)
    render_feature_grid("Why choose Lunar Linux?",
                        why + 1,
                        section_end(why),
                        1)

  expect = section_index("What should you expect?")
  if (expect)
    render_split_section("What should you expect?",
                         expect + 1,
                         section_end(expect),
                         "content-section")

  for (s = first_section(); s; s = next_section_index(s)) {

    if (s == section_at(1)) continue
    if (s == section_at(2)) continue
    if (s == section_at(3)) continue

    if (s == why) continue
    if (s == expect) continue

    e = section_end(s)

    if (s == last_section() && !has_subsections(s + 1, e))
      render_closing_banner(val[s], s + 1, e, 1)
    else if (has_subsections(s + 1, e))
      render_feature_grid(val[s], s + 1, e, 1)
    else
      render_split_section(val[s], s + 1, e, "content-section")
  }

  print "</main>"
}

function render_docs(    title, desc, quote, simple, learning, links, tail, e, items, c, j, sec_end, before_sub) {
  title = first_h1()
  desc = first_p()
  quote = first_quote_in_range(1, first_section() ? first_section() - 1 : n)
  simple = section_at(1)
  learning = section_at(2)

  print "<main class=\"page-main\">"
  print "  <section class=\"docs-hero\">"
  print "    <div class=\"container docs-hero-grid\">"
  print "      <article class=\"docs-hero-main\">"
  print "        <h1>" inline(title) "</h1>"
  print "        <p class=\"hero-description\">" inline(desc) "</p>"
  print "      </article>"

  if (quote != "") {
    c = split_items(quote, items)
    print "      <aside class=\"quote-box docs-hero-quote\">"
    if (c >= 1) print "        <p>" inline(items[1]) "</p>"
    for (j = 2; j <= c; j++)
      print "        <span>" inline(items[j]) "</span>"
    print "      </aside>"
  }

  print "    </div>"
  print "    <div class=\"container docs-philosophy-row\">"

  if (simple) {
    print "      <article class=\"content-card philosophy-card\">"
    print "        <h2>" inline(val[simple]) "</h2>"
    render_blocks(simple + 1, section_end(simple), "        ", 1, 1)
    print "      </article>"
  }

  if (learning) {
    print "      <article class=\"content-card docs-learning-card\">"
    print "        <h2>" inline(val[learning]) "</h2>"
    render_blocks(learning + 1, section_end(learning), "        ", 1, 1)
    print "      </article>"
  }

  print "    </div>"

  if (learning) {
    links = first_links_in_range(learning + 1, section_end(learning))
    if (links != "") {
      print "    <div class=\"container\">"
      render_actions(links, "      ")
      print "    </div>"
    }
  }

  print "  </section>"

  for (tail = section_at(3); tail; tail = next_section_index(tail)) {
    e = section_end(tail)
    if (tail == last_section() && !has_subsections(tail + 1, e))
      render_closing_banner(val[tail], tail + 1, e, 1)
    else if (has_subsections(tail + 1, e))
      render_feature_grid(val[tail], tail + 1, e, 1)
    else
      render_split_section(val[tail], tail + 1, e, "content-section")
  }

  print "</main>"
}

function render_community(    built, contact, quote, links, e, tail, items, c, j) {
  print "<main class=\"page-main community-main\">"

  built = section_index("Built by people who use it")
  contact = section_index("Get in touch")

  if (built && contact) {
    quote = first_quote_in_range(built + 1, section_end(built))
    links = first_links_in_range(contact + 1, section_end(contact))

    print "  <section class=\"page-hero community-hero\">"
    print "    <div class=\"container community-hero-grid\">"

    print "      <article class=\"community-hero-copy\">"
    print "        <p class=\"meta-line\">Lunar Linux</p>"
    print "        <h1>" inline(first_h1()) "</h1>"
    print "        <p class=\"hero-description\">" inline(first_p()) "</p>"
    print "        <h2>" inline(val[built]) "</h2>"
    render_blocks(built + 1, section_end(built), "        ", 1, 1)
    print "      </article>"

    print "      <div class=\"community-right-column\">"

    if (quote != "") {
      c = split_items(quote, items)
      print "        <aside class=\"quote-box compact-quote\">"
      if (c >= 1) print "          <p>" inline(items[1]) "</p>"
      for (j = 2; j <= c; j++)
        print "          <span>" inline(items[j]) "</span>"
      print "        </aside>"
    }

    print "        <aside class=\"community-contact-card\">"
    print "          <img class=\"community-contact\" src=\"assets/images/man-typing-with-smartphone-silhouette-isolated.jpg\" alt=\"\">"
    print "          <h2>" inline(val[contact]) "</h2>"
    render_blocks(contact + 1, section_end(contact), "          ", 1, 1)
    if (links != "") render_actions(links, "          ")
    print "        </aside>"

    print "      </div>"
    print "    </div>"
    print "  </section>"
  }
  else {
    render_hero(first_h1(), first_p())
  }

  for (tail = first_section(); tail; tail = next_section_index(tail)) {
    if (val[tail] == "Built by people who use it" || val[tail] == "Get in touch") continue
    e = section_end(tail)

    if (tail == last_section() && !has_subsections(tail + 1, e))
      render_closing_banner(val[tail], tail + 1, e, 0)
    else if (has_subsections(tail + 1, e))
      render_feature_grid(val[tail], tail + 1, e, 1)
    else
      render_split_section(val[tail], tail + 1, e, "content-section")
  }

  print "</main>"
}

function render_development(    built, start, compact, links, tail, e, first_h3, h3_end) {
  print "<main class=\"page-main development-main\">"

  built = section_index("Built by contributors")
  start = section_index("Start here")

  if (built && start) {
    first_h3 = 0
    for (e = built + 1; e <= section_end(built); e++) {
      if (kind[e] == "h3") { first_h3 = e; break }
    }

    print "  <section class=\"page-hero development-hero-31\">"
    print "    <div class=\"container development-hero-grid\">"

    print "      <article class=\"development-hero-copy\">"
    print "        <p class=\"meta-line\">Lunar Linux</p>"
    print "        <h1>" inline(first_h1()) "</h1>"
    print "        <p class=\"hero-description\">" inline(first_p()) "</p>"
    print "        <h2>" inline(val[built]) "</h2>"
    if (first_h3)
      render_blocks(built + 1, first_h3 - 1, "        ", 0, 1)
    else
      render_blocks(built + 1, section_end(built), "        ", 0, 1)
    print "      </article>"

    print "      <div class=\"development-right-column\">"

    if (first_h3) {
      h3_end = next_h3_or_end(first_h3, section_end(built))
      print "        <article class=\"feature-card compact-card\">"
      print "          <h3>" inline(val[first_h3]) "</h3>"
      render_blocks(first_h3 + 1, h3_end, "          ", 0, 1)
      print "        </article>"
    }

    links = first_links_in_range(start + 1, section_end(start))
    print "        <aside class=\"download-card\">"
    print "          <h2>" inline(val[start]) "</h2>"
    render_blocks(start + 1, section_end(start), "          ", 1, 1)
    if (links != "") render_actions(links, "          ")
    print "        </aside>"

    print "      </div>"
    print "    </div>"
    print "  </section>"
  }
  else {
    render_hero(first_h1(), first_p())
  }

  for (tail = first_section(); tail; tail = next_section_index(tail)) {
    if (val[tail] == "Built by contributors" || val[tail] == "Start here") continue
    e = section_end(tail)

    if (tail == last_section() && !has_subsections(tail + 1, e))
      render_closing_banner(val[tail], tail + 1, e, 0)
    else if (has_subsections(tail + 1, e))
      render_feature_grid(val[tail], tail + 1, e, 1)
    else
      render_split_section(val[tail], tail + 1, e, "content-section")
  }

  print "</main>"
}

function render_lur(    crater, links) {
  print "<main class=\"page-main lur-main\">"
  render_hero(first_h1(), first_p())

  crater = section_index("Crater")
  if (crater) {
    links = first_links_in_range(crater + 1, section_end(crater))
    print "  <section class=\"content-section muted-section\">"
    print "    <div class=\"container\">"
    print "      <article class=\"content-card wide\">"
    print "        <h2>Crater</h2>"
    render_blocks(crater + 1, section_end(crater), "        ", 0, 1)
    if (links != "") render_actions(links, "        ")
    print "      </article>"
    print "    </div>"
    print "  </section>"
  }

  print "</main>"
}

function render_archive_explore(title, a, b,    i, nxt, links, firstcard) {
  print "  <section class=\"content-section muted-section archive-explore-section\">"
  print "    <div class=\"container\">"
  print "      <h2 id=\"" slug_id(title) "\" class=\"section-title\">" inline(title) "</h2>"

  firstcard = 0
  for (i = a; i <= b; i++) {
    if (kind[i] == "h3") { firstcard = i; break }
  }

  if (firstcard && firstcard > a)
    render_blocks(a, firstcard - 1, "      ", 1, 1)
  else if (!firstcard)
    render_blocks(a, b, "      ", 1, 1)

  print "      <div class=\"archive-explore-grid\">"

  for (i = a; i <= b; i++) {
    if (kind[i] != "h3") continue
    nxt = next_h3_or_end(i, b)
    links = first_links_in_range(i + 1, nxt)

    print "        <article class=\"archive-explore-card\">"
    print "          <h3>" inline(val[i]) "</h3>"
    render_blocks(i + 1, nxt, "          ", 1, 1)
    if (links != "") render_actions(links, "          ")
    print "        </article>"

    i = nxt
  }

  print "      </div>"
  print "    </div>"
  print "  </section>"
}

function render_news_archive() {
  print "<main class=\"page-main archive-main\">"
  render_hero(first_h1(), first_p())
  print "  <section class=\"content-section archive-section\">"
  print "    <div class=\"container\">"
  print "{{ archive_news_html }}"
  print "{{ archive_news_actions_html }}"
  print "    </div>"
  print "  </section>"
  print "</main>"
}

function render_commits_archive() {
  print "<main class=\"page-main archive-main\">"
  render_hero(first_h1(), first_p())
  print "  <section class=\"content-section muted-section archive-section\">"
  print "    <div class=\"container\">"
  print "{{ archive_commits_html }}"
  print "{{ archive_commits_actions_html }}"
  print "    </div>"
  print "  </section>"
  print "</main>"
}

function render_archive(    overview, toc, commits, news, docs, lur) {
  print "<main class=\"page-main archive-main\">"
  render_hero(first_h1(), first_p())

  overview = section_index("What the archive keeps")
  if (overview) render_feature_grid("What the archive keeps", overview + 1, section_end(overview), 0)

  toc = section_index("Table of contents")
  if (toc) render_archive_explore("Table of contents", toc + 1, section_end(toc))

  commits = section_index("Commit archive")
  print "  <section id=\"commit-archive\" class=\"content-section muted-section archive-section\">"
  print "    <div class=\"container\">"
  print "      <h2 class=\"section-title\">Commit archive</h2>"
  if (commits) render_blocks(commits + 1, section_end(commits), "      ", 0, 1)
  print "{{ archive_commits_html }}"
  print "      <div class=\"hero-actions archive-section-actions\">"
  print "        <a class=\"button primary\" href=\"archive/commits/\">View complete commit archive →</a>"
  print "      </div>"
  print "    </div>"
  print "  </section>"

  news = section_index("News archive")
  print "  <section id=\"news-archive\" class=\"content-section archive-section\">"
  print "    <div class=\"container\">"
  print "      <h2 class=\"section-title\">News archive</h2>"
  if (news) render_blocks(news + 1, section_end(news), "      ", 0, 1)
  print "{{ archive_news_html }}"
  print "      <div class=\"hero-actions archive-section-actions\">"
  print "        <a class=\"button primary\" href=\"archive/news/\">View complete news archive →</a>"
  print "      </div>"
  print "    </div>"
  print "  </section>"

  docs = section_index("Documentation archive")
  if (docs) {
    print "  <section id=\"documentation-archive\" class=\"content-section muted-section archive-section\">"
    print "    <div class=\"container\">"
    print "      <h2 class=\"section-title\">Documentation archive</h2>"
    render_blocks(docs + 1, section_end(docs), "      ", 0, 0)
    print "    </div>"
    print "  </section>"
  }

  lur = section_index("LUR archive")
  if (lur) {
    print "  <section id=\"lur-archive\" class=\"content-section archive-section\">"
    print "    <div class=\"container\">"
    print "      <h2 class=\"section-title\">LUR archive</h2>"
    render_blocks(lur + 1, section_end(lur), "      ", 0, 0)
    print "    </div>"
    print "  </section>"
  }

  print "</main>"
}

function render_generic(    s, e) {
  print "<main class=\"page-main\">"
  render_hero(first_h1(), first_p())

  for (s = first_section(); s; s = next_section_index(s)) {
    e = section_end(s)
    if (s == last_section() && !has_subsections(s + 1, e))
      render_closing_banner(val[s], s + 1, e, 0)
    else if (has_subsections(s + 1, e))
      render_feature_grid(val[s], s + 1, e, 1)
    else
      render_split_section(val[s], s + 1, e, "content-section")
  }

  print "</main>"
}

function trim(s) {
  sub(/^[[:space:]]+/, "", s)
  sub(/[[:space:]]+$/, "", s)
  return s
}

BEGIN {
  SEP = "\034"
  LINKSEP = "\035"
  in_fm = 0
  body = 1
}

NR == 1 && $0 == "---" {
  in_fm = 1
  body = 0
  next
}

in_fm && $0 == "---" {
  in_fm = 0
  body = 1
  next
}

in_fm {
  next
}

{
  lines[++ln] = $0
}

END {
  i = 1

  while (i <= ln) {
    line = lines[i]

    if (line ~ /^[[:space:]]*$/) {
      i++
      continue
    }

    if (line ~ /^# /) {
      add("h1", substr(line, 3))
      i++
      continue
    }

    if (line ~ /^## /) {
      add("h2", substr(line, 4))
      i++
      continue
    }

    if (line ~ /^### /) {
      add("h3", substr(line, 5))
      i++
      continue
    }

    if (line ~ /^#### /) {
      add("h4", substr(line, 6))
      i++
      continue
    }

    if (line ~ /^##### /) {
      add("h5", substr(line, 7))
      i++
      continue
    }

    if (line ~ /^###### /) {
      add("h6", substr(line, 8))
      i++
      continue
    }

    if (line ~ /^- /) {
      c = 0
      while (i <= ln && lines[i] ~ /^- /) {
        list[++c] = substr(lines[i], 3)
        i++
      }
      add("ul", join_lines(list, c))
      delete list
      continue
    }

    if (line ~ /^[0-9]+\. /) {
      c = 0
      while (i <= ln && lines[i] ~ /^[0-9]+\. /) {
        s = lines[i]
        sub(/^[0-9]+\. +/, "", s)
        list[++c] = s
        i++
      }
      add("ol", join_lines(list, c))
      delete list
      continue
    }

    if (line ~ /^> /) {
      c = 0
      while (i <= ln && lines[i] ~ /^> /) {
        list[++c] = substr(lines[i], 3)
        i++
      }
      add("quote", join_lines(list, c))
      delete list
      continue
    }

    if (line ~ /^```/) {
      code = ""
      i++

      while (i <= ln && lines[i] !~ /^```/) {
        code = code lines[i] "\n"
        i++
        if (i <= ln && lines[i] == "")
            i++
      }

      add("code", code)

      if (i <= ln)
        i++

      continue
    }

    if (line == "<!-- HTML_BLOCK_BEGIN -->" || line == "@@HTML") {
      html = ""
      i++

    while (i <= ln &&
      lines[i] != "<!-- HTML_BLOCK_END -->" &&
      lines[i] != "@@ENDHTML") {
        html = html lines[i] "\n"
        i++
      }

      add("html", html)

      if (i <= ln)
        i++

      continue
    }

    if (line ~ /^@@INCLUDE:.*@@$/) {
        file = line
        sub(/^@@INCLUDE:/, "", file)
        sub(/@@$/, "", file)

        html = ""

        path = project_root "/src/includes/" file

        # Defensive check of the path value (the file exists?)
        if ((getline inc < path) < 0) {
            html = "<!-- include not found: " file " -->"
        } else {
            do {
                html = html inc "\n"
            } while ((getline inc < path) > 0)
        }
        close(path)

        add("html", html)

        i++
        continue
    }

    if (line ~ /^\[/ && line ~ /\]\(/) {
      c = 0
      while (i <= ln && lines[i] ~ /^\[/ && lines[i] ~ /\]\(/) {
        s = lines[i]
        p1 = index(s, "](")
        label = substr(s, 2, p1 - 2)
        rest = substr(s, p1 + 2)
        p2 = index(rest, ")")
        url = substr(rest, 1, p2 - 1)
        list[++c] = label LINKSEP url
        i++
      }
      add("links", join_lines(list, c))
      delete list
      continue
    }

    para = trim(line)
    i++
    while (i <= ln && lines[i] !~ /^[[:space:]]*$/ && !is_block_start(lines[i])) {
      para = para " " trim(lines[i])
      i++
    }
    add("p", para)
  }

  if (page == "index") render_index()
  else if (page == "download") render_download()
  else if (page == "info") render_news()
  else if (page == "news-archive") render_news_archive()
  else if (page == "commits-archive") render_commits_archive()
  else if (page == "about") render_about()
  else if (page == "docs") render_docs()
  else if (page == "community") render_community()
  else if (page == "development") render_development()
  else if (page == "lur") render_lur()
  else if (page == "archive") render_archive()
  else render_generic()
}
' "$markdown_file"
