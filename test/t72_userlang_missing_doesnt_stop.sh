#!/usr/bin/env bash
# test/t72_userlang_missing_doesnt_stop.sh — absent candidates don't terminate walk
# R4 AC4.c: missing file is silent and does NOT stop iteration.
# Fixture: no project config, XDG unset, tilde fallback has lang.chat: zh-TW.
# Asserts: stdout contains LANG_CHAT=zh-TW (walk reaches 3rd candidate);
#          stderr is empty (absent files produce no warning); exit 0.

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t72-test)"
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
# Fixture — XDG unset so candidate 2 is skipped by the env gate.
# No .specaffold/config.yml (candidate 1 absent).
# Tilde fallback (candidate 3) present with lang.chat: zh-TW.
# Iteration must walk past 2 absent paths and find the third.
# ---------------------------------------------------------------------------
unset XDG_CONFIG_HOME

CONSUMER="$SANDBOX/repo"
mkdir -p "$CONSUMER"

# Stub rules dir so the hook reaches the config-sniff block rather than
# logging "no valid rules found" and returning before it.
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

# Tilde fallback — the only candidate file present
mkdir -p "$HOME/.config/scaff"
printf 'lang:\n  chat: zh-TW\n' > "$HOME/.config/scaff/config.yml"

# ---------------------------------------------------------------------------
# Invoke hook from consumer cwd; capture stdout and stderr separately.
# ---------------------------------------------------------------------------
STDERR_FILE="$SANDBOX/stderr.txt"
JSON_OUT=$(cd "$CONSUMER" && "$HOOK" < /dev/null 2>"$STDERR_FILE")
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
# Check 2: stdout contains LANG_CHAT=zh-TW (walk reached candidate 3)
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
# Check 3: stderr is empty (absent files produce no warning — AC4.c)
# ---------------------------------------------------------------------------
STDERR_CONTENT="$(cat "$STDERR_FILE")"
if [ -z "$STDERR_CONTENT" ]; then
  pass "Check 3: stderr is empty (absent candidates silent)"
else
  fail "Check 3: stderr is not empty (got: $STDERR_CONTENT)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
