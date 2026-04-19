#!/usr/bin/env bash
# test/t71_userlang_stop_on_first_invalid.sh — D6 stop-on-first-hit when project value is invalid
#
# Requirements: R4 AC4.a (reworded — stop-on-first-hit-even-invalid), R4 AC4.b
# Decisions: D6 (stop-on-first-hit — the load-bearing semantic of this feature),
#            D4 (warning message names $cfg_source)
#
# Fixture:
#   project-level .spec-workflow/config.yml → chat: fr  (INVALID — outside {zh-TW, en})
#   user-home ~/.config/specflow/config.yml  → chat: zh-TW (VALID)
#
# Assertions per AC4.a (reworded, verbatim anchor):
#   1. Exit code 0  (AC4.b — session never blocked)
#   2. Stdout has NO LANG_CHAT= substring at all
#      (stop-on-first-hit: project held the key and was invalid → default-off;
#       user's valid zh-TW is NOT consulted)
#   3. Stderr has exactly ONE line mentioning .spec-workflow/config.yml
#   4. That warning line also mentions the invalid value fr
#   5. Stderr has NO mention of zh-TW (confirms user-home value was never read)
#   6. Stderr has NO mention of the user-home path (confirms iteration stopped)

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t71-test)"
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
# Setup: consumer dir with project-level config containing INVALID chat value
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER/.claude/rules/common"
mkdir -p "$CONSUMER/.spec-workflow"

# Project-level: chat: fr (invalid — outside {zh-TW, en})
printf 'lang:\n  chat: fr\n' > "$CONSUMER/.spec-workflow/config.yml"

# User-home: chat: zh-TW (valid — but must NOT be consulted; stop-on-first-hit)
mkdir -p "$HOME/.config/specflow"
printf 'lang:\n  chat: zh-TW\n' > "$HOME/.config/specflow/config.yml"

# Unset XDG so only project-level and tilde candidates are in play
unset XDG_CONFIG_HOME

# Provide a minimal valid rule so the hook produces a non-empty digest
# (ensures the stdout assertion is not trivially vacuous)
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
# Check 1: exit code must be 0 (AC4.b — session never blocked)
# ---------------------------------------------------------------------------
if [ "$RC" -eq 0 ]; then
  pass "Check 1: hook exited 0"
else
  fail "Check 1: hook exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stdout must contain NO LANG_CHAT= substring at all
# (stop-on-first-hit: project held the key, value was invalid → default-off;
#  user-home's valid zh-TW is not consulted)
# ---------------------------------------------------------------------------
if grep -q 'LANG_CHAT=' "$STDOUT_FILE" 2>/dev/null; then
  fail "Check 2: stdout contains LANG_CHAT= (must not — project's fr terminates walk; default-off)"
else
  pass "Check 2: stdout has no LANG_CHAT= line (default-off as required)"
fi

# ---------------------------------------------------------------------------
# Check 3: stderr must contain exactly one line mentioning .spec-workflow/config.yml
# The D7 log_warn format is:
#   session-start.sh: WARN: .spec-workflow/config.yml: lang.chat has unknown value 'fr' — ignored
# grep -c counts matching lines; exactly 1 is required.
# ---------------------------------------------------------------------------
PROJ_WARN_COUNT=$(grep -c '\.spec-workflow/config\.yml' "$STDERR_FILE" 2>/dev/null || echo "0")
if [ "$PROJ_WARN_COUNT" -eq 1 ]; then
  pass "Check 3: stderr has exactly 1 line mentioning .spec-workflow/config.yml (count: $PROJ_WARN_COUNT)"
else
  fail "Check 3: .spec-workflow/config.yml mention count $PROJ_WARN_COUNT (expected 1) — stderr: $(cat "$STDERR_FILE")"
fi

# ---------------------------------------------------------------------------
# Check 4: that same warning line also mentions the invalid value fr
# ---------------------------------------------------------------------------
if grep '\.spec-workflow/config\.yml' "$STDERR_FILE" 2>/dev/null | grep -q "'fr'"; then
  pass "Check 4: warning line mentions the invalid value 'fr'"
else
  fail "Check 4: warning line does not mention 'fr' — stderr: $(cat "$STDERR_FILE")"
fi

# ---------------------------------------------------------------------------
# Check 5: stderr must NOT mention zh-TW (confirms user-home value never read)
# ---------------------------------------------------------------------------
if grep -q 'zh-TW' "$STDERR_FILE" 2>/dev/null; then
  fail "Check 5: stderr mentions zh-TW (must not — user-home was not consulted)"
else
  pass "Check 5: stderr has no mention of zh-TW (user-home not consulted)"
fi

# ---------------------------------------------------------------------------
# Check 6: stderr must NOT mention the user-home config path (iteration stopped)
# ---------------------------------------------------------------------------
if grep -q '\.config/specflow/config\.yml' "$STDERR_FILE" 2>/dev/null; then
  fail "Check 6: stderr mentions user-home path (must not — iteration stopped at project)"
else
  pass "Check 6: stderr has no mention of user-home path (stop-on-first-hit confirmed)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
