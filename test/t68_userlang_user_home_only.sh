#!/usr/bin/env bash
# test/t68_userlang_user_home_only.sh — hook emits LANG_CHAT=zh-TW from user-home fallback
# R1 AC1.b; R4 AC4.b
# Fixture: no project-level .spec-workflow/config.yml; XDG_CONFIG_HOME unset;
# $HOME/.config/specflow/config.yml contains lang.chat: zh-TW.
# Assert: stdout contains LANG_CHAT=zh-TW; stderr empty; exit 0.

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
# 1. Build sandbox
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t68-test)"
trap 'rm -rf "$SANDBOX"' EXIT

# 2. Isolate HOME
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# 3. Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
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
# Set up consumer repo — no .spec-workflow/config.yml (project-level absent)
# Minimal .claude/rules/common/ so the hook reaches the config-sniff block.
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
mkdir -p "$CONSUMER/.claude/rules/common"

# Stub rule so the hook body runs rather than early-exiting on an empty rules dir
cat > "$CONSUMER/.claude/rules/common/stub-rule.md" <<'RULE'
---
name: stub-rule
scope: common
severity: must
created: 2026-04-19
updated: 2026-04-19
---

## Rule

Stub rule for test scaffolding only.

## Why

The hook requires a non-empty rules dir to reach the config-sniff block.

## How to apply

No-op.
RULE

# ---------------------------------------------------------------------------
# Set up user-home fallback config: $HOME/.config/specflow/config.yml
# Two-space indent under lang:, LF endings (printf — no trailing noise).
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.config/specflow"
printf 'lang:\n  chat: zh-TW\n' > "$HOME/.config/specflow/config.yml"

# XDG_CONFIG_HOME must be unset so only the tilde-fallback candidate fires.
unset XDG_CONFIG_HOME

# ---------------------------------------------------------------------------
# Invoke hook from consumer cwd (no .spec-workflow/config.yml present).
# Capture stdout and stderr separately.
# ---------------------------------------------------------------------------
STDERR_LOG="$SANDBOX/stderr.log"
JSON_OUT=$(cd "$CONSUMER" && "$HOOK" < /dev/null 2>"$STDERR_LOG")
RC=$?

# ---------------------------------------------------------------------------
# Check 1: hook exits 0 (AC4.b — session never blocked)
# ---------------------------------------------------------------------------
if [ "$RC" -eq 0 ]; then
  pass "Check 1: hook exits 0"
else
  fail "Check 1: hook exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stdout contains LANG_CHAT=zh-TW (AC1.b — user-home opt-in fires)
# ---------------------------------------------------------------------------
case "$JSON_OUT" in
  *LANG_CHAT=zh-TW*)
    pass "Check 2: stdout contains LANG_CHAT=zh-TW"
    ;;
  *)
    fail "Check 2: stdout does not contain LANG_CHAT=zh-TW (got: $JSON_OUT)"
    ;;
esac

# ---------------------------------------------------------------------------
# Check 3: stderr is empty (zh-TW is valid — no warning expected)
# ---------------------------------------------------------------------------
STDERR_CONTENT="$(cat "$STDERR_LOG")"
if [ -z "$STDERR_CONTENT" ]; then
  pass "Check 3: stderr is empty"
else
  fail "Check 3: stderr is not empty (got: $STDERR_CONTENT)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
