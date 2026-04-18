#!/usr/bin/env bash
# test/t46_migrate_dry_run.sh
#
# Verifies R6 AC6.a + R9 AC9.c:
#   `specflow-seed migrate --dry-run` must be byte-identical across all three
#   roots (consumer, $HOME/.claude/, source repo) — no mutation anywhere.
#   Output must contain at least one `would-create` line (non-empty plan).
#   Exit code must be 0.
#
# RED until T11 (cmd_migrate implementation) is merged.
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
# _REAL_HOME is captured before overriding HOME so asdf .tool-versions can be
# preserved inside the sandbox (missing this breaks python3 shim resolution).
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

# asdf compatibility: copy real user's python version config so the shim
# resolves python3 inside the sandboxed HOME. No-op on non-asdf setups.
if [ -f "$_REAL_HOME/.tool-versions" ]; then
  cp "$_REAL_HOME/.tool-versions" "$HOME/.tool-versions" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Step 1 — Pre-stage a global install (mirrors what bin/claude-symlink install
# produces on a real machine — absolute symlinks into the source repo).
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.claude/agents" \
         "$HOME/.claude/commands" \
         "$HOME/.claude/hooks" \
         "$HOME/.claude/team-memory"

# Absolute symlinks into the real source repo; ln -s needs the target to exist
# for some platforms when resolving, but we create unconditionally — the test
# later uses `ls -lR` (not shasum) to hash symlink-target strings, so dangling
# is acceptable here for the dry-run invariant.
ln -s "$REPO_ROOT/.claude/agents/specflow"         "$HOME/.claude/agents/specflow"
ln -s "$REPO_ROOT/.claude/commands/specflow"        "$HOME/.claude/commands/specflow"

# hooks and team-memory are dirs in the source repo; link them directly
if [ -d "$REPO_ROOT/.claude/hooks" ]; then
  rm -rf "$HOME/.claude/hooks"
  ln -s "$REPO_ROOT/.claude/hooks" "$HOME/.claude/hooks"
fi
if [ -d "$REPO_ROOT/.claude/team-memory" ]; then
  rm -rf "$HOME/.claude/team-memory"
  ln -s "$REPO_ROOT/.claude/team-memory" "$HOME/.claude/team-memory"
fi

# ---------------------------------------------------------------------------
# Step 2 — Pre-stage a consumer repo with a settings.json that uses the
# global (pre-migration) hook paths pointing into $HOME/.claude/hooks/*.
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
git -C "$CONSUMER" init -q
git -C "$CONSUMER" config user.email "t@example.com"
git -C "$CONSUMER" config user.name "t"
touch "$CONSUMER/.gitignore"
git -C "$CONSUMER" add .gitignore
git -C "$CONSUMER" commit -q -m "init"

# Write pre-migration settings.json: hooks wired to the global HOME/.claude/
# paths.  migrate --dry-run must not rewire this to consumer-local paths.
python3 - "$HOME" "$CONSUMER" <<'PYEOF'
import json, sys, os
home = sys.argv[1]
consumer = sys.argv[2]

settings = {
    "hooks": {
        "SessionStart": [{"type": "command",
                          "command": os.path.join(home, ".claude/hooks/session-start.sh")}],
        "Stop":         [{"type": "command",
                          "command": os.path.join(home, ".claude/hooks/stop.sh")}]
    }
}

out = os.path.join(consumer, "settings.json")
with open(out, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF

# ---------------------------------------------------------------------------
# Step 3 — Capture hash trees of all three roots BEFORE dry-run.
#
# Consumer: shasum on file contents (no symlinks at this stage).
# HOME/.claude: ls -lR captures symlink target strings; shasum on a symlink
#   follows the target, which lives OUTSIDE the sandbox — ls -lR gives us the
#   pointer bytes instead, which is what AC9.c protects.
# Source repo .claude: shasum on file contents sorted — baseline for "no
#   mutation to the source repo".
# ---------------------------------------------------------------------------
CONS_H1="$(find "$CONSUMER" -type f -not -path '*/.git/*' -exec shasum {} \; | sort | shasum | awk '{print $1}')"
HOME_H1="$(ls -lR "$HOME/.claude" | shasum | awk '{print $1}')"
SRC_H1="$(find "$REPO_ROOT/.claude" -type f | sort | xargs shasum 2>/dev/null | shasum | awk '{print $1}')"

# ---------------------------------------------------------------------------
# Step 4 — Run migrate --dry-run from inside the consumer directory.
#
# We cd into $CONSUMER per the hard rule (subshell keeps cwd local to step).
# Stdout is captured to assert the plan is non-empty; stderr goes to a file
# so failures are diagnosable without polluting the assertion logic.
# ---------------------------------------------------------------------------
DRY_OUT="$SANDBOX/dry-run.out"
DRY_ERR="$SANDBOX/dry-run.err"

set +e
(cd "$CONSUMER" && "$SEED" migrate --dry-run --from "$REPO_ROOT") \
  > "$DRY_OUT" 2>"$DRY_ERR"
DRY_RC=$?
set -e

# ---------------------------------------------------------------------------
# Step 5a — Exit code must be 0 even on --dry-run (AC6.a).
# ---------------------------------------------------------------------------
if [ "$DRY_RC" -ne 0 ]; then
  echo "FAIL: exit-code: migrate --dry-run exited $DRY_RC, expected 0" >&2
  echo "--- stdout ---" >&2; cat "$DRY_OUT" >&2
  echo "--- stderr ---" >&2; cat "$DRY_ERR" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 5b — Output must contain at least one `would-create` line.
#
# A fresh consumer-from-global always has paths to migrate; an empty plan
# means the command did not run at all (implementation bug).
# ---------------------------------------------------------------------------
if ! grep -q 'would-create' "$DRY_OUT" "$DRY_ERR" 2>/dev/null; then
  echo "FAIL: plan-empty: no 'would-create' line in migrate --dry-run output" >&2
  echo "--- stdout ---" >&2; cat "$DRY_OUT" >&2
  echo "--- stderr ---" >&2; cat "$DRY_ERR" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 5c — Recompute all three root hashes and compare (AC6.a + AC9.c).
#
# Any mutation to consumer, HOME/.claude, or source repo is a bug.
# ---------------------------------------------------------------------------
CONS_H2="$(find "$CONSUMER" -type f -not -path '*/.git/*' -exec shasum {} \; | sort | shasum | awk '{print $1}')"
HOME_H2="$(ls -lR "$HOME/.claude" | shasum | awk '{print $1}')"
SRC_H2="$(find "$REPO_ROOT/.claude" -type f | sort | xargs shasum 2>/dev/null | shasum | awk '{print $1}')"

FAIL=0

if [ "$CONS_H1" != "$CONS_H2" ]; then
  echo "FAIL: consumer: byte tree changed during --dry-run" >&2
  echo "  before: $CONS_H1" >&2
  echo "  after:  $CONS_H2" >&2
  FAIL=1
fi

if [ "$HOME_H1" != "$HOME_H2" ]; then
  echo "FAIL: home-claude: \$HOME/.claude tree changed during --dry-run" >&2
  echo "  before: $HOME_H1" >&2
  echo "  after:  $HOME_H2" >&2
  FAIL=1
fi

if [ "$SRC_H1" != "$SRC_H2" ]; then
  echo "FAIL: source-repo: .claude tree changed during --dry-run" >&2
  echo "  before: $SRC_H1" >&2
  echo "  after:  $SRC_H2" >&2
  FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

echo "PASS"
exit 0
