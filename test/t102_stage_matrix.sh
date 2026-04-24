#!/usr/bin/env bash
# test/t102_stage_matrix.sh
#
# T2 — Unit-test stage_status against all 72 (work-type x tier x stage) cells
# from PRD D3 matrix.
#
# Coverage:
#   - All 72 triples: 3 work-types (feature bug chore)
#                   x 3 tiers    (tiny standard audited)
#                   x 8 stages   (request design prd tech plan implement
#                                 validate archive)
#   - 4 labelled key asymmetry tests with exact PASS/FAIL names per task spec
#   - Malformed input: stage_status bogus tiny validate -> exit 2 + stderr
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md:
#   mktemp-d sandbox, HOME=$SANDBOX/home, preflight assert, trap cleanup.
#   (The helper does not read HOME; sandbox is template-uniform per the rule.)
#
# Performance: no shell-out in loops (rule 1).
#   Calling $(stage_status ...) inside the test loop is the SUT call,
#   not a tool re-spawn per iteration; this is the intended pattern for
#   unit-testing a sourced function.
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only
#   flags.  No `case` inside subshells (bash32-case-in-subshell.md).

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md -- never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
STAGE_MATRIX_LIB="${STAGE_MATRIX_LIB:-$REPO_ROOT/bin/scaff-stage-matrix}"

# ---------------------------------------------------------------------------
# Sandbox -- HOME isolation (sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Guard: library must exist (T1 ships this; test authors in parallel)
# ---------------------------------------------------------------------------
if [ ! -f "$STAGE_MATRIX_LIB" ]; then
  printf 'SKIP: %s not found -- T1 not yet merged; tests will be re-run post-wave.\n' \
    "$STAGE_MATRIX_LIB" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Source the library
# ---------------------------------------------------------------------------
# shellcheck source=/dev/null
. "$STAGE_MATRIX_LIB"

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# assert_cell <work_type> <tier> <stage> <expected>
assert_cell() {
  local wt="$1" tier="$2" stage="$3" expected="$4"
  local actual
  actual=$(stage_status "$wt" "$tier" "$stage")
  local label="${wt}_${tier}_${stage}"
  if [ "$actual" = "$expected" ]; then
    pass "$label: $expected"
  else
    fail "$label: expected '$expected', got '$actual'"
  fi
}

# ---------------------------------------------------------------------------
# Full 72-cell matrix assertions
# Encoded as space-separated quadruples: <work-type> <tier> <stage> <expected>
# Source: PRD D3 table -- stages x (type x tier) cells
# ---------------------------------------------------------------------------

printf '=== feature x tiny (8 cells) ===\n'
assert_cell feature tiny request  required
assert_cell feature tiny design   skipped
assert_cell feature tiny prd      required
assert_cell feature tiny tech     skipped
assert_cell feature tiny plan     optional
assert_cell feature tiny implement required
assert_cell feature tiny validate required
assert_cell feature tiny archive  required

printf '\n=== feature x standard (8 cells) ===\n'
assert_cell feature standard request  required
assert_cell feature standard design   optional
assert_cell feature standard prd      required
assert_cell feature standard tech     required
assert_cell feature standard plan     required
assert_cell feature standard implement required
assert_cell feature standard validate required
assert_cell feature standard archive  required

printf '\n=== feature x audited (8 cells) ===\n'
assert_cell feature audited request  required
assert_cell feature audited design   optional
assert_cell feature audited prd      required
assert_cell feature audited tech     required
assert_cell feature audited plan     required
assert_cell feature audited implement required
assert_cell feature audited validate required
assert_cell feature audited archive  required

printf '\n=== bug x tiny (8 cells) ===\n'
assert_cell bug tiny request  required
assert_cell bug tiny design   skipped
assert_cell bug tiny prd      required
assert_cell bug tiny tech     skipped
assert_cell bug tiny plan     optional
assert_cell bug tiny implement required
assert_cell bug tiny validate required
assert_cell bug tiny archive  required

printf '\n=== bug x standard (8 cells) ===\n'
assert_cell bug standard request  required
assert_cell bug standard design   optional
assert_cell bug standard prd      required
assert_cell bug standard tech     optional
assert_cell bug standard plan     required
assert_cell bug standard implement required
assert_cell bug standard validate required
assert_cell bug standard archive  required

printf '\n=== bug x audited (8 cells) ===\n'
assert_cell bug audited request  required
assert_cell bug audited design   optional
assert_cell bug audited prd      required
assert_cell bug audited tech     required
assert_cell bug audited plan     required
assert_cell bug audited implement required
assert_cell bug audited validate required
assert_cell bug audited archive  required

printf '\n=== chore x tiny (8 cells) ===\n'
assert_cell chore tiny request  required
assert_cell chore tiny design   skipped
assert_cell chore tiny prd      required
assert_cell chore tiny tech     skipped
assert_cell chore tiny plan     optional
assert_cell chore tiny implement required
assert_cell chore tiny validate required
assert_cell chore tiny archive  required

printf '\n=== chore x standard (8 cells) ===\n'
assert_cell chore standard request  required
assert_cell chore standard design   skipped
assert_cell chore standard prd      required
assert_cell chore standard tech     skipped
assert_cell chore standard plan     required
assert_cell chore standard implement required
assert_cell chore standard validate required
assert_cell chore standard archive  required

printf '\n=== chore x audited (8 cells) ===\n'
assert_cell chore audited request  required
assert_cell chore audited design   skipped
assert_cell chore audited prd      required
assert_cell chore audited tech     optional
assert_cell chore audited plan     required
assert_cell chore audited implement required
assert_cell chore audited validate required
assert_cell chore audited archive  required

# ---------------------------------------------------------------------------
# Labelled key asymmetry assertions (exact names per task spec)
# ---------------------------------------------------------------------------
printf '\n=== Key asymmetry assertions ===\n'

# bug_tiny_validate_required:
#   validate is required for bug-tiny (unlike feature-tiny where validate is
#   also required -- but bugs MUST not skip validate; regression test mandatory)
actual=$(stage_status bug tiny validate)
if [ "$actual" = "required" ]; then
  pass "bug_tiny_validate_required"
else
  fail "bug_tiny_validate_required: expected 'required', got '$actual'"
fi

# chore_tiny_design_skipped:
#   design is always skipped for chore (has-ui=false by construction per D3)
actual=$(stage_status chore tiny design)
if [ "$actual" = "skipped" ]; then
  pass "chore_tiny_design_skipped"
else
  fail "chore_tiny_design_skipped: expected 'skipped', got '$actual'"
fi

# feature_tiny_tech_skipped:
#   preserves tier_skips_stage byte-identity per R10.1
actual=$(stage_status feature tiny tech)
if [ "$actual" = "skipped" ]; then
  pass "feature_tiny_tech_skipped"
else
  fail "feature_tiny_tech_skipped: expected 'skipped', got '$actual'"
fi

# chore_audited_tech_optional:
#   chore-audited re-enables tech as optional (dep bump may warrant
#   architect sign-off per D3 rationale)
actual=$(stage_status chore audited tech)
if [ "$actual" = "optional" ]; then
  pass "chore_audited_tech_optional"
else
  fail "chore_audited_tech_optional: expected 'optional', got '$actual'"
fi

# ---------------------------------------------------------------------------
# Malformed input: stage_status bogus tiny validate -> exit 2 + stderr
# ---------------------------------------------------------------------------
printf '\n=== Malformed input tests ===\n'

STDERR_TMP="$SANDBOX/stderr.txt"

set +e
actual=$(stage_status bogus tiny validate 2>"$STDERR_TMP")
bogus_exit=$?
set -e

if [ "$bogus_exit" -eq 2 ]; then
  pass "malformed_work_type: exit 2 as expected"
else
  fail "malformed_work_type: expected exit 2, got $bogus_exit"
fi

if [ -s "$STDERR_TMP" ]; then
  pass "malformed_work_type: stderr non-empty (usage error emitted)"
else
  fail "malformed_work_type: expected usage error on stderr, got nothing"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
