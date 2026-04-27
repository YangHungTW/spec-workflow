#!/usr/bin/env bash
# t114 — regression test for 20260426-chore-seed-copies-settings
# Verifies scaff-seed init seeds .claude/settings.json via read-merge-write.
# Covers:
#   A1: fresh-install path — no prior settings.json → file created with SessionStart hook
#   A2: merge path — pre-existing settings.json with unrelated key preserved + hook added + .bak written
#   A3: update-mode parity — scaff-seed update does NOT touch settings.json
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only flags.
#   No `case` inside subshells (bash32-case-in-subshell.md).
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md.

set -euo pipefail

# ---------------------------------------------------------------------------
# Sandbox HOME — uniform discipline per sandbox-home-in-tests.md
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME (POSIX case, no `[[`)
case "$HOME" in
  "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ---------------------------------------------------------------------------
# Failure accumulator — collect all failures before exiting
# ---------------------------------------------------------------------------
FAIL_COUNT=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

pass() {
  printf 'PASS: %s\n' "$1"
}

# ---------------------------------------------------------------------------
# Helper: build a minimal consumer git repo
# ---------------------------------------------------------------------------
make_consumer() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "t@example.com"
  git -C "$dir" config user.name "t"
  printf '*.log\n' > "$dir/.gitignore"
  git -C "$dir" add .gitignore
  git -C "$dir" commit -q -m "init"
}

SRC_REF="$(git -C "$REPO_ROOT" rev-parse HEAD)"

# ===========================================================================
# A1 — fresh-install path
# No prior .claude/settings.json in consumer; after scaff-seed init the file
# must contain a hooks.SessionStart[*].hooks[*].command referencing session-start.sh.
# ===========================================================================
printf '=== A1: fresh-install path ===\n'

CONSUMER1="$SANDBOX/consumer1"
make_consumer "$CONSUMER1"

# Run scaff-seed init (suppress output; capture exit code)
INIT1_EXIT=0
(cd "$CONSUMER1" && PATH=/usr/bin:/bin:$PATH \
  "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref "$SRC_REF") \
  > /dev/null 2>&1 || INIT1_EXIT=$?

if [ "$INIT1_EXIT" = "0" ]; then
  pass "A1: scaff-seed init exited 0"
else
  fail "A1: scaff-seed init exited $INIT1_EXIT (expected 0)"
fi

SETTINGS1="$CONSUMER1/.claude/settings.json"
if [ -f "$SETTINGS1" ]; then
  pass "A1: .claude/settings.json exists after init"
else
  fail "A1: .claude/settings.json missing after init"
fi

# Extract the command value via python3 (no jq — bash-32-portability.md)
CMD1=""
if [ -f "$SETTINGS1" ]; then
  CMD1="$(python3 - "$SETTINGS1" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
hooks = data.get("hooks", {})
ss = hooks.get("SessionStart", [])
for grp in ss:
    for h in grp.get("hooks", []):
        if h.get("type") == "command" and h.get("command"):
            print(h["command"])
            raise SystemExit(0)
PYEOF
  )" || true
fi

if printf '%s\n' "$CMD1" | grep -qF '.claude/hooks/session-start.sh'; then
  pass "A1: SessionStart command references .claude/hooks/session-start.sh"
else
  fail "A1: SessionStart command missing or wrong: '$CMD1'"
fi

# ===========================================================================
# A2 — merge path
# Pre-existing settings.json with an unrelated top-level key (permissions)
# and no hooks block. After scaff-seed init:
#   (a) unrelated key preserved
#   (b) SessionStart hook command added
#   (c) .claude/settings.json.bak exists with original content
# ===========================================================================
printf '\n=== A2: merge path ===\n'

CONSUMER2="$SANDBOX/consumer2"
make_consumer "$CONSUMER2"
mkdir -p "$CONSUMER2/.claude"

# Pre-create settings.json with an unrelated key and no hooks block
python3 - "$CONSUMER2/.claude/settings.json" <<'PYEOF'
import json, sys
data = {"permissions": {"allow": ["Bash(*)", "Read(*)", "Write(*)"]}}
with open(sys.argv[1], "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

ORIGINAL_CONTENT="$(cat "$CONSUMER2/.claude/settings.json")"

# Run scaff-seed init
INIT2_EXIT=0
(cd "$CONSUMER2" && PATH=/usr/bin:/bin:$PATH \
  "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref "$SRC_REF") \
  > /dev/null 2>&1 || INIT2_EXIT=$?

if [ "$INIT2_EXIT" = "0" ]; then
  pass "A2: scaff-seed init exited 0"
else
  fail "A2: scaff-seed init exited $INIT2_EXIT (expected 0)"
fi

SETTINGS2="$CONSUMER2/.claude/settings.json"

# (a) unrelated key preserved
HAS_PERMS="$(python3 - "$SETTINGS2" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print("yes" if "permissions" in data else "no")
PYEOF
)"
if [ "$HAS_PERMS" = "yes" ]; then
  pass "A2a: pre-existing permissions key preserved"
else
  fail "A2a: pre-existing permissions key lost after merge"
fi

# (b) SessionStart hook command added
CMD2=""
CMD2="$(python3 - "$SETTINGS2" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
hooks = data.get("hooks", {})
ss = hooks.get("SessionStart", [])
for grp in ss:
    for h in grp.get("hooks", []):
        if h.get("type") == "command" and h.get("command"):
            print(h["command"])
            raise SystemExit(0)
PYEOF
)" || true

if printf '%s\n' "$CMD2" | grep -qF '.claude/hooks/session-start.sh'; then
  pass "A2b: SessionStart hook command added during merge"
else
  fail "A2b: SessionStart hook command missing after merge: '$CMD2'"
fi

# (c) .bak exists with original content
BAK2="$CONSUMER2/.claude/settings.json.bak"
if [ -f "$BAK2" ]; then
  pass "A2c: .claude/settings.json.bak exists"
else
  fail "A2c: .claude/settings.json.bak missing after merge"
fi

HAS_PERMS_IN_BAK="$(python3 - "$BAK2" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print("yes" if "permissions" in data else "no")
PYEOF
)"
if [ "$HAS_PERMS_IN_BAK" = "yes" ]; then
  pass "A2c: .bak contains permissions key (pre-merge user data preserved in backup)"
else
  fail "A2c: .bak missing permissions key — backup does not contain user data"
fi

# ===========================================================================
# A3 — update-mode parity
# scaff-seed update must NOT touch .claude/settings.json.
# Seed a consumer, then place a known settings.json content; run update;
# assert the file is byte-identical afterward.
# ===========================================================================
printf '\n=== A3: update-mode parity ===\n'

CONSUMER3="$SANDBOX/consumer3"
make_consumer "$CONSUMER3"

# Run scaff-seed init first so the manifest exists
(cd "$CONSUMER3" && PATH=/usr/bin:/bin:$PATH \
  "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref "$SRC_REF") \
  > /dev/null 2>&1 || true

# Now overwrite settings.json with a known sentinel value
SENTINEL='{"sentinel": "update-must-not-touch"}'
python3 - "$CONSUMER3/.claude/settings.json" <<'PYEOF'
import json, sys
data = {"sentinel": "update-must-not-touch"}
with open(sys.argv[1], "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

BEFORE="$(cat "$CONSUMER3/.claude/settings.json")"

# Run scaff-seed update
UPDATE_EXIT=0
(cd "$CONSUMER3" && PATH=/usr/bin:/bin:$PATH \
  "$REPO_ROOT/bin/scaff-seed" update --from "$REPO_ROOT" --to "$SRC_REF") \
  > /dev/null 2>&1 || UPDATE_EXIT=$?

# Exit code 1 is acceptable (user-modified files may be skipped); 0 also fine
if [ "$UPDATE_EXIT" = "0" ] || [ "$UPDATE_EXIT" = "1" ]; then
  pass "A3: scaff-seed update exited $UPDATE_EXIT (acceptable)"
else
  fail "A3: scaff-seed update exited $UPDATE_EXIT (expected 0 or 1)"
fi

AFTER="$(cat "$CONSUMER3/.claude/settings.json")"
if [ "$BEFORE" = "$AFTER" ]; then
  pass "A3: settings.json byte-identical after update (update did not touch it)"
else
  fail "A3: settings.json was modified by update (expected no change)"
fi

# ===========================================================================
# A4 — migrate path
# Pre-init a consumer, then run scaff-seed migrate --from "$REPO_ROOT".
# Asserts:
#   (a) exit 0
#   (b) post-migrate .claude/settings.json contains SessionStart hook command
#       referencing .claude/hooks/session-start.sh  (mirror of A1)
#   (c) merge sub-case: pre-existing settings.json triggers .bak creation
#       (mirror of A2c)
# ===========================================================================
printf '\n=== A4: migrate path ===\n'

CONSUMER4="$SANDBOX/consumer4"
make_consumer "$CONSUMER4"

# Pre-init so cmd_migrate takes the wiring-rewrite path (not init-from-scratch).
(cd "$CONSUMER4" && PATH=/usr/bin:/bin:$PATH \
  "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref "$SRC_REF") \
  > /dev/null 2>&1 || true

# Run scaff-seed migrate (captures exit code without aborting on non-zero)
MIGRATE4_EXIT=0
(cd "$CONSUMER4" && PATH=/usr/bin:/bin:$PATH \
  "$REPO_ROOT/bin/scaff-seed" migrate --from "$REPO_ROOT") \
  > /dev/null 2>&1 || MIGRATE4_EXIT=$?

if [ "$MIGRATE4_EXIT" = "0" ]; then
  pass "A4: scaff-seed migrate exited 0"
else
  fail "A4: scaff-seed migrate exited $MIGRATE4_EXIT (expected 0)"
fi

SETTINGS4="$CONSUMER4/.claude/settings.json"
if [ -f "$SETTINGS4" ]; then
  pass "A4: .claude/settings.json exists after migrate"
else
  fail "A4: .claude/settings.json missing after migrate"
fi

# Extract the SessionStart hook command via python3 (no jq — bash-32-portability.md)
CMD4=""
if [ -f "$SETTINGS4" ]; then
  CMD4="$(python3 - "$SETTINGS4" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
hooks = data.get("hooks", {})
ss = hooks.get("SessionStart", [])
for grp in ss:
    for h in grp.get("hooks", []):
        if h.get("type") == "command" and h.get("command"):
            print(h["command"])
            raise SystemExit(0)
PYEOF
  )" || true
fi

if printf '%s\n' "$CMD4" | grep -qF '.claude/hooks/session-start.sh'; then
  pass "A4: SessionStart command references .claude/hooks/session-start.sh"
else
  fail "A4: SessionStart command missing or wrong: '$CMD4'"
fi

# A4 merge sub-case: pre-existing settings.json triggers .bak creation
# Use a separate consumer so the pre-existing file state is clean.
CONSUMER4B="$SANDBOX/consumer4b"
make_consumer "$CONSUMER4B"
mkdir -p "$CONSUMER4B/.claude"

# Pre-init to author the manifest (wiring-rewrite path for migrate)
(cd "$CONSUMER4B" && PATH=/usr/bin:/bin:$PATH \
  "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref "$SRC_REF") \
  > /dev/null 2>&1 || true

# Overwrite settings.json with an unrelated key (no hooks block)
python3 - "$CONSUMER4B/.claude/settings.json" <<'PYEOF'
import json, sys
data = {"permissions": {"allow": ["Bash(*)", "Read(*)", "Write(*)"]}}
with open(sys.argv[1], "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF

# Run scaff-seed migrate — should merge and produce .bak
MIGRATE4B_EXIT=0
(cd "$CONSUMER4B" && PATH=/usr/bin:/bin:$PATH \
  "$REPO_ROOT/bin/scaff-seed" migrate --from "$REPO_ROOT") \
  > /dev/null 2>&1 || MIGRATE4B_EXIT=$?

if [ "$MIGRATE4B_EXIT" = "0" ]; then
  pass "A4: merge sub-case: scaff-seed migrate exited 0"
else
  fail "A4: merge sub-case: scaff-seed migrate exited $MIGRATE4B_EXIT (expected 0)"
fi

BAK4B="$CONSUMER4B/.claude/settings.json.bak"
if [ -f "$BAK4B" ]; then
  pass "A4: merge sub-case: .claude/settings.json.bak exists"
else
  fail "A4: merge sub-case: .claude/settings.json.bak missing after migrate"
fi

# ===========================================================================
# A5 — bug-fix regression: scaff-seed init must NOT create root-level
# settings.json/.bak; both SessionStart and Stop hooks must land at
# .claude/settings.json with the "bash ..." command form (R1, R5, R6, AC1-AC3).
# ===========================================================================
printf '\n=== A5: bug-fix regression (no root-level settings.json; bash prefix) ===\n'

CONSUMER5="$SANDBOX/consumer5"
make_consumer "$CONSUMER5"

# First run
INIT5_EXIT=0
(cd "$CONSUMER5" && PATH=/usr/bin:/bin:$PATH \
  "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref "$SRC_REF") \
  > /dev/null 2>&1 || INIT5_EXIT=$?

if [ "$INIT5_EXIT" = "0" ]; then
  pass "A5: scaff-seed init exited 0"
else
  fail "A5: scaff-seed init exited $INIT5_EXIT (expected 0)"
fi

# AC1: no root-level settings.json or .bak
if [ ! -e "$CONSUMER5/settings.json" ]; then
  pass "A5: no root-level settings.json (AC1)"
else
  fail "A5: stray root-level settings.json found (AC1 violation)"
fi

if [ ! -e "$CONSUMER5/settings.json.bak" ]; then
  pass "A5: no root-level settings.json.bak (AC1)"
else
  fail "A5: stray root-level settings.json.bak found (AC1 violation)"
fi

# AC2: .claude/settings.json exists with "bash ..." command form (R6)
SETTINGS5="$CONSUMER5/.claude/settings.json"
if [ -f "$SETTINGS5" ]; then
  pass "A5: .claude/settings.json exists (AC2)"
else
  fail "A5: .claude/settings.json missing after init (AC2)"
fi

# Extract SessionStart command (no jq — bash-32-portability.md)
SS_CMD5=""
if [ -f "$SETTINGS5" ]; then
  SS_CMD5="$(python3 - "$SETTINGS5" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
ss = data.get("hooks", {}).get("SessionStart", [])
for grp in ss:
    for h in grp.get("hooks", []):
        if h.get("type") == "command" and h.get("command"):
            print(h["command"])
            raise SystemExit(0)
PYEOF
  )" || true
fi

if [ "$SS_CMD5" = "bash .claude/hooks/session-start.sh" ]; then
  pass "A5: SessionStart command is 'bash .claude/hooks/session-start.sh' (R6/AC2)"
else
  fail "A5: SessionStart command wrong: '$SS_CMD5' (expected 'bash .claude/hooks/session-start.sh')"
fi

# Extract Stop command
STOP_CMD5=""
if [ -f "$SETTINGS5" ]; then
  STOP_CMD5="$(python3 - "$SETTINGS5" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
st = data.get("hooks", {}).get("Stop", [])
for grp in st:
    for h in grp.get("hooks", []):
        if h.get("type") == "command" and h.get("command"):
            print(h["command"])
            raise SystemExit(0)
PYEOF
  )" || true
fi

if [ "$STOP_CMD5" = "bash .claude/hooks/stop.sh" ]; then
  pass "A5: Stop command is 'bash .claude/hooks/stop.sh' (R6/AC2)"
else
  fail "A5: Stop command wrong: '$STOP_CMD5' (expected 'bash .claude/hooks/stop.sh')"
fi

# AC3: idempotency — second run leaves settings.json byte-identical
BEFORE5="$(cat "$SETTINGS5")"

INIT5B_EXIT=0
(cd "$CONSUMER5" && PATH=/usr/bin:/bin:$PATH \
  "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref "$SRC_REF") \
  > /dev/null 2>&1 || INIT5B_EXIT=$?

if [ "$INIT5B_EXIT" = "0" ]; then
  pass "A5: second scaff-seed init exited 0 (AC3)"
else
  fail "A5: second scaff-seed init exited $INIT5B_EXIT (expected 0) (AC3)"
fi

AFTER5="$(cat "$SETTINGS5")"
if [ "$BEFORE5" = "$AFTER5" ]; then
  pass "A5: .claude/settings.json byte-identical after second init — no duplicate entries (AC3)"
else
  fail "A5: .claude/settings.json changed after second init — not idempotent (AC3)"
fi

# ===========================================================================
# Summary
# ===========================================================================
printf '\n'
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: t114\n'
  exit 0
else
  printf 'FAIL: t114 — %d assertion(s) failed\n' "$FAIL_COUNT" >&2
  exit 1
fi
