#!/usr/bin/env bash
# test/t86_upgrade_audit.sh
#
# Focused tests for the upgrade audit-log behaviour of set_tier (PRD R13, AC4).
#
# Coverage:
#   1. Valid transition standard→audited (role=TPM, reason="test upgrade"):
#      STATUS Notes gains a line matching the R13 format
#      YYYY-MM-DD TPM — tier upgrade standard→audited: test upgrade
#   2. Invalid transition standard→tiny:
#      set_tier exits non-zero; STATUS.md is byte-identical to its pre-call state.
#   3. Same-tier "upgrade" standard→standard:
#      Developer-chosen disposition — no-op (exit 0), STATUS.md unchanged.
#      Rationale: validate_tier_transition treats self-transitions as valid
#      (idempotent callers); set_tier short-circuits before backup + mutation,
#      so the file is never touched.  The test asserts exit 0 AND byte-identity.
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md:
#   mktemp-d sandbox, HOME=$SANDBOX/home, preflight assert, trap cleanup.
#
# Fixture paths use mktemp -d "$REPO_ROOT/.test-t86.XXXXXX" per task spec.
#
# Bash 3.2 / BSD portable — no readlink -f, realpath, jq, mapfile, [[ =~ ]].

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TIER_LIB="${TIER_LIB:-$REPO_ROOT/bin/scaff-tier}"

# Security boundary check: reject TIER_LIB that resolves outside REPO_ROOT.
# Prevents a tampered env var from sourcing arbitrary code.
_tier_lib_parent="$(cd "$(dirname "$TIER_LIB")" 2>/dev/null && pwd -P)" || {
  printf 'FAIL: TIER_LIB parent directory not resolvable: %s\n' "$TIER_LIB" >&2
  exit 2
}
case "$_tier_lib_parent" in
  "$REPO_ROOT"/*|"$REPO_ROOT") ;;  # inside repo tree — OK
  *) printf 'FAIL: TIER_LIB outside REPO_ROOT (security): %s\n' "$TIER_LIB" >&2; exit 2 ;;
esac
unset _tier_lib_parent

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t86.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Guard: library must exist (T2 dependency)
# ---------------------------------------------------------------------------
if [ ! -f "$TIER_LIB" ]; then
  printf 'SKIP: %s not found — T2 not yet merged; re-run post-wave.\n' \
    "$TIER_LIB" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Guard: set_tier must be present in the library
# ---------------------------------------------------------------------------
# shellcheck source=/dev/null
. "$TIER_LIB"

if ! type set_tier > /dev/null 2>&1; then
  printf 'SKIP: set_tier() not found — T2 not yet merged; re-run post-wave.\n' >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Helper: build a minimal STATUS.md fixture in a given directory.
# Usage: make_status_fixture <dir> <tier_value>
#   tier_value must be one of tiny|standard|audited.
# ---------------------------------------------------------------------------
make_status_fixture() {
  local dir="$1"
  local tier_val="$2"
  mkdir -p "$dir"
  printf -- '- **slug**: test-feature\n- **has-ui**: false\n- **tier**: %s\n- **stage**: prd\n\n## Status Notes\n' \
    "$tier_val" > "$dir/STATUS.md"
}

# ---------------------------------------------------------------------------
# Test 1 — valid upgrade: standard→audited
#
# After set_tier with role=TPM and reason="test upgrade", STATUS Notes must
# contain a line matching the R13 format:
#   YYYY-MM-DD TPM — tier upgrade standard→audited: test upgrade
# The YYYY-MM-DD portion is today's date injected by set_tier; we match it
# with a grep pattern that allows any four-digit-dash-two-digit-dash-two-digit
# prefix rather than hardcoding the date.
# ---------------------------------------------------------------------------
d="$SANDBOX/feat_valid_upgrade"
make_status_fixture "$d" "standard"

set +e
set_tier "$d" "audited" "TPM" "test upgrade"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  fail "test1: set_tier standard→audited exited $rc (expected 0)"
else
  pass "test1: set_tier standard→audited exits 0"

  # Assert tier: field updated in STATUS.md
  new_tier="$(get_tier "$d")"
  if [ "$new_tier" = "audited" ]; then
    pass "test1: STATUS.md tier field is now 'audited'"
  else
    fail "test1: STATUS.md tier field expected 'audited', got '$new_tier'"
  fi

  status_content="$(cat "$d/STATUS.md")"

  # Assert R13 format: line must match pattern
  #   [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] TPM — tier upgrade standard→audited: test upgrade
  # Use grep with a fixed-string anchor for the stable tokens; the date prefix
  # is validated separately by checking the line starts with digits.
  r13_line="$(printf '%s\n' "$status_content" | grep 'TPM.*tier upgrade.*standard.*audited.*test upgrade' || true)"
  if [ -n "$r13_line" ]; then
    pass "test1: STATUS Notes contains R13 audit line (stable tokens)"
  else
    fail "test1: STATUS Notes missing R13 audit line; STATUS.md content: $status_content"
  fi

  # Assert the date prefix looks like YYYY-MM-DD (four digits, dash, two, dash, two).
  # Audit line starts with "- YYYY-MM-DD …"; $2 is the date (after the leading "-").
  date_prefix="$(printf '%s\n' "$r13_line" | awk '{print $2}')"
  case "$date_prefix" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      pass "test1: R13 audit line date prefix has YYYY-MM-DD shape: $date_prefix" ;;
    *)
      fail "test1: R13 audit line date prefix malformed: '$date_prefix'" ;;
  esac
fi

# ---------------------------------------------------------------------------
# Test 2 — invalid transition: standard→tiny
#
# set_tier must exit non-zero.
# STATUS.md must be byte-identical to its state before the call.
# ---------------------------------------------------------------------------
d="$SANDBOX/feat_invalid_downgrade"
make_status_fixture "$d" "standard"

# Capture pre-call snapshot
before_bytes="$(cat "$d/STATUS.md")"

set +e
set_tier "$d" "tiny" "TPM" "test downgrade"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
  pass "test2: set_tier standard→tiny exits non-zero ($rc)"
else
  fail "test2: set_tier standard→tiny must exit non-zero; got 0"
fi

# Byte-identity check: STATUS.md must be unchanged
after_bytes="$(cat "$d/STATUS.md")"
if [ "$before_bytes" = "$after_bytes" ]; then
  pass "test2: STATUS.md byte-identical after failed transition"
else
  fail "test2: STATUS.md was mutated by failed standard→tiny transition"
fi

# No backup should have been created (mutation was rejected before backup step)
if [ ! -f "$d/STATUS.md.bak" ]; then
  pass "test2: no STATUS.md.bak created on rejected transition"
else
  fail "test2: STATUS.md.bak unexpectedly created on rejected transition"
fi

# ---------------------------------------------------------------------------
# Test 3 — same-tier: standard→standard
#
# Developer-chosen disposition: no-op (exit 0), STATUS.md byte-identical.
# Rationale: validate_tier_transition treats self-transitions as valid
# (idempotent no-op). set_tier short-circuits before backup and mutation,
# so no STATUS line is appended and the file stays untouched.
# ---------------------------------------------------------------------------
d="$SANDBOX/feat_same_tier"
make_status_fixture "$d" "standard"

# Capture pre-call snapshot
before_bytes="$(cat "$d/STATUS.md")"

set +e
set_tier "$d" "standard" "TPM" "same-tier test"
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  pass "test3: set_tier standard→standard exits 0 (no-op)"
else
  fail "test3: set_tier standard→standard must exit 0 (no-op); got $rc"
fi

# Byte-identity: same-tier must not mutate STATUS.md
after_bytes="$(cat "$d/STATUS.md")"
if [ "$before_bytes" = "$after_bytes" ]; then
  pass "test3: STATUS.md byte-identical after same-tier call (no audit line appended)"
else
  fail "test3: STATUS.md was mutated by same-tier standard→standard call"
fi

# No backup should have been created (short-circuit before backup step)
if [ ! -f "$d/STATUS.md.bak" ]; then
  pass "test3: no STATUS.md.bak created on same-tier call"
else
  fail "test3: STATUS.md.bak unexpectedly created on same-tier call"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
