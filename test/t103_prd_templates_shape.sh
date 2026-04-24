#!/usr/bin/env bash
# test/t103_prd_templates_shape.sh
#
# T7 — Assert the three PRD template files (shipped by T3) have the correct
# shape.
#
# Assertions:
#
#   A. feature.md contains 8 required headings (## Problem, ## Goals,
#      ## Non-goals, ## Users, ## Requirements, ## Acceptance criteria,
#      ## Decisions, ## Open questions).
#
#   B. bug.md contains:
#      B.1 — ## Source section
#      B.2 — Each of the three type: values as literal strings:
#             url, ticket-id, description
#      B.3 — ## Repro, ## Expected, ## Actual, ## Environment sections
#
#   C. chore.md contains at least one occurrence of the exact checklist
#      skeleton marker:
#        - [ ] <item> — verify: <assertion>
#
#   D. .specaffold/features/_template/ has no subdirectories
#      (find .specaffold/features/_template -mindepth 1 -type d | wc -l == 0)
#      Per R12 / AC12: _template is a flat directory with no per-type subdirs.
#
# Template files live at .claude/commands/scaff/prd-templates/ (D7 location,
# as shipped by T3).  The _template dir check is a separate assertion on
# .specaffold/features/_template/ (T4 scope).
#
# Sandbox-HOME required per .claude/rules/bash/sandbox-home-in-tests.md:
#   this script does not invoke any CLI that writes $HOME, but the rule is
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

# T3 ships templates to .claude/commands/scaff/prd-templates/ (D7 location).
PRD_TEMPLATES_DIR="${PRD_TEMPLATES_DIR:-$REPO_ROOT/.claude/commands/scaff/prd-templates}"
FEATURE_MD="$PRD_TEMPLATES_DIR/feature.md"
BUG_MD="$PRD_TEMPLATES_DIR/bug.md"
CHORE_MD="$PRD_TEMPLATES_DIR/chore.md"

# T4 confirms the _template dir stays flat (no per-type subdirs per R12/AC12).
SPECAFFOLD_TEMPLATE_DIR="${SPECAFFOLD_TEMPLATE_DIR:-$REPO_ROOT/.specaffold/features/_template}"

# ---------------------------------------------------------------------------
# Test harness helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# assert_heading FILE HEADING
# Checks that FILE contains at least one line matching "^## HEADING$".
assert_heading() {
  local file="$1"
  local heading="$2"
  local count
  count="$(grep -c "^## ${heading}$" "$file" 2>/dev/null || true)"
  if [ "${count:-0}" -ge 1 ]; then
    pass "heading '## ${heading}' present in $(basename "$file")"
  else
    fail "heading '## ${heading}' missing from $(basename "$file")"
  fi
}

# assert_literal FILE STRING LABEL
# Checks that FILE contains STRING as a literal substring on at least one line.
# Uses grep -F -- to handle patterns that start with '-' (BSD grep requires
# explicit -- separator before a pattern beginning with a dash).
assert_literal() {
  local file="$1"
  local string="$2"
  local label="$3"
  local count
  count="$(grep -F -- "$string" "$file" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${count:-0}" -ge 1 ]; then
    pass "$label present in $(basename "$file")"
  else
    fail "$label missing from $(basename "$file")"
  fi
}

# ---------------------------------------------------------------------------
# Preflight — template files must exist (T3 ships them; FAIL fast if absent)
# ---------------------------------------------------------------------------
for tmpl in "$FEATURE_MD" "$BUG_MD" "$CHORE_MD"; do
  if [ ! -f "$tmpl" ]; then
    printf 'FAIL: template file not found: %s\n' "$tmpl" >&2
    printf 'NOTE: T3 must be merged before t103 can pass\n' >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# A. feature.md — 8 required headings
# ---------------------------------------------------------------------------
printf '=== A: feature.md headings ===\n'

assert_heading "$FEATURE_MD" "Problem"
assert_heading "$FEATURE_MD" "Goals"
assert_heading "$FEATURE_MD" "Non-goals"
assert_heading "$FEATURE_MD" "Users"
assert_heading "$FEATURE_MD" "Requirements"
assert_heading "$FEATURE_MD" "Acceptance criteria"
assert_heading "$FEATURE_MD" "Decisions"
assert_heading "$FEATURE_MD" "Open questions"

# ---------------------------------------------------------------------------
# B. bug.md — Source section, three type: values, four section headings
# ---------------------------------------------------------------------------
printf '\n=== B: bug.md sections and type values ===\n'

# B.1 — ## Source section
assert_heading "$BUG_MD" "Source"

# B.2 — Three type: values (literal strings per R14 / D1)
assert_literal "$BUG_MD" "url"         "type: url"
assert_literal "$BUG_MD" "ticket-id"   "type: ticket-id"
assert_literal "$BUG_MD" "description" "type: description"

# B.3 — Four additional required sections
assert_heading "$BUG_MD" "Repro"
assert_heading "$BUG_MD" "Expected"
assert_heading "$BUG_MD" "Actual"
assert_heading "$BUG_MD" "Environment"

# ---------------------------------------------------------------------------
# C. chore.md — checklist skeleton marker (exact literal)
# ---------------------------------------------------------------------------
printf '\n=== C: chore.md checklist skeleton marker ===\n'

assert_literal "$CHORE_MD" \
  "- [ ] <item> — verify: <assertion>" \
  "checklist skeleton marker"

# ---------------------------------------------------------------------------
# D. .specaffold/features/_template/ has no subdirectories (R12 / AC12)
# Per R12: _template is a flat directory; no per-type subdirs are created.
# ---------------------------------------------------------------------------
printf '\n=== D: .specaffold/features/_template has no subdirectories ===\n'

if [ ! -d "$SPECAFFOLD_TEMPLATE_DIR" ]; then
  fail "_template dir not found: $SPECAFFOLD_TEMPLATE_DIR"
else
  SUBDIR_COUNT="$(find "$SPECAFFOLD_TEMPLATE_DIR" -mindepth 1 -type d | wc -l | tr -d ' ')"
  if [ "$SUBDIR_COUNT" -eq 0 ]; then
    pass "_template dir has no subdirectories (count == 0)"
  else
    fail "_template dir contains $SUBDIR_COUNT subdirectory(ies) — expected 0 (R12/AC12)"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  printf 'PASS\n'
  exit 0
else
  exit 1
fi
