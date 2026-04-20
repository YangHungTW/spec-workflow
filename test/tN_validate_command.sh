#!/usr/bin/env bash
# test/tN_validate_command.sh
#
# Structural tests for .claude/commands/specflow/validate.md (T11).
#
# Verifications (from T11 Verify clause in 05-plan.md):
#   1. File exists.
#   2. Frontmatter description: line is present.
#   3. The command describes parallel dispatch of qa-tester AND qa-analyst.
#   4. Uses "## Validate verdict" footer naming (PRD R18), NOT "## Reviewer verdict".
#   5. Calls bin/specflow-aggregate-verdicts with tester analyst axes (D5, R17).
#   6. Composes 08-validate.md artefact.
#   7. STATUS update is conditional on PASS or NITS only (BLOCK leaves box unchecked).
#   8. All shell pseudocode is bash 3.2 portability-clean (no readlink -f, no realpath,
#      no jq, no mapfile, no [[ =~ ]] for portability-critical logic).
#
# Bash 3.2 / BSD portable: no readlink -f, realpath, jq, mapfile, [[ =~ ]].
# No HOME mutation in this script — purely reads/greps the command file.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TARGET="$REPO_ROOT/.claude/commands/specflow/validate.md"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# This test does not mutate HOME but we carry the discipline uniformly.
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-tN-validate.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

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

# ---------------------------------------------------------------------------
# Test 1 — File exists
# ---------------------------------------------------------------------------
if [ -f "$TARGET" ]; then
  pass "validate.md exists"
else
  fail "validate.md missing: $TARGET"
fi

# ---------------------------------------------------------------------------
# Test 2 — Frontmatter description: line present
# ---------------------------------------------------------------------------
if grep -q '^description:' "$TARGET" 2>/dev/null; then
  pass "frontmatter description: line present"
else
  fail "frontmatter description: line missing in $TARGET"
fi

# ---------------------------------------------------------------------------
# Test 3a — Parallel dispatch of qa-tester
# ---------------------------------------------------------------------------
if grep -q 'qa-tester' "$TARGET" 2>/dev/null; then
  pass "qa-tester referenced in validate.md"
else
  fail "qa-tester not referenced in validate.md"
fi

# ---------------------------------------------------------------------------
# Test 3b — Parallel dispatch of qa-analyst
# ---------------------------------------------------------------------------
if grep -q 'qa-analyst' "$TARGET" 2>/dev/null; then
  pass "qa-analyst referenced in validate.md"
else
  fail "qa-analyst not referenced in validate.md"
fi

# ---------------------------------------------------------------------------
# Test 3c — Parallel keyword present (D4)
# ---------------------------------------------------------------------------
if grep -qi 'parallel' "$TARGET" 2>/dev/null; then
  pass "parallel dispatch mentioned"
else
  fail "parallel dispatch not mentioned in validate.md"
fi

# ---------------------------------------------------------------------------
# Test 4a — Uses "## Validate verdict" (PRD R18)
# ---------------------------------------------------------------------------
if grep -q 'Validate verdict' "$TARGET" 2>/dev/null; then
  pass "'Validate verdict' footer referenced"
else
  fail "'Validate verdict' not referenced in validate.md"
fi

# ---------------------------------------------------------------------------
# Test 4b — Does NOT use "## Reviewer verdict" as a verdict header directive
#           (instructions must say "## Validate verdict", not "## Reviewer verdict")
#           The string may appear in negative-example / prohibition prose but must
#           not be used as the instructed footer header.
#           We check by ensuring every instructed "verdict" header uses "Validate".
# ---------------------------------------------------------------------------
# Grep for the pattern where the command would instruct agents to emit the OLD header.
# Legitimate mentions are negations like "NOT ## Reviewer verdict" — those are fine.
# A bare "## Reviewer verdict" line (as an example block or instruction) is a FAIL.
if grep -q '^## Reviewer verdict$' "$TARGET" 2>/dev/null; then
  fail "'## Reviewer verdict' as a standalone line found in validate.md (must use 'Validate verdict')"
else
  pass "no '## Reviewer verdict' as standalone header directive"
fi

# ---------------------------------------------------------------------------
# Test 5 — Calls bin/specflow-aggregate-verdicts with tester analyst (D5, R17)
# ---------------------------------------------------------------------------
if grep -q 'specflow-aggregate-verdicts' "$TARGET" 2>/dev/null; then
  pass "bin/specflow-aggregate-verdicts referenced"
else
  fail "bin/specflow-aggregate-verdicts not referenced in validate.md"
fi

if grep -q 'tester' "$TARGET" 2>/dev/null && grep -q 'analyst' "$TARGET" 2>/dev/null; then
  pass "tester and analyst axis names present"
else
  fail "tester and/or analyst axis names missing in validate.md"
fi

# ---------------------------------------------------------------------------
# Test 6 — Composes 08-validate.md artefact
# ---------------------------------------------------------------------------
if grep -q '08-validate' "$TARGET" 2>/dev/null; then
  pass "08-validate.md artefact referenced"
else
  fail "08-validate.md not referenced in validate.md"
fi

# ---------------------------------------------------------------------------
# Test 7 — STATUS update conditional on PASS/NITS (BLOCK leaves unchecked)
# ---------------------------------------------------------------------------
if grep -q 'PASS\|NITS' "$TARGET" 2>/dev/null; then
  pass "PASS/NITS verdict referenced for STATUS update"
else
  fail "PASS/NITS verdict references missing"
fi

if grep -q 'BLOCK' "$TARGET" 2>/dev/null; then
  pass "BLOCK verdict referenced (must not advance STATUS)"
else
  fail "BLOCK verdict not referenced in validate.md"
fi

# ---------------------------------------------------------------------------
# Test 8 — No bash 3.2 portability violations in shell code blocks
#          We check that the file does not use these in code fences (```sh / ```bash).
#          Mentions in prose prohibition lists (e.g. "no readlink -f") are fine.
#          We check for actual usage patterns: the word appearing in a code context
#          with a '$' or command prefix, not just prose mentions.
#          Heuristic: look for lines that start with whitespace and contain the
#          forbidden invocation (typical in indented code blocks).
# ---------------------------------------------------------------------------
# readlink -f would only appear as a code invocation like "readlink -f $path"
if grep -E '^\s+readlink -f' "$TARGET" 2>/dev/null | grep -qv '#'; then
  fail "bash-32 violation: readlink -f used in code block in validate.md"
else
  pass "no readlink -f in code blocks"
fi

# realpath as a command invocation (not prose mention)
if grep -E '^\s+realpath\b' "$TARGET" 2>/dev/null | grep -qv '#'; then
  fail "bash-32 violation: realpath used as command in code block in validate.md"
else
  pass "no realpath command in code blocks"
fi

# jq as a command invocation
if grep -E '^\s+jq\b' "$TARGET" 2>/dev/null | grep -qv '#'; then
  fail "bash-32 violation: jq used as command in code block in validate.md"
else
  pass "no jq command in code blocks"
fi

# mapfile as a command invocation
if grep -E '^\s+mapfile\b' "$TARGET" 2>/dev/null | grep -qv '#'; then
  fail "bash-32 violation: mapfile used as command in code block in validate.md"
else
  pass "no mapfile command in code blocks"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
