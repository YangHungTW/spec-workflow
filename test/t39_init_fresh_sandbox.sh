#!/usr/bin/env bash
# test/t39_init_fresh_sandbox.sh — smoke test for `specflow-seed init` on a fresh consumer repo.
# Verifies: AC1.a (files are regular + byte-match source), AC1.c (no symlinks under .claude/),
# AC2.a (self-contained install, manifest present, settings.json wired with consumer-local hooks),
# AC4.a (team-memory skeleton: role dirs with index.md only), AC5.a (rules byte-identical),
# and manifest specflow_ref matches the captured SHA.
#
# RED pre-T3: cmd_init stub emits "not-yet-implemented" — that is the expected failure state.
# GREEN post-T3 merge: all assertions pass.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SPECFLOW_SRC="${SPECFLOW_SRC:-$REPO_ROOT}"
SEED="${SEED:-$SPECFLOW_SRC/bin/specflow-seed}"

# ---------------------------------------------------------------------------
# Sandbox + HOME isolation (sandbox-home-in-tests.md — non-negotiable)
# Capture real HOME before sandboxing so asdf .tool-versions can be copied in.
# ---------------------------------------------------------------------------
_REAL_HOME="$HOME"
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t specflow-t39)"
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
# Build a minimal consumer git repo so repo_root resolves inside cmd_init
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
git init -q "$CONSUMER"
git -C "$CONSUMER" config user.email "t@example.com"
git -C "$CONSUMER" config user.name "t"
printf '*.log\n' > "$CONSUMER/.gitignore"
git -C "$CONSUMER" add .gitignore
git -C "$CONSUMER" commit -q -m "init"

# Capture the source HEAD SHA before running init; used for manifest ref-sniff.
AT_REF="$(git -C "$SPECFLOW_SRC" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Run init
# ---------------------------------------------------------------------------
cd "$CONSUMER"
"$SEED" init --from "$SPECFLOW_SRC" --ref "$AT_REF"
cd "$SANDBOX"

# ---------------------------------------------------------------------------
# Helper: fail with label and reason, then exit 1
# ---------------------------------------------------------------------------
fail() {
  echo "FAIL: $1: $2" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# AC1.a — every managed file under agents/specflow, commands/specflow, hooks
#          is a regular file (not a symlink) whose bytes match the source.
# ---------------------------------------------------------------------------
for subdir in ".claude/agents/specflow" ".claude/commands/specflow" ".claude/hooks"; do
  src_dir="$SPECFLOW_SRC/$subdir"
  dst_dir="$CONSUMER/$subdir"
  [ -d "$src_dir" ] || continue
  while IFS= read -r src_file; do
    rel="${src_file#$src_dir/}"
    dst_file="$dst_dir/$rel"
    [ -f "$dst_file" ] || fail "AC1.a" "missing regular file: $subdir/$rel"
    [ -L "$dst_file" ] && fail "AC1.a" "symlink found where regular file expected: $subdir/$rel"
    src_sum="$(shasum "$src_file" | awk '{print $1}')"
    dst_sum="$(shasum "$dst_file" | awk '{print $1}')"
    [ "$src_sum" = "$dst_sum" ] || fail "AC1.a" "byte mismatch: $subdir/$rel (src=$src_sum dst=$dst_sum)"
  done < <(find "$src_dir" -type f)
done

# ---------------------------------------------------------------------------
# AC1.c — no symlinks anywhere under the consumer's .claude/ tree
# ---------------------------------------------------------------------------
symlink_count="$(find "$CONSUMER/.claude" -type l | wc -l | tr -d ' ')"
[ "$symlink_count" = "0" ] || fail "AC1.c" "$symlink_count symlink(s) found under $CONSUMER/.claude"

# ---------------------------------------------------------------------------
# AC2.a — key directories populated; manifest present; settings.json wired
#          with consumer-local hook paths (not ~/.claude/hooks/…)
# ---------------------------------------------------------------------------
for subdir in ".claude/agents/specflow" ".claude/commands/specflow" ".claude/hooks" ".claude/rules" ".spec-workflow/features/_template"; do
  dir_count="$(find "$CONSUMER/$subdir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
  [ "$dir_count" -gt 0 ] || fail "AC2.a" "$subdir is empty or missing"
done

[ -f "$CONSUMER/.claude/specflow.manifest" ] || fail "AC2.a" "specflow.manifest not found"

SETTINGS="$CONSUMER/settings.json"
[ -f "$SETTINGS" ] || fail "AC2.a" "settings.json not found"

# settings.json must contain exactly one SessionStart and one Stop command entry,
# both referencing .claude/hooks/ (consumer-local), never ~/.claude/hooks/.
session_count="$(grep -c '"SessionStart"' "$SETTINGS" || true)"
stop_count="$(grep -c '"Stop"' "$SETTINGS" || true)"
[ "$session_count" -ge 1 ] || fail "AC2.a" "settings.json missing SessionStart entry"
[ "$stop_count" -ge 1 ] || fail "AC2.a" "settings.json missing Stop entry"

# Both hook command strings must point to .claude/hooks/ (relative, consumer-local),
# never to the tilde-expanded home path.
if grep -q 'HOME\|~/.claude' "$SETTINGS" 2>/dev/null; then
  fail "AC2.a" "settings.json contains non-consumer-local hook path (~/.claude or HOME)"
fi

# ---------------------------------------------------------------------------
# AC4.a — team-memory skeleton: role dirs have index.md only (no inherited lessons)
# ---------------------------------------------------------------------------
expected_roles="$(ls "$SPECFLOW_SRC/.claude/team-memory/" | grep -v 'README.md')"
while IFS= read -r role; do
  role_dir="$CONSUMER/.claude/team-memory/$role"
  [ -d "$role_dir" ] || fail "AC4.a" "team-memory role dir missing: $role"
done <<EOF
$expected_roles
EOF

# No .md file under team-memory other than index.md and README.md (no inherited lessons)
extra_md="$(find "$CONSUMER/.claude/team-memory" -name '*.md' -not -name 'index.md' -not -name 'README.md' | wc -l | tr -d ' ')"
[ "$extra_md" = "0" ] || fail "AC4.a" "$extra_md unexpected .md file(s) under team-memory (inherited lessons must not be copied)"

# ---------------------------------------------------------------------------
# AC5.a — every file under .claude/rules/ is byte-identical to its source
# ---------------------------------------------------------------------------
src_rules="$SPECFLOW_SRC/.claude/rules"
dst_rules="$CONSUMER/.claude/rules"
[ -d "$dst_rules" ] || fail "AC5.a" ".claude/rules not found in consumer"
while IFS= read -r src_file; do
  rel="${src_file#$src_rules/}"
  dst_file="$dst_rules/$rel"
  [ -f "$dst_file" ] || fail "AC5.a" "rules file missing: $rel"
  src_sum="$(shasum "$src_file" | awk '{print $1}')"
  dst_sum="$(shasum "$dst_file" | awk '{print $1}')"
  [ "$src_sum" = "$dst_sum" ] || fail "AC5.a" "rules byte mismatch: $rel"
done < <(find "$src_rules" -type f)

# ---------------------------------------------------------------------------
# Manifest specflow_ref matches captured SHA (D3 awk-sniff pattern)
# ---------------------------------------------------------------------------
manifest_ref="$(awk -F'"' '/"specflow_ref"/ { print $4; exit }' "$CONSUMER/.claude/specflow.manifest")"
[ "$manifest_ref" = "$AT_REF" ] || fail "manifest-ref" "specflow_ref mismatch: manifest=$manifest_ref expected=$AT_REF"

echo "PASS"
