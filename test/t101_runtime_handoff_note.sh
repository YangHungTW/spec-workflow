#!/usr/bin/env bash
# test/t101_runtime_handoff_note.sh
#
# T121 — Verify that T113's RUNTIME HANDOFF line is present in STATUS.md.
#
# Three assertions:
#
#   A. STATUS.md contains a line matching 'RUNTIME HANDOFF' (case-sensitive).
#
#   B. That line contains the exact substring:
#        B2 control plane exercised on this feature's first live session
#
#   C. That line contains the substring:
#        .specaffold/archive/20260420-flow-monitor-control-plane/03-prd.md §9
#
# Expected state before T113 merges: all three assertions FAIL with clear
# diagnostics pointing to the missing line.  That is the intended red state;
# the test passes only after T113 is merged into the main feature branch.
#
# Sandbox-HOME NOT required: this test only runs grep/cat against the repo
# working tree and never invokes any CLI that expands or writes $HOME.
# (bash/sandbox-home-in-tests.md — explicitly exempt for read-only repo
# traversal scripts.)
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only
#   flags.  No `case` inside subshells (bash32-case-in-subshell.md).
set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

STATUS_FILE="$REPO_ROOT/.specaffold/features/20260420-flow-monitor-control-plane/STATUS.md"

# ---------------------------------------------------------------------------
# Preflight — STATUS.md must exist
# ---------------------------------------------------------------------------
if [ ! -f "$STATUS_FILE" ]; then
  printf 'FAIL: STATUS.md not found at %s\n' "$STATUS_FILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Test harness helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Read the file once; reuse for all three assertions
# (performance rule: no re-reading the same file)
# ---------------------------------------------------------------------------
STATUS_CONTENT="$(cat "$STATUS_FILE")"

# ---------------------------------------------------------------------------
# Extract the RUNTIME HANDOFF line (if any) for assertions B and C
# ---------------------------------------------------------------------------
HANDOFF_LINE="$(printf '%s\n' "$STATUS_CONTENT" | grep 'RUNTIME HANDOFF' || true)"

# ---------------------------------------------------------------------------
# A. STATUS.md contains a line matching 'RUNTIME HANDOFF'
# ---------------------------------------------------------------------------
printf '=== A: RUNTIME HANDOFF line present ===\n'

if [ -n "$HANDOFF_LINE" ]; then
  pass "A: RUNTIME HANDOFF line found in STATUS.md"
else
  fail "A: no line matching 'RUNTIME HANDOFF' found in $STATUS_FILE — T113 not yet merged"
fi

# ---------------------------------------------------------------------------
# B. The line contains the B2 control-plane exercise substring
# ---------------------------------------------------------------------------
printf '\n=== B: B2 control plane exercise substring ===\n'

B2_SUBSTRING="B2 control plane exercised on this feature's first live session"

if [ -n "$HANDOFF_LINE" ]; then
  # Use parameter expansion strip to check for substring — POSIX, no [[ =~ ]]
  _stripped="${HANDOFF_LINE#*$B2_SUBSTRING}"
  if [ "$_stripped" != "$HANDOFF_LINE" ]; then
    pass "B: line contains expected B2 exercise substring"
  else
    fail "B: RUNTIME HANDOFF line does not contain expected substring: $B2_SUBSTRING"
    printf '     actual line: %s\n' "$HANDOFF_LINE" >&2
  fi
else
  fail "B: cannot check substring — RUNTIME HANDOFF line absent (see assertion A)"
fi

# ---------------------------------------------------------------------------
# C. The line references the PRD §9 location
# ---------------------------------------------------------------------------
printf '\n=== C: PRD §9 reference present ===\n'

PRD_REF=".specaffold/archive/20260420-flow-monitor-control-plane/03-prd.md §9"

if [ -n "$HANDOFF_LINE" ]; then
  _stripped="${HANDOFF_LINE#*$PRD_REF}"
  if [ "$_stripped" != "$HANDOFF_LINE" ]; then
    pass "C: line references PRD §9 location as expected"
  else
    fail "C: RUNTIME HANDOFF line does not reference PRD location: $PRD_REF"
    printf '     actual line: %s\n' "$HANDOFF_LINE" >&2
  fi
else
  fail "C: cannot check PRD reference — RUNTIME HANDOFF line absent (see assertion A)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
