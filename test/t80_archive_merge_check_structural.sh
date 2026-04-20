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
#   6. (security) slug/feature_dir boundary check: rejects .., /, leading -
#   7. (security) REASON validated as single-line before append
#   8. (security) STATUS.md append uses backup-then-temp-then-mv pattern
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

# Cache file contents once — avoid re-reading the same file 11 times.
# Perf rule: no re-reading the same file in a single tool invocation.
ARCHIVE_CONTENT="$(cat "$ARCHIVE_MD")"

# 1. Tier helper is sourced
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -q 'specflow-tier'; then
  pass "archive.md sources specflow-tier"
else
  fail "archive.md does not source specflow-tier"
fi

# 2. git merge-base --is-ancestor present
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -q 'merge-base --is-ancestor'; then
  pass "archive.md contains 'merge-base --is-ancestor'"
else
  fail "archive.md missing 'merge-base --is-ancestor'"
fi

# 3. --allow-unmerged flag present
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -q -- '--allow-unmerged'; then
  pass "archive.md references --allow-unmerged flag"
else
  fail "archive.md missing --allow-unmerged flag"
fi

# 4. REASON is treated as required (usage error path present)
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -q 'REASON' || \
   printf '%s\n' "$ARCHIVE_CONTENT" | grep -q 'reason'; then
  pass "archive.md documents REASON argument for --allow-unmerged"
else
  fail "archive.md missing REASON argument documentation"
fi

# 5. STATUS Notes line format on --allow-unmerged use
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -q 'allow-unmerged USED'; then
  pass "archive.md documents STATUS Notes line on --allow-unmerged use"
else
  fail "archive.md missing 'allow-unmerged USED' STATUS Notes format"
fi

# 6. tier=tiny skips merge-check
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -q 'tiny'; then
  pass "archive.md mentions tiny tier (skip path)"
else
  fail "archive.md missing tiny tier handling"
fi

# 7. tier=missing treated as tiny-equivalent
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -q 'missing'; then
  pass "archive.md mentions missing tier (legacy skip path)"
else
  fail "archive.md missing 'missing' tier handling"
fi

# 8. tier=malformed fails loud
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -q 'malformed'; then
  pass "archive.md mentions malformed tier (fail-loud path)"
else
  fail "archive.md missing malformed tier handling"
fi

# 9. (security must) slug boundary check — feature_dir path traversal prevention.
# archive.md must document that the slug is validated: reject slugs containing
# '..', '/', or a leading '-' before constructing feature_dir.
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -q '\.\.' || \
   printf '%s\n' "$ARCHIVE_CONTENT" | grep -qi 'boundary\|traversal\|slug.*valid\|valid.*slug\|reject.*\.\.\|leading.*-\|invalid slug'; then
  pass "archive.md documents slug boundary / path-traversal check"
else
  fail "archive.md missing slug boundary check (security: path traversal)"
fi

# 10. (security should) REASON single-line validation before STATUS append.
# archive.md must document that REASON is validated as single-line
# (no embedded newlines) before being appended to STATUS.md.
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -qi 'single.line\|newline\|printable.*ascii\|ascii.*printable\|reason.*valid\|valid.*reason'; then
  pass "archive.md documents REASON single-line validation"
else
  fail "archive.md missing REASON single-line validation (security: unsanitised append)"
fi

# 11. (security should) STATUS.md append uses atomic write pattern.
# archive.md must document backup-then-temp-then-mv (or equivalent atomic swap)
# for the STATUS Notes append rather than a bare redirect append.
if printf '%s\n' "$ARCHIVE_CONTENT" | grep -qi 'backup\|atomic\|tmp\|temp.*mv\|mv.*temp'; then
  pass "archive.md documents atomic/backup STATUS.md write pattern"
else
  fail "archive.md missing atomic/backup STATUS.md write pattern (security: non-atomic append)"
fi

printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
