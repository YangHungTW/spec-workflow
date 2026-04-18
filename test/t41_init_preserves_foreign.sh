#!/usr/bin/env bash
# test/t41_init_preserves_foreign.sh
#
# Verifies PRD AC2.c: when a managed destination path already has content the
# classifier did not put there, init refuses to overwrite (skip-and-report),
# preserves the existing content byte-for-byte, and exits non-zero.
#
# Three variants:
#   A — real file with user-modified content at a managed path
#   B — directory sitting where a managed file is expected
#   C — foreign symlink at a managed path
#
# Also: structural AC7.d check — bin/specflow-seed must not contain
# --force / -f / rm -rf flags.
#
# Will RED until T3 (cmd_init implementation) is merged; the stub exits 0
# and emits no skipped: lines, so the assertions below correctly fail.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SEED="${SEED:-$REPO_ROOT/bin/specflow-seed}"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation is mandatory (sandbox-home-in-tests.md)
# Capture real HOME before sandboxing so asdf .tool-versions can be copied in.
# ---------------------------------------------------------------------------
_REAL_HOME="$HOME"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against the real HOME
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
# Helpers
# ---------------------------------------------------------------------------

# make_consumer <dir> — initialise a git repo so repo_root resolves inside it
make_consumer() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "t@example.com"
  git -C "$dir" config user.name "t"
  # A committed file so HEAD exists and git rev-parse works
  touch "$dir/.gitignore"
  git -C "$dir" add .gitignore
  git -C "$dir" commit -q -m "init"
}

# capture_ref — HEAD SHA of this (source) repo, used as --ref argument
SOURCE_REF="$(git -C "$REPO_ROOT" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Variant A — real file with user-modified content
#
# A user-edited file at a managed path must be reported as skipped:user-modified
# and left byte-for-byte unchanged.  Exit code must be non-zero.
# ---------------------------------------------------------------------------
CONSUMER_A="$SANDBOX/consumer-a"
make_consumer "$CONSUMER_A"

# Pre-create the managed path with foreign content
mkdir -p "$CONSUMER_A/.claude/agents/specflow"
printf 'not the real architect.md' > "$CONSUMER_A/.claude/agents/specflow/architect.md"

OUTPUT_A="$SANDBOX/out-a.txt"
set +e
(cd "$CONSUMER_A" && "$SEED" init --from "$REPO_ROOT" --ref "$SOURCE_REF") > "$OUTPUT_A" 2>&1
EXIT_A=$?
set -e

# Must exit non-zero — AC7.c
if [ "$EXIT_A" -eq 0 ]; then
  echo "FAIL: variant A: expected non-zero exit, got 0" >&2
  exit 1
fi

# Must report skipped:user-modified for the conflicting path
if ! grep -q "skipped:user-modified" "$OUTPUT_A"; then
  echo "FAIL: variant A: expected 'skipped:user-modified' in output; got:" >&2
  cat "$OUTPUT_A" >&2
  exit 1
fi

# Content must be byte-for-byte preserved
CONTENT_A="$(cat "$CONSUMER_A/.claude/agents/specflow/architect.md")"
if [ "$CONTENT_A" != "not the real architect.md" ]; then
  echo "FAIL: variant A: foreign file content was modified (got: $CONTENT_A)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Variant B — directory sitting where a managed file is expected
#
# The classifier sees a directory where a regular file should go.  init must
# report skipped:real-file-conflict, leave the directory intact, exit non-zero.
# ---------------------------------------------------------------------------
CONSUMER_B="$SANDBOX/consumer-b"
make_consumer "$CONSUMER_B"

# Pre-create a directory where session-start.sh should be a regular file
mkdir -p "$CONSUMER_B/.claude/hooks/session-start.sh"

OUTPUT_B="$SANDBOX/out-b.txt"
set +e
(cd "$CONSUMER_B" && "$SEED" init --from "$REPO_ROOT" --ref "$SOURCE_REF") > "$OUTPUT_B" 2>&1
EXIT_B=$?
set -e

# Must exit non-zero — AC7.c
if [ "$EXIT_B" -eq 0 ]; then
  echo "FAIL: variant B: expected non-zero exit, got 0" >&2
  exit 1
fi

# Must report skipped:real-file-conflict
if ! grep -q "skipped:real-file-conflict" "$OUTPUT_B"; then
  echo "FAIL: variant B: expected 'skipped:real-file-conflict' in output; got:" >&2
  cat "$OUTPUT_B" >&2
  exit 1
fi

# The directory must still be present and still be a directory
if [ ! -d "$CONSUMER_B/.claude/hooks/session-start.sh" ]; then
  echo "FAIL: variant B: directory at managed path was removed or replaced" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Variant C — foreign symlink at a managed path
#
# R1 forbids symlinks in the consumer tree; a pre-existing symlink is treated
# as a conflict.  init must report skipped:real-file-conflict, leave the
# symlink untouched, exit non-zero.
# ---------------------------------------------------------------------------
CONSUMER_C="$SANDBOX/consumer-c"
make_consumer "$CONSUMER_C"

mkdir -p "$CONSUMER_C/.claude/agents/specflow"
ln -s /tmp/nowhere "$CONSUMER_C/.claude/agents/specflow/architect.md"

OUTPUT_C="$SANDBOX/out-c.txt"
set +e
(cd "$CONSUMER_C" && "$SEED" init --from "$REPO_ROOT" --ref "$SOURCE_REF") > "$OUTPUT_C" 2>&1
EXIT_C=$?
set -e

# Must exit non-zero — AC7.c
if [ "$EXIT_C" -eq 0 ]; then
  echo "FAIL: variant C: expected non-zero exit, got 0" >&2
  exit 1
fi

# Must report skipped:real-file-conflict (symlinks are foreign by definition)
if ! grep -q "skipped:real-file-conflict" "$OUTPUT_C"; then
  echo "FAIL: variant C: expected 'skipped:real-file-conflict' in output; got:" >&2
  cat "$OUTPUT_C" >&2
  exit 1
fi

# The symlink must still be present and still be a symlink
if [ ! -L "$CONSUMER_C/.claude/agents/specflow/architect.md" ]; then
  echo "FAIL: variant C: symlink at managed path was removed or replaced" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# AC7.d structural check — no force flags in bin/specflow-seed
#
# The binary must not contain --force, standalone -f, or rm -rf.
# This catches accidental introduction of destructive-by-default behaviour.
# ---------------------------------------------------------------------------
FORCE_HITS="$(grep -En 'rm -rf|--force' "$SEED" || true)"
if [ -n "$FORCE_HITS" ]; then
  echo "FAIL: AC7.d: bin/specflow-seed contains force/destructive flags:" >&2
  printf '%s\n' "$FORCE_HITS" >&2
  exit 1
fi

echo "PASS"
