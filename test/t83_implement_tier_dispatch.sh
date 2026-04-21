#!/usr/bin/env bash
# test/t80_implement_md_security_perf_style.sh
#
# Structural grep tests for implement.md fixing the review findings from T21 retry:
#   1. Security-must: UPGRADE_TASK sanitised (case-match for [A-Za-z0-9._-]+ + max 64 chars).
#   2. Security-should: STATUS.md append uses backup-then-temp-then-mv pattern (backup noted).
#   3. Perf-should: single git diff --shortstat call (no separate --name-only call after BASE).
#   4. Style-should: step 1 code block uses 3-space interior indent (body lines have 3+3=6 spaces).
#
# Pure grep — no agent invocation, no mutation.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests rule, NON-NEGOTIABLE)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t80-implement-md)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
IMPL="$REPO_ROOT/.claude/commands/scaff/implement.md"

PASS=0
FAIL=0

check() {
  local desc="$1" result="$2"
  if [ "$result" = "0" ]; then
    printf 'PASS: %s\n' "$desc"
    PASS=$((PASS + 1))
  else
    printf 'FAIL: %s\n' "$desc"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# 1. Security-must: UPGRADE_TASK has sanitisation applied before use in set_tier
#    Expect: a case/grep/tr/sed stripping non-[A-Za-z0-9._-] characters present
#    near UPGRADE_TASK extraction.
# ---------------------------------------------------------------------------

# The sanitisation must appear: look for tr -cd restricting UPGRADE_TASK to safe chars.
grep -qE 'tr -cd.*A-Za-z0-9|UPGRADE_TASK.*tr' "$IMPL"
check "security-must: UPGRADE_TASK sanitisation (tr -cd [A-Za-z0-9._-]) present in implement.md" "$?"

# Must also have a length bound (cut or expr or ${var:0:64} or awk NR==1)
grep -qE '(cut -c1-64|UPGRADE_TASK.*:0:64|awk.*length|wc -c.*64)' "$IMPL"
check "security-must: UPGRADE_TASK length bound present in implement.md" "$?"

# ---------------------------------------------------------------------------
# 2. Security-should: STATUS.md append uses backup pattern
#    Expect: cp STATUS.md STATUS.md.bak (or backup note) before the >> append.
# ---------------------------------------------------------------------------
grep -q 'STATUS.md.bak' "$IMPL"
check "security-should: STATUS.md.bak backup reference in implement.md" "$?"

# ---------------------------------------------------------------------------
# 3. Perf-should: single git diff --shortstat call derives both counts
#    The old code called git diff --name-only AND git diff --shortstat separately.
#    After the fix there must be NO git diff --name-only call in the threshold block
#    (the single shortstat call replaces it).
# ---------------------------------------------------------------------------
# After the fix, --name-only must not appear in the threshold block.
# Use the full "Threshold check (D7" header to "Do NOT halt" range.
THRESHOLD_REGION="$(awk '/Threshold check .D7/,/Do NOT halt/' "$IMPL")"
# Exclude comment lines (# ...) from the check — comments may reference --name-only
# as a description of what was removed; only actual code calls matter.
printf '%s\n' "$THRESHOLD_REGION" | grep -v '^ *#' | grep -q '\-\-name-only'
NAME_ONLY_PRESENT="$?"
# We want name-only to NOT be present in non-comment code (exit 1 from grep = absent = good)
if [ "$NAME_ONLY_PRESENT" = "1" ]; then
  check "perf-should: no separate --name-only call in threshold block (non-comment)" "0"
else
  check "perf-should: no separate --name-only call in threshold block (non-comment)" "1"
fi

# Confirm --shortstat is present in threshold block
printf '%s\n' "$THRESHOLD_REGION" | grep -q '\-\-shortstat'
check "perf-should: --shortstat present in threshold block" "$?"

# And that both files count and lines count come from a single awk on shortstat
printf '%s\n' "$THRESHOLD_REGION" | grep -q 'diff_files.*awk\|awk.*diff_files\|shortstat.*awk.*files'
check "perf-should: diff_files derived via awk from shortstat in threshold block" "$?"

# ---------------------------------------------------------------------------
# 4. Style-should: step 1 code block interior uses 3-space indent
#    The if-body lines inside step 1's ```bash block should have 6 spaces
#    (3-space fence prefix + 3-space body indent).
#    Check that TASK_FILE assignment lines have exactly 6 leading spaces.
# ---------------------------------------------------------------------------
# Lines containing TASK_FILE= inside the bash fence should start with 6 spaces
TASK_FILE_INDENT="$(grep 'TASK_FILE=' "$IMPL" | head -2)"
# Each line should have >= 6 leading spaces
BAD_INDENT=0
while IFS= read -r line; do
  leading="${line%%[! ]*}"  # strip everything from first non-space
  len="${#leading}"
  if [ "$len" -lt 6 ]; then
    BAD_INDENT=1
  fi
done <<EOF
$TASK_FILE_INDENT
EOF
if [ "$BAD_INDENT" = "0" ]; then
  check "style-should: step 1 TASK_FILE lines have >=6 leading spaces (3+3 indent)" "0"
else
  check "style-should: step 1 TASK_FILE lines have >=6 leading spaces (3+3 indent)" "1"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
