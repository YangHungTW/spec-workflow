#!/usr/bin/env bash
# test/tN_validate_verdict_header.sh — T16 verdict footer header rename test
# Verifies qa-tester.md and qa-analyst.md use '## Validate verdict' (not
# '## Reviewer verdict') with the correct axis values per PRD R18 / tech §2.2.
# Pure grep — no agent invocation.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests rule, NON-NEGOTIABLE)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t79-validate-verdict)"
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
AGENTS_DIR="$REPO_ROOT/.claude/agents/scaff"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Check each qa agent for the correct verdict header and axis
# ---------------------------------------------------------------------------
check_validate_agent() {
  local role="$1"   # tester or analyst
  local file="$AGENTS_DIR/qa-${role}.md"

  if [ ! -f "$file" ]; then
    fail "${role}: agent file missing: $file"
    return
  fi
  pass "${role}: agent file exists"

  local content
  content="$(cat "$file")"

  # 1. Must contain '## Validate verdict'
  count="$(printf '%s\n' "$content" | grep -c '^## Validate verdict' || true)"
  if [ "$count" -ge 1 ]; then
    pass "${role}: ## Validate verdict present"
  else
    fail "${role}: ## Validate verdict missing (required by PRD R18)"
  fi

  # 2. Must NOT contain '## Reviewer verdict'
  if printf '%s\n' "$content" | grep -q '^## Reviewer verdict'; then
    fail "${role}: ## Reviewer verdict still present — must be renamed"
  else
    pass "${role}: ## Reviewer verdict absent (correct)"
  fi

  # 3. Must have correct axis value
  if printf '%s\n' "$content" | grep -q "^axis: ${role}"; then
    pass "${role}: axis: ${role} present"
  else
    fail "${role}: axis: ${role} missing or wrong"
  fi

  # 4. Must have verdict shape
  if printf '%s\n' "$content" | grep -q 'verdict: PASS | NITS | BLOCK'; then
    pass "${role}: verdict shape present"
  else
    fail "${role}: verdict: PASS | NITS | BLOCK shape missing"
  fi
}

check_validate_agent "tester"
check_validate_agent "analyst"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
