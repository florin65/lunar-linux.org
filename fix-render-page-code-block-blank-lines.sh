#!/bin/sh

set -eu

TARGET=${1:-tools/render-page.sh}

if [ ! -f "$TARGET" ]; then
  printf 'missing target file: %s\n' "$TARGET" >&2
  exit 1
fi

python3 - "$TARGET" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

old = '''      while (i <= ln && lines[i] !~ /^```/) {
        code = code lines[i] "\n"
        i++
        if (i <= ln && lines[i] == "")
            i++
      }
'''

new = '''      while (i <= ln && lines[i] !~ /^```/) {
        code = code lines[i] "\n"
        i++
      }
'''

if text.count(old) != 1:
    raise SystemExit(
        "expected fenced code parser block was not found exactly once; "
        "target left unchanged"
    )

path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY

sh -n "$TARGET"

printf 'updated %s\n' "$TARGET"
