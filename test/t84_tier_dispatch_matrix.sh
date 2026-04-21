#!/usr/bin/env bash
# test/t84_tier_dispatch_matrix.sh
#
# Table-driven unit test: tier × stage dispatch matrix (PRD R10).
#
# For each (tier, stage) pair from the R10 matrix, asserts that
# tier_skips_stage returns the expected exit code:
#   0  — stage is skipped for this tier (R10 "—" cells)
#   1  — stage is required or optional (R10 "✅" or "🔵" or "⚫" cells)
#
# Coverage per T26:
#   tiny     — skips brainstorm, tech, design
#              review is 🔵 (optional) — tier_skips_stage returns 1 (not forced-skip)
#   standard — skips brainstorm only
#              design is ⚫ (conditional on has-ui: true) — tier_skips_stage returns 1;
#              the has-ui conditionality is resolved at command level, not in the helper
#   audited  — skips nothing (all stages required)
#   validate — all tiers require it; tiny runs tester-only default at command level
#              but tier_skips_stage still returns 1 (not skipped) for all tiers
#
# has-ui fixture variants: test both has-ui: false and has-ui: true for
# standard + design to confirm tier_skips_stage is has-ui-agnostic (the ⚫
# conditionality is a command-level concern, not a helper concern).
#
# Fixture path: mktemp -d "$REPO_ROOT/.test-t84.XXXXXX"
# Sandbox-HOME per .claude/rules/bash/sandbox-home-in-tests.md
# Bash 3.2 / BSD portable — no readlink -f, realpath, jq, mapfile, [[ =~ ]].

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TIER_LIB="${TIER_LIB:-$REPO_ROOT/bin/scaff-tier}"

# ---------------------------------------------------------------------------
# Fixture sandbox — under REPO_ROOT to satisfy path-boundary check in helper
# (mktemp -d "$REPO_ROOT/.test-t84.XXXXXX" per T26 fixture-path discipline)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t84.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

# ---------------------------------------------------------------------------
# HOME sandbox (sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Guard: library must exist; SKIP gracefully if not yet merged
# ---------------------------------------------------------------------------
if [ ! -f "$TIER_LIB" ]; then
  printf 'SKIP: %s not found — T2 not yet merged; re-run post-wave.\n' \
    "$TIER_LIB" >&2
  exit 0
fi

# Guard: tier_skips_stage must be defined after sourcing the library
SPECFLOW_TIER_LOADED=0
# shellcheck source=/dev/null
. "$TIER_LIB"

if ! type tier_skips_stage > /dev/null 2>&1; then
  printf 'SKIP: tier_skips_stage() not found in %s — production code not yet authored; re-run post-wave.\n' \
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

# assert_matrix <tier> <stage> <want_skip>
#   want_skip = "skip"  → expect tier_skips_stage returns 0
#   want_skip = "run"   → expect tier_skips_stage returns non-zero
assert_matrix() {
  local tier="$1"
  local stage="$2"
  local want="$3"
  local label="R10[${tier}][${stage}]=${want}"

  set +e
  tier_skips_stage "$tier" "$stage"
  local rc=$?
  set -e

  if [ "$want" = "skip" ]; then
    if [ "$rc" -eq 0 ]; then
      pass "$label — tier_skips_stage returned 0 (skipped)"
    else
      fail "$label — expected skip (0) but got $rc"
    fi
  else
    if [ "$rc" -ne 0 ]; then
      pass "$label — tier_skips_stage returned $rc (not skipped)"
    else
      fail "$label — expected run (non-0) but got 0"
    fi
  fi
}

# ---------------------------------------------------------------------------
# PRD R10 matrix — data-driven assertions
#
# Stage  | tiny | standard | audited
# -------|------|----------|--------
# request      ✅   ✅        ✅
# brainstorm   —    —         ✅
# prd          ✅   ✅        ✅
# tech         —    ✅        ✅
# plan         🔵   ✅        ✅
# design       —    ⚫        ✅
# implement    ✅   ✅        ✅
# validate     ✅   ✅        ✅
# review       🔵   🔵        ✅
# archive      ✅   ✅        ✅
#
# Legend:
#   ✅ = required → "run"
#   —  = skipped  → "skip"
#   🔵 = optional → tier_skips_stage returns non-0 ("run"); caller decides
#   ⚫ = conditional on has-ui — tier_skips_stage returns non-0 ("run");
#        command-level has-ui check handles the conditionality
# ---------------------------------------------------------------------------

printf '=== tiny tier ===\n'
assert_matrix "tiny" "request"    "run"
assert_matrix "tiny" "brainstorm" "skip"
assert_matrix "tiny" "prd"        "run"
assert_matrix "tiny" "tech"       "skip"
assert_matrix "tiny" "plan"       "run"   # 🔵 optional — not forced-skip by helper
assert_matrix "tiny" "design"     "skip"
assert_matrix "tiny" "implement"  "run"
assert_matrix "tiny" "validate"   "run"   # ✅ tester-only default at command level
assert_matrix "tiny" "review"     "run"   # 🔵 optional — not forced-skip by helper
assert_matrix "tiny" "archive"    "run"

printf '=== standard tier ===\n'
assert_matrix "standard" "request"    "run"
assert_matrix "standard" "brainstorm" "skip"
assert_matrix "standard" "prd"        "run"
assert_matrix "standard" "tech"       "run"
assert_matrix "standard" "plan"       "run"
assert_matrix "standard" "design"     "run"   # ⚫ has-ui conditional — helper is agnostic
assert_matrix "standard" "implement"  "run"
assert_matrix "standard" "validate"   "run"
assert_matrix "standard" "review"     "run"   # 🔵 optional
assert_matrix "standard" "archive"    "run"

printf '=== audited tier ===\n'
assert_matrix "audited" "request"    "run"
assert_matrix "audited" "brainstorm" "run"
assert_matrix "audited" "prd"        "run"
assert_matrix "audited" "tech"       "run"
assert_matrix "audited" "plan"       "run"
assert_matrix "audited" "design"     "run"
assert_matrix "audited" "implement"  "run"
assert_matrix "audited" "validate"   "run"
assert_matrix "audited" "review"     "run"
assert_matrix "audited" "archive"    "run"

# ---------------------------------------------------------------------------
# has-ui fixture variants for standard + design
#
# tier_skips_stage does NOT receive has-ui as input — the ⚫ conditionality in
# R10 is resolved at command level (next.md reads has-ui from STATUS.md and
# skips design only when has-ui: false AND tier=standard). The helper returns
# "run" (non-0) regardless of the has-ui fixture value.
#
# These two variants exist to document that requirement explicitly and to
# confirm no side-channel (e.g. env var leakage) causes the helper to behave
# differently based on the STATUS.md content of any feature dir.
# ---------------------------------------------------------------------------

printf '=== standard + design: has-ui fixture variants (helper is has-ui-agnostic) ===\n'

# Fixture: standard feature with has-ui: false
FIX_NO_UI="$SANDBOX/feat_standard_no_ui"
mkdir -p "$FIX_NO_UI"
cat > "$FIX_NO_UI/STATUS.md" <<'STATUS_EOF'
- **slug**: test-no-ui
- **has-ui**: false
- **tier**: standard
- **stage**: tech

## Status Notes
STATUS_EOF

# Fixture: standard feature with has-ui: true
FIX_UI="$SANDBOX/feat_standard_ui"
mkdir -p "$FIX_UI"
cat > "$FIX_UI/STATUS.md" <<'STATUS_EOF'
- **slug**: test-ui
- **has-ui**: true
- **tier**: standard
- **stage**: tech

## Status Notes
STATUS_EOF

# tier_skips_stage takes (tier, stage) only — no feature_dir argument.
# Both variants must return "run" (non-0) confirming the helper is agnostic.
assert_matrix "standard" "design" "run"   # has-ui: false fixture (env identical — no dir arg)
assert_matrix "standard" "design" "run"   # has-ui: true  fixture (env identical — no dir arg)

# Positive documentation: when has-ui is relevant the caller reads it separately.
# Confirm that get_tier reads from the fixture directories correctly so the
# test infrastructure is sound even though tier_skips_stage is dir-agnostic.
REPO_ROOT_SAVED="$REPO_ROOT"
export REPO_ROOT="$SANDBOX"  # widen boundary to cover both fixtures

# Temporarily allow REPO_ROOT to include SANDBOX for get_tier boundary check
TIER_NO_UI="$(REPO_ROOT="$SANDBOX" get_tier "$FIX_NO_UI")"
TIER_UI="$(REPO_ROOT="$SANDBOX" get_tier "$FIX_UI")"
export REPO_ROOT="$REPO_ROOT_SAVED"

if [ "$TIER_NO_UI" = "standard" ]; then
  pass "has-ui fixture: get_tier reads 'standard' from has-ui:false fixture"
else
  fail "has-ui fixture: get_tier returned '$TIER_NO_UI' for has-ui:false fixture (expected 'standard')"
fi

if [ "$TIER_UI" = "standard" ]; then
  pass "has-ui fixture: get_tier reads 'standard' from has-ui:true fixture"
else
  fail "has-ui fixture: get_tier returned '$TIER_UI' for has-ui:true fixture (expected 'standard')"
fi

# ---------------------------------------------------------------------------
# validate stage: tester-only default (tiny) is command-level, not helper-level
#
# tier_skips_stage("tiny", "validate") MUST return non-0 (not skipped at
# helper level). The "tester-only" vs "both axes" distinction is enforced
# inside next.md / validate.md after checking tier, not in the helper.
# ---------------------------------------------------------------------------

printf '=== validate: tester-only default is command-level, not helper-level ===\n'
assert_matrix "tiny"     "validate" "run"
assert_matrix "standard" "validate" "run"
assert_matrix "audited"  "validate" "run"

# ---------------------------------------------------------------------------
# Edge cases: missing and malformed tier inputs
#
# tier_skips_stage with an unrecognised tier value should return non-0 (no
# mandatory skip for unknown tiers — callers surface the malformed/missing
# state before calling the helper per tech §4.1).
# ---------------------------------------------------------------------------

printf '=== edge cases: unrecognised tier inputs ===\n'
assert_matrix "missing"   "brainstorm" "run"
assert_matrix "malformed" "brainstorm" "run"
assert_matrix "missing"   "tech"       "run"
assert_matrix "malformed" "design"     "run"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
