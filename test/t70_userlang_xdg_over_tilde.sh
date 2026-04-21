#!/usr/bin/env bash
# test/t70_userlang_xdg_over_tilde.sh — XDG config wins over simple-tilde fallback
# R1 AC1.d (XDG wins over tilde when both present); R4 AC4.b (exit 0).
# Assert: stdout contains LANG_CHAT=zh-TW; stderr clean; exit 0.

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t70-test)"
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
# Fixture: XDG config has zh-TW; tilde fallback has en.
# No .specaffold/config.yml (project candidate absent).
# XDG wins over tilde because it appears earlier in the candidate list.
# ---------------------------------------------------------------------------
export XDG_CONFIG_HOME="$SANDBOX/xdg"
mkdir -p "$XDG_CONFIG_HOME/scaff"
printf 'lang:\n  chat: zh-TW\n' > "$XDG_CONFIG_HOME/scaff/config.yml"

mkdir -p "$HOME/.config/scaff"
printf 'lang:\n  chat: en\n' > "$HOME/.config/scaff/config.yml"

# Consumer repo directory — no .specaffold/config.yml present (project absent)
CONSUMER="$SANDBOX/repo"
mkdir -p "$CONSUMER"

# Minimal .claude/rules/common so the hook reaches the config-sniff block
# rather than early-exiting on a missing rules dir.
mkdir -p "$CONSUMER/.claude/rules/common"
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
# Invoke hook from consumer cwd; capture stdout and stderr separately.
# ---------------------------------------------------------------------------
STDERR_LOG="$SANDBOX/stderr.log"
JSON_OUT=$(cd "$CONSUMER" && "$HOOK" < /dev/null 2>"$STDERR_LOG")
RC=$?

# ---------------------------------------------------------------------------
# Check 1: hook exits 0
# ---------------------------------------------------------------------------
if [ "$RC" -eq 0 ]; then
  pass "Check 1: hook exits 0"
else
  fail "Check 1: hook exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stdout contains LANG_CHAT=zh-TW (XDG wins)
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
# Check 3: stdout does NOT contain LANG_CHAT=en (tilde not consulted)
# ---------------------------------------------------------------------------
case "$JSON_OUT" in
  *LANG_CHAT=en*)
    fail "Check 3: stdout contains LANG_CHAT=en (tilde was consulted — XDG should have stopped iteration)"
    ;;
  *)
    pass "Check 3: stdout does not contain LANG_CHAT=en"
    ;;
esac

# ---------------------------------------------------------------------------
# Check 4: stderr is empty (zh-TW is a recognised value — no warning)
# ---------------------------------------------------------------------------
STDERR_CONTENT="$(cat "$STDERR_LOG")"
if [ -z "$STDERR_CONTENT" ]; then
  pass "Check 4: stderr is empty"
else
  fail "Check 4: stderr is not empty (got: $STDERR_CONTENT)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
