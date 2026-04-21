#!/usr/bin/env bash
# test/t63_lint_no_jq_no_readlink_f.sh — static portability-token check
# for the three files added/edited by this feature:
#   bin/scaff-lint
#   .claude/hooks/session-start.sh
#   bin/scaff-seed
#
# STATIC test: pure grep, no CLI invocation, no HOME mutation.
# sandbox-HOME preamble is intentionally omitted — this test neither invokes
# a CLI that reads/writes $HOME nor mutates any filesystem state.
#
# Usage: bash test/t63_lint_no_jq_no_readlink_f.sh
# Exits 0 iff all checks pass; FAIL: <reason> to stderr + exit 1 on failure.

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script — never hardcode worktree paths
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

LINT="$REPO_ROOT/bin/scaff-lint"
SESSION_START="$REPO_ROOT/.claude/hooks/session-start.sh"
SEED="$REPO_ROOT/bin/scaff-seed"

# ---------------------------------------------------------------------------
# Prohibited-token ERE pattern (verbatim from bash-32-portability.md):
#   readlink -f  — GNU-only flag; portable alternative is resolve_path helper
#   realpath     — GNU coreutils; not on macOS base system
#   jq           — not on a fresh Mac; parse JSON with python3 instead
#   mapfile      — bash 4+ builtin; use while-read loop on bash 3.2
#   [[ .*=~      — regex match dialect differs between bash 3 and 4+
#   rm -rf       — unconditional recursive delete; violates no-force rule
#    --force     — leading space catches flag usage, not word fragments
# ---------------------------------------------------------------------------
PATTERN='readlink -f|realpath|jq|mapfile|\[\[ .*=~|rm -rf| --force'

# ---------------------------------------------------------------------------
# False-positive handling for bin/scaff-lint:
#   The file contains a Python heredoc that legitimately uses
#   `os.path.realpath` — the Python standard library function, NOT the GNU
#   `realpath` shell command.  We exclude those lines with a post-grep filter
#   (`grep -v 'os\.path\.realpath'`) so only actual shell-command invocations
#   of `realpath` would remain as findings.
# ---------------------------------------------------------------------------

FAIL=0

# ---------------------------------------------------------------------------
# Helper: scan one file, emit file:line:match on violations
# ---------------------------------------------------------------------------
check_file() {
  local file="$1"
  local filter="${2:-}"   # optional grep -v pattern to exclude false positives

  if [ ! -f "$file" ]; then
    echo "FAIL: file not found: $file" >&2
    FAIL=1
    return
  fi

  local hits
  if [ -n "$filter" ]; then
    hits="$(grep -En "$PATTERN" "$file" | grep -v "$filter" || true)"
  else
    hits="$(grep -En "$PATTERN" "$file" || true)"
  fi

  # Also exclude lines that are shell comments explaining what NOT to use
  # (lines whose non-whitespace content starts with '#').
  # grep -En on a single file produces "LINE:CONTENT" (no filename prefix).
  hits="$(printf '%s\n' "$hits" | grep -Ev '^[0-9]+:[[:space:]]*#' || true)"

  if [ -n "$hits" ]; then
    echo "FAIL: prohibited token in $file:" >&2
    printf '%s\n' "$hits" >&2
    FAIL=1
  fi
}

check_file "$LINT"         'os\.path\.realpath'
check_file "$SESSION_START"
check_file "$SEED"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

echo "PASS"
exit 0
