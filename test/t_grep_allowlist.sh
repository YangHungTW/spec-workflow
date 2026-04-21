#!/usr/bin/env bash
# test/t_grep_allowlist.sh
#
# T23 — Assert that the full repo tree contains no legacy "specflow" or
# "spec-workflow" references outside the files listed in
# .claude/carryover-allowlist.txt.
#
# Exit codes:
#   0  — zero violations (all hits are allow-listed, or no hits at all)
#   2  — one or more files have hits not covered by the allow-list
#
# Sandbox-HOME NOT required: this script only runs grep against the repo
# working tree; it never invokes any CLI that reads or writes $HOME.
# (bash/sandbox-home-in-tests.md — rule applies only when a CLI expands
# or writes under $HOME; pure read-only repo traversal is exempt.)
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only
#   flags.  No `case` inside subshells (bash32-case-in-subshell.md).
set -euo pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script — never hardcode worktree path
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

ALLOWLIST="$REPO_ROOT/.claude/carryover-allowlist.txt"

# ---------------------------------------------------------------------------
# Preflight — allow-list file must exist (authored by T22)
# ---------------------------------------------------------------------------
if [ ! -f "$ALLOWLIST" ]; then
  printf 'FAIL: allow-list not found: %s\n' "$ALLOWLIST" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Load allow-list patterns into a newline-separated variable.
# Skip blank lines and lines beginning with #.
# (No mapfile — bash 3.2 portable; while-read loop instead.)
# ---------------------------------------------------------------------------
PATTERNS=""
while IFS= read -r raw; do
  # Strip leading/trailing whitespace
  line="${raw#"${raw%%[! ]*}"}"
  line="${line%"${line##*[! ]}"}"
  # Skip blank lines and comment lines
  case "$line" in
    ''|\#*) continue ;;
  esac
  if [ -z "$PATTERNS" ]; then
    PATTERNS="$line"
  else
    PATTERNS="$PATTERNS
$line"
  fi
done < "$ALLOWLIST"

# ---------------------------------------------------------------------------
# is_allowed FILE
# Returns 0 (true) if FILE matches any pattern in $PATTERNS; 1 otherwise.
# Pattern matching uses case/glob — no [[ =~ ]] — bash 3.2 safe.
# NOTE: case inside a function body is safe; only case inside $() subshells
# triggers the bash 3.2 parse bug (bash32-case-in-subshell.md).
# The file path is stripped of the leading "./" so patterns like
# ".git/**" work against "file" rather than "./file".
# Special case: ".git" (the worktree pointer file) is implicitly allowed
# because it is git metadata — its content (the gitdir path) is not a
# source reference. The allow-list pattern ".git/**" covers objects inside
# the git dir but not the pointer file itself.
# ---------------------------------------------------------------------------
is_allowed() {
  local file="$1"
  # Strip leading "./" so patterns match without it
  local f="${file#./}"
  # Always allow the worktree .git pointer file (git metadata, not source)
  if [ "$f" = ".git" ]; then
    return 0
  fi
  local pat
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    # shellcheck disable=SC2254
    case "$f" in
      $pat) return 0 ;;
    esac
  done <<PATEOF
$PATTERNS
PATEOF
  return 1
}

# ---------------------------------------------------------------------------
# Grep full tree for legacy references; collect hit files.
# grep -rl: list files only (no content), recursive.
# Exclude .git via grep's own --exclude-dir for correctness, but
# .git/** is also in the allow-list as a belt-and-suspenders guard.
# Suppress non-zero exit (no matches) with || true.
# ---------------------------------------------------------------------------
cd "$REPO_ROOT"
HIT_FILES="$(grep -rlE "specflow|spec-workflow" . --exclude-dir=.git 2>/dev/null || true)"

# ---------------------------------------------------------------------------
# Filter: collect files that are NOT covered by any allow-list pattern.
# ---------------------------------------------------------------------------
VIOLATIONS=""
if [ -n "$HIT_FILES" ]; then
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    if ! is_allowed "$hit"; then
      if [ -z "$VIOLATIONS" ]; then
        VIOLATIONS="$hit"
      else
        VIOLATIONS="$VIOLATIONS
$hit"
      fi
    fi
  done <<HITEOF
$HIT_FILES
HITEOF
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if [ -n "$VIOLATIONS" ]; then
  printf 'FAIL: t_grep_allowlist.sh — legacy specflow/spec-workflow references found outside allow-list:\n' >&2
  while IFS= read -r v; do
    [ -z "$v" ] && continue
    printf '  %s\n' "$v" >&2
  done <<VEOF
$VIOLATIONS
VEOF
  exit 2
fi

printf 'PASS: t_grep_allowlist.sh — tree free of legacy specflow/spec-workflow references (or all hits allow-listed)\n'
exit 0
