#!/usr/bin/env bash
# test/t45_migrate_from_global.sh
#
# D10 behavioral guard: verifies that cmd_migrate does NOT tear down shared
# ~/.claude/ symlinks that belong to the global install (bin/claude-symlink).
# Regression here would break every other project using specaffold globally.
#
# Requirements covered:
#   R9  AC9.a  — other projects' ~/.claude/ data unaffected after migrate
#   R9  AC9.b  — migrate is idempotent; second run exits 0, consumer byte-identical
#   R10 AC10.a — global symlinks still resolve to the same targets after migrate
#
# RED until T11 (cmd_migrate implementation) is merged.
set -euo pipefail

# ---------------------------------------------------------------------------
# Locate bin/scaff-seed relative to this script — never hardcode so the
# test survives worktree moves and CI checkouts (test-script-path-convention).
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
# Doubly load-bearing: this test mutates $HOME/.claude/ subtree structure to
# simulate a real global install, so isolating HOME prevents any accident
# from reaching the developer's real ~/.claude/.
# Capture real HOME first so asdf .tool-versions can be copied into the
# sandboxed HOME (missing this breaks python3 shim resolution).
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
# Step 1 — Pre-stage a global install under $HOME/.claude/
#
# Emulates what bin/claude-symlink install produces on a real machine.
# All symlink targets are absolute per .claude/rules/common/absolute-symlink-targets.md.
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.claude/agents" "$HOME/.claude/commands" "$HOME/.claude/team-memory"

ln -s "$REPO_ROOT/.claude/agents/scaff"  "$HOME/.claude/agents/scaff"
ln -s "$REPO_ROOT/.claude/commands/scaff" "$HOME/.claude/commands/scaff"
ln -s "$REPO_ROOT/.claude/hooks"             "$HOME/.claude/hooks"

# Link each role directory under team-memory using a while-read loop so
# the iteration is portable to bash 3.2 (no mapfile / readarray).
ls "$REPO_ROOT/.claude/team-memory" | while IFS= read -r role; do
  # Skip the README — it is a file, not a role directory
  if [ -d "$REPO_ROOT/.claude/team-memory/$role" ]; then
    ln -s "$REPO_ROOT/.claude/team-memory/$role" \
          "$HOME/.claude/team-memory/$role"
  fi
done

# ---------------------------------------------------------------------------
# Step 2 — Pre-stage a consumer project
#
# Simulate a project that was previously wired to use the global install:
# settings.json has SessionStart + Stop hooks pointing at $HOME/.claude/hooks.
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
git -C "$CONSUMER" init -q
git -C "$CONSUMER" config user.email "t@example.com"
git -C "$CONSUMER" config user.name "t"

# Write settings.json with global-install hook paths.
# The pre-migration shape mirrors what bin/scaff-install-hook would have
# written for a global-install consumer.
cat > "$CONSUMER/settings.json" <<SETTINGS_EOF
{
  "hooks": {
    "SessionStart": [{"hooks": [{"type":"command","command":"$HOME/.claude/hooks/session-start.sh"}]}],
    "Stop": [{"hooks": [{"type":"command","command":"$HOME/.claude/hooks/stop.sh"}]}]
  }
}
SETTINGS_EOF

git -C "$CONSUMER" add .
git -C "$CONSUMER" commit -q -m "init with global-install settings"

# ---------------------------------------------------------------------------
# Step 3 — Add a "foreign" file under ~/.claude/
#
# This is the AC9.a "unrelated content" anchor: migrate must not delete,
# modify, or touch any path in ~/.claude/ that is not part of its own
# migration scope.
# ---------------------------------------------------------------------------
echo 'unrelated' > "$HOME/.claude/other-project-marker"

# ---------------------------------------------------------------------------
# Step 4 — Capture pre-migrate state
#
# Use readlink (bare, BSD-safe) to snapshot symlink target strings.
# We compare target strings rather than dereferencing through symlinks
# because the sandbox targets resolve outside the sandbox — only the
# symlink pointer itself must be unchanged.
# ---------------------------------------------------------------------------
MARKER_HASH_BEFORE="$(shasum "$HOME/.claude/other-project-marker" | awk '{print $1}')"

AGENT_TARGET_BEFORE="$(readlink "$HOME/.claude/agents/scaff")"
COMMANDS_TARGET_BEFORE="$(readlink "$HOME/.claude/commands/scaff")"
HOOKS_TARGET_BEFORE="$(readlink "$HOME/.claude/hooks")"

# Pick one representative team-memory role as the canary; developer is always present.
TM_ROLE_CANARY="developer"
TM_CANARY_TARGET_BEFORE="$(readlink "$HOME/.claude/team-memory/$TM_ROLE_CANARY")"

# ---------------------------------------------------------------------------
# Step 5 — Run migrate
# ---------------------------------------------------------------------------
MIGRATE_OUT="$SANDBOX/migrate.out"
set +e
(cd "$CONSUMER" && "$SEED" migrate --from "$REPO_ROOT") > "$MIGRATE_OUT" 2>&1
MIGRATE_RC=$?
set -e

if [ "$MIGRATE_RC" -ne 0 ]; then
  echo "FAIL: exit-code: migrate exited $MIGRATE_RC, expected 0" >&2
  echo "--- migrate output ---" >&2
  cat "$MIGRATE_OUT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 6 — AC9.a: foreign marker file must be byte-identical
# ---------------------------------------------------------------------------
MARKER_HASH_AFTER="$(shasum "$HOME/.claude/other-project-marker" | awk '{print $1}')"
if [ "$MARKER_HASH_BEFORE" != "$MARKER_HASH_AFTER" ]; then
  echo "FAIL: AC9.a: other-project-marker was modified by migrate" >&2
  echo "  before: $MARKER_HASH_BEFORE" >&2
  echo "  after:  $MARKER_HASH_AFTER" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 7 — AC9.a + AC10.a: all four global symlinks must be untouched
#
# migrate must not modify, replace, or delete symlinks that belong to the
# global install.  Comparing readlink output proves the symlink pointer
# itself was never rewritten.
# ---------------------------------------------------------------------------
AGENT_TARGET_AFTER="$(readlink "$HOME/.claude/agents/scaff")"
if [ "$AGENT_TARGET_BEFORE" != "$AGENT_TARGET_AFTER" ]; then
  echo "FAIL: AC10.a: agents/scaff symlink was modified by migrate" >&2
  echo "  before: $AGENT_TARGET_BEFORE" >&2
  echo "  after:  $AGENT_TARGET_AFTER" >&2
  exit 1
fi

COMMANDS_TARGET_AFTER="$(readlink "$HOME/.claude/commands/scaff")"
if [ "$COMMANDS_TARGET_BEFORE" != "$COMMANDS_TARGET_AFTER" ]; then
  echo "FAIL: AC10.a: commands/scaff symlink was modified by migrate" >&2
  echo "  before: $COMMANDS_TARGET_BEFORE" >&2
  echo "  after:  $COMMANDS_TARGET_AFTER" >&2
  exit 1
fi

HOOKS_TARGET_AFTER="$(readlink "$HOME/.claude/hooks")"
if [ "$HOOKS_TARGET_BEFORE" != "$HOOKS_TARGET_AFTER" ]; then
  echo "FAIL: AC10.a: hooks symlink was modified by migrate" >&2
  echo "  before: $HOOKS_TARGET_BEFORE" >&2
  echo "  after:  $HOOKS_TARGET_AFTER" >&2
  exit 1
fi

TM_CANARY_TARGET_AFTER="$(readlink "$HOME/.claude/team-memory/$TM_ROLE_CANARY")"
if [ "$TM_CANARY_TARGET_BEFORE" != "$TM_CANARY_TARGET_AFTER" ]; then
  echo "FAIL: AC10.a: team-memory/$TM_ROLE_CANARY symlink was modified by migrate" >&2
  echo "  before: $TM_CANARY_TARGET_BEFORE" >&2
  echo "  after:  $TM_CANARY_TARGET_AFTER" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 8 — AC9.b: consumer-local migration artifacts must be present
#
# After migrate, the consumer must have a local .claude tree wired to its
# own copy of the hooks (consumer-local), not the global install paths.
# ---------------------------------------------------------------------------
MANIFEST="$CONSUMER/.claude/scaff.manifest"
if [ ! -f "$MANIFEST" ]; then
  echo "FAIL: AC9.b: .claude/scaff.manifest not created by migrate" >&2
  exit 1
fi

# settings.json must now reference consumer-local hook paths, not the
# old global-install paths.  A consumer-local path contains ".claude/hooks".
SETTINGS_CONTENT="$(cat "$CONSUMER/settings.json")"
if ! printf '%s\n' "$SETTINGS_CONTENT" | grep -q '\.claude/hooks/session-start\.sh'; then
  echo "FAIL: AC9.b: settings.json does not reference consumer-local session-start.sh" >&2
  echo "--- settings.json ---" >&2
  printf '%s\n' "$SETTINGS_CONTENT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Step 9 — AC9.b idempotent re-run
#
# Second migrate must exit 0 and report every path as "already" (no-op).
# Consumer state must be byte-identical to the state after the first run.
# ---------------------------------------------------------------------------

# Capture consumer filesystem fingerprint after the first run.  Exclude .git
# because git internals (index timestamps etc.) can change independently.
cons_hash() {
  find "$CONSUMER" -not -path '*/.git/*' -type f | sort | xargs shasum | shasum | awk '{print $1}'
}
CONS_HASH_1="$(cons_hash)"

MIGRATE2_OUT="$SANDBOX/migrate2.out"
set +e
(cd "$CONSUMER" && "$SEED" migrate --from "$REPO_ROOT") > "$MIGRATE2_OUT" 2>&1
MIGRATE2_RC=$?
set -e

if [ "$MIGRATE2_RC" -ne 0 ]; then
  echo "FAIL: AC9.b: second migrate exited $MIGRATE2_RC, expected 0" >&2
  echo "--- migrate2 output ---" >&2
  cat "$MIGRATE2_OUT" >&2
  exit 1
fi

# Every action line in the second run must be "already" (idempotency proof).
# Non-already lines (skipped: or created: etc.) would indicate the first run
# left the consumer in a non-idempotent state.
NON_ALREADY="$(grep -v 'already' "$MIGRATE2_OUT" || true)"
if [ -n "$NON_ALREADY" ]; then
  echo "FAIL: AC9.b: second migrate produced non-already output lines" >&2
  printf '%s\n' "$NON_ALREADY" >&2
  exit 1
fi

CONS_HASH_2="$(cons_hash)"
if [ "$CONS_HASH_1" != "$CONS_HASH_2" ]; then
  echo "FAIL: AC9.b: consumer state changed between first and second migrate" >&2
  echo "  hash1: $CONS_HASH_1" >&2
  echo "  hash2: $CONS_HASH_2" >&2
  exit 1
fi

echo "PASS"
exit 0
