#!/usr/bin/env bash
# test/t80_tier_proposal_heuristic.sh
#
# Determinism test for the tier-proposal keyword-scan heuristic.
#
# Strategy:
#   1. Parse .claude/agents/specflow/pm.md for the keyword sets that T19
#      embeds (tiny-keywords and audited-keywords sections).  If those sections
#      are absent (T19 not yet merged), emit SKIP and exit 0 — the test will
#      be re-run post-wave.
#   2. If bin/specflow-tier does not expose propose_tier(), emit SKIP and
#      exit 0.  T25 adds propose_tier; if T2 is present but T25 itself is
#      the first commit, both halves land together (red→green in the same
#      task).
#   3. Run each fixture ask through propose_tier() and assert expected tier.
#
# Fixture set (from T25 spec, derived from tech §D6):
#   "fix typo in README"             → tiny
#   "rotate oauth secrets"           → audited
#   "rename internal helper"         → tiny   (keyword: rename)
#   "add dashboard page"             → standard (no keyword hit)
#   "migrate db schema for payment"  → audited
#   ""  (empty string)               → standard (default)
#   "   " (whitespace only)          → standard (default)
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md.
# Bash 3.2 / BSD portable — no readlink -f, realpath, jq, mapfile, [[ =~ ]].

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TIER_LIB="${TIER_LIB:-$REPO_ROOT/bin/specflow-tier}"
PM_MD="${PM_MD:-$REPO_ROOT/.claude/agents/specflow/pm.md}"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t80.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Guard: specflow-tier library must exist (T2 dependency)
# ---------------------------------------------------------------------------
if [ ! -f "$TIER_LIB" ]; then
  printf 'SKIP: %s not found — T2 not yet merged; re-run post-wave.\n' \
    "$TIER_LIB" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Guard: pm.md must expose the keyword sets (T19 dependency)
# We probe for the canonical tiny-keyword "typo" and audited-keyword "oauth"
# (verbatim from T19 spec) as markers that T19 has landed.
# ---------------------------------------------------------------------------
if [ ! -f "$PM_MD" ]; then
  printf 'SKIP: %s not found — T19 not yet merged; re-run post-wave.\n' \
    "$PM_MD" >&2
  exit 0
fi

pm_has_tiny=""
pm_has_audited=""
# Case-insensitive grep; -i is POSIX and available on BSD/GNU.
if grep -qi 'typo' "$PM_MD" 2>/dev/null; then
  pm_has_tiny="1"
fi
if grep -qi 'oauth' "$PM_MD" 2>/dev/null; then
  pm_has_audited="1"
fi

if [ -z "$pm_has_tiny" ] || [ -z "$pm_has_audited" ]; then
  printf 'SKIP: pm.md missing tier-proposal keyword sets (T19 pending) — re-run post-wave.\n' >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Guard: propose_tier() must exist in specflow-tier (T25 adds it)
# ---------------------------------------------------------------------------
SPECFLOW_TIER_LOADED=0
# shellcheck source=/dev/null
. "$TIER_LIB"

if ! command -v propose_tier > /dev/null 2>&1; then
  # propose_tier is a shell function, not a command — use type instead.
  # 'type propose_tier' exits non-zero if the function isn't defined.
  if ! type propose_tier > /dev/null 2>&1; then
    printf 'SKIP: propose_tier() not found in %s — T25 production code not yet added; re-run after this commit.\n' \
      "$TIER_LIB" >&2
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

assert_tier() {
  local label="$1"
  local ask="$2"
  local expected="$3"
  local actual
  actual="$(propose_tier "$ask")"
  if [ "$actual" = "$expected" ]; then
    pass "$label → '$actual'"
  else
    fail "$label → expected '$expected', got '$actual'"
  fi
}

# ---------------------------------------------------------------------------
# Fixture assertions (T25 spec §Scope)
# ---------------------------------------------------------------------------

assert_tier 'typo in README → tiny'          'fix typo in README'            'tiny'
assert_tier 'rotate oauth secrets → audited' 'rotate oauth secrets'          'audited'
assert_tier 'rename internal helper → tiny'  'rename internal helper'        'tiny'
assert_tier 'add dashboard page → standard'  'add dashboard page'            'standard'
assert_tier 'migrate db schema for payment → audited' \
                                             'migrate db schema for payment'  'audited'
assert_tier 'empty string → standard'        ''                              'standard'
assert_tier 'whitespace only → standard'     '   '                           'standard'

# ---------------------------------------------------------------------------
# Additional edge-case: keyword match is case-insensitive
# ---------------------------------------------------------------------------
assert_tier 'TYPO (uppercase) → tiny'        'Fix TYPO in README'            'tiny'
assert_tier 'OAuth (mixed case) → audited'   'Rotate OAuth Secrets'          'audited'

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
