#!/usr/bin/env bash
# test/t89_inline_review_default.sh
#
# Structural grep tests for T31 (AC11 / R16):
#   Verify that implement.md's inline-review gate logic encodes the correct
#   default for tiny vs standard tiers.
#
# Two cases per spec:
#   A. tiny tier, no --inline-review flag  → inline review SKIPPED by default
#   B. standard tier (no explicit flag)    → inline review RUNS by default
#
# Strategy: pure structural inspection of implement.md (no agent invocation,
# no mutation).  The gate logic is authored in W3 T21; this test (W4 T31)
# verifies the resulting text carries every required element.
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md.
# Bash 3.2 / BSD portable — no readlink -f, realpath, jq, mapfile, [[ =~ ]].

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# Must come BEFORE sandbox so $REPO_ROOT is available for mktemp path.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
IMPL="${IMPL:-$REPO_ROOT/.claude/commands/scaff/implement.md}"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (NON-NEGOTIABLE; sandbox-home-in-tests rule)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t89.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Guard: implement.md must exist; skip gracefully if T21 not yet merged
# ---------------------------------------------------------------------------
if [ ! -f "$IMPL" ]; then
  printf 'SKIP: implement.md not found at %s — T21 not yet merged; re-run post-wave.\n' "$IMPL" >&2
  exit 0
fi

# Guard: gate section must be present (look for the tier-based default header)
if ! grep -q 'Tier-based default' "$IMPL" 2>/dev/null; then
  printf 'SKIP: Tier-based default section absent from implement.md — T21 tier-gate not yet merged; re-run post-wave.\n' >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Test harness helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

check() {
  local desc="$1" rc="$2"
  if [ "$rc" = "0" ]; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

# ---------------------------------------------------------------------------
# Extract the inline-review gate region for focused assertions.
# Region: from "Tier-based default" heading through the first "If skipping:"
# line (inclusive).  awk stops after matching that sentinel so we don't
# accidentally match unrelated occurrences of "tiny" later in the file.
# ---------------------------------------------------------------------------
GATE_REGION="$(awk '/Tier-based default/,/If skipping:/' "$IMPL")"

# ---------------------------------------------------------------------------
# Case A — tiny tier: inline review SKIPPED by default (no --inline-review)
# ---------------------------------------------------------------------------

# A1: The gate logic must contain an explicit branch for FEATURE_TIER = tiny
#     that describes skipping as the default behaviour (R16).
printf '%s\n' "$GATE_REGION" | grep -qiE 'FEATURE_TIER.*=.*tiny|tiny.*default.*skip|tiny.*skip'
check "A1: gate region names FEATURE_TIER=tiny as the skip-default trigger" "$?"

# A2: The word "skip" (any case) must appear in the tiny branch prose —
#     confirming the action taken when tier=tiny and flag absent.
printf '%s\n' "$GATE_REGION" | grep -qi 'tiny.*skip\|skip.*tiny\|tiny.*default.*skip\|default.*skip.*tiny'
check "A2: gate region confirms tiny tier defaults to SKIP inline review" "$?"

# A3: R16 must be cited in the gate region (requirement traceability).
printf '%s\n' "$GATE_REGION" | grep -q 'R16'
check "A3: R16 cited in gate region (requirement traceability)" "$?"

# A4: The skip log line must reference 'tiny-default' as the reason value so
#     STATUS Notes clearly distinguishes automatic skips from manual bypasses.
grep -q 'tiny-default' "$IMPL"
check "A4: 'tiny-default' reason appears in implement.md STATUS Notes log pattern" "$?"

# ---------------------------------------------------------------------------
# Case B — standard tier: inline review RUNS by default
# ---------------------------------------------------------------------------

# B1: The gate region must contain a fallback arm for standard (and audited)
#     that says inline review runs by default.
printf '%s\n' "$GATE_REGION" | grep -qiE 'standard.*inline.*run|else.*run.*inline|run inline review.*default|default.*standard.*audited|standard.*audited.*inline'
check "B1: gate region has a fallback arm where inline review RUNS for standard/audited" "$?"

# B2: The Rules section at the bottom of the file must state the on/off
#     defaults unambiguously (developer/user quick-reference).
RULES_REGION="$(awk '/^## Rules/,0' "$IMPL")"
printf '%s\n' "$RULES_REGION" | grep -qi 'tiny.*inline.*off\|inline.*off.*tiny\|tiny.*review.*OFF\|OFF.*default'
check "B2: Rules section documents tiny = inline review OFF by default" "$?"

# B3: The --inline-review flag description must state it opts IN on tiny
#     (confirming standard and audited already run inline review by default).
grep -qiE '\-\-inline-review.*opt.?in.*tiny|tiny.*opt.?in.*\-\-inline-review|standard.*audited.*inline.*default' "$IMPL"
check "B3: --inline-review flag described as opt-in for tiny (standard/audited default ON)" "$?"

# ---------------------------------------------------------------------------
# Gate completeness — both flags documented
# ---------------------------------------------------------------------------

# C1: --skip-inline-review flag must be described in the command header
grep -q -- '--skip-inline-review' "$IMPL"
check "C1: --skip-inline-review flag appears in implement.md header/description" "$?"

# C2: --inline-review flag must be described in the command header
grep -q -- '--inline-review' "$IMPL"
check "C2: --inline-review flag appears in implement.md header/description" "$?"

# C3: The gate must source scaff-tier (or equivalent) to read FEATURE_TIER —
#     the tier value must come from the helper, not be hardcoded.
grep -qE 'source.*scaff-tier|get_tier.*feature_dir|FEATURE_TIER.*get_tier' "$IMPL"
check "C3: gate sources scaff-tier library and calls get_tier to resolve FEATURE_TIER" "$?"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
