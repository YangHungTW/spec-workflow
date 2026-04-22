#!/usr/bin/env bash
# test/t76_agent_color_frontmatter.sh — T3: assert color: frontmatter invariants
# on the 10 scaff agent core files (non-appendix).
#
# AC1: All 10 non-appendix files have exactly one ^color: line each; total = 10.
# AC2: Every color value is in {red, blue, green, yellow, purple, orange, pink, cyan}.
# AC3: The 3 reviewer-*.md files all have color: red; the 7 non-reviewer files
#      have 7 distinct non-red values.
# AC5: No *.appendix.md file under .claude/agents/scaff/ carries a ^color: line.
#
# Usage: bash test/t76_agent_color_frontmatter.sh
# Exits 0 on all assertions pass; non-zero with FAIL: message otherwise.

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this test file
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AGENTS_DIR="$REPO_ROOT/.claude/agents/scaff"

# ---------------------------------------------------------------------------
# Sandbox HOME — template discipline (sandbox-home-in-tests); read-only script.
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t agent-color-test)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# The 10 non-appendix agent core files (explicit list, no glob, no subshell loop).
# Space-separated — none of these filenames contain spaces.
# ---------------------------------------------------------------------------
CORE_FILES="$AGENTS_DIR/pm.md \
$AGENTS_DIR/architect.md \
$AGENTS_DIR/tpm.md \
$AGENTS_DIR/developer.md \
$AGENTS_DIR/designer.md \
$AGENTS_DIR/qa-analyst.md \
$AGENTS_DIR/qa-tester.md \
$AGENTS_DIR/reviewer-security.md \
$AGENTS_DIR/reviewer-performance.md \
$AGENTS_DIR/reviewer-style.md"

# Reviewer subset
REVIEWER_FILES="$AGENTS_DIR/reviewer-security.md \
$AGENTS_DIR/reviewer-performance.md \
$AGENTS_DIR/reviewer-style.md"

# Non-reviewer subset
NON_REVIEWER_FILES="$AGENTS_DIR/pm.md \
$AGENTS_DIR/architect.md \
$AGENTS_DIR/tpm.md \
$AGENTS_DIR/developer.md \
$AGENTS_DIR/designer.md \
$AGENTS_DIR/qa-analyst.md \
$AGENTS_DIR/qa-tester.md"

# Allowed palette values
ALLOWED_COLORS="red blue green yellow purple orange pink cyan"

# ---------------------------------------------------------------------------
# Batch grep: read all color: lines from all 10 core files in one invocation.
# Produces lines of the form: <filepath>:color: <value>
# ---------------------------------------------------------------------------
# shellcheck disable=SC2086
ALL_COLOR_LINES="$(grep -h '^color:' $CORE_FILES 2>/dev/null || true)"

# ---------------------------------------------------------------------------
# AC1: total count of color: lines must be exactly 10.
# ---------------------------------------------------------------------------
total_count="$(printf '%s\n' "$ALL_COLOR_LINES" | grep -c '^color:' || true)"
# Trim BSD leading spaces from wc -l output
total_count="$(printf '%s' "$total_count" | tr -d ' ')"

if [ "$total_count" -eq 10 ]; then
  pass "AC1: total color: line count = $total_count (expected 10)"
else
  fail "AC1: total color: line count = $total_count (expected 10)"
fi

# ---------------------------------------------------------------------------
# AC2: every color value must be in the allowed palette.
# Extract distinct values via awk (one awk invocation); validate each via case.
# ---------------------------------------------------------------------------
# awk extracts the second field (the color value) from "color: <value>" lines.
DISTINCT_VALS="$(printf '%s\n' "$ALL_COLOR_LINES" | awk '{print $2}' | sort -u)"

ac2_ok=1
for val in $DISTINCT_VALS; do
  found=0
  for allowed in $ALLOWED_COLORS; do
    if [ "$val" = "$allowed" ]; then
      found=1
      break
    fi
  done
  if [ "$found" -eq 0 ]; then
    fail "AC2: color value '$val' is not in allowed palette {$ALLOWED_COLORS}"
    ac2_ok=0
  fi
done
if [ "$ac2_ok" -eq 1 ]; then
  pass "AC2: all color values are within the allowed palette"
fi

# ---------------------------------------------------------------------------
# AC3a: all 3 reviewer files have color: red.
# One grep invocation across the 3 reviewer files.
# ---------------------------------------------------------------------------
# shellcheck disable=SC2086
REVIEWER_COLOR_LINES="$(grep -h '^color:' $REVIEWER_FILES 2>/dev/null || true)"
reviewer_count="$(printf '%s\n' "$REVIEWER_COLOR_LINES" | grep -c '^color:' || true)"
reviewer_count="$(printf '%s' "$reviewer_count" | tr -d ' ')"
reviewer_red_count="$(printf '%s\n' "$REVIEWER_COLOR_LINES" | grep -c '^color: red$' || true)"
reviewer_red_count="$(printf '%s' "$reviewer_red_count" | tr -d ' ')"

if [ "$reviewer_count" -eq 3 ] && [ "$reviewer_red_count" -eq 3 ]; then
  pass "AC3a: all 3 reviewer files have color: red"
else
  fail "AC3a: reviewer files: $reviewer_red_count of $reviewer_count have color: red (expected 3 of 3)"
fi

# ---------------------------------------------------------------------------
# AC3b: the 7 non-reviewer files have 7 distinct non-red values.
# One grep invocation; awk + sort -u to count distinct non-red values.
# ---------------------------------------------------------------------------
# shellcheck disable=SC2086
NON_REVIEWER_COLOR_LINES="$(grep -h '^color:' $NON_REVIEWER_FILES 2>/dev/null || true)"
non_reviewer_count="$(printf '%s\n' "$NON_REVIEWER_COLOR_LINES" | grep -c '^color:' || true)"
non_reviewer_count="$(printf '%s' "$non_reviewer_count" | tr -d ' ')"

# Extract values, filter out red, count distinct
non_red_distinct="$(printf '%s\n' "$NON_REVIEWER_COLOR_LINES" | awk '{print $2}' | grep -v '^red$' | sort -u | wc -l | tr -d ' ')"

# Also verify none of the non-reviewer values is red
non_reviewer_red_count="$(printf '%s\n' "$NON_REVIEWER_COLOR_LINES" | grep -c '^color: red$' || true)"
non_reviewer_red_count="$(printf '%s' "$non_reviewer_red_count" | tr -d ' ')"

if [ "$non_reviewer_count" -eq 7 ] && [ "$non_reviewer_red_count" -eq 0 ] && [ "$non_red_distinct" -eq 7 ]; then
  pass "AC3b: 7 non-reviewer files have 7 distinct non-red color values"
else
  fail "AC3b: non-reviewer files: count=$non_reviewer_count red=$non_reviewer_red_count distinct_non_red=$non_red_distinct (expected 7 files, 0 red, 7 distinct)"
fi

# ---------------------------------------------------------------------------
# AC5: no *.appendix.md file carries a ^color: line.
# Single grep invocation with -l to list matching files (if any).
# ---------------------------------------------------------------------------
appendix_hits="$(grep -l '^color:' "$AGENTS_DIR"/*.appendix.md 2>/dev/null || true)"
if [ -z "$appendix_hits" ]; then
  pass "AC5: no *.appendix.md file carries a color: line"
else
  fail "AC5: the following appendix files unexpectedly carry color: — $appendix_hits"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  exit 1
fi
