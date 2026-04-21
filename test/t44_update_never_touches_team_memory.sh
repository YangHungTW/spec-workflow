#!/usr/bin/env bash
# test/t44_update_never_touches_team_memory.sh
#
# Verifies R4 AC4.b + R8 AC8.c:
#   cmd_update must not read, write, or delete anything under
#   <consumer>/.claude/team-memory/.  A local "lesson" seeded before the
#   update run must be byte-identical and mtime-identical afterwards.
#
# The hash captures both content (shasum) and mtime so a write-then-restore
# would still be caught.  A pure read does NOT change mtime, which is
# intentional — R8 AC8.c is a disk-mutation guard, not a syscall-count guard.
# Static analysis of bin/scaff-seed (grep) is the appropriate read-check.
#
# RED until T7 (cmd_update implementation) is merged.
set -euo pipefail

# ---------------------------------------------------------------------------
# Locate bin/scaff-seed relative to this script — never hardcode the path
# so the test survives worktree moves and CI checkouts.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SEED="${SEED:-$REPO_ROOT/bin/scaff-seed}"

if [ ! -x "$SEED" ]; then
  echo "FAIL: setup: scaff-seed not found or not executable: $SEED" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sandbox-HOME — mandatory per .claude/rules/bash/sandbox-home-in-tests.md.
# Capture real HOME first so asdf .tool-versions can be copied into the
# sandboxed HOME (W2 hotfix lesson: missing this breaks python3 shim resolution).
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
# Step 1 — Build consumer repo and init at ref-A (HEAD of this repo)
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
git -C "$CONSUMER" init -q
git -C "$CONSUMER" config user.email "t@example.com"
git -C "$CONSUMER" config user.name "t"
touch "$CONSUMER/.gitignore"
git -C "$CONSUMER" add .gitignore
git -C "$CONSUMER" commit -q -m "init"

SRC_A_REF="$(git -C "$REPO_ROOT" rev-parse HEAD)"

(cd "$CONSUMER" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_A_REF") > /dev/null 2>&1

# ---------------------------------------------------------------------------
# Step 2 — Seed a local team-memory lesson in the consumer
#
# This file represents consumer-local knowledge that cmd_update must not
# touch.  We capture mtime + content before the update run.
# ---------------------------------------------------------------------------
LESSON_DIR="$CONSUMER/.claude/team-memory/developer"
mkdir -p "$LESSON_DIR"
echo 'local lesson' > "$LESSON_DIR/my-lesson.md"

LESSON_CONTENT="$(cat "$LESSON_DIR/my-lesson.md")"

# Capture mtime using a uname-dispatch wrapper so stat -f (BSD) vs stat -c
# (Linux) is never spread across call sites.
file_mtime() {
  local f="$1"
  local uname_s
  uname_s="$(uname -s 2>/dev/null)"
  if [ "$uname_s" = "Darwin" ] || [ "$uname_s" = "FreeBSD" ] || \
     [ "$uname_s" = "OpenBSD" ] || [ "$uname_s" = "NetBSD" ]; then
    stat -f '%m' "$f" 2>/dev/null
  else
    stat -c '%Y' "$f" 2>/dev/null
  fi
}

LESSON_MTIME="$(file_mtime "$LESSON_DIR/my-lesson.md")"

# ---------------------------------------------------------------------------
# Step 3 — Build ref-B source fixture (same shape as T8/t42)
#
# Copy the live repo's .claude tree and append a sentinel to one agent file
# to synthesise a "ref-B" SHA change; everything else stays at ref-A bytes.
# ---------------------------------------------------------------------------
SRC_B="$SANDBOX/src-at-ref-b"
mkdir -p "$SRC_B"

cp -R "$REPO_ROOT/.claude" "$SRC_B/.claude"
mkdir -p "$SRC_B/bin" "$SRC_B/.specaffold/features/_template"

cp "$REPO_ROOT/bin/scaff-seed"         "$SRC_B/bin/scaff-seed"
cp "$REPO_ROOT/bin/scaff-install-hook" "$SRC_B/bin/scaff-install-hook"

if [ -d "$REPO_ROOT/.specaffold/features/_template" ]; then
  cp -R "$REPO_ROOT/.specaffold/features/_template/." \
        "$SRC_B/.specaffold/features/_template/"
fi

echo '# ref-B change' >> "$SRC_B/.claude/agents/scaff/architect.md"

git -C "$SRC_B" init -q
git -C "$SRC_B" config user.email "t@example.com"
git -C "$SRC_B" config user.name "t"
git -C "$SRC_B" add .
git -C "$SRC_B" commit -q -m "ref-B"

REF_B="$(git -C "$SRC_B" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Step 4 — Capture team-memory subtree fingerprint before the update
#
# tm_hash() isolates the BSD/Linux stat-flag dispatch so it never leaks
# into call sites.  find + shasum captures both content and mtime, so any
# disk mutation (write or delete) will change the hash even if the content
# is later restored.
# ---------------------------------------------------------------------------
tm_hash() {
  local uname_s
  uname_s="$(uname -s 2>/dev/null)"
  if [ "$uname_s" = "Darwin" ] || [ "$uname_s" = "FreeBSD" ] || \
     [ "$uname_s" = "OpenBSD" ] || [ "$uname_s" = "NetBSD" ]; then
    find "$CONSUMER/.claude/team-memory" -type f \
      -exec shasum {} \; -exec stat -f '%m' {} \; | sort | shasum | awk '{print $1}'
  else
    find "$CONSUMER/.claude/team-memory" -type f \
      -exec shasum {} \; -exec stat -c '%Y' {} \; | sort | shasum | awk '{print $1}'
  fi
}

TM_HASH_1="$(tm_hash)"

# ---------------------------------------------------------------------------
# Step 5 — Run cmd_update
# ---------------------------------------------------------------------------
UPDATE_OUT="$SANDBOX/update.out"
set +e
(cd "$CONSUMER" && "$SEED" update --from "$SRC_B" --to "$REF_B") > "$UPDATE_OUT" 2>&1
UPDATE_RC=$?
set -e

if [ "$UPDATE_RC" -ne 0 ]; then
  echo "FAIL: exit-code: update exited $UPDATE_RC, expected 0" >&2
  echo "--- update output ---" >&2
  cat "$UPDATE_OUT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 6 — Assert team-memory tree is byte+mtime identical after update
# ---------------------------------------------------------------------------
TM_HASH_2="$(tm_hash)"

if [ "$TM_HASH_1" != "$TM_HASH_2" ]; then
  echo "FAIL: tm-mtime: team-memory tree touched by cmd_update" >&2
  echo "  before: $TM_HASH_1" >&2
  echo "  after:  $TM_HASH_2" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 7 — Assert lesson content is byte-for-byte unchanged
# ---------------------------------------------------------------------------
LESSON_AFTER="$(cat "$LESSON_DIR/my-lesson.md")"
if [ "$LESSON_CONTENT" != "$LESSON_AFTER" ]; then
  echo "FAIL: lesson-content: my-lesson.md was modified by cmd_update" >&2
  echo "  expected: $LESSON_CONTENT" >&2
  echo "  got:      $LESSON_AFTER" >&2
  exit 1
fi

echo "PASS"
exit 0
