#!/usr/bin/env bash
# test/t57_hook_config_malformed.sh — AC7.b: malformed config.yml → fail-safe default-off
# Sandbox config with syntactically broken YAML; hook must not emit LANG_CHAT=,
# must not crash, and must exit 0 (session never blocked on malformed config).

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t57-test)"
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
# Setup: sandbox consumer with broken YAML config + minimal rules dir
# (a real rules dir avoids a rules-dir-missing WARN that would pollute
#  the stderr assertion — we only want to observe the config parse path)
# ---------------------------------------------------------------------------
WORKDIR="$SANDBOX/consumer"
mkdir -p "$WORKDIR/.specaffold"
mkdir -p "$WORKDIR/.claude/rules/common"

# Broken YAML: no colon after lang, no indent hierarchy, garbage line.
# The awk sniff in the hook is narrow — this produces empty cfg_chat,
# so the hook takes the silent "" branch. Both the silent branch and
# the warn branch satisfy AC7.b as long as exit is 0 and no marker is emitted.
cat > "$WORKDIR/.specaffold/config.yml" <<'YAML'
lang
  chat zh-TW
:::garbage:::
YAML

# Minimal valid rule so the hook has something to digest (avoids noise WARN)
cat > "$WORKDIR/.claude/rules/common/stub-rule.md" <<'RULE'
---
name: stub-rule
scope: common
severity: must
created: 2026-04-19
updated: 2026-04-19
---

## Rule

Stub rule for test isolation.

## Why

Keeps the hook digest non-empty without real rules.

## How to apply

No-op.
RULE

# ---------------------------------------------------------------------------
# Run hook; capture stdout and stderr separately
# ---------------------------------------------------------------------------
STDOUT_FILE="$SANDBOX/stdout.txt"
STDERR_FILE="$SANDBOX/stderr.txt"

cd "$WORKDIR" && "$HOOK" < /dev/null > "$STDOUT_FILE" 2>"$STDERR_FILE"
RC=$?

STDOUT_CONTENT="$(cat "$STDOUT_FILE")"

# ---------------------------------------------------------------------------
# Check 1: exit code is 0 (fail-safe — session never blocked)
# ---------------------------------------------------------------------------
if [ "$RC" -eq 0 ]; then
  pass "Check 1: hook exits 0 on malformed config"
else
  fail "Check 1: hook exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stdout does NOT contain LANG_CHAT= (default-off preserved)
# ---------------------------------------------------------------------------
case "$STDOUT_CONTENT" in
  *LANG_CHAT=*)
    fail "Check 2: stdout contains LANG_CHAT= despite malformed config"
    ;;
  *)
    pass "Check 2: stdout does not contain LANG_CHAT= (default-off preserved)"
    ;;
esac

# ---------------------------------------------------------------------------
# Check 3: stderr has at most one warning line (accept silent OR single-warn)
# ---------------------------------------------------------------------------
STDERR_LINES=$(awk 'END{print NR}' "$STDERR_FILE" 2>/dev/null)
if [ "$STDERR_LINES" -le 1 ]; then
  pass "Check 3: stderr has at most one line (count: $STDERR_LINES)"
else
  fail "Check 3: stderr has $STDERR_LINES lines (expected 0 or 1; got: $(cat "$STDERR_FILE"))"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
