#!/usr/bin/env bash
# test/t55_hook_config_zh_tw.sh — hook emits LANG_CHAT=zh-TW when config opts in
# Creates a sandbox consumer repo with .specaffold/config.yml (lang.chat: zh-TW).
# Asserts: stdout contains LANG_CHAT=zh-TW; stderr empty; exit 0.

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t55-test)"
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
# Set up consumer directory with config.yml (D9 schema: lang.chat: zh-TW)
# and a minimal .claude/rules/common/ so the hook passes its early-exit guard.
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER/.specaffold"
mkdir -p "$CONSUMER/.claude/rules/common"

# Minimal valid rule so the hook does not exit early (rules dir must exist)
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

# Exact D9 schema — two-space indent under lang:, no quoting, no inline comment
cat > "$CONSUMER/.specaffold/config.yml" <<'CONFIG'
lang:
  chat: zh-TW
CONFIG

# ---------------------------------------------------------------------------
# Check 1: hook exits 0
# ---------------------------------------------------------------------------
STDERR_LOG="$SANDBOX/stderr.log"
JSON_OUT=$(cd "$CONSUMER" && "$HOOK" < /dev/null 2>"$STDERR_LOG")
RC=$?

if [ "$RC" -eq 0 ]; then
  pass "Check 1: hook exits 0"
else
  fail "Check 1: hook exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stdout contains LANG_CHAT=zh-TW
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
# Check 3: stderr is empty (recognised value — no warning)
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
