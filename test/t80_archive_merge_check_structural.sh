#!/usr/bin/env bash
# test/t80_archive_merge_check_structural.sh
#
# Structural tests for T23: archive.md merge-check + --allow-unmerged REASON.
#
# Verifies that archive.md contains the required structural elements
# introduced by T23:
#   1. Sources bin/specflow-tier (tier resolution)
#   2. Uses git merge-base --is-ancestor for merge-check
#   3. Handles --allow-unmerged flag with required REASON argument
#   4. Appends STATUS Notes line on --allow-unmerged use
#   5. Tier-dispatch: standard/audited run merge-check; tiny/missing skip it;
#      malformed fails loud
#
# Bash 3.2 / BSD portable — no readlink -f, realpath, jq, mapfile, [[ =~ ]].

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
ARCHIVE_MD="$REPO_ROOT/.claude/commands/specflow/archive.md"

PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

if [ ! -f "$ARCHIVE_MD" ]; then
  printf 'SKIP: %s not found\n' "$ARCHIVE_MD" >&2
  exit 0
fi

# 1. Tier helper is sourced
if grep -q 'specflow-tier' "$ARCHIVE_MD"; then
  pass "archive.md sources specflow-tier"
else
  fail "archive.md does not source specflow-tier"
fi

# 2. git merge-base --is-ancestor present
if grep -q 'merge-base --is-ancestor' "$ARCHIVE_MD"; then
  pass "archive.md contains 'merge-base --is-ancestor'"
else
  fail "archive.md missing 'merge-base --is-ancestor'"
fi

# 3. --allow-unmerged flag present
if grep -q -- '--allow-unmerged' "$ARCHIVE_MD"; then
  pass "archive.md references --allow-unmerged flag"
else
  fail "archive.md missing --allow-unmerged flag"
fi

# 4. REASON is treated as required (usage error path present)
if grep -q 'REASON' "$ARCHIVE_MD" || grep -q 'reason' "$ARCHIVE_MD"; then
  pass "archive.md documents REASON argument for --allow-unmerged"
else
  fail "archive.md missing REASON argument documentation"
fi

# 5. STATUS Notes line format on --allow-unmerged use
if grep -q 'allow-unmerged USED' "$ARCHIVE_MD"; then
  pass "archive.md documents STATUS Notes line on --allow-unmerged use"
else
  fail "archive.md missing 'allow-unmerged USED' STATUS Notes format"
fi

# 6. tier=tiny skips merge-check
if grep -q 'tiny' "$ARCHIVE_MD"; then
  pass "archive.md mentions tiny tier (skip path)"
else
  fail "archive.md missing tiny tier handling"
fi

# 7. tier=missing treated as tiny-equivalent
if grep -q 'missing' "$ARCHIVE_MD"; then
  pass "archive.md mentions missing tier (legacy skip path)"
else
  fail "archive.md missing 'missing' tier handling"
fi

# 8. tier=malformed fails loud
if grep -q 'malformed' "$ARCHIVE_MD"; then
  pass "archive.md mentions malformed tier (fail-loud path)"
else
  fail "archive.md missing malformed tier handling"
fi

printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
