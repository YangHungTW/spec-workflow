#!/usr/bin/env bash
# test/t75_tier_no_sed_forks.sh
#
# Structural / performance test — get_tier must NOT invoke sed for value
# extraction; shell parameter expansion replaces the two sed forks.
#
# Rule: reviewer/performance.md "Prefer awk/sed over python3" and
# "Minimise fork/exec in hot paths" — but specifically the first-attempt
# review flagged TWO sed forks in get_tier (lines 77 & 79) for a function
# that only needs grep + shell expansion.  This test asserts the final
# implementation is sed-free inside the value-extraction section.
#
# Approach: grep-structural.  We extract the get_tier function body and
# check that sed does NOT appear inside it as a command invocation.
# We also check that grep -m1 (the one allowed external call) IS present.
#
# Requirements: perf finding from T2 inline review.
# Depends on: T2 (bin/specflow-tier exists).

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TIER_LIB="$REPO_ROOT/bin/specflow-tier"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sanity
# ---------------------------------------------------------------------------
if [ ! -f "$TIER_LIB" ]; then
  echo "FAIL: bin/specflow-tier not found: $TIER_LIB" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Extract the get_tier function body
# (awk: from the opening line to the closing '}' that ends the function)
# ---------------------------------------------------------------------------
get_tier_block=$(awk '/^get_tier\(\)/,/^}/' "$TIER_LIB" 2>/dev/null)

if [ -z "$get_tier_block" ]; then
  fail "get_tier() block not found in $TIER_LIB"
  echo "=== Results: $PASS passed, $FAIL failed ==="
  exit 1
else
  pass "get_tier() block extracted (non-empty)"
fi

# ---------------------------------------------------------------------------
# Check 1: sed must NOT appear as a command inside get_tier
# (value extraction must use shell parameter expansion, not sed forks)
# Filter out comment lines first so mentions of "sed" in prose comments
# do not trigger a false positive.
# ---------------------------------------------------------------------------
non_comment_block=$(printf '%s\n' "$get_tier_block" | grep -v '^[[:space:]]*#')
if printf '%s\n' "$non_comment_block" | grep -qE '\bsed[[:space:]]|[|][[:space:]]*sed|\$\(.*sed'; then
  fail "Check 1: sed command invocation found inside get_tier — should use shell parameter expansion instead"
else
  pass "Check 1: no sed command invocation inside get_tier (parameter expansion used)"
fi

# ---------------------------------------------------------------------------
# Check 2: grep -m1 IS present (the one allowed external fork for line match)
# ---------------------------------------------------------------------------
if printf '%s\n' "$get_tier_block" | grep -qF 'grep -m1'; then
  pass "Check 2: grep -m1 present in get_tier (single external fork for line match)"
else
  fail "Check 2: grep -m1 not found in get_tier — the line-match external call may be missing or changed"
fi

# ---------------------------------------------------------------------------
# Check 3: shell parameter expansion strips the prefix
# Pattern: ##* (strip longest prefix) somewhere in the block
# ---------------------------------------------------------------------------
if printf '%s\n' "$get_tier_block" | grep -qF '##'; then
  pass "Check 3: '##' parameter expansion present in get_tier (prefix strip)"
else
  fail "Check 3: '##' parameter expansion not found in get_tier — sed-free strip may not be implemented"
fi

# ---------------------------------------------------------------------------
# Check 4: functional regression — get_tier still returns correct values
# after the sed removal (live execution check)
# Fixtures must live inside REPO_ROOT so the boundary guard does not reject them.
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t75-tier-perf)"
trap 'rm -rf "$SANDBOX" "$REPO_ROOT/.spec-workflow/features/_t75_perf_fixture"' EXIT

FIXTURE_DIR="$REPO_ROOT/.spec-workflow/features/_t75_perf_fixture"
mkdir -p "$FIXTURE_DIR"

# Test with a value that had CRLF in the original sed-based implementation
printf -- '- **slug**: test\n- **has-ui**: false\n- **tier**: audited\n- **stage**: plan\n' \
  > "$FIXTURE_DIR/STATUS.md"

result=$(SPECFLOW_TIER_LOADED=0 REPO_ROOT="$REPO_ROOT" bash -c \
  ". '$TIER_LIB'; get_tier '$FIXTURE_DIR'" 2>/dev/null) || true

if [ "$result" = "audited" ]; then
  pass "Check 4: get_tier returns 'audited' correctly after sed removal"
else
  fail "Check 4: get_tier returned '$result' (expected 'audited') — regression after sed removal"
fi

# Also test 'tiny' and 'malformed'
printf -- '- **tier**: tiny\n' > "$FIXTURE_DIR/STATUS.md"
result_tiny=$(SPECFLOW_TIER_LOADED=0 REPO_ROOT="$REPO_ROOT" bash -c \
  ". '$TIER_LIB'; get_tier '$FIXTURE_DIR'" 2>/dev/null) || true
if [ "$result_tiny" = "tiny" ]; then
  pass "Check 4b: get_tier returns 'tiny' correctly"
else
  fail "Check 4b: get_tier returned '$result_tiny' (expected 'tiny')"
fi

printf -- '- **tier**: notavalid\n' > "$FIXTURE_DIR/STATUS.md"
result_mal=$(SPECFLOW_TIER_LOADED=0 REPO_ROOT="$REPO_ROOT" bash -c \
  ". '$TIER_LIB'; get_tier '$FIXTURE_DIR'" 2>/dev/null) || true
if [ "$result_mal" = "malformed" ]; then
  pass "Check 4c: get_tier returns 'malformed' for invalid value"
else
  fail "Check 4c: get_tier returned '$result_mal' (expected 'malformed')"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
