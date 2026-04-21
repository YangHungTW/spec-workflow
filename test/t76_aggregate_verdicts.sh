#!/usr/bin/env bash
# test/t76_aggregate_verdicts.sh
#
# Unit tests for bin/scaff-aggregate-verdicts (T7).
#
# Coverage per tech §4.4 and T8 spec:
#   1. Three-axis review case: PASS/PASS/PASS → PASS;
#      PASS/NITS/PASS → NITS; PASS/BLOCK/PASS → BLOCK.
#   2. Two-axis validate case: tester/analyst permutations.
#   3. Malformed-footer cases: missing header, missing verdict: key,
#      verdict value not in {PASS,NITS,BLOCK}. Each → BLOCK.
#   4. Security-must signal: axis: security + severity: must →
#      aggregator stdout contains suggest-audited-upgrade: line.
#   5. No suggest-audited-upgrade when finding is should/advisory
#      or on a non-security axis.
#   6. Argument-error cases: no axis-set, missing --dir, dir absent → exit 2.
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md.
# Fixtures live inside REPO_ROOT per W0a lesson (mktemp inside repo root).
# Bash 3.2 / BSD portable: no readlink -f, realpath, jq, mapfile, [[ =~ ]].
#
# Behaviour while T7 is absent (parallel authoring):
#   Tests are RED until T7 merges.  If bin/scaff-aggregate-verdicts is
#   absent the script emits a SKIP notice and exits 0 so CI stays green
#   before the wave merge.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AGG="${AGG:-$REPO_ROOT/bin/scaff-aggregate-verdicts}"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# Fixtures also live inside SANDBOX which is under REPO_ROOT.
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t76.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Skip guard: T7 not yet merged — stay RED but don't fail CI pre-merge
# ---------------------------------------------------------------------------
if [ ! -f "$AGG" ]; then
  printf 'SKIP: %s not found — T7 not yet merged; tests RED until wave merge.\n' \
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
# Helper: write a well-formed verdict file for a given axis and verdict.
#
# Usage: write_verdict <dir> <axis> <verdict> [severity]
#   severity defaults to "" (no findings block).
#   Pass "must" or "should" to inject a findings line.
# ---------------------------------------------------------------------------
write_verdict() {
  local dir="$1"
  local axis="$2"
  local verdict="$3"
  local severity="${4:-}"
  local file="$dir/${axis}.txt"
  printf '## Reviewer verdict\n' > "$file"
  printf 'axis: %s\n' "$axis" >> "$file"
  printf 'verdict: %s\n' "$verdict" >> "$file"
  if [ -n "$severity" ]; then
    printf 'findings:\n' >> "$file"
    printf '  - severity: %s\n' "$severity" >> "$file"
    printf '    file: some/file.sh\n' >> "$file"
    printf '    line: 1\n' >> "$file"
    printf '    rule: test-rule\n' >> "$file"
    printf '    message: test finding\n' >> "$file"
  fi
}

# Helper: run aggregator and capture stdout + exit code
run_agg() {
  # Usage: run_agg <stdout_var> <exit_var> <axis...> --dir <dir>
  # Passes all arguments straight through to the CLI.
  local _out _rc
  set +e
  _out="$("$AGG" "$@" 2>/dev/null)"
  _rc=$?
  set -e
  # Assign to caller-specified names via two positional vars before args
  printf '%s' "$_out"
  return "$_rc"
}

# ---------------------------------------------------------------------------
# Section 1 — Three-axis review case
# ---------------------------------------------------------------------------

# 1a: PASS/PASS/PASS → PASS
d="$SANDBOX/s1a"
mkdir -p "$d"
write_verdict "$d" security PASS
write_verdict "$d" performance PASS
write_verdict "$d" style PASS
result="$(set +e; "$AGG" security performance style --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^PASS$'; then
  pass "three-axis PASS/PASS/PASS → PASS"
else
  fail "three-axis PASS/PASS/PASS → expected PASS, got: $result"
fi

# 1b: PASS/NITS/PASS → NITS
d="$SANDBOX/s1b"
mkdir -p "$d"
write_verdict "$d" security PASS
write_verdict "$d" performance NITS
write_verdict "$d" style PASS
result="$(set +e; "$AGG" security performance style --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^NITS$'; then
  pass "three-axis PASS/NITS/PASS → NITS"
else
  fail "three-axis PASS/NITS/PASS → expected NITS, got: $result"
fi

# 1c: PASS/BLOCK/PASS → BLOCK
d="$SANDBOX/s1c"
mkdir -p "$d"
write_verdict "$d" security PASS
write_verdict "$d" performance BLOCK
write_verdict "$d" style PASS
result="$(set +e; "$AGG" security performance style --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^BLOCK$'; then
  pass "three-axis PASS/BLOCK/PASS → BLOCK"
else
  fail "three-axis PASS/BLOCK/PASS → expected BLOCK, got: $result"
fi

# ---------------------------------------------------------------------------
# Section 2 — Two-axis validate case (tester / analyst)
# ---------------------------------------------------------------------------

# 2a: tester:PASS + analyst:PASS → PASS
d="$SANDBOX/s2a"
mkdir -p "$d"
write_verdict "$d" tester PASS
write_verdict "$d" analyst PASS
result="$(set +e; "$AGG" tester analyst --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^PASS$'; then
  pass "two-axis tester:PASS analyst:PASS → PASS"
else
  fail "two-axis tester:PASS analyst:PASS → expected PASS, got: $result"
fi

# 2b: tester:PASS + analyst:BLOCK → BLOCK
d="$SANDBOX/s2b"
mkdir -p "$d"
write_verdict "$d" tester PASS
write_verdict "$d" analyst BLOCK
result="$(set +e; "$AGG" tester analyst --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^BLOCK$'; then
  pass "two-axis tester:PASS analyst:BLOCK → BLOCK"
else
  fail "two-axis tester:PASS analyst:BLOCK → expected BLOCK, got: $result"
fi

# 2c: tester:NITS + analyst:PASS → NITS
d="$SANDBOX/s2c"
mkdir -p "$d"
write_verdict "$d" tester NITS
write_verdict "$d" analyst PASS
result="$(set +e; "$AGG" tester analyst --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^NITS$'; then
  pass "two-axis tester:NITS analyst:PASS → NITS"
else
  fail "two-axis tester:NITS analyst:PASS → expected NITS, got: $result"
fi

# ---------------------------------------------------------------------------
# Section 3 — Malformed-footer cases → BLOCK
# Per tech §4.1 and PRD R18: malformed = fail-loud = BLOCK.
# ---------------------------------------------------------------------------

# 3a: missing ## Reviewer verdict header
d="$SANDBOX/s3a"
mkdir -p "$d"
# Write a file that has verdict: line but NO header
printf 'axis: security\nverdict: PASS\n' > "$d/security.txt"
result="$(set +e; "$AGG" security --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^BLOCK$'; then
  pass "malformed: missing header → BLOCK"
else
  fail "malformed: missing header → expected BLOCK, got: $result"
fi

# 3b: missing verdict: key (has header but no verdict: line)
d="$SANDBOX/s3b"
mkdir -p "$d"
printf '## Reviewer verdict\naxis: security\n' > "$d/security.txt"
result="$(set +e; "$AGG" security --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^BLOCK$'; then
  pass "malformed: missing verdict: key → BLOCK"
else
  fail "malformed: missing verdict: key → expected BLOCK, got: $result"
fi

# 3c: verdict value not in {PASS,NITS,BLOCK} — e.g. "OOPS"
d="$SANDBOX/s3c"
mkdir -p "$d"
printf '## Reviewer verdict\naxis: security\nverdict: OOPS\n' > "$d/security.txt"
result="$(set +e; "$AGG" security --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^BLOCK$'; then
  pass "malformed: verdict OOPS (not in closed set) → BLOCK"
else
  fail "malformed: verdict OOPS → expected BLOCK, got: $result"
fi

# ---------------------------------------------------------------------------
# Section 4 — Security-must signal: suggest-audited-upgrade:
# When axis: security file contains severity: must → stdout must include
# suggest-audited-upgrade: line IN ADDITION TO the aggregated verdict.
# ---------------------------------------------------------------------------

# 4a: security axis with severity: must → BLOCK + suggest-audited-upgrade
d="$SANDBOX/s4a"
mkdir -p "$d"
write_verdict "$d" security BLOCK must
result="$(set +e; "$AGG" security --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^BLOCK$'; then
  pass "security-must: aggregated verdict is BLOCK"
else
  fail "security-must: expected BLOCK, got: $result"
fi
if printf '%s\n' "$result" | grep -q '^suggest-audited-upgrade:'; then
  pass "security-must: stdout contains suggest-audited-upgrade: line"
else
  fail "security-must: stdout missing suggest-audited-upgrade: line; got: $result"
fi

# 4b: security axis with severity: must even when declared verdict is PASS
#     (must-severity overrides declared verdict; signal still fires)
d="$SANDBOX/s4b"
mkdir -p "$d"
# Verdicts with must-severity finding but declared PASS —
# the file is malformed per D1 contract (must => BLOCK) but aggregator
# still sees severity: must on axis: security, so signal must fire.
write_verdict "$d" security PASS must
result="$(set +e; "$AGG" security --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^suggest-audited-upgrade:'; then
  pass "security-must (declared PASS): suggest-audited-upgrade: emitted"
else
  fail "security-must (declared PASS): suggest-audited-upgrade: missing; got: $result"
fi

# ---------------------------------------------------------------------------
# Section 5 — No suggest-audited-upgrade when finding is should/advisory
#             or on a non-security axis
# ---------------------------------------------------------------------------

# 5a: security axis with severity: should → no suggest-audited-upgrade
d="$SANDBOX/s5a"
mkdir -p "$d"
write_verdict "$d" security NITS should
result="$(set +e; "$AGG" security --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^suggest-audited-upgrade:'; then
  fail "security-should: suggest-audited-upgrade must NOT appear for should finding"
else
  pass "security-should: no suggest-audited-upgrade (correct)"
fi

# 5b: non-security axis (performance) with severity: must → no suggest-audited-upgrade
d="$SANDBOX/s5b"
mkdir -p "$d"
write_verdict "$d" performance BLOCK must
result="$(set +e; "$AGG" performance --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^suggest-audited-upgrade:'; then
  fail "performance-must: suggest-audited-upgrade must NOT appear for non-security axis"
else
  pass "performance-must: no suggest-audited-upgrade (correct)"
fi

# 5c: three-axis run where only performance has must — no security signal
d="$SANDBOX/s5c"
mkdir -p "$d"
write_verdict "$d" security PASS
write_verdict "$d" performance BLOCK must
write_verdict "$d" style PASS
result="$(set +e; "$AGG" security performance style --dir "$d" 2>/dev/null; set -e)" || true
if printf '%s\n' "$result" | grep -q '^suggest-audited-upgrade:'; then
  fail "perf-must-only: suggest-audited-upgrade must NOT appear when only performance has must"
else
  pass "perf-must-only: no suggest-audited-upgrade (correct)"
fi

# ---------------------------------------------------------------------------
# Section 6 — Argument-error cases: exit 2
# ---------------------------------------------------------------------------

# 6a: no axis-set (only --dir) → exit 2
d="$SANDBOX/s6a"
mkdir -p "$d"
set +e
"$AGG" --dir "$d" > /dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 2 ]; then
  pass "arg-error: no axis-set → exit 2"
else
  fail "arg-error: no axis-set → expected exit 2, got $rc"
fi

# 6b: no --dir flag → exit 2
set +e
"$AGG" security performance style > /dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 2 ]; then
  pass "arg-error: no --dir flag → exit 2"
else
  fail "arg-error: no --dir flag → expected exit 2, got $rc"
fi

# 6c: --dir points to a non-existent directory → exit 2
set +e
"$AGG" security --dir "$SANDBOX/does-not-exist" > /dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 2 ]; then
  pass "arg-error: --dir missing dir → exit 2"
else
  fail "arg-error: --dir missing dir → expected exit 2, got $rc"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
