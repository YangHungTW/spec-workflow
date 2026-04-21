#!/usr/bin/env bash
# test/t34_reviewer_verdict_contract.sh — D1 verdict footer contract test
# Verifies each reviewer agent file contains the mandatory output contract
# elements, and that the verdict footer parse logic classifies severity correctly.
# Pure grep/awk — no invocation of the agents themselves.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests rule, NON-NEGOTIABLE)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t34-test)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AGENTS_DIR="$REPO_ROOT/.claude/agents/scaff"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Helper: classify a verdict footer fixture → PASS | NITS | BLOCK | MALFORMED
#
# Input: a string containing the D1 verdict footer block.
# Logic mirrors D2 aggregator: extract verdict: line, then classify by
# presence of must/should-severity findings.
#
# Rules:
#   - No "## Reviewer verdict" → MALFORMED
#   - No "verdict:" line or value outside {PASS,NITS,BLOCK} → MALFORMED
#   - Any finding with severity: must → BLOCK (regardless of declared verdict)
#   - Any finding with severity: should → NITS (if no must)
#   - No findings → declared verdict respected (PASS)
# ---------------------------------------------------------------------------
classify_footer() {
  local footer="$1"

  # Must have the section header
  printf '%s\n' "$footer" | grep -q '^## Reviewer verdict' || { echo "MALFORMED"; return; }

  # Must have a verdict: line with a known value
  local declared
  declared="$(printf '%s\n' "$footer" | awk '/^verdict:/{print $2; exit}')"
  case "$declared" in
    PASS|NITS|BLOCK) ;;
    *) echo "MALFORMED"; return ;;
  esac

  # Classify by severity of findings (must → BLOCK, should → NITS, else declared)
  if printf '%s\n' "$footer" | grep -q '^\s*severity: must'; then
    echo "BLOCK"; return
  fi
  if printf '%s\n' "$footer" | grep -q '^\s*severity: should'; then
    echo "NITS"; return
  fi
  echo "$declared"
}

# ---------------------------------------------------------------------------
# Per-axis agent contract checks
# ---------------------------------------------------------------------------
check_agent() {
  local axis="$1"
  local agent_file="$AGENTS_DIR/reviewer-${axis}.md"

  # 1. File exists
  if [ ! -f "$agent_file" ]; then
    fail "${axis}: agent file missing: $agent_file"
    return
  fi
  pass "${axis}: agent file exists"

  # Read the file once; all subsequent checks grep the variable (R3)
  local content
  content="$(cat "$agent_file")"

  # 2. model: sonnet frontmatter
  if printf '%s\n' "$content" | grep -q '^model: sonnet$'; then
    pass "${axis}: model: sonnet present"
  else
    fail "${axis}: model: sonnet missing or wrong"
  fi

  # 3. ## Reviewer verdict literal
  if printf '%s\n' "$content" | grep -q '^## Reviewer verdict'; then
    pass "${axis}: ## Reviewer verdict present"
  else
    fail "${axis}: ## Reviewer verdict missing"
  fi

  # 4. axis: <matching-axis>
  if printf '%s\n' "$content" | grep -q "^axis: ${axis}"; then
    pass "${axis}: axis: ${axis} present"
  else
    fail "${axis}: axis: ${axis} missing or wrong"
  fi

  # 5. verdict: PASS | NITS | BLOCK shape
  if printf '%s\n' "$content" | grep -q 'verdict: PASS | NITS | BLOCK'; then
    pass "${axis}: verdict shape present"
  else
    fail "${axis}: verdict: PASS | NITS | BLOCK shape missing"
  fi

  # 6. Findings schema keys: severity, file, line, rule, message
  local missing_keys=""
  for key in severity file line rule message; do
    if ! printf '%s\n' "$content" | grep -q "${key}:"; then
      missing_keys="${missing_keys} ${key}"
    fi
  done
  if [ -z "$missing_keys" ]; then
    pass "${axis}: all 5 findings schema keys present"
  else
    fail "${axis}: findings schema keys missing:${missing_keys}"
  fi

  # 7. Stay-in-lane instruction
  if printf '%s\n' "$content" | grep -q 'Comment only on findings against your axis rubric'; then
    pass "${axis}: stay-in-lane instruction present"
  else
    fail "${axis}: stay-in-lane instruction missing"
  fi
}

for axis in security performance style; do
  check_agent "$axis"
done

# ---------------------------------------------------------------------------
# Round-trip severity classification tests
# ---------------------------------------------------------------------------

# Fixture A — one must finding → classifies to BLOCK
FIXTURE_MUST="## Reviewer verdict
axis: security
verdict: BLOCK
findings:
  - severity: must
    file: bin/example.sh
    line: 10
    rule: injection-attacks
    message: String-built shell command includes variable FOO"

result="$(classify_footer "$FIXTURE_MUST")"
if [ "$result" = "BLOCK" ]; then
  pass "round-trip: must finding → BLOCK"
else
  fail "round-trip: must finding → expected BLOCK, got $result"
fi

# Fixture B — one should finding, no must → classifies to NITS
FIXTURE_SHOULD="## Reviewer verdict
axis: performance
verdict: NITS
findings:
  - severity: should
    file: bin/example.sh
    line: 20
    rule: reviewer-performance
    message: git invoked once per file; consider batching"

result="$(classify_footer "$FIXTURE_SHOULD")"
if [ "$result" = "NITS" ]; then
  pass "round-trip: should finding → NITS"
else
  fail "round-trip: should finding → expected NITS, got $result"
fi

# Fixture C — zero findings → classifies to PASS
FIXTURE_PASS="## Reviewer verdict
axis: style
verdict: PASS
findings:"

result="$(classify_footer "$FIXTURE_PASS")"
if [ "$result" = "PASS" ]; then
  pass "round-trip: no findings → PASS"
else
  fail "round-trip: no findings → expected PASS, got $result"
fi

# Fixture D — malformed (missing header) → MALFORMED
FIXTURE_MALFORMED="axis: security
verdict: BLOCK
findings:"

result="$(classify_footer "$FIXTURE_MALFORMED")"
if [ "$result" = "MALFORMED" ]; then
  pass "round-trip: missing header → MALFORMED"
else
  fail "round-trip: missing header → expected MALFORMED, got $result"
fi

# Fixture E — malformed (unknown verdict value) → MALFORMED
FIXTURE_BAD_VERDICT="## Reviewer verdict
axis: security
verdict: UNKNOWN
findings:"

result="$(classify_footer "$FIXTURE_BAD_VERDICT")"
if [ "$result" = "MALFORMED" ]; then
  pass "round-trip: unknown verdict → MALFORMED"
else
  fail "round-trip: unknown verdict → expected MALFORMED, got $result"
fi

# ---------------------------------------------------------------------------
# Per-axis fixture round-trips (one full D1 footer per axis)
# ---------------------------------------------------------------------------
for axis in security performance style; do
  fixture="## Reviewer verdict
axis: ${axis}
verdict: BLOCK
findings:
  - severity: must
    file: bin/test-${axis}.sh
    line: 1
    rule: reviewer-${axis}
    message: test finding for ${axis} axis"

  # Verify fixture has all 5 required keys
  missing=""
  for key in severity file line rule message; do
    if ! printf '%s\n' "$fixture" | grep -q "${key}:"; then
      missing="${missing} ${key}"
    fi
  done
  if [ -z "$missing" ]; then
    pass "fixture-${axis}: all 5 findings keys present"
  else
    fail "fixture-${axis}: missing keys:${missing}"
  fi

  # Verify classify_footer agrees with the must finding
  r="$(classify_footer "$fixture")"
  if [ "$r" = "BLOCK" ]; then
    pass "fixture-${axis}: classifies to BLOCK"
  else
    fail "fixture-${axis}: expected BLOCK, got $r"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
