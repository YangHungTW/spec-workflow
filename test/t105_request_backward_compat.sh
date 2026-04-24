#!/usr/bin/env bash
# test/t105_request_backward_compat.sh
#
# T14 — AC3 / AC15 / R15 backward-compat gate for /scaff:request
#
# Assertions:
#
#   A. request.md minimal-drift:
#      A.1 — grep -c 'work-type' request.md returns 1 or 2
#      A.2 — Probe anchors preserved: 'why now', 'success criteria',
#             'out-of-scope', 'has-ui'
#
#   B. prd-templates/feature.md canonical feature PRD headings present:
#      ## Problem, ## Goals, ## Non-goals, ## Requirements,
#      ## Acceptance criteria, ## Decisions, ## Open questions
#
#   C. pm.md /scaff:request section probe anchors preserved (AC15):
#      'why now', 'success criteria', 'out-of-scope', 'has-ui'
#
# Sandbox-HOME required per .claude/rules/bash/sandbox-home-in-tests.md:
#   this script does not invoke a CLI that writes $HOME, but the rule is
#   applied uniformly as a template discipline.
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only flags.
#   No `case` inside subshells (bash32-case-in-subshell.md).
set -euo pipefail

# ---------------------------------------------------------------------------
# Sandbox HOME — uniform discipline per sandbox-home-in-tests.md
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to proceed against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

REQUEST_MD="${REQUEST_MD:-$REPO_ROOT/.claude/commands/scaff/request.md}"
FEATURE_TEMPLATE_MD="${FEATURE_TEMPLATE_MD:-$REPO_ROOT/.specaffold/prd-templates/feature.md}"
PM_MD="${PM_MD:-$REPO_ROOT/.claude/agents/scaff/pm.md}"

# ---------------------------------------------------------------------------
# Test harness helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# assert_contains FILE LITERAL LABEL
# Checks that FILE contains LITERAL as a literal substring on at least one line.
assert_contains() {
  local file="$1"
  local literal="$2"
  local label="$3"
  local count
  count="$(grep -cF -- "$literal" "$file" 2>/dev/null || true)"
  if [ "${count:-0}" -ge 1 ]; then
    pass "$label present in $(basename "$file")"
  else
    fail "$label missing from $(basename "$file")"
  fi
}

# assert_heading FILE HEADING
# Checks that FILE contains at least one line matching "^## HEADING$".
assert_heading() {
  local file="$1"
  local heading="$2"
  local count
  count="$(grep -c "^## ${heading}$" "$file" 2>/dev/null || true)"
  if [ "${count:-0}" -ge 1 ]; then
    pass "heading '## ${heading}' present in $(basename "$file")"
  else
    fail "heading '## ${heading}' missing from $(basename "$file")"
  fi
}

# ---------------------------------------------------------------------------
# Preflight — source files must exist
# ---------------------------------------------------------------------------
for src_file in "$REQUEST_MD" "$FEATURE_TEMPLATE_MD" "$PM_MD"; do
  if [ ! -f "$src_file" ]; then
    printf 'FAIL: required file not found: %s\n' "$src_file" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# A. request.md — minimal-drift assertion
# ---------------------------------------------------------------------------
printf '=== A: request.md minimal-drift ===\n'

# A.1 — work-type count must be 1 or 2 (the sole permitted addition per T12)
WORK_TYPE_COUNT="$(grep -c 'work-type' "$REQUEST_MD" 2>/dev/null || true)"
if [ "$WORK_TYPE_COUNT" -ge 1 ] && [ "$WORK_TYPE_COUNT" -le 2 ]; then
  pass "request.md: work-type count is $WORK_TYPE_COUNT (allowed: 1-2)"
else
  fail "request.md: work-type count is $WORK_TYPE_COUNT (expected: 1 or 2)"
fi

# A.2 — Existing probe anchors preserved
for anchor in "why now" "success criteria" "out-of-scope" "has-ui"; do
  assert_contains "$REQUEST_MD" "$anchor" "request.md anchor '$anchor'"
done

# ---------------------------------------------------------------------------
# B. prd-templates/feature.md — canonical feature PRD headings present
# ---------------------------------------------------------------------------
printf '\n=== B: prd-templates/feature.md canonical headings ===\n'

for heading in "Problem" "Goals" "Non-goals" "Requirements" \
               "Acceptance criteria" "Decisions" "Open questions"; do
  assert_heading "$FEATURE_TEMPLATE_MD" "$heading"
done

# ---------------------------------------------------------------------------
# C. pm.md — /scaff:request section probe anchors preserved (AC15)
# ---------------------------------------------------------------------------
printf '\n=== C: pm.md request-section probe anchors ===\n'

for anchor in "why now" "success criteria" "out-of-scope" "has-ui"; do
  assert_contains "$PM_MD" "$anchor" "pm.md anchor '$anchor'"
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf 'PASS\n'
  exit 0
else
  exit 1
fi
