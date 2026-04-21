#!/usr/bin/env bash
set -u -o pipefail

SRC="${SCAFF_SRC:-}"
if [ -z "$SRC" ]; then
  echo "SCAFF_SRC not set; export it to the source-repo clone path" >&2
  exit 2
fi
[ -x "$SRC/bin/scaff-seed" ] || {
  echo "$SRC/bin/scaff-seed not found or not executable" >&2
  exit 2
}
exec "$SRC/bin/scaff-seed" "$@"
