#!/usr/bin/env bash
# test/t106_pm_tpm_status_shape.sh
#
# T16 — AC4/AC5/AC10/AC11/AC12 + §6.2 RUNTIME HANDOFF sentinel
#
# Assertions:
#
#   A. pm.md probe branches present (AC4):
#      /scaff:bug section exists (count=1)
#      /scaff:chore section exists (count=1)
#
#   B. pm.md keyword table anchors present (AC5) — R6 bug + R7 chore:
#      'race condition', 'typo', 'bump dep', 'cleanup'
#
#   C. tpm.md verbatim retrospective prompts (AC10) — each count=1:
#      feature retro prompt, bug retro prompt, chore retro prompt
#
#   D. _template/STATUS.md has work-type field (AC11) — count=1
#
#   E. _template/ has no subdirs (AC12) — find count=0
#
#   F. This feature's STATUS.md has RUNTIME HANDOFF sentinel (§6.2 / tech-D10)
#      T17 ships this line; T16 gate runs at wave close after T17 merges.
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md:
#   this script does not invoke a CLI that writes $HOME, but the rule is
#   applied uniformly as a template discipline.
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only flags.
#   No `case` inside subshells (bash32-case-in-subshell.md).
set -euo pipefail

# ---------------------------------------------------------------------------
# Sandbox HOME — uniform discipline per sandbox-home-in-tests.md
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to proceed against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# Env-var overrides for all path inputs
PM_MD="${PM_MD:-$REPO_ROOT/.claude/agents/scaff/pm.md}"
TPM_MD="${TPM_MD:-$REPO_ROOT/.claude/agents/scaff/tpm.md}"
TEMPLATE_STATUS="${TEMPLATE_STATUS:-$REPO_ROOT/.specaffold/features/_template/STATUS.md}"
TEMPLATE_DIR="${TEMPLATE_DIR:-$REPO_ROOT/.specaffold/features/_template}"
FEATURE_STATUS="${FEATURE_STATUS:-$REPO_ROOT/.specaffold/features/20260424-entry-type-split/STATUS.md}"

# ---------------------------------------------------------------------------
# Test harness helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# assert_count_eq FILE PATTERN EXPECTED_COUNT LABEL
# Uses grep -c; PATTERN is a fixed string.
assert_count_eq_F() {
  local file="$1"
  local pattern="$2"
  local expected="$3"
  local label="$4"
  local count
  count="$(grep -cF -- "$pattern" "$file" 2>/dev/null || true)"
  if [ "$count" = "$expected" ]; then
    pass "$label (count=$count)"
  else
    fail "$label — expected count=$expected got count=$count in $(basename "$file")"
  fi
}

# assert_count_ge FILE PATTERN MIN LABEL
# Uses grep -c; PATTERN is a fixed string; passes when count >= MIN.
assert_count_ge_F() {
  local file="$1"
  local pattern="$2"
  local min="$3"
  local label="$4"
  local count
  count="$(grep -cF -- "$pattern" "$file" 2>/dev/null || true)"
  if [ "$count" -ge "$min" ]; then
    pass "$label (count=$count)"
  else
    fail "$label — expected count>=$min got count=$count in $(basename "$file")"
  fi
}

# assert_count_eq_E FILE PATTERN EXPECTED_COUNT LABEL
# Uses grep -cE; PATTERN is an extended regex.
assert_count_eq_E() {
  local file="$1"
  local pattern="$2"
  local expected="$3"
  local label="$4"
  local count
  count="$(grep -cE -- "$pattern" "$file" 2>/dev/null || true)"
  if [ "$count" = "$expected" ]; then
    pass "$label (count=$count)"
  else
    fail "$label — expected count=$expected got count=$count in $(basename "$file")"
  fi
}

# assert_count_ge_E FILE PATTERN MIN LABEL
# Uses grep -cE; PATTERN is an extended regex; passes when count >= MIN.
assert_count_ge_E() {
  local file="$1"
  local pattern="$2"
  local min="$3"
  local label="$4"
  local count
  count="$(grep -cE -- "$pattern" "$file" 2>/dev/null || true)"
  if [ "$count" -ge "$min" ]; then
    pass "$label (count=$count)"
  else
    fail "$label — expected count>=$min got count=$count in $(basename "$file")"
  fi
}

# ---------------------------------------------------------------------------
# Preflight — source files must exist
# ---------------------------------------------------------------------------
for src_file in "$PM_MD" "$TPM_MD" "$TEMPLATE_STATUS" "$TEMPLATE_DIR"; do
  if [ ! -e "$src_file" ]; then
    printf 'FAIL: required path not found: %s\n' "$src_file" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# A. pm.md probe branches (AC4)
# ---------------------------------------------------------------------------
printf '=== A: pm.md /scaff:bug and /scaff:chore sections ===\n'

assert_count_eq_E "$PM_MD" '^## When invoked for /scaff:bug' 1 \
  "pm.md has exactly one '## When invoked for /scaff:bug' section"

assert_count_eq_E "$PM_MD" '^## When invoked for /scaff:chore' 1 \
  "pm.md has exactly one '## When invoked for /scaff:chore' section"

# ---------------------------------------------------------------------------
# B. pm.md keyword table anchors (AC5) — R6 bug + R7 chore
# ---------------------------------------------------------------------------
printf '\n=== B: pm.md R6/R7 keyword anchors ===\n'

assert_count_ge_F "$PM_MD" 'race condition' 1 \
  "pm.md contains 'race condition' anchor (R6 audited bug)"

assert_count_ge_F "$PM_MD" 'typo' 1 \
  "pm.md contains 'typo' anchor (R6 tiny bug / R7 chore doc tiny)"

assert_count_ge_F "$PM_MD" 'bump dep' 1 \
  "pm.md contains 'bump dep' anchor (R7 chore audited)"

assert_count_ge_F "$PM_MD" 'cleanup' 1 \
  "pm.md contains 'cleanup' anchor (R7 chore tiny)"

# ---------------------------------------------------------------------------
# C. tpm.md verbatim retrospective prompts (AC10)
# ---------------------------------------------------------------------------
printf '\n=== C: tpm.md verbatim retrospective prompts ===\n'

assert_count_eq_F "$TPM_MD" \
  'What technical decisions surprised you? Architecture patterns worth extracting into memory?' \
  1 \
  "tpm.md: feature retro prompt present (count=1)"

assert_count_eq_F "$TPM_MD" \
  'What guardrail (test, review axis, rule) would have caught this bug before release? Where in the pipeline did it slip through?' \
  1 \
  "tpm.md: bug retro prompt present (count=1)"

assert_count_eq_F "$TPM_MD" \
  'Could this cleanup have been automated? Does it indicate a broader tech-debt pattern worth naming?' \
  1 \
  "tpm.md: chore retro prompt present (count=1)"

# ---------------------------------------------------------------------------
# D. _template/STATUS.md has work-type field (AC11)
# ---------------------------------------------------------------------------
printf '\n=== D: _template/STATUS.md work-type field ===\n'

assert_count_eq_E "$TEMPLATE_STATUS" '^\- \*\*work-type\*\*:' 1 \
  "_template/STATUS.md has exactly one '- **work-type**:' line"

# ---------------------------------------------------------------------------
# E. _template/ has no subdirs (AC12)
# ---------------------------------------------------------------------------
printf '\n=== E: _template/ has no subdirectories ===\n'

SUBDIR_COUNT="$(find "$TEMPLATE_DIR" -mindepth 1 -type d | wc -l | tr -d ' ')"
if [ "$SUBDIR_COUNT" = "0" ]; then
  pass "_template/ contains no subdirectories (count=0)"
else
  fail "_template/ contains $SUBDIR_COUNT subdirectory/ies (expected 0)"
fi

# ---------------------------------------------------------------------------
# F. RUNTIME HANDOFF sentinel in this feature's STATUS (§6.2 / tech-D10)
# ---------------------------------------------------------------------------
printf '\n=== F: RUNTIME HANDOFF sentinel in feature STATUS.md ===\n'

if [ ! -f "$FEATURE_STATUS" ]; then
  fail "RUNTIME HANDOFF sentinel — $FEATURE_STATUS not found (T17 has not merged yet)"
else
  assert_count_ge_E "$FEATURE_STATUS" \
    '^- [0-9]{4}-[0-9]{2}-[0-9]{2} .* RUNTIME HANDOFF \(for successor bug/chore\):' \
    1 \
    "feature STATUS.md has RUNTIME HANDOFF sentinel line (§6.2)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf 'PASS\n'
  exit 0
else
  printf 'FAIL\n'
  exit 1
fi
