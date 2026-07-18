#!/usr/bin/env python3
from pathlib import Path
import shutil
import sys

repo = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
path = repo / "tools/build-site.sh"
helper = repo / "tools/finalize-build-state.sh"
backup = repo / "tools/build-site.sh.before-phase4"

if not path.is_file():
    raise SystemExit(f"missing file: {path}")
if not helper.is_file():
    raise SystemExit(f"install helper first: {helper}")

text = path.read_text(encoding="utf-8")
original = text

if "STRICT_BUILD=${STRICT_BUILD:-no}" not in text:
    anchor = "STRICT_ARCHIVE=${STRICT_ARCHIVE:-no}\n"
    if anchor not in text:
        raise SystemExit("could not find STRICT_ARCHIVE setting")
    text = text.replace(anchor, anchor + "STRICT_BUILD=${STRICT_BUILD:-no}\n", 1)

if 'FINALIZE_BUILD_STATE="$TOOLS/finalize-build-state.sh"' not in text:
    anchor = 'ARCHIVE_LINKS_COMPONENT="$COMPONENTS/archive-links.sh"\n'
    if anchor not in text:
        raise SystemExit("could not find component path block")
    text = text.replace(
        anchor,
        anchor + 'FINALIZE_BUILD_STATE="$TOOLS/finalize-build-state.sh"\n',
        1,
    )

display_start = text.find('  if [ -f "$BUILD_REPORT_FILE" ]; then\n')
if display_start < 0:
    raise SystemExit("could not find final build-report display block")

strict_start = text.find(
    '  if [ "${archive_status:-skipped}" = "warning" ]',
    display_start,
)
if strict_start < 0:
    raise SystemExit("could not find final strict archive block")

strict_end = text.find("\n  fi\n", strict_start)
if strict_end < 0:
    raise SystemExit("could not find end of strict archive block")
strict_end += len("\n  fi\n")

new_tail = '''  phase4_status=0

  if [ -x "$FINALIZE_BUILD_STATE" ]; then
    if ! PROJECT_ROOT="$PROJECT_ROOT" \
      SRC="$SRC" \
      NEWS_SRC="$NEWS_SRC" \
      PUBLIC="$PUBLIC" \
      BUILD="$BUILD" \
      BUILD_REPORT_FILE="$BUILD_REPORT_FILE" \
      PAGE_SIGNATURE_DIR="$PAGE_SIGNATURE_DIR" \
      NEWS_SIGNATURE_DIR="${NEWS_SIGNATURE_DIR:-$BUILD/news-signatures}" \
      ARCHIVE_NEWS_SIGNATURE_DIR="${ARCHIVE_NEWS_SIGNATURE_DIR:-$BUILD/archive-news-signatures}" \
      STRICT_BUILD="$STRICT_BUILD" \
      "$FINALIZE_BUILD_STATE"
    then
      phase4_status=$?
    fi
  else
    printf 'build finalizer missing: %s\n' \
      "$(rel_from_project "$FINALIZE_BUILD_STATE")" >&2
    phase4_status=1
  fi

  if [ -f "$BUILD_REPORT_FILE" ]; then
    printf '\n'
    cat "$BUILD_REPORT_FILE"
  else
    printf 'build report missing: %s\n' \
      "$(rel_from_project "$BUILD_REPORT_FILE")" >&2
    phase4_status=1
  fi

  if [ "${archive_status:-skipped}" = "warning" ] &&
     [ "$STRICT_ARCHIVE" = "yes" ]; then
    printf 'STRICT_ARCHIVE=yes: failing after the active Website build completed.\n' >&2
    return 1
  fi

  if [ "$phase4_status" -ne 0 ]; then
    return "$phase4_status"
  fi
'''

text = text[:display_start] + new_tail + text[strict_end:]

if text == original:
    print("Phase 4 integration is already installed")
    raise SystemExit(0)

shutil.copy2(path, backup)
path.write_text(text, encoding="utf-8")

print(f"updated: {path}")
print(f"backup:  {backup}")
print("next:")
print("  sh -n tools/finalize-build-state.sh")
print("  sh -n tools/build-site.sh")
print("  ./build-site.sh")
print("  STRICT_BUILD=yes ./build-site.sh")
