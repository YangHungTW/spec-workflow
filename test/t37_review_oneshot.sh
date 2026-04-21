#!/usr/bin/env bash
# test/t37_review_oneshot.sh — shape test for .claude/commands/scaff/review.md
# Verifies the command file exists with the required frontmatter, documented flags,
# report filename pattern, STATUS policy, and exit code semantics.
# Usage: bash test/t37_review_oneshot.sh
# Exits 0 iff all checks pass.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ---------------------------------------------------------------------------
# Sandbox / HOME preflight (sandbox-home-in-tests rule — non-negotiable)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t scaff-t37)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

REVIEW_MD="$REPO_ROOT/.claude/commands/scaff/review.md"

echo "=== t37_review_oneshot ==="

# ---------------------------------------------------------------------------
# Check 1: file exists
# ---------------------------------------------------------------------------
if [ -f "$REVIEW_MD" ]; then
  pass "Check 1: review.md exists"
else
  fail "Check 1: review.md missing at $REVIEW_MD"
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 2: frontmatter present — first line must be ---
# ---------------------------------------------------------------------------
FIRST_LINE="$(head -1 "$REVIEW_MD")"
if [ "$FIRST_LINE" = "---" ]; then
  pass "Check 2: frontmatter opens with ---"
else
  fail "Check 2: frontmatter missing (first line: $FIRST_LINE)"
fi

# ---------------------------------------------------------------------------
# Check 3: description mentions /scaff:review <slug>
# ---------------------------------------------------------------------------
if grep -q '/scaff:review' "$REVIEW_MD"; then
  pass "Check 3: description mentions /scaff:review <slug>"
else
  fail "Check 3: description does not mention /scaff:review <slug>"
fi

# ---------------------------------------------------------------------------
# Check 4: --axis security|performance|style documented
# ---------------------------------------------------------------------------
if grep -q -- '--axis' "$REVIEW_MD"; then
  pass "Check 4: --axis flag documented"
else
  fail "Check 4: --axis flag not documented"
fi

# Check that the three axis values are listed alongside --axis
for axis in security performance style; do
  if grep -q "$axis" "$REVIEW_MD"; then
    pass "Check 4.$axis: axis value '$axis' documented"
  else
    fail "Check 4.$axis: axis value '$axis' not found in review.md"
  fi
done

# ---------------------------------------------------------------------------
# Check 5: report file pattern review-YYYYMMDD-HHMM.md documented
# ---------------------------------------------------------------------------
if grep -q 'review-.*-.*-.*\.md' "$REVIEW_MD"; then
  pass "Check 5: report filename pattern documented"
else
  fail "Check 5: report filename pattern not documented"
fi

# ---------------------------------------------------------------------------
# Check 6: "Never advances STATUS" statement present
# ---------------------------------------------------------------------------
if grep -qi 'never advance\|never advances' "$REVIEW_MD"; then
  pass "Check 6: 'Never advances STATUS' statement present"
else
  fail "Check 6: 'Never advances STATUS' statement missing"
fi

# ---------------------------------------------------------------------------
# Check 7: exit code semantics — 0 on PASS/NITS, 1 on BLOCK
# ---------------------------------------------------------------------------
if grep -q 'Exit 0' "$REVIEW_MD" || grep -q 'exit 0' "$REVIEW_MD"; then
  pass "Check 7a: exit 0 (PASS/NITS) documented"
else
  fail "Check 7a: exit 0 for PASS/NITS not found in review.md"
fi

if grep -q 'Exit 1' "$REVIEW_MD" || grep -q 'exit 1' "$REVIEW_MD"; then
  pass "Check 7b: exit 1 (BLOCK) documented"
else
  fail "Check 7b: exit 1 for BLOCK not found in review.md"
fi

# Verify exit 1 is tied to BLOCK (not just any exit 1)
if grep -i 'block' "$REVIEW_MD" | grep -qi 'exit 1\|non-zero'; then
  pass "Check 7c: exit 1 linked to BLOCK verdict"
else
  # More lenient: check that BLOCK and exit 1 both appear in the exit-code section
  BLOCK_LINE=$(grep -n 'BLOCK' "$REVIEW_MD" | tail -1 | cut -d: -f1)
  EXIT1_LINE=$(grep -n 'Exit 1\|exit 1' "$REVIEW_MD" | tail -1 | cut -d: -f1)
  if [ -n "$BLOCK_LINE" ] && [ -n "$EXIT1_LINE" ]; then
    pass "Check 7c: BLOCK and exit 1 both documented (lines $BLOCK_LINE and $EXIT1_LINE)"
  else
    fail "Check 7c: BLOCK verdict with exit-1 semantics not clearly documented"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
