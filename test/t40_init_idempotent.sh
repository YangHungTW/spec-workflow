#!/usr/bin/env bash
# test/t40_init_idempotent.sh — AC2.b: second init at same ref must be byte-identical
#
# Verifies PRD AC2.b: running specflow-seed init a SECOND time on an already-
# initialised consumer at the same ref leaves every file in an "already" state,
# reports skipped=0, and produces a byte-identical filesystem hash before/after.
#
# Expected to be RED until T3 (cmd_init implementation) is merged.
set -euo pipefail

# ---------------------------------------------------------------------------
# Locate bin/specflow-seed relative to this script — never hardcode the path
# so the test survives worktree moves and CI checkouts.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SEED="${SEED:-$REPO_ROOT/bin/specflow-seed}"

if [ ! -x "$SEED" ]; then
  echo "FAIL: setup: specflow-seed not found or not executable: $SEED" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sandbox-HOME — mandatory per .claude/rules/bash/sandbox-home-in-tests.md.
# All consumer and home mutations live inside SANDBOX; real $HOME never touched.
# Capture real HOME before sandboxing so asdf .tool-versions can be copied in.
# ---------------------------------------------------------------------------
_REAL_HOME="$HOME"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# asdf compatibility: preserve the real user's python version config so the
# shim can resolve python3 inside the sandboxed HOME. No-op on non-asdf setups.
if [ -f "$_REAL_HOME/.tool-versions" ]; then
  cp "$_REAL_HOME/.tool-versions" "$HOME/.tool-versions" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Capture the source ref once so both init runs pin to the same SHA.
# This avoids a race if the repo advances between the two calls.
# ---------------------------------------------------------------------------
SRC_REF="$(git -C "$REPO_ROOT" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Build a minimal consumer repo — needs at least one commit so git commands
# inside specflow-seed (git rev-parse --show-toplevel) resolve cleanly.
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
git -C "$CONSUMER" init -q
git -C "$CONSUMER" config user.email "t@example.com"
git -C "$CONSUMER" config user.name "t"
printf '.specflow-seed-ignore\n' > "$CONSUMER/.gitignore"
git -C "$CONSUMER" add .gitignore
git -C "$CONSUMER" commit -q -m "init"

# ---------------------------------------------------------------------------
# First init — establish the baseline state.
# We swallow output; a failure here is a pre-condition failure, not the AC.
# cd into the consumer before invoking so repo_root() resolves there,
# matching the same discipline as t39 (cd then call) and t41 (subshell).
# ---------------------------------------------------------------------------
(cd "$CONSUMER" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > /dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Hash the consumer tree AFTER the first init (before the second run).
# We hash file contents (not timestamps) so only byte changes register.
# Using shasum (BSD/macOS) which is present on Darwin; sha1sum on Linux.
# ---------------------------------------------------------------------------
hash_tree() {
  local dir="$1"
  find "$dir" -type f -not -path '*/.git/*' \
    -exec shasum {} \; | sort | shasum | awk '{print $1}'
}

FIND_HASH_1="$(hash_tree "$CONSUMER")"

# ---------------------------------------------------------------------------
# Second init — the run under test (AC2.b).
# Capture both stdout and stderr for assertion; allow non-zero exit from set -e
# by wrapping in a subshell that returns the exit code explicitly.
# ---------------------------------------------------------------------------
SECOND_OUT="$SANDBOX/second_init.out"
set +e
(cd "$CONSUMER" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > "$SECOND_OUT" 2>&1
SECOND_RC=$?
set -e

# ---------------------------------------------------------------------------
# Assertion 1: exit code must be 0
# ---------------------------------------------------------------------------
if [ "$SECOND_RC" -ne 0 ]; then
  echo "FAIL: exit-code: second init exited $SECOND_RC, expected 0" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertion 2: output must contain at least two "already" lines
# (one per managed file — confirms convergence was reported per-path).
# ---------------------------------------------------------------------------
ALREADY_COUNT="$(grep -c 'already' "$SECOND_OUT" || true)"
if [ "$ALREADY_COUNT" -lt 2 ]; then
  echo "FAIL: already-count: expected >=2 'already' lines, got $ALREADY_COUNT" >&2
  echo "--- second init output ---" >&2
  cat "$SECOND_OUT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertion 3: output must NOT contain any "created:" lines
# (every path was already converged; nothing new should have been written).
# ---------------------------------------------------------------------------
if grep -q 'created:' "$SECOND_OUT"; then
  echo "FAIL: created-lines: second init emitted 'created:' lines — files were overwritten" >&2
  cat "$SECOND_OUT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertion 4: summary line must show skipped=0
# (no conflicts, no mutations that were rejected).
# ---------------------------------------------------------------------------
if ! grep -q 'skipped=0' "$SECOND_OUT"; then
  echo "FAIL: skipped=0: summary line missing or shows non-zero skipped" >&2
  cat "$SECOND_OUT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertion 5: filesystem must be byte-identical before/after second run
# ---------------------------------------------------------------------------
FIND_HASH_2="$(hash_tree "$CONSUMER")"
if [ "$FIND_HASH_1" != "$FIND_HASH_2" ]; then
  echo "FAIL: byte-identical: filesystem hash changed after second init" >&2
  echo "  before: $FIND_HASH_1" >&2
  echo "  after:  $FIND_HASH_2" >&2
  exit 1
fi

echo "PASS"
exit 0
