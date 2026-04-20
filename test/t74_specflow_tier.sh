#!/usr/bin/env bash
# test/t74_specflow_tier.sh
#
# Unit tests for bin/specflow-tier (sourceable bash library).
#
# Coverage:
#   1. get_tier — all five output states: tiny, standard, audited, missing,
#      malformed, and file-not-found (→ missing per D2 five-state spec).
#   2. set_tier — full transition matrix (valid and invalid transitions).
#      Self-transition (same→same) is treated as a no-op (exit 0).
#      STATUS Notes audit line format per PRD R13.
#   3. validate_tier_transition — returns 0 for allowed, non-zero for disallowed.
#   4. tier_skips_stage — every (tier, stage) pair per PRD R10 matrix.
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md:
#   mktemp-d sandbox, HOME=$SANDBOX/home, preflight assert, trap cleanup.
#
# Bash 3.2 / BSD portable — no readlink -f, realpath, jq, mapfile, [[ =~ ]].

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TIER_LIB="${TIER_LIB:-$REPO_ROOT/bin/specflow-tier}"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t74-test)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Guard: library must exist
# ---------------------------------------------------------------------------
if [ ! -f "$TIER_LIB" ]; then
  printf 'SKIP: %s not found — T2 not yet merged; tests will be re-run post-wave.\n' \
    "$TIER_LIB" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# Source the library — reset the loaded-guard to allow re-source within this
# test process when needed; initial source suffices for all tests.
SPECFLOW_TIER_LOADED=0
# shellcheck source=/dev/null
. "$TIER_LIB"

# ---------------------------------------------------------------------------
# Helper: build a minimal STATUS.md fixture in a temp dir.
# Usage: make_status_fixture <dir> [tier_value|"_missing"|"_malformed"]
#   _missing  → STATUS.md has no tier: field at all
#   _malformed → STATUS.md has 'tier: bogus' (not in closed set)
#   otherwise  → STATUS.md has 'tier: <value>'
# ---------------------------------------------------------------------------
make_status_fixture() {
  local dir="$1"
  local tier_spec="${2:-standard}"
  mkdir -p "$dir"
  if [ "$tier_spec" = "_missing" ]; then
    printf -- '- **slug**: test-feature\n- **has-ui**: false\n- **stage**: prd\n\n## Status Notes\n' \
      > "$dir/STATUS.md"
  elif [ "$tier_spec" = "_malformed" ]; then
    printf -- '- **slug**: test-feature\n- **has-ui**: false\n- **tier**: bogus\n- **stage**: prd\n\n## Status Notes\n' \
      > "$dir/STATUS.md"
  else
    printf -- '- **slug**: test-feature\n- **has-ui**: false\n- **tier**: %s\n- **stage**: prd\n\n## Status Notes\n' \
      "$tier_spec" > "$dir/STATUS.md"
  fi
}

# ---------------------------------------------------------------------------
# Section 1 — get_tier
# ---------------------------------------------------------------------------

# 1a: valid tier values — each of the three enum members
for tier_val in tiny standard audited; do
  d="$SANDBOX/feat_get_${tier_val}"
  make_status_fixture "$d" "$tier_val"
  result="$(get_tier "$d")"
  if [ "$result" = "$tier_val" ]; then
    pass "get_tier: '$tier_val' STATUS → '$tier_val'"
  else
    fail "get_tier: '$tier_val' STATUS → got '$result', expected '$tier_val'"
  fi
done

# 1b: missing tier field → 'missing'
d="$SANDBOX/feat_get_missing"
make_status_fixture "$d" "_missing"
result="$(get_tier "$d")"
if [ "$result" = "missing" ]; then
  pass "get_tier: missing tier field → 'missing'"
else
  fail "get_tier: missing tier field → got '$result', expected 'missing'"
fi

# 1c: malformed tier value → 'malformed'
d="$SANDBOX/feat_get_malformed"
make_status_fixture "$d" "_malformed"
result="$(get_tier "$d")"
if [ "$result" = "malformed" ]; then
  pass "get_tier: malformed tier field → 'malformed'"
else
  fail "get_tier: malformed tier field → got '$result', expected 'malformed'"
fi

# 1d: file-not-found (no STATUS.md in dir) → 'missing'
d="$SANDBOX/feat_get_no_file"
mkdir -p "$d"
# Do NOT create STATUS.md
result="$(get_tier "$d")"
if [ "$result" = "missing" ]; then
  pass "get_tier: no STATUS.md → 'missing'"
else
  fail "get_tier: no STATUS.md → got '$result', expected 'missing'"
fi

# 1e: get_tier never exits non-zero (per tech §4.1)
d="$SANDBOX/feat_get_nonzero_check"
make_status_fixture "$d" "_malformed"
get_tier "$d" > /dev/null
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "get_tier: never exits non-zero (malformed STATUS exits $rc)"
else
  fail "get_tier: must not exit non-zero; got exit code $rc"
fi

# ---------------------------------------------------------------------------
# Section 2 — set_tier and STATUS Notes audit line (PRD R13)
# ---------------------------------------------------------------------------

# Helper: run set_tier and check exit code
assert_set_tier_exit() {
  local label="$1"
  local feature_dir="$2"
  local new_tier="$3"
  local expected_exit="$4"
  local role="${5:-tpm}"
  local reason="${6:-test reason}"
  set +e
  set_tier "$feature_dir" "$new_tier" "$role" "$reason"
  local actual_exit=$?
  set -e
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    pass "set_tier: $label → exit $actual_exit (expected $expected_exit)"
  else
    fail "set_tier: $label → exit $actual_exit (expected $expected_exit)"
  fi
}

# 2a: valid upgrades
d="$SANDBOX/feat_set_tiny_to_standard"
make_status_fixture "$d" "tiny"
assert_set_tier_exit "tiny→standard" "$d" "standard" 0

d="$SANDBOX/feat_set_tiny_to_audited"
make_status_fixture "$d" "tiny"
assert_set_tier_exit "tiny→audited" "$d" "audited" 0

d="$SANDBOX/feat_set_standard_to_audited"
make_status_fixture "$d" "standard"
assert_set_tier_exit "standard→audited" "$d" "audited" 0

# 2b: missing→standard is the migration path — allowed
d="$SANDBOX/feat_set_missing_to_standard"
make_status_fixture "$d" "_missing"
assert_set_tier_exit "missing→standard (migration path)" "$d" "standard" 0

# 2c: invalid downgrades — must exit 2
d="$SANDBOX/feat_set_standard_to_tiny"
make_status_fixture "$d" "standard"
assert_set_tier_exit "standard→tiny (downgrade)" "$d" "tiny" 2

d="$SANDBOX/feat_set_audited_to_standard"
make_status_fixture "$d" "audited"
assert_set_tier_exit "audited→standard (downgrade)" "$d" "standard" 2

d="$SANDBOX/feat_set_audited_to_tiny"
make_status_fixture "$d" "audited"
assert_set_tier_exit "audited→tiny (downgrade)" "$d" "tiny" 2

# 2d: missing→anything-except-standard — must exit 2
d="$SANDBOX/feat_set_missing_to_tiny"
make_status_fixture "$d" "_missing"
assert_set_tier_exit "missing→tiny (invalid)" "$d" "tiny" 2

d="$SANDBOX/feat_set_missing_to_audited"
make_status_fixture "$d" "_missing"
assert_set_tier_exit "missing→audited (invalid)" "$d" "audited" 2

# 2e: malformed→anything — must exit 2
for new_t in tiny standard audited; do
  d="$SANDBOX/feat_set_malformed_to_${new_t}"
  make_status_fixture "$d" "_malformed"
  assert_set_tier_exit "malformed→${new_t}" "$d" "$new_t" 2
done

# 2f: self-transition — no-op (exit 0)
for tier_val in tiny standard audited; do
  d="$SANDBOX/feat_set_self_${tier_val}"
  make_status_fixture "$d" "$tier_val"
  assert_set_tier_exit "${tier_val}→${tier_val} (self-transition no-op)" "$d" "$tier_val" 0
done

# 2g: STATUS Notes audit line per PRD R13
# Format: YYYY-MM-DD <role> — tier upgrade <old>→<new>: <reason>
d="$SANDBOX/feat_set_audit_trail"
make_status_fixture "$d" "tiny"
export SPECFLOW_INVOKER_ROLE="tpm"
set +e
set_tier "$d" "standard" "tpm" "test-audit-trail"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  status_content="$(cat "$d/STATUS.md")"
  # Check that the audit line matches the required format token set:
  # must contain 'tier upgrade' and 'tiny→standard' and 'test-audit-trail'
  if printf '%s\n' "$status_content" | grep -q 'tier upgrade'; then
    pass "set_tier: audit line contains 'tier upgrade'"
  else
    fail "set_tier: audit line missing 'tier upgrade' in STATUS Notes"
  fi
  if printf '%s\n' "$status_content" | grep -q 'tiny.*standard'; then
    pass "set_tier: audit line contains old→new tier reference"
  else
    fail "set_tier: audit line missing old→new tier reference (tiny.*standard)"
  fi
  if printf '%s\n' "$status_content" | grep -q 'test-audit-trail'; then
    pass "set_tier: audit line contains trigger reason"
  else
    fail "set_tier: audit line missing trigger reason 'test-audit-trail'"
  fi
else
  fail "set_tier: tiny→standard failed (exit $rc); cannot check audit trail"
fi

# 2h: updated STATUS.md reflects new tier
d="$SANDBOX/feat_set_tier_persists"
make_status_fixture "$d" "tiny"
set +e
set_tier "$d" "standard" "tpm" "persistence-check"
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  new_tier="$(get_tier "$d")"
  if [ "$new_tier" = "standard" ]; then
    pass "set_tier: STATUS.md reflects new tier after upgrade"
  else
    fail "set_tier: STATUS.md does not reflect new tier; get_tier returned '$new_tier'"
  fi
else
  fail "set_tier: tiny→standard failed (exit $rc); cannot check persistence"
fi

# ---------------------------------------------------------------------------
# Section 3 — validate_tier_transition
# ---------------------------------------------------------------------------

# Returns 0 for allowed transitions, non-zero for disallowed.
assert_validate() {
  local label="$1"
  local old_tier="$2"
  local new_tier="$3"
  local expected_ok="$4"   # "yes" → expect 0; "no" → expect non-zero
  set +e
  validate_tier_transition "$old_tier" "$new_tier"
  local rc=$?
  set -e
  if [ "$expected_ok" = "yes" ]; then
    if [ "$rc" -eq 0 ]; then
      pass "validate_tier_transition: $label → allowed (exit 0)"
    else
      fail "validate_tier_transition: $label → expected allowed but got exit $rc"
    fi
  else
    if [ "$rc" -ne 0 ]; then
      pass "validate_tier_transition: $label → rejected (exit $rc)"
    else
      fail "validate_tier_transition: $label → expected rejection but got exit 0"
    fi
  fi
}

assert_validate "tiny→standard"   "tiny"     "standard" "yes"
assert_validate "tiny→audited"    "tiny"     "audited"  "yes"
assert_validate "standard→audited" "standard" "audited"  "yes"
assert_validate "missing→standard (migration)" "missing" "standard" "yes"

assert_validate "standard→tiny (downgrade)"   "standard" "tiny"     "no"
assert_validate "audited→standard (downgrade)" "audited"  "standard" "no"
assert_validate "audited→tiny (downgrade)"     "audited"  "tiny"     "no"
assert_validate "missing→tiny (invalid)"       "missing"  "tiny"     "no"
assert_validate "missing→audited (invalid)"    "missing"  "audited"  "no"
assert_validate "malformed→tiny"               "malformed" "tiny"    "no"
assert_validate "malformed→standard"           "malformed" "standard" "no"
assert_validate "malformed→audited"            "malformed" "audited"  "no"

# ---------------------------------------------------------------------------
# Section 4 — tier_skips_stage
# Per PRD R10 matrix:
#   ✅ = required (NOT skipped → tier_skips_stage returns non-zero)
#   —  = skipped  (tier_skips_stage returns 0)
#   🔵 = optional (not forced-skipped by tier → returns non-zero)
#   ⚫  = conditional on has-ui (not forced-skipped by tier → returns non-zero)
#
# Returns 0 if the tier causes the stage to be skipped; non-zero otherwise.
# ---------------------------------------------------------------------------

assert_skips() {
  local label="$1"
  local tier="$2"
  local stage="$3"
  local expected_skip="$4"   # "yes" → expect 0 (skip); "no" → expect non-zero
  set +e
  tier_skips_stage "$tier" "$stage"
  local rc=$?
  set -e
  if [ "$expected_skip" = "yes" ]; then
    if [ "$rc" -eq 0 ]; then
      pass "tier_skips_stage($tier, $stage): skipped (exit 0)"
    else
      fail "tier_skips_stage($tier, $stage): expected skip (0) but got exit $rc — $label"
    fi
  else
    if [ "$rc" -ne 0 ]; then
      pass "tier_skips_stage($tier, $stage): not skipped (exit $rc)"
    else
      fail "tier_skips_stage($tier, $stage): expected no-skip (non-0) but got exit 0 — $label"
    fi
  fi
}

# tiny tier
assert_skips "tiny: request required"    "tiny" "request"    "no"
assert_skips "tiny: brainstorm skipped"  "tiny" "brainstorm" "yes"
assert_skips "tiny: prd required"        "tiny" "prd"        "no"
assert_skips "tiny: tech skipped"        "tiny" "tech"       "yes"
assert_skips "tiny: plan optional→not skipped by tier" "tiny" "plan"  "no"
assert_skips "tiny: design skipped"      "tiny" "design"     "yes"
assert_skips "tiny: implement required"  "tiny" "implement"  "no"
assert_skips "tiny: validate required"   "tiny" "validate"   "no"
assert_skips "tiny: review optional→not skipped by tier" "tiny" "review" "no"
assert_skips "tiny: archive required"    "tiny" "archive"    "no"

# standard tier
assert_skips "standard: request required"    "standard" "request"    "no"
assert_skips "standard: brainstorm skipped"  "standard" "brainstorm" "yes"
assert_skips "standard: prd required"        "standard" "prd"        "no"
assert_skips "standard: tech required"       "standard" "tech"       "no"
assert_skips "standard: plan required"       "standard" "plan"       "no"
assert_skips "standard: design conditional→not skipped by tier" "standard" "design" "no"
assert_skips "standard: implement required"  "standard" "implement"  "no"
assert_skips "standard: validate required"   "standard" "validate"   "no"
assert_skips "standard: review optional→not skipped by tier" "standard" "review" "no"
assert_skips "standard: archive required"    "standard" "archive"    "no"

# audited tier
assert_skips "audited: request required"   "audited" "request"    "no"
assert_skips "audited: brainstorm required" "audited" "brainstorm" "no"
assert_skips "audited: prd required"       "audited" "prd"        "no"
assert_skips "audited: tech required"      "audited" "tech"       "no"
assert_skips "audited: plan required"      "audited" "plan"       "no"
assert_skips "audited: design required"    "audited" "design"     "no"
assert_skips "audited: implement required" "audited" "implement"  "no"
assert_skips "audited: validate required"  "audited" "validate"   "no"
assert_skips "audited: review required"    "audited" "review"     "no"
assert_skips "audited: archive required"   "audited" "archive"    "no"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
