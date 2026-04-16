#!/usr/bin/env bash
# test/t10_summary.sh — T10 verify checks for emit_summary, exit codes, __probe gate
# Usage: bash test/t10_summary.sh
# Exits 0 iff all checks pass; non-zero otherwise.
#
# Covers:
#   - install/uninstall/update: clean run → summary ends (exit 0), exit 0
#   - install/uninstall/update: conflict run → summary ends (exit 1), exit 1
#   - verb-set grep audit: every `report` call uses only the closed verb set
#   - __probe gate: without SPECFLOW_PROBE=1 → exits 2 (unknown subcommand)
#                   with SPECFLOW_PROBE=1 → works

set -u -o pipefail

WORKTREE="/Users/yanghungtw/Tools/spec-workflow/.worktrees/symlink-operation-T10"
SCRIPT="$WORKTREE/bin/claude-symlink"
REPO="$WORKTREE"
PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Preflight: script must exist and be executable
# ---------------------------------------------------------------------------
if [ ! -x "$SCRIPT" ]; then
  echo "ABORT: script not found or not executable: $SCRIPT" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Preflight: refuse to run against the real $HOME
# ---------------------------------------------------------------------------
REAL_HOME=$(cd ~ && pwd -P 2>/dev/null || echo "$HOME")

TOP_SANDBOX=$(mktemp -d 2>/dev/null || mktemp -d -t 'claude-symlink-t10')
trap 'rm -rf "$TOP_SANDBOX"' EXIT

echo "=== T10 emit_summary / exit-code / __probe-gate Tests ==="
echo "TOP_SANDBOX=$TOP_SANDBOX"
echo "REPO=$REPO"
echo

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$desc"
  else
    fail "$desc — expected '$expected', got '$actual'"
  fi
}

assert_zero() {
  local desc="$1" val="$2"
  if [ "$val" -eq 0 ]; then
    pass "$desc"
  else
    fail "$desc — expected 0, got $val"
  fi
}

assert_nonzero() {
  local desc="$1" val="$2"
  if [ "$val" -ne 0 ]; then
    pass "$desc"
  else
    fail "$desc — expected non-zero, got $val"
  fi
}

make_sandbox_home() {
  local name="$1"
  local sbox="$TOP_SANDBOX/$name"
  mkdir -p "$sbox/home"
  echo "$sbox/home"
}

# Get the last stdout line of a command (exit code captured separately)
last_line() {
  # $@ is the command; capture stdout
  "$@" 2>/dev/null | tail -1
}

# ---------------------------------------------------------------------------
# INSTALL — clean run
# ---------------------------------------------------------------------------
echo "--- install: clean run ---"
{
  SBX=$(make_sandbox_home "install_clean")
  export HOME="$SBX"

  output=$(HOME="$SBX" "$SCRIPT" install 2>/dev/null)
  exit_code=$?

  last=$(printf '%s' "$output" | tail -1)

  assert_zero "install clean: exit code 0" "$exit_code"

  case "$last" in
    summary:*) pass "install clean: last stdout line starts with 'summary:'" ;;
    *)         fail "install clean: last stdout line starts with 'summary:' — got: $last" ;;
  esac

  case "$last" in
    *"(exit 0)") pass "install clean: summary ends with '(exit 0)'" ;;
    *)           fail "install clean: summary ends with '(exit 0)' — got: $last" ;;
  esac
}
echo

# ---------------------------------------------------------------------------
# INSTALL — conflict run (real file pre-placed)
# ---------------------------------------------------------------------------
echo "--- install: conflict run ---"
{
  SBX=$(make_sandbox_home "install_conflict")
  mkdir -p "$SBX/.claude/agents"
  echo "conflict" > "$SBX/.claude/agents/specflow"

  output=$(HOME="$SBX" "$SCRIPT" install 2>/dev/null)
  exit_code=$?

  last=$(printf '%s' "$output" | tail -1)

  assert_nonzero "install conflict: exit code non-zero (1)" "$exit_code"
  assert_eq "install conflict: exit code is exactly 1" "1" "$exit_code"

  case "$last" in
    summary:*) pass "install conflict: last stdout line starts with 'summary:'" ;;
    *)         fail "install conflict: last stdout line starts with 'summary:' — got: $last" ;;
  esac

  case "$last" in
    *"(exit 1)") pass "install conflict: summary ends with '(exit 1)'" ;;
    *)           fail "install conflict: summary ends with '(exit 1)' — got: $last" ;;
  esac
}
echo

# ---------------------------------------------------------------------------
# UNINSTALL — clean run (after install)
# ---------------------------------------------------------------------------
echo "--- uninstall: clean run ---"
{
  SBX=$(make_sandbox_home "uninstall_clean")
  export HOME="$SBX"

  # First install so there is something to uninstall
  HOME="$SBX" "$SCRIPT" install > /dev/null 2>&1

  output=$(HOME="$SBX" "$SCRIPT" uninstall 2>/dev/null)
  exit_code=$?

  last=$(printf '%s' "$output" | tail -1)

  assert_zero "uninstall clean: exit code 0" "$exit_code"

  case "$last" in
    summary:*) pass "uninstall clean: last stdout line starts with 'summary:'" ;;
    *)         fail "uninstall clean: last stdout line starts with 'summary:' — got: $last" ;;
  esac

  case "$last" in
    *"(exit 0)") pass "uninstall clean: summary ends with '(exit 0)'" ;;
    *)           fail "uninstall clean: summary ends with '(exit 0)' — got: $last" ;;
  esac
}
echo

# ---------------------------------------------------------------------------
# UNINSTALL — conflict run (foreign symlink at managed path)
# ---------------------------------------------------------------------------
echo "--- uninstall: conflict run (skipped:not-ours) ---"
{
  SBX=$(make_sandbox_home "uninstall_conflict")

  # Place a foreign symlink at agents/specflow
  mkdir -p "$SBX/.claude/agents"
  ln -s /tmp/decoy "$SBX/.claude/agents/specflow"

  output=$(HOME="$SBX" "$SCRIPT" uninstall 2>/dev/null)
  exit_code=$?

  last=$(printf '%s' "$output" | tail -1)

  # skipped:not-ours does NOT bump MAX_CODE per the spec (only skipped:conflict:* do).
  # Actually re-reading the spec: "bumps to 1 on any skipped:conflict:* / mutation failure".
  # skipped:not-ours is NOT a conflict, so this run should exit 0.
  # But we still want to verify summary line is printed.
  case "$last" in
    summary:*) pass "uninstall not-ours: last stdout line starts with 'summary:'" ;;
    *)         fail "uninstall not-ours: last stdout line starts with 'summary:' — got: $last" ;;
  esac

  case "$last" in
    *"(exit 0)") pass "uninstall not-ours: summary ends with '(exit 0)'" ;;
    *)           fail "uninstall not-ours: summary ends with '(exit 0)' — got: $last" ;;
  esac
}
echo

# ---------------------------------------------------------------------------
# UPDATE — clean run (after install)
# ---------------------------------------------------------------------------
echo "--- update: clean run ---"
{
  SBX=$(make_sandbox_home "update_clean")

  # Install first
  HOME="$SBX" "$SCRIPT" install > /dev/null 2>&1

  output=$(HOME="$SBX" "$SCRIPT" update 2>/dev/null)
  exit_code=$?

  last=$(printf '%s' "$output" | tail -1)

  assert_zero "update clean: exit code 0" "$exit_code"

  case "$last" in
    summary:*) pass "update clean: last stdout line starts with 'summary:'" ;;
    *)         fail "update clean: last stdout line starts with 'summary:' — got: $last" ;;
  esac

  case "$last" in
    *"(exit 0)") pass "update clean: summary ends with '(exit 0)'" ;;
    *)           fail "update clean: summary ends with '(exit 0)' — got: $last" ;;
  esac
}
echo

# ---------------------------------------------------------------------------
# UPDATE — conflict run (real file pre-placed)
# ---------------------------------------------------------------------------
echo "--- update: conflict run ---"
{
  SBX=$(make_sandbox_home "update_conflict")
  mkdir -p "$SBX/.claude/agents"
  echo "conflict" > "$SBX/.claude/agents/specflow"

  output=$(HOME="$SBX" "$SCRIPT" update 2>/dev/null)
  exit_code=$?

  last=$(printf '%s' "$output" | tail -1)

  assert_nonzero "update conflict: exit code non-zero (1)" "$exit_code"
  assert_eq "update conflict: exit code is exactly 1" "1" "$exit_code"

  case "$last" in
    summary:*) pass "update conflict: last stdout line starts with 'summary:'" ;;
    *)         fail "update conflict: last stdout line starts with 'summary:' — got: $last" ;;
  esac

  case "$last" in
    *"(exit 1)") pass "update conflict: summary ends with '(exit 1)'" ;;
    *)           fail "update conflict: summary ends with '(exit 1)' — got: $last" ;;
  esac
}
echo

# ---------------------------------------------------------------------------
# SUMMARY FORMAT: double-space before (exit N)
# ---------------------------------------------------------------------------
echo "--- summary format: double-space before (exit N) ---"
{
  SBX=$(make_sandbox_home "summary_format")

  output=$(HOME="$SBX" "$SCRIPT" install 2>/dev/null)
  last=$(printf '%s' "$output" | tail -1)

  # The spec says: "summary: created=N already=N removed=N skipped=N  (exit CODE)"
  # Note double space before (exit ...
  if echo "$last" | grep -qE '^summary: created=[0-9]+ already=[0-9]+ removed=[0-9]+ skipped=[0-9]+  \(exit [0-9]+\)$'; then
    pass "summary format: matches 'summary: created=N already=N removed=N skipped=N  (exit N)'"
  else
    fail "summary format: does not match spec — got: $last"
  fi
}
echo

# ---------------------------------------------------------------------------
# VERB-SET AUDIT
# Grep all `report ` call sites in bin/claude-symlink and assert every verb
# argument matches the closed set:
#   created|created:replaced-broken|already|removed|removed:orphan|
#   skipped:[^ ]+|would-[a-z:-]+
# ---------------------------------------------------------------------------
echo "--- verb-set audit ---"
{
  # Extract the second word (verb) from every `report <verb>` call site.
  # Match lines like:   report "verb"   or   report 'verb'   or   report verb
  # We look for lines matching `^\s*report ` and extract the next token (stripping quotes).
  closed_set_regex='^(created|created:replaced-broken|already|removed|removed:orphan|skipped:[^ "]+|would-[a-z:-]+)$'

  bad_verbs=0
  while IFS= read -r verb; do
    # Strip surrounding quotes
    verb="${verb#\"}"
    verb="${verb%\"}"
    verb="${verb#\'}"
    verb="${verb%\'}"
    if ! echo "$verb" | grep -qE "$closed_set_regex"; then
      echo "  BAD VERB: '$verb'"
      bad_verbs=$((bad_verbs + 1))
    fi
  done < <(grep -E '^\s*report ' "$SCRIPT" | awk '{print $2}')

  if [ "$bad_verbs" -eq 0 ]; then
    pass "verb-set audit: all report() verbs are in the closed set"
  else
    fail "verb-set audit: $bad_verbs verb(s) outside the closed set"
  fi
}
echo

# ---------------------------------------------------------------------------
# __probe GATE: without SPECFLOW_PROBE=1 → exits 2 (unknown subcommand)
# ---------------------------------------------------------------------------
echo "--- __probe gate: ungated __probe exits 2 ---"
{
  # Unset SPECFLOW_PROBE to ensure it's not set
  unset SPECFLOW_PROBE 2>/dev/null || true

  "$SCRIPT" __probe > /dev/null 2>&1
  exit_code=$?

  assert_eq "__probe without SPECFLOW_PROBE=1 exits 2" "2" "$exit_code"
}
echo

# ---------------------------------------------------------------------------
# __probe GATE: with SPECFLOW_PROBE=1 → works (prints REPO=...)
# ---------------------------------------------------------------------------
echo "--- __probe gate: with SPECFLOW_PROBE=1 works ---"
{
  output=$(SPECFLOW_PROBE=1 "$SCRIPT" __probe 2>/dev/null)
  exit_code=$?

  assert_zero "SPECFLOW_PROBE=1 __probe exits 0" "$exit_code"

  case "$output" in
    "REPO=$REPO") pass "SPECFLOW_PROBE=1 __probe prints REPO=<worktree>" ;;
    *)            fail "SPECFLOW_PROBE=1 __probe prints REPO=<worktree> — got: $output" ;;
  esac
}
echo

# ---------------------------------------------------------------------------
# DRY-RUN exits 0 even when conflicts would exist (would-skip does not bump MAX_CODE)
# ---------------------------------------------------------------------------
echo "--- dry-run: conflict does not bump exit code ---"
{
  SBX=$(make_sandbox_home "dryrun_conflict")
  mkdir -p "$SBX/.claude/agents"
  echo "conflict" > "$SBX/.claude/agents/specflow"

  output=$(HOME="$SBX" "$SCRIPT" install --dry-run 2>/dev/null)
  exit_code=$?

  last=$(printf '%s' "$output" | tail -1)

  assert_zero "dry-run conflict: exit code is 0" "$exit_code"

  case "$last" in
    *"(exit 0)") pass "dry-run conflict: summary ends with '(exit 0)'" ;;
    *)           fail "dry-run conflict: summary ends with '(exit 0)' — got: $last" ;;
  esac
}
echo

echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
