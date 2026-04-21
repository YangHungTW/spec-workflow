#!/usr/bin/env bash
set -u -o pipefail

SRC="${SPECFLOW_SRC:-}"
if [ -z "$SRC" ]; then
  echo "SPECFLOW_SRC not set; export it to the source-repo clone path" >&2
  exit 2
fi
[ -x "$SRC/bin/specflow-seed" ] || {
  echo "$SRC/bin/specflow-seed not found or not executable" >&2
  exit 2
}
exec "$SRC/bin/specflow-seed" "$@"
