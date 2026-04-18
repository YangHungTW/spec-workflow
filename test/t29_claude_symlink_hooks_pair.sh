#!/usr/bin/env bash
# test/t29_claude_symlink_hooks_pair.sh — T3 verify: hooks dir-pair lifecycle
#
# Tests the new hooks dir-pair added by T2 (bin/claude-symlink 4-site extension).
# Covers: install, idempotent re-install, update, uninstall.
#
# Requires T2 merged before this test goes green.
#
# Usage: bash test/t29_claude_symlink_hooks_pair.sh
# Exits 0 on PASS, 1 on FAIL, 2 on preflight failure.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Discover locations — never hardcode worktree paths (developer memory rule)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="${SCRIPT:-$REPO_ROOT/bin/claude-symlink}"
EXPECTED_HOOKS_SRC="$REPO_ROOT/.claude/hooks"

# ---------------------------------------------------------------------------
# Sandbox setup — sandbox-home-in-tests rule (must)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME (POSIX case pattern, bash 3.2 safe)
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Preflight — script must exist and be executable
# ---------------------------------------------------------------------------
if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: script not found or not executable: $SCRIPT" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass_msg() {
  echo "PASS: $*"
}

# ---------------------------------------------------------------------------
# Step 1 — Assert clean start: hooks symlink must not exist yet
# ---------------------------------------------------------------------------
if [ -e "$HOME/.claude/hooks" ] || [ -L "$HOME/.claude/hooks" ]; then
  fail "step 1: expected no hooks path before install, found one at $HOME/.claude/hooks"
fi
pass_msg "step 1: clean start — no hooks path before install"

# ---------------------------------------------------------------------------
# Step 2 — Run install; assert symlink created with correct absolute target
# ---------------------------------------------------------------------------
install_out=$("$SCRIPT" install 2>&1)
install_exit=$?

if [ "$install_exit" -ne 0 ]; then
  fail "step 2: install exited $install_exit (expected 0). Output: $install_out"
fi

if [ ! -L "$HOME/.claude/hooks" ]; then
  fail "step 2: $HOME/.claude/hooks is not a symlink after install. Output: $install_out"
fi

hooks_target="$(readlink "$HOME/.claude/hooks")"

# Assert target is absolute (starts with /)
case "$hooks_target" in
  /*) ;;
  *) fail "step 2: symlink target is not absolute: $hooks_target" ;;
esac

# Assert target equals the repo's .claude/hooks
if [ "$hooks_target" != "$EXPECTED_HOOKS_SRC" ]; then
  fail "step 2: symlink target mismatch. Expected '$EXPECTED_HOOKS_SRC', got '$hooks_target'"
fi
pass_msg "step 2: install created $HOME/.claude/hooks -> $hooks_target"

# ---------------------------------------------------------------------------
# Step 3 — Idempotent re-install: output must contain 'already' for hooks row;
#           symlink target must be byte-identical
# ---------------------------------------------------------------------------
install2_out=$("$SCRIPT" install 2>&1)
install2_exit=$?

if [ "$install2_exit" -ne 0 ]; then
  fail "step 3: second install exited $install2_exit (expected 0). Output: $install2_out"
fi

if ! echo "$install2_out" | grep -q 'already'; then
  fail "step 3: second install output does not contain 'already'. Output: $install2_out"
fi

hooks_target2="$(readlink "$HOME/.claude/hooks")"
if [ "$hooks_target2" != "$hooks_target" ]; then
  fail "step 3: symlink target changed on second install. Before='$hooks_target' After='$hooks_target2'"
fi
pass_msg "step 3: idempotent re-install reports 'already'; symlink target unchanged"

# ---------------------------------------------------------------------------
# Step 4 — Update: output must contain 'already' for hooks row
# ---------------------------------------------------------------------------
update_out=$("$SCRIPT" update 2>&1)
update_exit=$?

if [ "$update_exit" -ne 0 ]; then
  fail "step 4: update exited $update_exit (expected 0). Output: $update_out"
fi

if ! echo "$update_out" | grep -q 'already'; then
  fail "step 4: update output does not contain 'already'. Output: $update_out"
fi
pass_msg "step 4: update reports 'already' for hooks row"

# ---------------------------------------------------------------------------
# Step 5 — Uninstall: hooks symlink must be removed
# ---------------------------------------------------------------------------
uninstall_out=$("$SCRIPT" uninstall 2>&1)
uninstall_exit=$?

if [ "$uninstall_exit" -ne 0 ]; then
  fail "step 5: uninstall exited $uninstall_exit (expected 0). Output: $uninstall_out"
fi

if [ -e "$HOME/.claude/hooks" ] || [ -L "$HOME/.claude/hooks" ]; then
  fail "step 5: $HOME/.claude/hooks still exists after uninstall"
fi
pass_msg "step 5: uninstall removed $HOME/.claude/hooks"

# ---------------------------------------------------------------------------
# All assertions passed
# ---------------------------------------------------------------------------
echo "PASS"
exit 0
