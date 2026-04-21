#!/usr/bin/env bash
# test/t21_agent_line_count.sh — T20 verify: non-empty line count <= R9b ceiling per agent
# Usage: bash test/t21_agent_line_count.sh
# Exits 0 iff all 7 role files meet their ceiling; exits 1 on any failure.
#
# Ceilings (R9b):
#   pm 22, designer 22, architect 37, tpm 44, developer 24, qa-analyst 21, qa-tester 23

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AGENTS_DIR="$REPO_ROOT/.claude/agents/scaff"

# ---------------------------------------------------------------------------
# Sandbox HOME (rule: sandbox-home-in-tests — even read-only scripts carry this)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t agent-line-count-test)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_line_count() {
  local role="$1"
  local ceiling="$2"
  local file="$AGENTS_DIR/${role}.md"

  if [ ! -f "$file" ]; then
    fail "line_count[$role]: file not found: $file"
    return
  fi

  local count
  count="$(grep -cv '^$' "$file")"

  if [ "$count" -le "$ceiling" ]; then
    pass "line_count[$role]: $count <= $ceiling"
  else
    fail "line_count[$role]: $count > $ceiling (ceiling is $ceiling)"
  fi
}

# ---------------------------------------------------------------------------
# Assertions — role ceiling table per R9b
# ---------------------------------------------------------------------------
assert_line_count "pm"          22
assert_line_count "designer"    22
assert_line_count "architect"   37
assert_line_count "tpm"         44
assert_line_count "developer"   24
assert_line_count "qa-analyst"  21
assert_line_count "qa-tester"   23

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  exit 1
fi
