#!/bin/sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
COMPONENT="$PROJECT_ROOT/components/commit-journal.sh"

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

printf 'abc123\tother\tfoo & bar\tBump <version> & fix\t\n' > "$current_input"

cat > "$current_expected" <<'EOF_CURRENT'
      <div class="moonbase-journal">
        <table class="moonbase-table">
          <colgroup>
            <col class="moonbase-col-commit">
            <col class="moonbase-col-repository">
            <col class="moonbase-col-module">
            <col class="moonbase-col-comment">
          </colgroup>
          <thead>
            <tr>
              <th>Commit</th>
              <th>Repository</th>
              <th>Module</th>
              <th>Comment</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="commit-id"><a href="https://github.com/lunar-linux/moonbase-other/commit/abc123" target="_blank" rel="noopener">abc123</a></td>
              <td class="repository-name">other</td>
              <td class="module-name">foo &amp; bar</td>
              <td class="commit-comment">Bump &lt;version&gt; &amp; fix</td>
            </tr>
          </tbody>
        </table>
      </div>
EOF_CURRENT

COMMIT_JOURNAL_INDENT='      ' "$COMPONENT" current "$current_input" > "$current_actual"
assert_equal "$current_expected" "$current_actual" "current variant"

archive_input="$tmpdir/archive.tsv"
archive_expected="$tmpdir/archive.expected"
archive_actual="$tmpdir/archive.actual"

printf 'def456\tcore\tbash\tUpdate package\t2026-07-18 17:20\n' > "$archive_input"

cat > "$archive_expected" <<'EOF_ARCHIVE'
      <div class="moonbase-journal archive-journal">
        <table class="moonbase-table archive-commits-table">
          <thead><tr><th>Commit</th><th>Repository</th><th>Module</th><th>Comment</th></tr></thead>
          <tbody>
            <tr><td class="commit-id"><a href="https://github.com/lunar-linux/moonbase-core/commit/def456" target="_blank" rel="noopener" title="2026-07-18 17:20">def456</a></td><td class="repository-name">core</td><td class="module-name">bash</td><td class="commit-comment">Update package</td></tr>
          </tbody>
        </table>
      </div>
EOF_ARCHIVE

COMMIT_JOURNAL_INDENT='      ' "$COMPONENT" archive "$archive_input" > "$archive_actual"
assert_equal "$archive_expected" "$archive_actual" "archive variant"

empty="$tmpdir/empty.tsv"
: > "$empty"

COMMIT_JOURNAL_INDENT='      ' "$COMPONENT" current "$empty" > "$tmpdir/empty-current.html"
grep -q 'No Moonbase commits were found for the selected period.' "$tmpdir/empty-current.html" ||
  fail "current empty state"

COMMIT_JOURNAL_INDENT='      ' "$COMPONENT" archive "$empty" > "$tmpdir/empty-archive.html"
grep -q 'No archived commits were found.' "$tmpdir/empty-archive.html" ||
  fail "archive empty state"

if "$COMPONENT" invalid "$empty" > "$tmpdir/invalid.out" 2> "$tmpdir/invalid.err"; then
  fail "invalid variant succeeded"
fi
[ ! -s "$tmpdir/invalid.out" ] || fail "invalid variant emitted HTML"

if "$COMPONENT" current "$tmpdir/missing.tsv" > "$tmpdir/missing.out" 2> "$tmpdir/missing.err"; then
  fail "missing input succeeded"
fi
[ ! -s "$tmpdir/missing.out" ] || fail "missing input emitted HTML"

printf 'one\ttwo\tthree\n' > "$tmpdir/bad-fields.tsv"
if "$COMPONENT" current "$tmpdir/bad-fields.tsv" > "$tmpdir/bad.out" 2> "$tmpdir/bad.err"; then
  fail "malformed input succeeded"
fi
[ ! -s "$tmpdir/bad.out" ] || fail "malformed input emitted partial HTML"

printf '\trepo\tmodule\tsummary\t\n' > "$tmpdir/empty-required.tsv"
if "$COMPONENT" current "$tmpdir/empty-required.tsv" > "$tmpdir/empty-required.out" 2> "$tmpdir/empty-required.err"; then
  fail "empty required field succeeded"
fi
[ ! -s "$tmpdir/empty-required.out" ] || fail "empty required field emitted partial HTML"

printf 'a1\trepo\tFirst\tOne\t\nb2\trepo\tSecond\tTwo\t\n' > "$tmpdir/order.tsv"
"$COMPONENT" current "$tmpdir/order.tsv" > "$tmpdir/order.html"
first_line=$(grep -n '>First</td>' "$tmpdir/order.html" | cut -d: -f1)
second_line=$(grep -n '>Second</td>' "$tmpdir/order.html" | cut -d: -f1)
[ "$first_line" -lt "$second_line" ] || fail "input order was not preserved"

printf "a'1\trep&o\tmod<ule>\tsum\"mary\tdate'&\"\n" > "$tmpdir/escaping.tsv"
"$COMPONENT" archive "$tmpdir/escaping.tsv" > "$tmpdir/escaping.html"
grep -q 'moonbase-rep&amp;o/commit/a&#39;1' "$tmpdir/escaping.html" ||
  fail "URL attribute escaping"
grep -q 'title="date&#39;&amp;&quot;"' "$tmpdir/escaping.html" ||
  fail "title attribute escaping"
grep -q 'mod&lt;ule&gt;' "$tmpdir/escaping.html" ||
  fail "text escaping"

printf 'PASS: commit-journal component tests\n'
