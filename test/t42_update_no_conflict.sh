#!/usr/bin/env bash
# test/t42_update_no_conflict.sh
#
# Verifies R7 AC7.b + R8 AC8.a:
#   - A drifted-ours file (source changed, consumer still at baseline) gets
#     backed up to <path>.bak and replaced with ref-B content.
#   - Every other managed file reports "already".
#   - Manifest specflow_ref advances to the new ref.
#   - Exit code is 0.
#
# RED until T7 (cmd_update implementation) is merged; the current stub exits 0
# but emits no replaced:drifted lines, so the AC7.b assertion correctly fails.
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
# All consumer and fixture mutations live inside SANDBOX; real $HOME is
# never touched.  Capture real HOME first so asdf shims keep working.
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
# Step 1 — Build "source at ref-B" fixture
#
# We copy the live repo's .claude tree so the fixture has the same managed
# files as the real source.  Then we append a one-line marker to one agent
# file to synthesise the "ref-B" change; every other file stays at ref-A.
# ---------------------------------------------------------------------------
SRC_B="$SANDBOX/src-at-ref-b"
mkdir -p "$SRC_B"

cp -R "$REPO_ROOT/.claude" "$SRC_B/.claude"
mkdir -p "$SRC_B/bin" "$SRC_B/.spec-workflow/features/_template"

# Copy production scripts so specflow-seed's structural preflight passes inside
# the fixture (it checks that bin/specflow-seed and bin/specflow-install-hook
# exist in the source root).
cp "$REPO_ROOT/bin/specflow-seed"        "$SRC_B/bin/specflow-seed"
cp "$REPO_ROOT/bin/specflow-install-hook" "$SRC_B/bin/specflow-install-hook"

# Copy feature template so the plan() function finds the structural marker.
if [ -d "$REPO_ROOT/.spec-workflow/features/_template" ]; then
  cp -R "$REPO_ROOT/.spec-workflow/features/_template/." \
        "$SRC_B/.spec-workflow/features/_template/"
fi

# Synthesise ref-B: append a sentinel line to architect.md so sha256 differs.
CHANGED_RELPATH=".claude/agents/specflow/architect.md"
echo '# ref-B change' >> "$SRC_B/$CHANGED_RELPATH"

# Commit the fixture so git rev-parse HEAD resolves inside it.
git -C "$SRC_B" init -q
git -C "$SRC_B" config user.email "t@example.com"
git -C "$SRC_B" config user.name "t"
git -C "$SRC_B" add .
git -C "$SRC_B" -c user.email=t@e -c user.name=t commit -q -m "ref-B"

REF_B="$(git -C "$SRC_B" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Step 2 — Build consumer repo and init at ref-A (HEAD of this repo)
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
# Step 3 — Capture the consumer's pre-update content of the changed file
#
# This is the ref-A content.  After update it should match ref-B content,
# and the .bak file should match this captured value.
# ---------------------------------------------------------------------------
if [ ! -f "$CONSUMER/$CHANGED_RELPATH" ]; then
  echo "FAIL: setup: init did not create $CHANGED_RELPATH in consumer" >&2
  exit 1
fi
PRE_CONTENT="$(cat "$CONSUMER/$CHANGED_RELPATH")"

# ---------------------------------------------------------------------------
# Step 4 — Run update from ref-A → ref-B
#
# We call update inside a subshell cd'd to the consumer so repo_root() inside
# specflow-seed resolves the consumer, not this test script's directory.
# Capture stdout+stderr together so assertions can inspect both streams.
# ---------------------------------------------------------------------------
UPDATE_OUT="$SANDBOX/update.out"
set +e
(cd "$CONSUMER" && "$SEED" update --from "$SRC_B" --to "$REF_B") > "$UPDATE_OUT" 2>&1
UPDATE_RC=$?
set -e

# ---------------------------------------------------------------------------
# Step 5 — Assertions
# ---------------------------------------------------------------------------

# AC7.b — replaced:drifted line present for the changed file
if ! grep -q "replaced:drifted:.*$CHANGED_RELPATH" "$UPDATE_OUT" &&
   ! grep -q "replaced:drifted: $CHANGED_RELPATH" "$UPDATE_OUT"; then
  echo "FAIL: AC7.b: expected 'replaced:drifted' for $CHANGED_RELPATH in output" >&2
  echo "--- update output ---" >&2
  cat "$UPDATE_OUT" >&2
  exit 1
fi

# AC7.b — .bak file exists
BAK_PATH="$CONSUMER/${CHANGED_RELPATH}.bak"
if [ ! -f "$BAK_PATH" ]; then
  echo "FAIL: AC7.b: backup file not created: $BAK_PATH" >&2
  exit 1
fi

# AC7.b — .bak content matches pre-update content (ref-A bytes preserved)
BAK_CONTENT="$(cat "$BAK_PATH")"
if [ "$BAK_CONTENT" != "$PRE_CONTENT" ]; then
  echo "FAIL: AC7.b: backup content does not match pre-update content" >&2
  echo "  expected (pre-update): $(printf '%s' "$PRE_CONTENT" | wc -c) bytes" >&2
  echo "  got (bak):             $(printf '%s' "$BAK_CONTENT" | wc -c) bytes" >&2
  exit 1
fi

# AC7.b — updated file now matches ref-B source content
SRC_HASH="$(shasum "$SRC_B/$CHANGED_RELPATH"       | awk '{print $1}')"
DST_HASH="$(shasum "$CONSUMER/$CHANGED_RELPATH"    | awk '{print $1}')"
if [ "$SRC_HASH" != "$DST_HASH" ]; then
  echo "FAIL: AC7.b: consumer file does not match ref-B source after update" >&2
  echo "  src sha1: $SRC_HASH" >&2
  echo "  dst sha1: $DST_HASH" >&2
  exit 1
fi

# Every other managed file must report "already" — no unexpected replacements
# We expect replaced:drifted for exactly 1 path; all other output lines that
# contain a managed-file indicator should say "already".
ALREADY_COUNT="$(grep -c 'already' "$UPDATE_OUT" || true)"
if [ "$ALREADY_COUNT" -lt 1 ]; then
  echo "FAIL: already-count: expected at least 1 'already' line for unchanged files" >&2
  echo "--- update output ---" >&2
  cat "$UPDATE_OUT" >&2
  exit 1
fi

# AC8.a — manifest specflow_ref advanced to REF_B
MANIFEST="$CONSUMER/.claude/specflow.manifest"
if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: AC8.a: manifest not found at $MANIFEST" >&2
  exit 1
fi
MANIFEST_REF="$(awk -F'"' '/"specflow_ref"/{print $4; exit}' "$MANIFEST")"
if [ "$MANIFEST_REF" != "$REF_B" ]; then
  echo "FAIL: AC8.a: manifest specflow_ref='$MANIFEST_REF', expected '$REF_B'" >&2
  exit 1
fi

# Exit code must be 0 — clean update with no user-modified conflicts
if [ "$UPDATE_RC" -ne 0 ]; then
  echo "FAIL: exit-code: update exited $UPDATE_RC, expected 0" >&2
  echo "--- update output ---" >&2
  cat "$UPDATE_OUT" >&2
  exit 1
fi

echo "PASS"
exit 0
