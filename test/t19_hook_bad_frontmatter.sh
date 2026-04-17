#!/usr/bin/env bash
# test/t19_hook_bad_frontmatter.sh — bad-frontmatter rule skipped with WARN
# Creates a sandbox rules dir with one valid rule + one bad-frontmatter file.
# Invokes session-start.sh from the sandbox (so RULES_DIR=".claude/rules" resolves there).
# Asserts: exit 0, valid rules digested, bad rule logged as WARN and skipped.

set -u

# ---------------------------------------------------------------------------
# Locate repo root relative to this test file
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
HOOK="$REPO_ROOT/.claude/hooks/session-start.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (discipline per sandbox-home-in-tests rule)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t19-test)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Sanity: hook must exist and be executable
# ---------------------------------------------------------------------------
if [ ! -x "$HOOK" ]; then
  fail "hook not executable: $HOOK"
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# Setup: build sandbox .claude/rules with one valid + one bad-frontmatter rule
# ---------------------------------------------------------------------------
WORKDIR="$SANDBOX/work"
RULES_COMMON="$WORKDIR/.claude/rules/common"
mkdir -p "$RULES_COMMON"

# Valid rule file
cat > "$RULES_COMMON/good-rule.md" <<'RULE'
---
name: good-rule
scope: common
severity: must
created: 2026-04-17
updated: 2026-04-17
---

## Rule

Always do the right thing.

## Why

Because it matters.

## How to apply

Just do it.
RULE

# Bad frontmatter — missing required keys (no 'name', 'scope', etc.)
cat > "$RULES_COMMON/bad-rule.md" <<'RULE'
This file has no frontmatter at all.
Just plain prose with no YAML fences.
RULE

# ---------------------------------------------------------------------------
# Check 1: hook exits 0 with bad frontmatter present
# ---------------------------------------------------------------------------
STDERR_FILE="$SANDBOX/stderr.txt"
JSON_OUT=$(cd "$WORKDIR" && "$HOOK" < /dev/null 2>"$STDERR_FILE")
RC=$?
if [ "$RC" -eq 0 ]; then
  pass "Check 1: hook exits 0 despite bad-frontmatter file"
else
  fail "Check 1: hook exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stdout is valid JSON
# ---------------------------------------------------------------------------
if python3 -c "import json,sys; json.loads(sys.argv[1])" "$JSON_OUT" 2>/dev/null; then
  pass "Check 2: stdout is valid JSON"
else
  fail "Check 2: stdout is not valid JSON (got: $JSON_OUT)"
fi

# ---------------------------------------------------------------------------
# Check 3: additionalContext contains the valid rule name
# ---------------------------------------------------------------------------
CONTEXT=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d.get('hookSpecificOutput', {}).get('additionalContext', ''))
" "$JSON_OUT" 2>/dev/null)
case "$CONTEXT" in
  *good-rule*)
    pass "Check 3: additionalContext contains good-rule"
    ;;
  *)
    fail "Check 3: additionalContext missing good-rule (got: $CONTEXT)"
    ;;
esac

# ---------------------------------------------------------------------------
# Check 4: additionalContext does NOT contain the bad rule file's content
# (bad-rule has no valid digest — it should be skipped)
# ---------------------------------------------------------------------------
case "$CONTEXT" in
  *bad-rule*)
    fail "Check 4: bad-rule appeared in additionalContext (should be skipped)"
    ;;
  *)
    pass "Check 4: bad-rule correctly absent from additionalContext"
    ;;
esac

# ---------------------------------------------------------------------------
# Check 5: stderr contains a WARN mentioning the bad rule file
# ---------------------------------------------------------------------------
WARN_LINE=$(grep 'WARN' "$STDERR_FILE" | grep 'bad-rule' 2>/dev/null || true)
if [ -n "$WARN_LINE" ]; then
  pass "Check 5: stderr WARN logged for bad-rule.md"
else
  fail "Check 5: expected WARN for bad-rule.md in stderr (got: $(cat "$STDERR_FILE"))"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
