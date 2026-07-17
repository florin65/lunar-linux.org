#!/bin/sh

# =========================================================
# Generate Moonbase git logs for recent commits
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
BUILD_DIR=${BUILD_DIR:-cache}
MOONBASE_DIR=${MOONBASE_DIR:-../moonbase}
MOONBASE_LOG_DIR=${MOONBASE_LOG_DIR:-$BUILD_DIR/moonbase-logs}
MOONBASE_REPOS=${MOONBASE_REPOS:-core efl kde other xfce xorg gnome3 gnome}
MOONBASE_LOG_DAYS=${MOONBASE_LOG_DAYS:-1}
UPDATE_MOONBASE_REPOS=${UPDATE_MOONBASE_REPOS:-no}

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

MOONBASE=$(abs_path "$MOONBASE_DIR")
LOG_DIR=$(abs_path "$MOONBASE_LOG_DIR")
LOG_PARENT=$(dirname -- "$LOG_DIR")
STAGED_LOG_DIR=
BACKUP_LOG_DIR=

cleanup() {
  [ -n "$STAGED_LOG_DIR" ] && rm -rf "$STAGED_LOG_DIR"
  [ -n "$BACKUP_LOG_DIR" ] && rm -rf "$BACKUP_LOG_DIR"
}

trap cleanup EXIT HUP INT TERM

if [ ! -d "$MOONBASE" ]; then
  printf 'missing moonbase directory: %s\n' "$MOONBASE" >&2
  exit 1
fi

mkdir -p "$LOG_PARENT"
STAGED_LOG_DIR=$(mktemp -d "$LOG_PARENT/.moonbase-logs.XXXXXX")

SINCE_DATE=$(date -d "$MOONBASE_LOG_DAYS day ago" +%F)
UNTIL_DATE=$(date +%F)

for repo in $MOONBASE_REPOS; do
  repo_dir="$MOONBASE/$repo"

  if [ ! -d "$repo_dir/.git" ]; then
    printf 'missing configured Moonbase repository: %s\n' \
      "$repo_dir" >&2
    exit 1
  fi

  (
    cd "$repo_dir"

    branch=$(git symbolic-ref --short HEAD 2>/dev/null || printf 'unknown')

    if [ "$branch" != "master" ]; then
      printf 'unexpected branch for %s: %s\n' "$repo" "$branch" >&2
      exit 1
    fi

    if [ "$UPDATE_MOONBASE_REPOS" = "yes" ]; then
      printf 'updating %s\n' "$repo" >&2
      git config pull.rebase false
      git pull "https://github.com/lunar-linux/moonbase-$repo"
    fi

    tmp="$STAGED_LOG_DIR/$repo.log.tmp"

    git log \
      --no-merges \
      --since="$SINCE_DATE 00:00:00" \
      --until="$UNTIL_DATE 00:00:00" \
      --pretty=format:'%ad|%h|%s' \
      --date=short > "$tmp"

    if [ -s "$tmp" ]; then
      mv "$tmp" "$STAGED_LOG_DIR/$repo.log"
    else
      rm -f "$tmp"
    fi
  )
done

if [ -e "$LOG_DIR" ]; then
  BACKUP_LOG_DIR=$(mktemp -d "$LOG_PARENT/.moonbase-logs-backup.XXXXXX")
  rmdir "$BACKUP_LOG_DIR"

  if ! mv "$LOG_DIR" "$BACKUP_LOG_DIR"; then
    printf 'could not preserve current Moonbase log directory: %s\n' \
      "$LOG_DIR" >&2
    exit 1
  fi
fi

if ! mv "$STAGED_LOG_DIR" "$LOG_DIR"; then
  printf 'could not publish Moonbase log directory: %s\n' "$LOG_DIR" >&2

  if [ -n "$BACKUP_LOG_DIR" ] && [ -e "$BACKUP_LOG_DIR" ]; then
    mv "$BACKUP_LOG_DIR" "$LOG_DIR" || true
    BACKUP_LOG_DIR=
  fi

  exit 1
fi

STAGED_LOG_DIR=

if [ -n "$BACKUP_LOG_DIR" ]; then
  rm -rf "$BACKUP_LOG_DIR"
  BACKUP_LOG_DIR=
fi

find "$LOG_DIR" -type f -name '*.log' | sort | while IFS= read -r log; do
  printf 'generated %s\n' "$(rel_from_project "$log")"
done
