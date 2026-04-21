#!/usr/bin/env bash
# test/tT20_next_tier_dispatch.sh
#
# Structural tests for T20: tier-aware stage skip in next.md.
#
# Verifies that .claude/commands/scaff/next.md contains the required
# tier-aware dispatch constructs per tech §2.2 Flow B and T20 acceptance
# criteria:
#   1. `bin/scaff-tier` is sourced near the top.
#   2. `tier_skips_stage` is called before stage dispatch.
#   3. `get_tier` is called to read the feature's tier.
#   4. `missing` state is handled (treated as standard).
#   5. `malformed` state is handled with fail-loud path (exit 2).
#   6. STATUS Notes format token present: "next — tier".
#
# These are pure grep-based structural checks — no execution of next.md.
# Bash 3.2 / BSD portable.

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
NEXT_MD="$REPO_ROOT/.claude/commands/scaff/next.md"

PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

if [ ! -f "$NEXT_MD" ]; then
  printf 'FAIL: %s not found\n' "$NEXT_MD" >&2
  exit 1
fi

# 1. bin/scaff-tier is sourced
if grep -q 'scaff-tier' "$NEXT_MD"; then
  pass "next.md sources scaff-tier"
else
  fail "next.md does not source scaff-tier"
fi

# 2. tier_skips_stage is called
if grep -q 'tier_skips_stage' "$NEXT_MD"; then
  pass "next.md calls tier_skips_stage"
else
  fail "next.md does not call tier_skips_stage"
fi

# 3. get_tier is called
if grep -q 'get_tier' "$NEXT_MD"; then
  pass "next.md calls get_tier"
else
  fail "next.md does not call get_tier"
fi

# 4. missing state treated as standard — must appear near tier handling
# "missing" must co-appear with "standard" in the tier-dispatch context,
# not just in the general STATUS-missing sentence.
if grep -q 'missing.*standard\|standard.*missing' "$NEXT_MD"; then
  pass "next.md handles missing tier state (treats as standard)"
else
  fail "next.md does not handle missing tier state as standard"
fi

# 5. malformed state exits non-zero (fail-loud)
# Must have an exit 2 (or similar) associated with malformed path.
if grep -q 'malformed.*exit\|exit.*malformed' "$NEXT_MD"; then
  pass "next.md handles malformed tier state with fail-loud exit"
else
  fail "next.md does not have fail-loud exit for malformed tier state"
fi

# 6. STATUS Notes format: "next — tier"
if grep -q 'next.*tier.*skips\|next — tier' "$NEXT_MD"; then
  pass "next.md contains STATUS Notes format token"
else
  fail "next.md missing STATUS Notes format: 'next — tier ... skips'"
fi

printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
