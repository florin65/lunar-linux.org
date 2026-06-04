#!/bin/sh

# Serve the generated public/ tree directly.
# This avoids broken relative links when index.html is opened through
# the root-level symlink.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PORT="${1:-8001}"

cd "$ROOT/public"
printf 'Serving %s on http://localhost:%s/\n' "$PWD" "$PORT"
exec python3 -m http.server "$PORT"
