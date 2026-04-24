#!/usr/bin/env bash
# test/t104_entry_commands_shape.sh
#
# T13 — Assert bug.md and chore.md entry commands have correct structural shape.
#
# Assertions (AC1, AC2, AC7):
#
#   A. bug.md shape:
#      A.1 — File exists at .claude/commands/scaff/bug.md
#      A.2 — Frontmatter description line contains 'scaff:bug'
#      A.3 — Body contains classification branches: url, ticket-id, description
#      A.4 — Body references slug prefix '-fix-' (AC7 / D4)
#      A.5 — Body references PRD template .specaffold/prd-templates/bug.md
#      A.6 — Body sets 'work-type: bug'
#      A.7 — Body contains 'exit 2' near slug-prefix-rejection flow
#
#   B. chore.md shape:
#      B.1 — File exists at .claude/commands/scaff/chore.md
#      B.2 — Frontmatter description contains 'scaff:chore'
#      B.3 — Body references slug prefix '-chore-'
#      B.4 — Body references PRD template .specaffold/prd-templates/chore.md
#      B.5 — Body sets 'work-type: chore'
#      B.6 — Body contains 'exit 2' near slug-prefix-rejection flow
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

# Command files shipped by T10 and T11
COMMANDS_DIR="${COMMANDS_DIR:-$REPO_ROOT/.claude/commands/scaff}"
BUG_MD="$COMMANDS_DIR/bug.md"
CHORE_MD="$COMMANDS_DIR/chore.md"

# ---------------------------------------------------------------------------
# Test harness helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# assert_file_exists FILE LABEL
assert_file_exists() {
  local file="$1"
  local label="$2"
  if [ -f "$file" ]; then
    pass "$label exists"
  else
    fail "$label not found: $file"
  fi
}

# assert_literal FILE STRING LABEL
# Checks that FILE contains STRING as a literal substring on at least one line.
assert_literal() {
  local file="$1"
  local string="$2"
  local label="$3"
  local count
  count="$(grep -cF -- "$string" "$file" 2>/dev/null || true)"
  if [ "${count:-0}" -ge 1 ]; then
    pass "$label present in $(basename "$file")"
  else
    fail "$label missing from $(basename "$file")"
  fi
}

# ---------------------------------------------------------------------------
# Preflight — command files must exist (T10/T11 must be merged first)
# ---------------------------------------------------------------------------
for cmd_file in "$BUG_MD" "$CHORE_MD"; do
  if [ ! -f "$cmd_file" ]; then
    printf 'FAIL: command file not found: %s\n' "$cmd_file" >&2
    printf 'NOTE: T10/T11 must be merged before t104 can pass\n' >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# A. bug.md — structural shape assertions
# ---------------------------------------------------------------------------
printf '=== A: bug.md shape ===\n'

# A.1 — file exists
assert_file_exists "$BUG_MD" "bug.md"

# A.2 — frontmatter description references scaff:bug
assert_literal "$BUG_MD" "scaff:bug" "frontmatter description: scaff:bug"

# A.3 — three classification branches (AC1 three-branch evidence)
assert_literal "$BUG_MD" "url"         "classification branch: url"
assert_literal "$BUG_MD" "ticket-id"   "classification branch: ticket-id"
assert_literal "$BUG_MD" "description" "classification branch: description"

# A.4 — slug prefix '-fix-' (AC7 / D4)
assert_literal "$BUG_MD" "-fix-" "slug prefix -fix-"

# A.5 — PRD template reference
assert_literal "$BUG_MD" "prd-templates/bug.md" "PRD template ref: prd-templates/bug.md"

# A.6 — work-type field
assert_literal "$BUG_MD" "work-type: bug" "work-type: bug"

# A.7 — exit 2 usage error branch (slug-prefix-rejection flow)
assert_literal "$BUG_MD" "exit 2" "exit 2 in slug-prefix-rejection flow"

# ---------------------------------------------------------------------------
# B. chore.md — structural shape assertions
# ---------------------------------------------------------------------------
printf '\n=== B: chore.md shape ===\n'

# B.1 — file exists
assert_file_exists "$CHORE_MD" "chore.md"

# B.2 — frontmatter description references scaff:chore
assert_literal "$CHORE_MD" "scaff:chore" "frontmatter description: scaff:chore"

# B.3 — slug prefix '-chore-'
assert_literal "$CHORE_MD" "-chore-" "slug prefix -chore-"

# B.4 — PRD template reference
assert_literal "$CHORE_MD" "prd-templates/chore.md" "PRD template ref: prd-templates/chore.md"

# B.5 — work-type field
assert_literal "$CHORE_MD" "work-type: chore" "work-type: chore"

# B.6 — exit 2 usage error branch (slug-prefix-rejection flow)
assert_literal "$CHORE_MD" "exit 2" "exit 2 in slug-prefix-rejection flow"

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
