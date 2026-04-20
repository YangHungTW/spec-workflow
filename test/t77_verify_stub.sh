#!/usr/bin/env bash
# test/t77_verify_stub.sh
#
# Structural assertion for T14: verify.md deprecation stub.
#
# Checks:
#   1. description: line starts with RETIRED (per D8 stub shape).
#   2. Body references /specflow:validate as the successor.
#   3. Body contains "No STATUS mutation occurs. Exits non-zero."
#
# Bash 3.2 / BSD portable — no readlink -f, realpath, jq, mapfile.
# No HOME mutation — no sandbox needed (read-only check).

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TARGET="$REPO_ROOT/.claude/commands/specflow/verify.md"

pass=0
fail=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "PASS: $desc"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc"
    fail=$((fail + 1))
  fi
}

# 1. File exists
[ -f "$TARGET" ]
check "verify.md exists" "$?"

# 2. description: starts with RETIRED
grep -q '^description: RETIRED' "$TARGET"
check "description: line starts with RETIRED" "$?"

# 3. References /specflow:validate as successor
grep -q '/specflow:validate' "$TARGET"
check "body references /specflow:validate" "$?"

# 4. Non-zero exit notice present
grep -q 'Exits non-zero' "$TARGET"
check "body contains 'Exits non-zero'" "$?"

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
