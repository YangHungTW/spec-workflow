#!/usr/bin/env bash
# test/t43_update_user_modified.sh
#
# Verifies R7 AC7.a: when a managed file is user-modified (actual != expected
# AND actual != baseline), update skips it with skipped:user-modified, leaves
# the content byte-identical, and exits non-zero.
#
# Also verifies R8 AC8.b: the manifest ref is NOT advanced when any conflict
# exists; after reverting the hand-edit, re-running update advances the ref.
#
# Two-file fixture shape:
#   - architect.md  — changed ONLY in ref-B fixture (clean drifted path)
#   - pm.md         — changed in BOTH ref-B fixture AND by user edit
#                     (conflict path → user-modified)
#
# Will RED until T7 (cmd_update implementation) is merged.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SEED="${SEED:-$REPO_ROOT/bin/scaff-seed}"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation mandatory (sandbox-home-in-tests.md)
# Capture real HOME before sandboxing for asdf .tool-versions compatibility.
# ---------------------------------------------------------------------------
_REAL_HOME="$HOME"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# asdf compatibility: real user's python version shim must resolve inside sandbox
if [ -f "$_REAL_HOME/.tool-versions" ]; then
  cp "$_REAL_HOME/.tool-versions" "$HOME/.tool-versions" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Helper: initialise a minimal git repo so repo_root detection works
# ---------------------------------------------------------------------------
make_consumer() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "t@example.com"
  git -C "$dir" config user.name "t"
  touch "$dir/.gitignore"
  git -C "$dir" add .gitignore
  git -C "$dir" commit -q -m "init"
}

# ---------------------------------------------------------------------------
# Step 1 — Capture ref-A: the current HEAD of this repo
# ---------------------------------------------------------------------------
REF_A="$(git -C "$REPO_ROOT" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Step 2 — Build a ref-B source fixture
#
# We copy the live source tree into an isolated git repo and commit two
# changes: one to architect.md (clean drifted path) and one to pm.md
# (conflict path).  This gives us a deterministic ref-B SHA with two
# files changed relative to ref-A's baseline content.
# ---------------------------------------------------------------------------
SRC_B="$SANDBOX/src-at-ref-b"
cp -r "$REPO_ROOT/." "$SRC_B"
rm -rf "$SRC_B/.git"

git -C "$SRC_B" init -q
git -C "$SRC_B" config user.email "fixture@example.com"
git -C "$SRC_B" config user.name "fixture"
git -C "$SRC_B" add -A
git -C "$SRC_B" commit -q -m "ref-A baseline"

# Mutate architect.md — clean drifted path (no user edit will touch this)
printf '\n# ref-B architect change\n' >> "$SRC_B/.claude/agents/scaff/architect.md"

# Mutate pm.md — conflict path (user will also edit this file)
printf '\n# ref-B pm change\n' >> "$SRC_B/.claude/agents/scaff/pm.md"

git -C "$SRC_B" add -A
git -C "$SRC_B" commit -q -m "ref-B changes"

REF_B="$(git -C "$SRC_B" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Step 3 — init consumer at ref-A
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
make_consumer "$CONSUMER"

(cd "$CONSUMER" && "$SEED" init --from "$REPO_ROOT" --ref "$REF_A") > "$SANDBOX/init-out.txt" 2>&1

# ---------------------------------------------------------------------------
# Step 4 — Hand-edit pm.md in the consumer
#
# Writing a local edit to pm.md means the classifier will see:
#   actual   = ref-A content + user edit
#   expected = ref-B content
#   baseline = ref-A content
# Since actual != baseline AND actual != expected, the state is user-modified.
# ---------------------------------------------------------------------------
printf '\n# user local edit\n' >> "$CONSUMER/.claude/agents/scaff/pm.md"

# Preserve the post-edit content so we can assert byte-identity after update
USER_CONTENT="$(cat "$CONSUMER/.claude/agents/scaff/pm.md")"

# ---------------------------------------------------------------------------
# Step 5 — Run update; expect non-zero exit due to user-modified conflict
# ---------------------------------------------------------------------------
UPDATE_OUT="$SANDBOX/update-out.txt"
set +e
(cd "$CONSUMER" && "$SEED" update --from "$SRC_B" --to "$REF_B") > "$UPDATE_OUT" 2>&1
UPDATE_EXIT=$?
set -e

# R7 AC7.a — output must report skipped:user-modified for pm.md
if ! grep -q "skipped:user-modified:.*pm\.md\|skipped:user-modified: \.claude/agents/scaff/pm\.md" "$UPDATE_OUT"; then
  echo "FAIL: step 5a: expected 'skipped:user-modified' for pm.md in output; got:" >&2
  cat "$UPDATE_OUT" >&2
  exit 1
fi

# R7 AC7.a — pm.md must be byte-identical to user's post-edit content
ACTUAL_CONTENT="$(cat "$CONSUMER/.claude/agents/scaff/pm.md")"
if [ "$ACTUAL_CONTENT" != "$USER_CONTENT" ]; then
  echo "FAIL: step 5b: pm.md content was modified by update; expected user content preserved" >&2
  exit 1
fi

# Conflict does not halt the run — architect.md (clean drifted path) must be replaced
if ! grep -q "replaced:drifted:.*architect\.md\|replaced:drifted: \.claude/agents/scaff/architect\.md" "$UPDATE_OUT"; then
  echo "FAIL: step 5c: expected 'replaced:drifted' for architect.md in output; got:" >&2
  cat "$UPDATE_OUT" >&2
  exit 1
fi

# R8 AC8.b — manifest ref must NOT have advanced (still ref-A)
MANIFEST="$CONSUMER/.claude/scaff.manifest"
if ! grep -q "$REF_A" "$MANIFEST"; then
  echo "FAIL: step 5d: manifest ref should still be REF_A ($REF_A) after conflicted update; got:" >&2
  cat "$MANIFEST" >&2
  exit 1
fi

# R7 AC7.c — exit code must be non-zero
if [ "$UPDATE_EXIT" -eq 0 ]; then
  echo "FAIL: step 5e: expected non-zero exit after user-modified conflict, got 0" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 6 — Revert-then-re-run (R8 AC8.b second half)
#
# Write the ref-A baseline content back to pm.md so the classifier now sees
# actual == baseline → drifted-ours, which the updater may overwrite cleanly.
# ---------------------------------------------------------------------------
cp "$REPO_ROOT/.claude/agents/scaff/pm.md" "$CONSUMER/.claude/agents/scaff/pm.md"

RERUN_OUT="$SANDBOX/rerun-out.txt"
set +e
(cd "$CONSUMER" && "$SEED" update --from "$SRC_B" --to "$REF_B") > "$RERUN_OUT" 2>&1
RERUN_EXIT=$?
set -e

# After revert, pm.md should now be replaced:drifted (no conflict)
if ! grep -q "replaced:drifted:.*pm\.md\|replaced:drifted: \.claude/agents/scaff/pm\.md" "$RERUN_OUT"; then
  echo "FAIL: step 6a: expected 'replaced:drifted' for pm.md on rerun; got:" >&2
  cat "$RERUN_OUT" >&2
  exit 1
fi

# Manifest ref must now equal REF_B (advanced after clean run)
if ! grep -q "$REF_B" "$MANIFEST"; then
  echo "FAIL: step 6b: manifest ref should be REF_B ($REF_B) after clean rerun; got:" >&2
  cat "$MANIFEST" >&2
  exit 1
fi

# Clean run must exit 0
if [ "$RERUN_EXIT" -ne 0 ]; then
  echo "FAIL: step 6c: expected exit 0 on clean rerun, got $RERUN_EXIT" >&2
  exit 1
fi

echo "PASS"
