#!/usr/bin/env bash
# test/t77_deprecation_stubs.sh
#
# Structural tests for the four retired-command deprecation stubs:
#   brainstorm → /specflow:prd   (PRD R4)
#   tasks      → /specflow:plan  (PRD R4)
#   verify     → /specflow:validate  (PRD R4)
#   gap-check  → /specflow:validate  (PRD R4)
#
# Per-command assertions (tech §D8, tech §4.4):
#   1. Command file exists.
#   2. Frontmatter description: line matches RETIRED — see /specflow:<successor> shape.
#   3. Successor mapping matches PRD R4 verbatim.
#   4. Structural invocation proxy: body contains expected no-mutation and
#      non-zero-exit sentinels (full slash-command invocation from bash is
#      non-trivial; grep-based proxy is acceptable per tech §4.4).
#
# SKIP behaviour: if ANY of the four stubs are not yet merged (i.e. the
#   description: line does not start with "RETIRED"), the script emits a
#   SKIP notice for that command and exits 0 at the end so CI stays green
#   before the wave merge.
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md:
#   mktemp inside REPO_ROOT (W0a lesson), HOME=$SANDBOX/home, preflight.
#
# Bash 3.2 / BSD portable — no readlink -f, realpath, jq, mapfile, [[ =~ ]].

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# Fixtures under REPO_ROOT per W0a lesson.
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t77.XXXXXX")"
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
SKIP=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
skip() { printf 'SKIP: %s\n' "$1" >&2; SKIP=$((SKIP + 1)); }

COMMANDS_DIR="$REPO_ROOT/.claude/commands/specflow"

# ---------------------------------------------------------------------------
# check_stub <command> <expected_successor>
#
# Asserts for one retired command:
#   A. File exists.
#   B. description: line begins with "RETIRED — see /specflow:<successor>"
#      (shape per D8 stub template).
#   C. Successor token in description matches <expected_successor> exactly.
#   D. Structural proxy: body contains "No STATUS mutation occurs" (D8 template).
#   E. Structural proxy: body contains "Exits non-zero" (D8 template).
#
# When the file exists but does NOT contain the RETIRED marker, SKIP all
# assertions for that command (T12–T15 not yet merged).
# ---------------------------------------------------------------------------
check_stub() {
  local cmd="$1"
  local expected_successor="$2"
  local file="$COMMANDS_DIR/${cmd}.md"
  local label="$cmd → /specflow:${expected_successor}"

  # A. File must exist
  if [ ! -f "$file" ]; then
    fail "[$label] A: command file missing: $file"
    return
  fi
  pass "[$label] A: command file exists"

  # Read description line (first line with "^description:")
  local desc_line
  desc_line="$(grep -m1 '^description:' "$file" 2>/dev/null || true)"

  # Pre-check: is the stub already merged?
  # If not (description does not contain RETIRED), emit SKIP for B–E.
  case "$desc_line" in
    *RETIRED*)
      ;;
    *)
      skip "[$label] B–E: stub not yet merged (description: '${desc_line}') — T12–T15 pending; re-run post-wave"
      return
      ;;
  esac

  # B. description: line matches RETIRED — see /specflow:<successor> shape
  case "$desc_line" in
    "description: RETIRED — see /specflow:"*)
      pass "[$label] B: description: line has RETIRED shape"
      ;;
    *)
      fail "[$label] B: description: line does not match expected shape; got: ${desc_line}"
      ;;
  esac

  # C. Successor token matches expected_successor
  # Extract token after "see /specflow:" — stop at first non-word char (. space etc.)
  local desc_after
  desc_after="${desc_line##*see /specflow:}"
  # Trim everything from first non-alphanumeric-hyphen character
  local actual_successor
  actual_successor="$(printf '%s' "$desc_after" | awk '{gsub(/[^a-zA-Z0-9-].*/, ""); print}')"

  if [ "$actual_successor" = "$expected_successor" ]; then
    pass "[$label] C: successor token is '${expected_successor}' (matches PRD R4)"
  else
    fail "[$label] C: successor token is '${actual_successor}', expected '${expected_successor}'"
  fi

  # D. Structural proxy: body must contain "No STATUS mutation occurs"
  # This is the canonical D8 sentinel confirming the stub does not mutate.
  if grep -q 'No STATUS mutation occurs' "$file" 2>/dev/null; then
    pass "[$label] D: body contains 'No STATUS mutation occurs' sentinel"
  else
    fail "[$label] D: body missing 'No STATUS mutation occurs' sentinel (D8 template)"
  fi

  # E. Structural proxy: body must contain "Exits non-zero"
  # This is the canonical D8 sentinel confirming the stub exits non-zero.
  if grep -q 'Exits non-zero' "$file" 2>/dev/null; then
    pass "[$label] E: body contains 'Exits non-zero' sentinel"
  else
    fail "[$label] E: body missing 'Exits non-zero' sentinel (D8 template)"
  fi
}

# ---------------------------------------------------------------------------
# Run assertions for each retired command per PRD R4 successor mapping
# ---------------------------------------------------------------------------

check_stub "brainstorm" "prd"
check_stub "tasks"      "plan"
check_stub "verify"     "validate"
check_stub "gap-check"  "validate"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed, %d skipped ===\n' \
  "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
