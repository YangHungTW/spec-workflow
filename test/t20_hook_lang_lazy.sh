#!/usr/bin/env bash
# test/t20_hook_lang_lazy.sh — lang_heuristic lazy-loading test
# Creates a sandbox git repo with .claude/rules/{common,bash}/ populated.
# (a) When a .sh file is present in git status → bash rules appear in digest.
# (b) When only non-sh files are present → bash rules absent, common present.

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t20-test)"
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
# Helper: build_rules_dir <base>
# Populates <base>/.claude/rules/common/ and <base>/.claude/rules/bash/
# with one valid rule each (different names so we can distinguish them).
# ---------------------------------------------------------------------------
build_rules_dir() {
  local base="$1"
  local rules_common="$base/.claude/rules/common"
  local rules_bash="$base/.claude/rules/bash"
  mkdir -p "$rules_common" "$rules_bash"

  cat > "$rules_common/common-rule.md" <<'RULE'
---
name: common-rule
scope: common
severity: must
created: 2026-04-17
updated: 2026-04-17
---

## Rule

This is the common rule, always loaded.

## Why

Common rules apply to all sessions.

## How to apply

Apply it always.
RULE

  cat > "$rules_bash/bash-only-rule.md" <<'RULE'
---
name: bash-only-rule
scope: bash
severity: must
created: 2026-04-17
updated: 2026-04-17
---

## Rule

This rule only loads when bash files are detected.

## Why

Lazy loading saves context.

## How to apply

Only applies when .sh files are active.
RULE
}

# ---------------------------------------------------------------------------
# Condition (a): .sh file present in git status → bash rules appear in digest
# ---------------------------------------------------------------------------
REPO_A="$SANDBOX/repo_a"
mkdir -p "$REPO_A"
build_rules_dir "$REPO_A"

# Init a git repo so git status works; create an untracked .sh file
(cd "$REPO_A" && git init -q 2>/dev/null && touch something.sh)

JSON_A=$(cd "$REPO_A" && "$HOOK" < /dev/null 2>/dev/null)
CONTEXT_A=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d.get('hookSpecificOutput', {}).get('additionalContext', ''))
" "$JSON_A" 2>/dev/null)

# common-rule should always be present
case "$CONTEXT_A" in
  *common-rule*)
    pass "Check 1a: common-rule present when .sh file in worktree"
    ;;
  *)
    fail "Check 1a: common-rule missing (got: $CONTEXT_A)"
    ;;
esac

# bash-only-rule should be present because of something.sh
case "$CONTEXT_A" in
  *bash-only-rule*)
    pass "Check 2a: bash-only-rule present when .sh file in worktree"
    ;;
  *)
    fail "Check 2a: bash-only-rule absent despite .sh file in worktree (got: $CONTEXT_A)"
    ;;
esac

# ---------------------------------------------------------------------------
# Condition (b): no .sh file → bash rules absent, only common loaded
# ---------------------------------------------------------------------------
REPO_B="$SANDBOX/repo_b"
mkdir -p "$REPO_B"
build_rules_dir "$REPO_B"

# Init a git repo; create only a .txt file (not .sh, .md, or git-tracked)
(cd "$REPO_B" && git init -q 2>/dev/null && touch something.txt)

JSON_B=$(cd "$REPO_B" && "$HOOK" < /dev/null 2>/dev/null)
CONTEXT_B=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d.get('hookSpecificOutput', {}).get('additionalContext', ''))
" "$JSON_B" 2>/dev/null)

# common-rule must still be present
case "$CONTEXT_B" in
  *common-rule*)
    pass "Check 3b: common-rule still present with no .sh file"
    ;;
  *)
    fail "Check 3b: common-rule missing with no .sh file (got: $CONTEXT_B)"
    ;;
esac

# bash-only-rule must be absent
case "$CONTEXT_B" in
  *bash-only-rule*)
    fail "Check 4b: bash-only-rule appeared despite no .sh file (got: $CONTEXT_B)"
    ;;
  *)
    pass "Check 4b: bash-only-rule correctly absent with no .sh file"
    ;;
esac

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
