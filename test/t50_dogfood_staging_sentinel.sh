#!/usr/bin/env bash
# test/t50_dogfood_staging_sentinel.sh
#
# ============================================================================
# SANDBOX-HOME EXCEPTION — documented per T18 in
# .specaffold/features/20260418-per-project-install/06-tasks.md
#
# This test intentionally operates against the REAL $HOME/.claude/ state of
# the developer's machine rather than a sandboxed copy. The reason: AC10.a
# (R10) asserts that the live global install is still operational — specifically
# that ~/.claude/agents/scaff still resolves back into this source repo.
# A sandboxed HOME would be empty by construction and could never exercise
# that live invariant.
#
# Safety justification: every operation in this test is provably read-only:
#   - `bin/claude-symlink <sub> --dry-run` computes a plan but mutates nothing.
#   - `readlink` reads a symlink target; it does not follow it to disk.
#   - `ls -lR` and `shasum` are pure readers.
# The read-only claim is verified by capturing the $HOME/.claude tree hash
# BEFORE running any operation and asserting byte-identity AFTER. If any
# operation mutates the real home directory, that hash assertion trips.
# ============================================================================
#
# Requirements: R10 AC10.a — pre-W6 staging sentinel.
# Gate: T21 (dogfood migrate) MUST NOT run until this test exits 0.
# Lifecycle: this test becomes RED after T21 runs (by design — T21 tears down
# the global symlinks). T21's commit removes the t50 registration from smoke.sh.

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate bin/claude-symlink relative to this script so the test survives
# worktree moves and CI checkouts (test-script-path-convention memory).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SYMLINK_CLI="$REPO_ROOT/bin/claude-symlink"

if [ ! -x "$SYMLINK_CLI" ]; then
  echo "FAIL: setup: bin/claude-symlink not found or not executable: $SYMLINK_CLI" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Capture pre-test hash of $HOME/.claude to prove read-only invariant at the
# end. Using ls -lR (sizes + timestamps + names) is sufficient — full content
# hash would be expensive; structural identity is the contract we need.
# ---------------------------------------------------------------------------
HOME_HASH_1="$(ls -lR "$HOME/.claude" 2>/dev/null | shasum | awk '{print $1}')"

# ---------------------------------------------------------------------------
# AC10.a — dry-run of all three subcommands must exit 0.
# Confirms the external contract of bin/claude-symlink is unbroken throughout
# this feature's implement stage (no task in this feature may regress it).
# ---------------------------------------------------------------------------
if ! "$SYMLINK_CLI" install --dry-run > /dev/null 2>&1; then
  echo "FAIL: AC10.a: bin/claude-symlink install --dry-run exited non-zero" >&2
  exit 1
fi

if ! "$SYMLINK_CLI" uninstall --dry-run > /dev/null 2>&1; then
  echo "FAIL: AC10.a: bin/claude-symlink uninstall --dry-run exited non-zero" >&2
  exit 1
fi

if ! "$SYMLINK_CLI" update --dry-run > /dev/null 2>&1; then
  echo "FAIL: AC10.a: bin/claude-symlink update --dry-run exited non-zero" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# AC10.a — live symlink must still point back into this source repo.
# The target path is deterministic: REPO_ROOT is the checkout the developer
# is working in, so the expected symlink target is inside it.
# ---------------------------------------------------------------------------
EXPECTED_TARGET="$REPO_ROOT/.claude/agents/scaff"
ACTUAL_TARGET="$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)"

if [ "$ACTUAL_TARGET" != "$EXPECTED_TARGET" ]; then
  echo "FAIL: AC10.a: symlink does not resolve to this repo" >&2
  echo "  expected: $EXPECTED_TARGET" >&2
  echo "  actual:   ${ACTUAL_TARGET:-<not found>}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Read-only invariant check — hash must be byte-identical after all operations
# above. Any mutation to $HOME/.claude/ from this test is a contract violation.
# ---------------------------------------------------------------------------
HOME_HASH_2="$(ls -lR "$HOME/.claude" 2>/dev/null | shasum | awk '{print $1}')"

if [ "$HOME_HASH_1" != "$HOME_HASH_2" ]; then
  echo "FAIL: sentinel mutated \$HOME/.claude — invariant broken" >&2
  exit 1
fi

echo PASS
exit 0
