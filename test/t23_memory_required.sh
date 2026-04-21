#!/usr/bin/env bash
# test/t23_memory_required.sh — T20 verify: each agent core file has 3 required memory tokens
# Usage: bash test/t23_memory_required.sh
# Exits 0 iff all 7 role files contain all 3 required tokens.
#
# Required tokens per file:
#   1. ls ~/.claude/team-memory/<role>/
#   2. none apply because
#   3. dir not present:

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t agent-memory-test)"
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

# assert_token <role> <token_description> <grep_pattern>
assert_token() {
  local role="$1"
  local desc="$2"
  local pattern="$3"
  local file="$AGENTS_DIR/${role}.md"

  if [ ! -f "$file" ]; then
    fail "token[$role][$desc]: file not found: $file"
    return
  fi

  if grep -qF "$pattern" "$file"; then
    pass "token[$role][$desc]: found"
  else
    fail "token[$role][$desc]: NOT found (pattern: '$pattern')"
  fi
}

# ---------------------------------------------------------------------------
# Assertions for all 7 roles
# ---------------------------------------------------------------------------
ROLES="pm designer architect tpm developer qa-analyst qa-tester"

for role in $ROLES; do
  # Token 1: role-specific ls command
  assert_token "$role" "ls-team-memory" "ls ~/.claude/team-memory/${role}/"
  # Token 2: none apply because
  assert_token "$role" "none-apply-because" "none apply because"
  # Token 3: dir not present:
  assert_token "$role" "dir-not-present" "dir not present:"
done

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
