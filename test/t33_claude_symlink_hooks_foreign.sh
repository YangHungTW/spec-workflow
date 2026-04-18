#!/usr/bin/env bash
# test/t33_claude_symlink_hooks_foreign.sh — T7 foreign-content skip test
# Usage: bash test/t33_claude_symlink_hooks_foreign.sh
# Exits 0 iff all checks pass; 1 on assertion failure; 2 on preflight failure.
#
# Verifies the no-force-on-user-paths rule for the hooks dir-pair added by T2:
# - install skips a real dir at $HOME/.claude/hooks with skipped:real-dir
# - uninstall skips the same real dir with skipped:not-ours
# - In both cases the real dir and its contents are untouched.
#
# RED: this test fails until T2 (4-site claude-symlink edit) is merged.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate script under test (cwd-agnostic per test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="${SCRIPT:-$REPO_ROOT/bin/claude-symlink}"

# ---------------------------------------------------------------------------
# Preflight: script must exist and be executable
# ---------------------------------------------------------------------------
if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: script not found or not executable: $SCRIPT" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# python3 not required; this test is pure-bash
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Sandbox setup (sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t33-test)"
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
trap 'rm -rf "$SANDBOX"' EXIT

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Setup: pre-create a REAL directory at $HOME/.claude/hooks/ (not a symlink)
# containing a sentinel file — simulates a user's pre-existing hooks directory
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.claude/hooks"
echo 'foreign' > "$HOME/.claude/hooks/foreign.txt"

# Sanity-check setup
if [ ! -d "$HOME/.claude/hooks" ] || [ -L "$HOME/.claude/hooks" ]; then
  fail "setup: $HOME/.claude/hooks must be a real dir, not a symlink"
fi
if [ ! -f "$HOME/.claude/hooks/foreign.txt" ]; then
  fail "setup: sentinel file not created"
fi

# ---------------------------------------------------------------------------
# STEP 1: run install — must skip the real dir
# ---------------------------------------------------------------------------
INSTALL_OUT="$("$SCRIPT" install 2>&1)" || true

# Assert: output contains [skipped:real-dir] for the hooks path
if echo "$INSTALL_OUT" | grep -q '\[skipped:real-dir\]'; then
  pass "install: skipped:real-dir reported for real dir at \$HOME/.claude/hooks"
else
  fail "install: expected '[skipped:real-dir]' in output. Got: $INSTALL_OUT"
fi

# Assert: $HOME/.claude/hooks is still a real directory, not a symlink
if [ -d "$HOME/.claude/hooks" ] && [ ! -L "$HOME/.claude/hooks" ]; then
  pass "install: \$HOME/.claude/hooks remains a real directory (not clobbered)"
else
  fail "install: \$HOME/.claude/hooks was removed or converted to a symlink"
fi

# Assert: foreign.txt still present and intact
if [ -f "$HOME/.claude/hooks/foreign.txt" ]; then
  pass "install: foreign.txt still present"
else
  fail "install: foreign.txt was removed"
fi

FOREIGN_CONTENT="$(cat "$HOME/.claude/hooks/foreign.txt")"
if [ "$FOREIGN_CONTENT" = "foreign" ]; then
  pass "install: foreign.txt content untouched"
else
  fail "install: foreign.txt content changed: got '$FOREIGN_CONTENT'"
fi

# ---------------------------------------------------------------------------
# STEP 2: run uninstall — must skip the real dir with skipped:not-ours
# ---------------------------------------------------------------------------
UNINSTALL_OUT="$("$SCRIPT" uninstall 2>&1)" || true

# Assert: output contains [skipped:not-ours] for the hooks path
if echo "$UNINSTALL_OUT" | grep -q '\[skipped:not-ours\]'; then
  pass "uninstall: skipped:not-ours reported for real dir at \$HOME/.claude/hooks"
else
  fail "uninstall: expected '[skipped:not-ours]' in output. Got: $UNINSTALL_OUT"
fi

# Assert: real dir still present after uninstall
if [ -d "$HOME/.claude/hooks" ] && [ ! -L "$HOME/.claude/hooks" ]; then
  pass "uninstall: \$HOME/.claude/hooks still a real directory after uninstall"
else
  fail "uninstall: \$HOME/.claude/hooks was removed or changed"
fi

# Assert: foreign.txt still present after uninstall
if [ -f "$HOME/.claude/hooks/foreign.txt" ]; then
  pass "uninstall: foreign.txt still present after uninstall"
else
  fail "uninstall: foreign.txt was removed during uninstall"
fi

FOREIGN_CONTENT2="$(cat "$HOME/.claude/hooks/foreign.txt")"
if [ "$FOREIGN_CONTENT2" = "foreign" ]; then
  pass "uninstall: foreign.txt content untouched after uninstall"
else
  fail "uninstall: foreign.txt content changed after uninstall: got '$FOREIGN_CONTENT2'"
fi

echo "PASS"
exit 0
