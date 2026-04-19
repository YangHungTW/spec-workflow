#!/usr/bin/env bash
# test/t54_hook_config_absent.sh — hook silent when config missing
# R1 AC1.a, AC1.c; R7 AC7.c
# Assert: when .spec-workflow/config.yml is absent, stdout has no LANG_CHAT=,
# stderr is empty, and hook exits 0.

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
# Sandbox — HOME isolation (mandatory per sandbox-home-in-tests rule)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t54-test)"
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
# Build a minimal consumer repo — NO .spec-workflow/config.yml
# The hook reads .spec-workflow/config.yml from cwd; its absence is the
# ordinary default-off case (AC7.c, D9) and must produce no warning.
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"

# Minimal .claude/rules/common so the hook can emit a digest (not strictly
# required, but ensures the hook body runs rather than early-exiting on a
# missing rules dir, so the config-absent path is genuinely exercised).
mkdir -p "$CONSUMER/.claude/rules/common"

cat > "$CONSUMER/.claude/rules/common/test-rule.md" <<'RULE'
---
name: test-rule
scope: common
severity: must
created: 2026-04-19
updated: 2026-04-19
---

## Rule

Placeholder rule so the hook has a valid common rule to digest.

## Why

Without at least one valid rule the hook skips the digest loop entirely;
having a rule here keeps the config-absent check in the live code path.

## How to apply

This rule exists only for test harness purposes.
RULE

# ---------------------------------------------------------------------------
# Invoke hook from consumer cwd; capture stdout and stderr separately.
# No .spec-workflow/config.yml exists — that is the condition under test.
# ---------------------------------------------------------------------------
STDERR_FILE="$SANDBOX/stderr.txt"
JSON_OUT=$(cd "$CONSUMER" && "$HOOK" < /dev/null 2>"$STDERR_FILE")
RC=$?

# ---------------------------------------------------------------------------
# Check 1: hook exits 0
# ---------------------------------------------------------------------------
if [ "$RC" -eq 0 ]; then
  pass "Check 1: hook exits 0 when config absent"
else
  fail "Check 1: hook exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stdout does NOT contain LANG_CHAT=
# Missing config must not inject any LANG_CHAT marker.
# ---------------------------------------------------------------------------
case "$JSON_OUT" in
  *LANG_CHAT=*)
    fail "Check 2: stdout contains LANG_CHAT= (expected absent)"
    ;;
  *)
    pass "Check 2: stdout has no LANG_CHAT= line"
    ;;
esac

# ---------------------------------------------------------------------------
# Check 3: stderr is empty (missing file is ordinary — no WARN emitted)
# ---------------------------------------------------------------------------
STDERR_CONTENT="$(cat "$STDERR_FILE")"
if [ -z "$STDERR_CONTENT" ]; then
  pass "Check 3: stderr is empty when config absent"
else
  fail "Check 3: stderr non-empty (got: $STDERR_CONTENT)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
