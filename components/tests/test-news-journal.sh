#!/bin/sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
COMPONENT="$PROJECT_ROOT/components/news-journal.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_equal() {
  expected=$1
  actual=$2
  label=$3

  if ! cmp -s "$expected" "$actual"; then
    printf 'FAIL: %s\n' "$label" >&2
    diff -u "$expected" "$actual" >&2 || true
    exit 1
  fi
}

[ -x "$COMPONENT" ] || fail "component is not executable: $COMPONENT"

current_input="$tmpdir/current.tsv"
current_expected="$tmpdir/current.expected"
current_actual="$tmpdir/current.actual"

printf '2026-07-18 17:20\t2026-07-18T17:20\tProject & Team\tWebsite <3.3> released\tnews/release.html?x=1&y=2\tA concise & useful summary.\n' > "$current_input"

cat > "$current_expected" <<'EOF_CURRENT'
      <div class="community-news-journal">
        <table class="community-news-table compact-news-table">
          <colgroup>
            <col class="community-news-col-meta">
            <col class="community-news-col-content">
          </colgroup>
          <thead>
            <tr>
              <th>Date</th>
              <th>News</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="news-meta">
                <time datetime="2026-07-18T17:20">2026-07-18 17:20</time>
                <span>Project &amp; Team</span>
              </td>
              <td class="news-content">
                <a class="news-title-link" href="news/release.html?x=1&amp;y=2">Website &lt;3.3&gt; released</a>
                <p>A concise &amp; useful summary.</p>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
EOF_CURRENT

NEWS_JOURNAL_INDENT='      ' "$COMPONENT" current "$current_input" > "$current_actual"
assert_equal "$current_expected" "$current_actual" "current variant"

archive_input="$tmpdir/archive.tsv"
archive_expected="$tmpdir/archive.expected"
archive_actual="$tmpdir/archive.actual"

printf '2026-07-18 17:20\t2026-07-18T17:20\tProject\tWebsite 3.3 released\tarchive/news/2026/07/release.html\t030d0b5bb42c\n' > "$archive_input"

cat > "$archive_expected" <<'EOF_ARCHIVE'
      <div class="community-news-journal archive-journal">
        <table class="community-news-table archive-news-table">
          <thead><tr><th>Date</th><th>News</th></tr></thead>
          <tbody>
            <tr>
              <td class="news-meta"><time datetime="2026-07-18T17:20">2026-07-18 17:20</time><span>Project</span></td>
              <td class="news-content"><a class="news-title-link" href="archive/news/2026/07/release.html">Website 3.3 released</a><p>Archive id: <code>030d0b5bb42c</code></p></td>
            </tr>
          </tbody>
        </table>
      </div>
EOF_ARCHIVE

NEWS_JOURNAL_INDENT='      ' "$COMPONENT" archive "$archive_input" > "$archive_actual"
assert_equal "$archive_expected" "$archive_actual" "archive variant"

empty="$tmpdir/empty.tsv"
: > "$empty"

NEWS_JOURNAL_INDENT='      ' "$COMPONENT" current "$empty" > "$tmpdir/empty-current.actual"
grep -q 'No valid community or project news entries were found.' "$tmpdir/empty-current.actual" || fail "current empty state"

NEWS_JOURNAL_INDENT='      ' "$COMPONENT" archive "$empty" > "$tmpdir/empty-archive.actual"
grep -q 'No valid archived news entries were found.' "$tmpdir/empty-archive.actual" || fail "archive empty state"

if "$COMPONENT" invalid "$empty" > "$tmpdir/invalid.out" 2> "$tmpdir/invalid.err"; then
  fail "invalid variant succeeded"
fi
[ ! -s "$tmpdir/invalid.out" ] || fail "invalid variant emitted HTML"

printf 'one\ttwo\tthree\n' > "$tmpdir/bad-fields.tsv"
if "$COMPONENT" current "$tmpdir/bad-fields.tsv" > "$tmpdir/bad.out" 2> "$tmpdir/bad.err"; then
  fail "malformed input succeeded"
fi
[ ! -s "$tmpdir/bad.out" ] || fail "malformed input emitted partial HTML"

printf '2026-01-02\t2026-01-02\tA\tFirst\tfirst.html\tOne\n2026-01-01\t2026-01-01\tB\tSecond\tsecond.html\tTwo\n' > "$tmpdir/order.tsv"
"$COMPONENT" current "$tmpdir/order.tsv" > "$tmpdir/order.html"
first_line=$(grep -n '>First</a>' "$tmpdir/order.html" | cut -d: -f1)
second_line=$(grep -n '>Second</a>' "$tmpdir/order.html" | cut -d: -f1)
[ "$first_line" -lt "$second_line" ] || fail "input order was not preserved"

printf 'PASS: news-journal component tests\n'
