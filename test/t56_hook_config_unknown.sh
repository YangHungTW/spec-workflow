#!/usr/bin/env bash
# test/t56_hook_config_unknown.sh — unknown lang.chat value → warning + default-off
#
# Requirements: R7 (AC7.a)
# Decisions: D7 (unknown value → one stderr warning + default-off)
#
# Config under test:
#   lang:
#     chat: fr
#
# Assertions:
#   1. Stdout does NOT contain LANG_CHAT=
#   2. Stderr has exactly one warning line mentioning lang.chat AND the value fr
#   3. Exit code 0

set -u

# ---------------------------------------------------------------------------
# Locate hook relative to this test file — survives worktree moves (memory:
# test-script-path-convention)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
HOOK="$REPO_ROOT/.claude/hooks/session-start.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (mandatory per sandbox-home-in-tests rule)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t56-test)"
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
  fail "setup: hook not executable: $HOOK"
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# Setup: minimal consumer dir with config.yml containing unknown lang.chat
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER/.claude/rules/common"
mkdir -p "$CONSUMER/.specaffold"

cat > "$CONSUMER/.specaffold/config.yml" <<'YAML'
lang:
  chat: fr
YAML

# Provide a minimal valid rule so the hook produces a non-empty digest
# (ensures the stdout assertion is not trivially vacuous).
# Rule body deliberately avoids the marker string so stdout check is unambiguous.
cat > "$CONSUMER/.claude/rules/common/language-preferences.md" <<'RULE'
---
name: language-preferences
scope: common
severity: should
created: 2026-04-19
updated: 2026-04-19
---

## Rule

Honour the language preference declared in config; otherwise this rule is a no-op.

## Why

Centralised preference keeps all roles consistent.

## How to apply

Check for the chat marker in the additional-context payload.
RULE

# ---------------------------------------------------------------------------
# Execute hook from the consumer directory; capture stdout and stderr
# ---------------------------------------------------------------------------
STDOUT_FILE="$SANDBOX/stdout.log"
STDERR_FILE="$SANDBOX/stderr.log"

RC=0
cd "$CONSUMER" && "$HOOK" < /dev/null > "$STDOUT_FILE" 2>"$STDERR_FILE" || RC=$?

# ---------------------------------------------------------------------------
# Check 1: exit code must be 0 (hook never blocks session start)
# ---------------------------------------------------------------------------
if [ "$RC" -eq 0 ]; then
  pass "Check 1: hook exited 0"
else
  fail "Check 1: hook exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stdout must NOT contain LANG_CHAT= (unknown value → default-off)
# ---------------------------------------------------------------------------
if grep -q 'LANG_CHAT=' "$STDOUT_FILE" 2>/dev/null; then
  fail "Check 2: stdout contains LANG_CHAT= (should not — fr is unknown)"
else
  pass "Check 2: stdout has no LANG_CHAT= line"
fi

# ---------------------------------------------------------------------------
# Check 3: stderr must contain exactly one line mentioning lang.chat
# The log_warn format is:
#   session-start.sh: WARN: config.yml: lang.chat has unknown value 'fr' — ignored
# grep -c counts matching lines; exactly 1 is required.
# ---------------------------------------------------------------------------
WARN_COUNT=$(grep -c 'lang\.chat' "$STDERR_FILE" 2>/dev/null || echo "0")
if [ "$WARN_COUNT" -eq 1 ]; then
  pass "Check 3: stderr has exactly 1 line mentioning lang.chat (count: $WARN_COUNT)"
else
  fail "Check 3: stderr lang.chat line count $WARN_COUNT (expected 1) — stderr: $(cat "$STDERR_FILE")"
fi

# ---------------------------------------------------------------------------
# Check 4: that warning line also mentions the invalid value fr
# ---------------------------------------------------------------------------
if grep -q 'lang\.chat' "$STDERR_FILE" 2>/dev/null && grep 'lang\.chat' "$STDERR_FILE" | grep -q 'fr'; then
  pass "Check 4: warning line mentions the invalid value 'fr'"
else
  fail "Check 4: warning line does not mention 'fr' — stderr: $(cat "$STDERR_FILE")"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
