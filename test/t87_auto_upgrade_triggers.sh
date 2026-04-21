#!/usr/bin/env bash
# test/t87_auto_upgrade_triggers.sh
#
# Structural tests for the four auto-upgrade triggers (T29, AC9, R14, D7).
#
# Four independent sub-tests — each asserts one trigger fires on the
# appropriate production artefact:
#
#   A. Diff-lines trigger  — implement.md threshold block:
#        250-line single-file diff exceeds SPECFLOW_TIER_DIFF_LINES:-200.
#        Verify the threshold logic is present and the WARNING/STATUS note
#        shape matches the D7 spec (structural grep — full implement
#        invocation is infeasible per tech §4.4).
#
#   B. Diff-files trigger  — implement.md threshold block:
#        100-line diff across 5 files exceeds SPECFLOW_TIER_DIFF_FILES:-3.
#        Same structural verification strategy.
#
#   C. Security-must trigger — bin/scaff-aggregate-verdicts:
#        A verdict dir containing axis:security + severity:must causes the
#        aggregator to emit a "suggest-audited-upgrade:" line on stdout.
#
#   D. Sensitive-path trigger — pm.md keyword scan:
#        pm.md keyword-scan lists "settings.json" and "auth" in the audited
#        keyword set so the PM proposes audited for any ask referencing those
#        paths (structural grep).
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md.
# Bash 3.2 / BSD portable: no readlink -f, realpath, jq, mapfile, [[ =~ ]].
# Fixtures under REPO_ROOT per W0a lesson (mktemp -d "$REPO_ROOT/.test-t87.XXXXXX").

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

IMPL="${IMPL:-$REPO_ROOT/.claude/commands/scaff/implement.md}"
AGG="${AGG:-$REPO_ROOT/bin/scaff-aggregate-verdicts}"
PM_MD="${PM_MD:-$REPO_ROOT/.claude/agents/scaff/pm.md}"

# ---------------------------------------------------------------------------
# Input validation — canonicalise IMPL / PM_MD / AGG and assert each resolved
# path is under REPO_ROOT (security: path-traversal on user-supplied env vars).
# Uses cd+dirname+pwd-P (BSD-safe; no readlink -f).
# If the parent directory of a path does not yet exist (e.g. pre-wave artefact),
# we fall back to the raw value; the sub-test itself will SKIP when the file is
# absent — the boundary check is still enforced on whatever value is presented.
# ---------------------------------------------------------------------------
_resolve_file_path() {
  local p="$1"
  local dir base resolved_dir
  dir="$(dirname "$p")"
  base="$(basename "$p")"
  if resolved_dir="$(cd "$dir" 2>/dev/null && pwd -P)"; then
    printf '%s/%s\n' "$resolved_dir" "$base"
  else
    # Parent dir absent — return raw value; sub-test will SKIP on [ ! -f ]
    printf '%s\n' "$p"
  fi
}

IMPL="$(_resolve_file_path "$IMPL")"
if [ "${IMPL#$REPO_ROOT/}" = "$IMPL" ]; then
  printf 'ERROR: IMPL must be under %s (got: %s)\n' "$REPO_ROOT" "$IMPL" >&2
  exit 2
fi

PM_MD="$(_resolve_file_path "$PM_MD")"
if [ "${PM_MD#$REPO_ROOT/}" = "$PM_MD" ]; then
  printf 'ERROR: PM_MD must be under %s (got: %s)\n' "$REPO_ROOT" "$PM_MD" >&2
  exit 2
fi

AGG="$(_resolve_file_path "$AGG")"
if [ "${AGG#$REPO_ROOT/}" = "$AGG" ]; then
  printf 'ERROR: AGG must be under %s (got: %s)\n' "$REPO_ROOT" "$AGG" >&2
  exit 2
fi
# For AGG, also assert it is executable when it exists — an env-var override
# pointing at a non-executable file would silently fail at invocation time.
if [ -e "$AGG" ] && [ ! -x "$AGG" ]; then
  printf 'ERROR: AGG is not executable: %s\n' "$AGG" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# Fixtures also live inside SANDBOX (which is under REPO_ROOT).
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t87.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# grep_in_file <desc> <pattern> <file>
# Reports PASS when pattern matches, FAIL when absent.
# Uses grep -E (extended regex).  Pass unescaped | for alternation.
grep_in_file() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — pattern '$pattern' not found in $file"
  fi
}

# ---------------------------------------------------------------------------
# Sub-test A — Diff-lines trigger (structural grep of implement.md)
#
# The threshold check (D7) must:
#   1. Reference the SPECFLOW_TIER_DIFF_LINES env-var with default 200.
#   2. Emit a WARNING line when the check fires.
#   3. Append a STATUS Notes pending line (the STATUS_NOTE or equivalent).
#
# 250 lines > 200 default — so the lines trigger fires when diff_lines
# exceeds SPECFLOW_TIER_DIFF_LINES.
# ---------------------------------------------------------------------------

if [ ! -f "$IMPL" ]; then
  printf 'SKIP: %s not found — T21 not yet merged; re-run post-wave.\n' \
    "$IMPL" >&2
  # Continue to sub-tests that may still pass
else
  # A1: env-var with default 200 present in threshold block
  grep_in_file \
    "A1: SPECFLOW_TIER_DIFF_LINES default 200 in implement.md" \
    'SPECFLOW_TIER_DIFF_LINES[^:]*:-200' \
    "$IMPL"

  # A2: comparison against the lines threshold
  # Actual: [ "$diff_lines" -gt "$TIER_DIFF_LINES" ]
  grep_in_file \
    "A2: diff_lines threshold comparison present in implement.md" \
    'diff_lines.*-gt.*TIER_DIFF_LINES' \
    "$IMPL"

  # A3: WARNING emission on threshold breach
  # Actual: printf 'WARNING: tiny-tier feature exceeds threshold ...' >&2
  grep_in_file \
    "A3: WARNING emitted on threshold breach in implement.md" \
    'WARNING.*tiny-tier' \
    "$IMPL"

  # A4: STATUS Notes pending/suggested line written on threshold breach
  # Actual: STATUS_NOTE="$(printf '%s implement — auto-upgrade SUGGESTED ...')"
  grep_in_file \
    "A4: STATUS pending note appended on threshold breach in implement.md" \
    'auto-upgrade SUGGESTED' \
    "$IMPL"
fi

# ---------------------------------------------------------------------------
# Sub-test B — Diff-files trigger (structural grep of implement.md)
#
# 100 lines across 5 files: files trigger fires when diff_files > 3 default.
# Complement of sub-test A — verifies the files axis of the OR condition.
# ---------------------------------------------------------------------------

if [ ! -f "$IMPL" ]; then
  printf 'SKIP: %s not found — T21 not yet merged; re-run post-wave.\n' \
    "$IMPL" >&2
else
  # B1: env-var with default 3 present
  grep_in_file \
    "B1: SPECFLOW_TIER_DIFF_FILES default 3 in implement.md" \
    'SPECFLOW_TIER_DIFF_FILES[^:]*:-3' \
    "$IMPL"

  # B2: comparison against the files threshold
  # Actual: [ "$diff_files" -gt "$TIER_DIFF_FILES" ]
  grep_in_file \
    "B2: diff_files threshold comparison present in implement.md" \
    'diff_files.*-gt.*TIER_DIFF_FILES' \
    "$IMPL"

  # B3: the condition uses OR so lines and files can independently trigger.
  # Actual lines 166-167:
  #   if [ "$diff_lines" -gt "$TIER_DIFF_LINES" ] || \
  #      [ "$diff_files" -gt "$TIER_DIFF_FILES" ]; then
  # The || may appear at the end of a line; grep for it adjacent to TIER_DIFF.
  grep_in_file \
    "B3: OR between lines and files thresholds in implement.md" \
    'TIER_DIFF_LINES.*[|][|]|[|][|].*TIER_DIFF_FILES' \
    "$IMPL"
fi

# ---------------------------------------------------------------------------
# Sub-test C — Security-must trigger (direct invocation of aggregator)
#
# A verdict dir containing axis: security + severity: must →
# aggregator stdout must include "suggest-audited-upgrade:" line.
# ---------------------------------------------------------------------------

if [ ! -f "$AGG" ]; then
  printf 'SKIP: %s not found — T7 not yet merged; re-run post-wave.\n' \
    "$AGG" >&2
else
  VDIR="$SANDBOX/c-verdict"
  mkdir -p "$VDIR"

  # Write a well-formed security verdict with a must-severity finding.
  printf '## Reviewer verdict\naxis: security\nverdict: BLOCK\nfindings:\n  - severity: must\n    file: some/path.sh\n    line: 42\n    rule: injection-attacks\n    message: test finding for trigger test\n' \
    > "$VDIR/security.txt"

  AGG_OUT=""
  set +e
  AGG_OUT="$("$AGG" security --dir "$VDIR" 2>/dev/null)"
  AGG_RC=$?
  set -e

  # C1: aggregator exits 0 on successful classification
  if [ "$AGG_RC" -eq 0 ]; then
    pass "C1: aggregator exits 0 for security-must verdict"
  else
    fail "C1: aggregator expected exit 0, got $AGG_RC"
  fi

  # C2: suggest-audited-upgrade: line present in stdout
  if printf '%s\n' "$AGG_OUT" | grep -q '^suggest-audited-upgrade:'; then
    pass "C2: aggregator emits suggest-audited-upgrade: for security-must finding"
  else
    fail "C2: aggregator missing suggest-audited-upgrade: line; got: $AGG_OUT"
  fi

  # C3: implement.md step 7c consumes the signal and calls set_tier
  #     with the reason "security-must finding in <task>" (structural grep).
  if [ -f "$IMPL" ]; then
    grep_in_file \
      "C3: implement.md step 7c invokes set_tier with security-must reason" \
      'set_tier.*audited.*security-must finding' \
      "$IMPL"
  else
    printf 'SKIP C3: %s not found — T21 pending; re-run post-wave.\n' "$IMPL" >&2
  fi

  # C4: verify a non-security must finding does NOT emit the signal.
  VDIR2="$SANDBOX/c-non-security"
  mkdir -p "$VDIR2"
  printf '## Reviewer verdict\naxis: performance\nverdict: BLOCK\nfindings:\n  - severity: must\n    file: some/path.sh\n    line: 5\n    rule: reviewer-performance\n    message: shell-out in loop\n' \
    > "$VDIR2/performance.txt"

  AGG_OUT2=""
  set +e
  AGG_OUT2="$("$AGG" performance --dir "$VDIR2" 2>/dev/null)"
  set -e

  if printf '%s\n' "$AGG_OUT2" | grep -q '^suggest-audited-upgrade:'; then
    fail "C4: non-security must must NOT emit suggest-audited-upgrade; got: $AGG_OUT2"
  else
    pass "C4: non-security must does not emit suggest-audited-upgrade (correct)"
  fi
fi

# ---------------------------------------------------------------------------
# Sub-test D — Sensitive-path trigger (structural grep of pm.md)
#
# pm.md's audited-keyword set must include "settings.json" and "auth" so
# that a PRD referencing those paths results in the PM proposing audited.
# This is the PM-side suggestion path (R14 / D6 keyword scan).
# ---------------------------------------------------------------------------

if [ ! -f "$PM_MD" ]; then
  printf 'SKIP: %s not found — T19 not yet merged; re-run post-wave.\n' \
    "$PM_MD" >&2
else
  # D1: "settings.json" appears in the audited keyword list in pm.md
  if grep -q 'settings\.json' "$PM_MD" 2>/dev/null; then
    pass "D1: pm.md audited keywords include settings.json"
  else
    fail "D1: pm.md missing settings.json in audited keyword set"
  fi

  # D2: "auth" appears in the audited keyword list in pm.md
  if grep -q '\bauth\b' "$PM_MD" 2>/dev/null; then
    pass "D2: pm.md audited keywords include auth"
  else
    fail "D2: pm.md missing 'auth' in audited keyword set"
  fi

  # D3: the keyword section is under an "Audited keywords" heading or
  #     equivalent label that distinguishes it from tiny keywords.
  # Actual: **Audited keywords** (any one match → propose `audited`):
  grep_in_file \
    "D3: pm.md has an Audited keywords section label" \
    '[*][*]Audited keywords[*][*]' \
    "$PM_MD"

  # D4: the keyword scan instructions reference scanning audited keywords
  #     BEFORE tiny keywords (scan order rule in pm.md).
  # Actual: "1. Scan audited keywords first. If any match → initial proposal is `audited`."
  grep_in_file \
    "D4: pm.md scan order — audited keywords checked first" \
    'Scan audited keywords first' \
    "$PM_MD"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
