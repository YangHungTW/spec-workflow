#!/usr/bin/env bash
# test/t76_aggregate_verdicts.sh
#
# TDD red-test for bin/specflow-aggregate-verdicts.
# Authored as part of T7 to satisfy the "no production code without a failing
# test first" requirement.  Full coverage lives in T8's test file; this script
# covers the minimal contract needed to drive T7's implementation.
#
# Coverage (mirrors T8 spec to bootstrap TDD):
#   1. PASS / NITS / BLOCK aggregation for three-axis review case.
#   2. Malformed-footer cases → BLOCK.
#   3. Security-must signal → suggest-audited-upgrade line present.
#   4. No signal when finding is should/avoid or non-security axis.
#   5. Exit 0 on PASS/NITS/BLOCK; exit 2 on bad argv.
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md.
# Bash 3.2 / BSD portable — no readlink -f, realpath, jq, mapfile, [[ =~ ]].

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root and script under test
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AGG="${AGG:-$REPO_ROOT/bin/specflow-aggregate-verdicts}"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t76.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Guard: CLI must exist
# ---------------------------------------------------------------------------
if [ ! -f "$AGG" ]; then
  printf 'SKIP: %s not found — T7 not yet committed; re-run post-wave.\n' \
    "$AGG" >&2
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
# Fixture helpers
# ---------------------------------------------------------------------------

# make_verdict_file <dir> <name> <axis> <verdict> [severity]
# Creates a well-formed verdict file in <dir>/<name>.txt.
# If severity is provided, adds a finding line with that severity.
make_verdict_file() {
  local dir="$1"
  local name="$2"
  local axis="$3"
  local verdict="$4"
  local severity="${5:-}"

  mkdir -p "$dir"
  {
    printf '## Reviewer verdict\n'
    printf 'axis: %s\n' "$axis"
    printf 'verdict: %s\n' "$verdict"
    if [ -n "$severity" ]; then
      printf 'findings:\n'
      printf '  - severity: %s\n' "$severity"
      printf '    file: bin/example.sh\n'
      printf '    line: 1\n'
      printf '    rule: test-rule\n'
      printf '    message: test finding\n'
    fi
  } > "$dir/${name}.txt"
}

# ---------------------------------------------------------------------------
# 1. Three-axis review: {PASS, PASS, PASS} → PASS
# ---------------------------------------------------------------------------
VDIR="$SANDBOX/v_all_pass"
mkdir -p "$VDIR"
make_verdict_file "$VDIR" "T1-security"    "security"    "PASS"
make_verdict_file "$VDIR" "T1-performance" "performance" "PASS"
make_verdict_file "$VDIR" "T1-style"       "style"       "PASS"

set +e
OUT="$("$AGG" security performance style --dir "$VDIR" 2>/dev/null)"
RC=$?
set -e

if [ "$RC" -eq 0 ] && [ "$OUT" = "PASS" ]; then
  pass "three-axis all-PASS → PASS (exit 0)"
else
  fail "three-axis all-PASS → got '$OUT' exit $RC (expected 'PASS' exit 0)"
fi

# ---------------------------------------------------------------------------
# 2. Three-axis: {PASS, NITS, PASS} → NITS
# ---------------------------------------------------------------------------
VDIR="$SANDBOX/v_nits"
mkdir -p "$VDIR"
make_verdict_file "$VDIR" "T2-security"    "security"    "PASS"
make_verdict_file "$VDIR" "T2-performance" "performance" "NITS"
make_verdict_file "$VDIR" "T2-style"       "style"       "PASS"

set +e
OUT="$("$AGG" security performance style --dir "$VDIR" 2>/dev/null)"
RC=$?
set -e

if [ "$RC" -eq 0 ] && [ "$OUT" = "NITS" ]; then
  pass "three-axis with NITS → NITS (exit 0)"
else
  fail "three-axis with NITS → got '$OUT' exit $RC (expected 'NITS' exit 0)"
fi

# ---------------------------------------------------------------------------
# 3. Three-axis: {PASS, BLOCK, PASS} → BLOCK
# ---------------------------------------------------------------------------
VDIR="$SANDBOX/v_block"
mkdir -p "$VDIR"
make_verdict_file "$VDIR" "T3-security"    "security"    "PASS"
make_verdict_file "$VDIR" "T3-performance" "performance" "BLOCK"
make_verdict_file "$VDIR" "T3-style"       "style"       "PASS"

set +e
OUT="$("$AGG" security performance style --dir "$VDIR" 2>/dev/null)"
RC=$?
set -e

if [ "$RC" -eq 0 ] && [ "$OUT" = "BLOCK" ]; then
  pass "three-axis with BLOCK → BLOCK (exit 0)"
else
  fail "three-axis with BLOCK → got '$OUT' exit $RC (expected 'BLOCK' exit 0)"
fi

# ---------------------------------------------------------------------------
# 4. Malformed: missing ## Reviewer verdict header → BLOCK
# ---------------------------------------------------------------------------
VDIR="$SANDBOX/v_malformed_header"
mkdir -p "$VDIR"
printf 'verdict: PASS\naxis: security\n' > "$VDIR/T4-security.txt"

set +e
OUT="$("$AGG" security --dir "$VDIR" 2>/dev/null)"
RC=$?
set -e

if [ "$RC" -eq 0 ] && [ "$OUT" = "BLOCK" ]; then
  pass "malformed (missing header) → BLOCK (exit 0)"
else
  fail "malformed (missing header) → got '$OUT' exit $RC (expected 'BLOCK' exit 0)"
fi

# ---------------------------------------------------------------------------
# 5. Malformed: missing verdict: key → BLOCK
# ---------------------------------------------------------------------------
VDIR="$SANDBOX/v_malformed_no_verdict"
mkdir -p "$VDIR"
printf '## Reviewer verdict\naxis: security\n' > "$VDIR/T5-security.txt"

set +e
OUT="$("$AGG" security --dir "$VDIR" 2>/dev/null)"
RC=$?
set -e

if [ "$RC" -eq 0 ] && [ "$OUT" = "BLOCK" ]; then
  pass "malformed (missing verdict: key) → BLOCK (exit 0)"
else
  fail "malformed (missing verdict: key) → got '$OUT' exit $RC (expected 'BLOCK' exit 0)"
fi

# ---------------------------------------------------------------------------
# 6. Malformed: verdict value outside closed set → BLOCK
# ---------------------------------------------------------------------------
VDIR="$SANDBOX/v_malformed_bad_verdict"
mkdir -p "$VDIR"
printf '## Reviewer verdict\naxis: security\nverdict: OOPS\n' \
  > "$VDIR/T6-security.txt"

set +e
OUT="$("$AGG" security --dir "$VDIR" 2>/dev/null)"
RC=$?
set -e

if [ "$RC" -eq 0 ] && [ "$OUT" = "BLOCK" ]; then
  pass "malformed (verdict OOPS) → BLOCK (exit 0)"
else
  fail "malformed (verdict OOPS) → got '$OUT' exit $RC (expected 'BLOCK' exit 0)"
fi

# ---------------------------------------------------------------------------
# 7. Security-must signal — axis: security + severity: must → suggest-audited-upgrade
# ---------------------------------------------------------------------------
VDIR="$SANDBOX/v_sec_must"
mkdir -p "$VDIR"
make_verdict_file "$VDIR" "T7-security" "security" "BLOCK" "must"

set +e
OUT="$("$AGG" security --dir "$VDIR" 2>/dev/null)"
RC=$?
set -e

LINE1="$(printf '%s\n' "$OUT" | head -1)"
LINE2="$(printf '%s\n' "$OUT" | sed -n '2p')"

if [ "$RC" -eq 0 ] && [ "$LINE1" = "BLOCK" ]; then
  pass "security-must: aggregated verdict is BLOCK"
else
  fail "security-must: expected BLOCK exit 0; got '$LINE1' exit $RC"
fi

case "$LINE2" in
  "suggest-audited-upgrade:"*)
    pass "security-must: suggest-audited-upgrade line present"
    ;;
  *)
    fail "security-must: suggest-audited-upgrade line missing; got '$LINE2'"
    ;;
esac

# ---------------------------------------------------------------------------
# 8. No signal when finding severity is should (not must) on security axis
# ---------------------------------------------------------------------------
VDIR="$SANDBOX/v_sec_should"
mkdir -p "$VDIR"
make_verdict_file "$VDIR" "T8-security" "security" "NITS" "should"

set +e
OUT="$("$AGG" security --dir "$VDIR" 2>/dev/null)"
RC=$?
set -e

LINE2_SHOULD="$(printf '%s\n' "$OUT" | sed -n '2p')"
case "$LINE2_SHOULD" in
  "suggest-audited-upgrade:"*)
    fail "security-should: spurious suggest-audited-upgrade when severity=should"
    ;;
  *)
    pass "security-should: no suggest-audited-upgrade when severity=should"
    ;;
esac

# ---------------------------------------------------------------------------
# 9. No signal when severity is must but axis is NOT security
# ---------------------------------------------------------------------------
VDIR="$SANDBOX/v_non_sec_must"
mkdir -p "$VDIR"
make_verdict_file "$VDIR" "T9-performance" "performance" "BLOCK" "must"

set +e
OUT="$("$AGG" performance --dir "$VDIR" 2>/dev/null)"
RC=$?
set -e

LINE2_NONSEC="$(printf '%s\n' "$OUT" | sed -n '2p')"
case "$LINE2_NONSEC" in
  "suggest-audited-upgrade:"*)
    fail "non-security-must: spurious suggest-audited-upgrade when axis is performance"
    ;;
  *)
    pass "non-security-must: no suggest-audited-upgrade for performance axis must"
    ;;
esac

# ---------------------------------------------------------------------------
# 10. Exit 2 on bad argv — no axis-set
# ---------------------------------------------------------------------------
set +e
"$AGG" --dir "$SANDBOX/v_all_pass" > /dev/null 2>&1
RC_NOAXIS=$?
set -e

if [ "$RC_NOAXIS" -eq 2 ]; then
  pass "exit 2 when no axis-set given"
else
  fail "expected exit 2 with no axis-set; got exit $RC_NOAXIS"
fi

# ---------------------------------------------------------------------------
# 11. Exit 2 on bad argv — missing --dir
# ---------------------------------------------------------------------------
set +e
"$AGG" security performance style > /dev/null 2>&1
RC_NODIR=$?
set -e

if [ "$RC_NODIR" -eq 2 ]; then
  pass "exit 2 when --dir not given"
else
  fail "expected exit 2 without --dir; got exit $RC_NODIR"
fi

# ---------------------------------------------------------------------------
# 12. Exit 2 on bad argv — dir does not exist
# ---------------------------------------------------------------------------
set +e
"$AGG" security --dir "$SANDBOX/no_such_dir" > /dev/null 2>&1
RC_NOEXIST=$?
set -e

if [ "$RC_NOEXIST" -eq 2 ]; then
  pass "exit 2 when --dir does not exist"
else
  fail "expected exit 2 for nonexistent dir; got exit $RC_NOEXIST"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
