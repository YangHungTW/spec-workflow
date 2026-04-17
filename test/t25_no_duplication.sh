#!/usr/bin/env bash
# test/t25_no_duplication.sh — T21: verify cross-role content is not duplicated in agent files
# After T17 remediation, grep for content that now lives in .claude/rules/ should
# return zero hits across all agent .md files.
# Usage: bash test/t25_no_duplication.sh
# Exits 0 iff all checks pass (zero hits).

set -u

# ---------------------------------------------------------------------------
# Locate repo root relative to this test file
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AGENTS_DIR="$REPO_ROOT/.claude/agents/specflow"

# ---------------------------------------------------------------------------
# Sandbox / HOME isolation (sandbox-home-in-tests discipline)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t25-test)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Dedup checks: each pattern should return zero matching files
# Patterns sourced from AC-no-duplication and T17 audit keyword set.
# ---------------------------------------------------------------------------

# Check 1: readlink -f / readlink -- / realpath (bash-32-portability rule)
HITS="$(grep -lE 'readlink -f|readlink --|realpath' "$AGENTS_DIR"/*.md 2>/dev/null)"
if [ -z "$HITS" ]; then
  pass "Check 1: no agent files contain readlink -f / readlink -- / realpath"
else
  fail "Check 1: agent files still contain readlink/realpath references: $HITS"
fi

# Check 2: --force (no-force-on-user-paths rule)
# Exclude rule-name back-references (lines that only mention the rule file name)
HITS="$(grep -lE '(^|[^-])--force' "$AGENTS_DIR"/*.md 2>/dev/null)"
if [ -z "$HITS" ]; then
  pass "Check 2: no agent files contain --force"
else
  fail "Check 2: agent files still contain --force references: $HITS"
fi

# Check 3: sandbox-HOME / mktemp -d.*HOME (sandbox-home-in-tests rule)
HITS="$(grep -lE 'sandbox-HOME|mktemp -d.*HOME' "$AGENTS_DIR"/*.md 2>/dev/null)"
if [ -z "$HITS" ]; then
  pass "Check 3: no agent files contain sandbox-HOME / mktemp -d.*HOME"
else
  fail "Check 3: agent files still contain sandbox-HOME references: $HITS"
fi

# Check 4: classification before mutation / classify-before-mutate prose
# (classify-before-mutate rule)
HITS="$(grep -lE 'classification before mutation' "$AGENTS_DIR"/*.md 2>/dev/null)"
if [ -z "$HITS" ]; then
  pass "Check 4: no agent files contain 'classification before mutation' prose"
else
  fail "Check 4: agent files still contain classification-before-mutation prose: $HITS"
fi

# Check 5: absolute symlink / absolute-symlink-targets inline guidance
HITS="$(grep -lE 'absolute symlink targets|absolute-symlink-targets' "$AGENTS_DIR"/*.md 2>/dev/null)"
if [ -z "$HITS" ]; then
  pass "Check 5: no agent files contain absolute symlink targets inline guidance"
else
  fail "Check 5: agent files still contain absolute symlink guidance: $HITS"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
