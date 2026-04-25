#!/usr/bin/env bash
# test/t110_runtime_sandbox_acs.sh
#
# T9 — Runtime sandbox harness for AC7, AC8, AC10, AC11 (plus AC9 structural).
#
# Extracts the SCAFF PREFLIGHT fenced block from .specaffold/preflight.md and
# runs it directly inside sandbox CWDs to verify runtime behaviour.
#
# Assertions:
#   A1 (AC7)  — refusal happy path: exit 70, REFUSED:PREFLIGHT, expected tokens,
#               CWD in message, exactly one non-empty output line.
#   A2 (AC8)  — zero side effects: filesystem hash identical before/after;
#               no .specaffold/, STATUS.md, or .git created.
#   A3 (AC10) — passthrough on present config: exit 0, silent (empty output).
#   A4 (AC11) — malformed config still passes: zero-byte and non-YAML config
#               both exit 0 with empty output.
#   A5 (AC9)  — exempt path is structurally satisfied: .claude/commands/scaff/scaff-init.md
#               does not exist; the gate cannot fire on the exempt path.
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only flags.
#   No `case` inside subshells (bash32-case-in-subshell.md).
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md:
#   applied uniformly even though the gate under test does not touch $HOME.

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
# Block extraction — done once, up front, before any fixture runs
# ---------------------------------------------------------------------------
PREFLIGHT_MD="$REPO_ROOT/.specaffold/preflight.md"
if [ ! -f "$PREFLIGHT_MD" ]; then
  printf 'FAIL: %s missing — T1 has not merged yet\n' "$PREFLIGHT_MD" >&2
  exit 1
fi

BLOCK="$(awk '/^# === SCAFF PREFLIGHT/,/^# === END SCAFF PREFLIGHT/' "$PREFLIGHT_MD")"
printf '%s\n' "$BLOCK" > "$SANDBOX/preflight.sh"

# ---------------------------------------------------------------------------
# A1 — AC7: refusal happy path
# ---------------------------------------------------------------------------
printf '=== A1: AC7 — refusal happy path ===\n'

mkdir -p "$SANDBOX/proj-noinit"
OUT="$(cd "$SANDBOX/proj-noinit" && bash "$SANDBOX/preflight.sh" 2>&1)" \
  && EXIT=0 || EXIT=$?

if [ "$EXIT" = "70" ]; then
  pass "A1: exit code is 70"
else
  fail "A1: expected exit 70, got $EXIT"
fi

if printf '%s\n' "$OUT" | grep -qF 'REFUSED:PREFLIGHT'; then
  pass "A1: output contains REFUSED:PREFLIGHT"
else
  fail "A1: output does not contain REFUSED:PREFLIGHT (got: $OUT)"
fi

if printf '%s\n' "$OUT" | grep -qF '.specaffold/config.yml'; then
  pass "A1: output contains .specaffold/config.yml"
else
  fail "A1: output does not contain .specaffold/config.yml (got: $OUT)"
fi

if printf '%s\n' "$OUT" | grep -qF '/scaff-init'; then
  pass "A1: output contains /scaff-init"
else
  fail "A1: output does not contain /scaff-init (got: $OUT)"
fi

if printf '%s\n' "$OUT" | grep -qF "$SANDBOX/proj-noinit"; then
  pass "A1: output contains runtime CWD ($SANDBOX/proj-noinit)"
else
  fail "A1: output does not contain runtime CWD ($SANDBOX/proj-noinit) (got: $OUT)"
fi

# Exactly one non-empty line
NONEMPTY_COUNT="$(printf '%s\n' "$OUT" | grep -c '^.\{1,\}$' || true)"
if [ "$NONEMPTY_COUNT" = "1" ]; then
  pass "A1: output is exactly one non-empty line"
else
  fail "A1: expected exactly 1 non-empty line, got $NONEMPTY_COUNT (out: $OUT)"
fi

# ---------------------------------------------------------------------------
# A2 — AC8: zero side effects
# ---------------------------------------------------------------------------
printf '\n=== A2: AC8 — zero side effects ===\n'

BEFORE="$(find "$SANDBOX/proj-noinit" -ls 2>/dev/null | sort | shasum | awk '{print $1}')"
cd "$SANDBOX/proj-noinit" && bash "$SANDBOX/preflight.sh" > /dev/null 2>&1 || true
AFTER="$(find "$SANDBOX/proj-noinit" -ls 2>/dev/null | sort | shasum | awk '{print $1}')"

if [ "$BEFORE" = "$AFTER" ]; then
  pass "A2: filesystem hash identical before/after (no side effects)"
else
  fail "A2: filesystem hash changed — gate left side effects"
fi

if [ ! -d "$SANDBOX/proj-noinit/.specaffold" ]; then
  pass "A2: .specaffold/ not created"
else
  fail "A2: .specaffold/ was created unexpectedly"
fi

if [ ! -f "$SANDBOX/proj-noinit/STATUS.md" ]; then
  pass "A2: STATUS.md not created"
else
  fail "A2: STATUS.md was created unexpectedly"
fi

if [ ! -d "$SANDBOX/proj-noinit/.git" ]; then
  pass "A2: .git/ not created"
else
  fail "A2: .git/ was created unexpectedly"
fi

# ---------------------------------------------------------------------------
# A3 — AC10: passthrough on present config
# ---------------------------------------------------------------------------
printf '\n=== A3: AC10 — passthrough on present config ===\n'

mkdir -p "$SANDBOX/proj-init/.specaffold"
touch "$SANDBOX/proj-init/.specaffold/config.yml"

OUT3="$(cd "$SANDBOX/proj-init" && bash "$SANDBOX/preflight.sh" 2>&1)" \
  && EXIT3=0 || EXIT3=$?

if [ "$EXIT3" = "0" ]; then
  pass "A3: exit code is 0 (passthrough)"
else
  fail "A3: expected exit 0, got $EXIT3"
fi

if [ -z "$OUT3" ]; then
  pass "A3: output is empty (silent passthrough per R7)"
else
  fail "A3: expected empty output, got: $OUT3"
fi

# ---------------------------------------------------------------------------
# A4 — AC11: malformed config still passes
# ---------------------------------------------------------------------------
printf '\n=== A4: AC11 — malformed config still passes ===\n'

# Sub-fixture (a): zero-byte config
printf '' > "$SANDBOX/proj-init/.specaffold/config.yml"

OUT4A="$(cd "$SANDBOX/proj-init" && bash "$SANDBOX/preflight.sh" 2>&1)" \
  && EXIT4A=0 || EXIT4A=$?

if [ "$EXIT4A" = "0" ]; then
  pass "A4a: zero-byte config — exit 0"
else
  fail "A4a: zero-byte config — expected exit 0, got $EXIT4A"
fi

if [ -z "$OUT4A" ]; then
  pass "A4a: zero-byte config — output is empty"
else
  fail "A4a: zero-byte config — expected empty output, got: $OUT4A"
fi

# Sub-fixture (b): non-YAML garbage content
printf 'not yaml at all\n@@@\n' > "$SANDBOX/proj-init/.specaffold/config.yml"

OUT4B="$(cd "$SANDBOX/proj-init" && bash "$SANDBOX/preflight.sh" 2>&1)" \
  && EXIT4B=0 || EXIT4B=$?

if [ "$EXIT4B" = "0" ]; then
  pass "A4b: non-YAML config — exit 0"
else
  fail "A4b: non-YAML config — expected exit 0, got $EXIT4B"
fi

if [ -z "$OUT4B" ]; then
  pass "A4b: non-YAML config — output is empty"
else
  fail "A4b: non-YAML config — expected empty output, got: $OUT4B"
fi

# ---------------------------------------------------------------------------
# A5 — AC9: exempt path is structurally satisfied
# ---------------------------------------------------------------------------
printf '\n=== A5: AC9 — exempt path structurally satisfied (D8) ===\n'

if [ ! -e "$REPO_ROOT/.claude/commands/scaff/scaff-init.md" ]; then
  pass "A5: .claude/commands/scaff/scaff-init.md does not exist — gate cannot fire on exempt path"
else
  fail "A5: .claude/commands/scaff/scaff-init.md exists unexpectedly — AC9 exemption violated (D8)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: t110\n'
  exit 0
else
  printf 'FAIL: t110 — %d assertion(s) failed\n' "$FAIL_COUNT" >&2
  exit 1
fi
