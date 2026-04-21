#!/usr/bin/env bash
# test/t69_userlang_project_over_user.sh — project-level config wins over user-home
# R1 AC1.c (project wins over user-home file-level); R4 AC4.b.
# Assert: stdout contains LANG_CHAT=zh-TW; no LANG_CHAT=en; stderr empty; exit 0.

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t69-test)"
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
# Set up user-home config: lang.chat = en
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.config/scaff"
printf 'lang:\n  chat: en\n' > "$HOME/.config/scaff/config.yml"

# ---------------------------------------------------------------------------
# Set up project repo with .specaffold/config.yml: lang.chat = zh-TW
# and a minimal .claude/rules/common/ so the hook body is fully exercised.
# ---------------------------------------------------------------------------
REPO="$SANDBOX/repo"
mkdir -p "$REPO/.specaffold"
mkdir -p "$REPO/.claude/rules/common"

printf 'lang:\n  chat: zh-TW\n' > "$REPO/.specaffold/config.yml"

# Stub rule so the hook has a valid rules dir to digest
cat > "$REPO/.claude/rules/common/stub-rule.md" <<'RULE'
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

# Ensure XDG_CONFIG_HOME is unset so only the tilde-fallback path is used for
# the user-home candidate (D6: project slot wins over user-home slot).
unset XDG_CONFIG_HOME

# ---------------------------------------------------------------------------
# Invoke hook from inside the project repo; capture stdout and stderr.
# ---------------------------------------------------------------------------
STDERR_LOG="$SANDBOX/stderr.log"
JSON_OUT=$(cd "$REPO" && "$HOOK" < /dev/null 2>"$STDERR_LOG")
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
# Check 2: stdout contains LANG_CHAT=zh-TW (project-level wins)
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
# Check 3: stdout does NOT contain LANG_CHAT=en (user-home value not cascaded)
# ---------------------------------------------------------------------------
case "$JSON_OUT" in
  *LANG_CHAT=en*)
    fail "Check 3: stdout contains LANG_CHAT=en (user-home value must not leak)"
    ;;
  *)
    pass "Check 3: stdout has no LANG_CHAT=en"
    ;;
esac

# ---------------------------------------------------------------------------
# Check 4: stderr is empty
# ---------------------------------------------------------------------------
STDERR_CONTENT="$(cat "$STDERR_LOG")"
if [ -z "$STDERR_CONTENT" ]; then
  pass "Check 4: stderr is empty"
else
  fail "Check 4: stderr non-empty (got: $STDERR_CONTENT)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
