#!/usr/bin/env bash
# test/t47_migrate_user_modified.sh
#
# Verifies R9 AC9.d: when the consumer has a user-modified file, `migrate`:
#   (a) reports skipped:user-modified for that file
#   (b) exits non-zero
#   (c) does NOT rewire settings.json (still points at global hooks)
#   (d) does NOT touch $HOME/.claude/ symlinks (D10 abstention holds on fail path)
#
# Will RED until T11 (cmd_migrate implementation) is merged.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SEED="${SEED:-$REPO_ROOT/bin/specflow-seed}"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation mandatory (sandbox-home-in-tests.md).
# Capture real HOME first so asdf .tool-versions can be copied in for python3.
# ---------------------------------------------------------------------------
_REAL_HOME="$HOME"
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t specflow-t47)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME — a wrong subshell env could
# point HOME at the real directory and cause irreversible writes.
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# asdf compatibility: the shim needs to resolve python3 from the tool-versions
# file; without this, specflow-install-hook (python3 script) fails inside sandbox.
if [ -f "$_REAL_HOME/.tool-versions" ]; then
  cp "$_REAL_HOME/.tool-versions" "$HOME/.tool-versions" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Step 1 — Pre-stage global install (mirrors what bin/claude-symlink install
# produces; D10 requires these symlinks remain untouched after a conflicted
# migrate run).
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.claude/agents" "$HOME/.claude/commands" "$HOME/.claude/hooks-parent"

# Absolute symlink targets per absolute-symlink-targets.md
ln -s "$REPO_ROOT/.claude/agents/specflow"   "$HOME/.claude/agents/specflow"
ln -s "$REPO_ROOT/.claude/commands/specflow" "$HOME/.claude/commands/specflow"
ln -s "$REPO_ROOT/.claude/hooks"             "$HOME/.claude/hooks"

# Capture the symlink target strings BEFORE the migrate run so we can assert
# they are byte-identical after the conflicted run (D10 abstention on fail path).
AGENT_LINK_BEFORE="$(readlink "$HOME/.claude/agents/specflow")"

# ---------------------------------------------------------------------------
# Step 2 — Build a minimal consumer git repo with pre-migration settings.json
# (SessionStart + Stop pointing at the global ~/.claude/hooks/ paths, which is
# the pre-migration wiring shape that migrate is supposed to rewire on success).
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
git init -q "$CONSUMER"
git -C "$CONSUMER" config user.email "t@example.com"
git -C "$CONSUMER" config user.name "t"
printf '*.log\n' > "$CONSUMER/.gitignore"
git -C "$CONSUMER" add .gitignore
git -C "$CONSUMER" commit -q -m "init"

# Write the pre-migration settings.json that references global hook paths.
# On a clean migrate run the tool would rewire these to consumer-local paths;
# on a conflicted run it must leave this file untouched (AC9.d).
cat > "$CONSUMER/settings.json" <<'SETTINGS_EOF'
{
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/session-start.sh"}]}],
    "Stop":         [{"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/stop.sh"}]}]
  }
}
SETTINGS_EOF

# Capture the SHA of settings.json now; a conflicted migrate MUST leave it unchanged.
SETTINGS_HASH_BEFORE="$(shasum "$CONSUMER/settings.json" | awk '{print $1}')"

# ---------------------------------------------------------------------------
# Step 3 — Pre-create a user-modified file in the consumer.
# Writing content to architect.md means the classifier will see it as
# user-modified (actual != source, no baseline recorded yet since init was
# never run) — exactly the conflict state AC9.d tests.
# ---------------------------------------------------------------------------
mkdir -p "$CONSUMER/.claude/agents/specflow"
printf 'user edit\n' > "$CONSUMER/.claude/agents/specflow/architect.md"
USER_CONTENT="$(cat "$CONSUMER/.claude/agents/specflow/architect.md")"

# ---------------------------------------------------------------------------
# Step 4 — Run migrate; expect non-zero exit due to user-modified conflict.
# The set +e / set -e wrapper prevents the test itself from aborting on the
# expected non-zero return from migrate.
# ---------------------------------------------------------------------------
MIGRATE_OUT="$SANDBOX/migrate-out.txt"
set +e
(cd "$CONSUMER" && "$SEED" migrate --from "$REPO_ROOT") > "$MIGRATE_OUT" 2>&1
MIGRATE_EXIT=$?
set -e

# ---------------------------------------------------------------------------
# Assertion (a) — output must report skipped:user-modified for architect.md
# ---------------------------------------------------------------------------
if ! grep -q "skipped:user-modified" "$MIGRATE_OUT"; then
  echo "FAIL: assertion-a: expected 'skipped:user-modified' in migrate output; got:" >&2
  cat "$MIGRATE_OUT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertion (b) — exit code must be non-zero (conflict → non-clean run)
# ---------------------------------------------------------------------------
if [ "$MIGRATE_EXIT" -eq 0 ]; then
  echo "FAIL: assertion-b: expected non-zero exit after user-modified conflict, got 0" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertion (c.content) — user-modified file content is byte-identical to what
# the user wrote; migrate must NOT have overwritten it.
# ---------------------------------------------------------------------------
ACTUAL_CONTENT="$(cat "$CONSUMER/.claude/agents/specflow/architect.md")"
if [ "$ACTUAL_CONTENT" != "$USER_CONTENT" ]; then
  echo "FAIL: assertion-c: architect.md content was modified by migrate; user content must be preserved" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertion (c.settings) — settings.json hash UNCHANGED.
# On a conflicted run, migrate must NOT rewire settings.json (AC9.d).
# A changed hash would mean the global-hook wiring was replaced, silently
# altering hook dispatch for other projects on this machine.
# ---------------------------------------------------------------------------
SETTINGS_HASH_AFTER="$(shasum "$CONSUMER/settings.json" | awk '{print $1}')"
if [ "$SETTINGS_HASH_AFTER" != "$SETTINGS_HASH_BEFORE" ]; then
  echo "FAIL: assertion-c.settings: settings.json was modified on a conflicted migrate run; hash before=$SETTINGS_HASH_BEFORE after=$SETTINGS_HASH_AFTER" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertion (d) — $HOME/.claude/agents/specflow symlink target UNCHANGED.
# D10 abstention holds even on the failure path: migrate must never touch
# global symlinks, regardless of whether the run succeeded or conflicted.
# A changed readlink value would mean another project's global install was
# disrupted — the catastrophic regression 05-plan.md §3 R2 guards against.
# ---------------------------------------------------------------------------
AGENT_LINK_AFTER="$(readlink "$HOME/.claude/agents/specflow")"
if [ "$AGENT_LINK_AFTER" != "$AGENT_LINK_BEFORE" ]; then
  echo "FAIL: assertion-d: \$HOME/.claude/agents/specflow symlink was mutated by conflicted migrate; before=$AGENT_LINK_BEFORE after=$AGENT_LINK_AFTER" >&2
  exit 1
fi

echo "PASS"
