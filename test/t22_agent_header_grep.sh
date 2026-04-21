#!/usr/bin/env bash
# test/t22_agent_header_grep.sh — T20 verify: each agent core file has required D10 headers
# Usage: bash test/t22_agent_header_grep.sh
# Exits 0 iff all 7 role files contain all required headers in correct order.
#
# Required headers (D10 six-block template):
#   frontmatter (--- block) → "You are the" → ## Team memory →
#   ## When invoked → ## Output contract → ## Rules

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t agent-header-test)"
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

# assert_header_present <role> <header_pattern>
# Checks that the grep pattern exists in the file
assert_header_present() {
  local role="$1"
  local pattern="$2"
  local file="$AGENTS_DIR/${role}.md"

  if grep -q "$pattern" "$file" 2>/dev/null; then
    pass "header[$role]: '$pattern' found"
  else
    fail "header[$role]: '$pattern' NOT found"
  fi
}

# assert_header_order <role>
# Uses awk to verify ordering:
#   1. frontmatter close (---) after line 1
#   2. "You are the" after frontmatter
#   3. ## Team memory after "You are the"
#   4. ## When invoked after ## Team memory
#   5. ## Output contract after ## When invoked
#   6. ## Rules after ## Output contract
assert_header_order() {
  local role="$1"
  local file="$AGENTS_DIR/${role}.md"

  if [ ! -f "$file" ]; then
    fail "order[$role]: file not found: $file"
    return
  fi

  # awk walks the file and records line numbers for each landmark
  # then checks they appear in increasing order
  local result
  result="$(awk '
    BEGIN {
      fm_close=0; fm_count=0; identity=0;
      team_mem=0; when_invoked=0; output_contract=0; rules=0;
    }
    /^---$/ {
      fm_count++
      if (fm_count == 2) fm_close = NR
      next
    }
    /^You are the/ && identity == 0 { identity = NR }
    /^## Team memory/ && team_mem == 0 { team_mem = NR }
    /^## When invoked/ && when_invoked == 0 { when_invoked = NR }
    /^## Output contract/ && output_contract == 0 { output_contract = NR }
    /^## Rules/ && rules == 0 { rules = NR }
    END {
      ok = 1
      if (fm_close == 0)       { print "missing-frontmatter-close"; ok=0 }
      if (identity == 0)       { print "missing-identity-line"; ok=0 }
      if (team_mem == 0)       { print "missing-team-memory"; ok=0 }
      if (when_invoked == 0)   { print "missing-when-invoked"; ok=0 }
      if (output_contract == 0){ print "missing-output-contract"; ok=0 }
      if (rules == 0)          { print "missing-rules"; ok=0 }
      if (ok) {
        # check ordering
        if (fm_close >= identity)        { print "frontmatter-after-identity"; ok=0 }
        if (identity >= team_mem)        { print "identity-after-team-memory"; ok=0 }
        if (team_mem >= when_invoked)    { print "team-memory-after-when-invoked"; ok=0 }
        if (when_invoked >= output_contract) { print "when-invoked-after-output-contract"; ok=0 }
        if (output_contract >= rules)    { print "output-contract-after-rules"; ok=0 }
      }
      if (ok) print "OK"
    }
  ' "$file")"

  if [ "$result" = "OK" ]; then
    pass "order[$role]: all 6 blocks present and correctly ordered"
  else
    fail "order[$role]: $result"
  fi
}

# ---------------------------------------------------------------------------
# Run checks for all 7 roles
# ---------------------------------------------------------------------------
ROLES="pm designer architect tpm developer qa-analyst qa-tester"

for role in $ROLES; do
  assert_header_order "$role"
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
