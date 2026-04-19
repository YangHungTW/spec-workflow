#!/usr/bin/env bash
# test/t65_subagent_diff_empty.sh
#
# Static test. Assert that the union of all commits on the feature branch
# (vs. main merge-base, or vs. HEAD~1 if main is not reachable) shows zero
# lines changed under .claude/agents/specflow/.
#
# Requirements: R4 AC4.a — zero agent diff throughout this feature.
#
# NOTE — brittleness: this test is intentionally simple and is brittle to
# branch shape. It is designed as a gap-check / verify backstop to be run
# at feature close, not at every wave merge mid-implement. The BASE
# resolution below is:
#   1. git merge-base HEAD main  — works when main is reachable (normal case).
#   2. git rev-parse HEAD~1      — fallback for detached-HEAD / isolated worktree.
# If neither parent is meaningful (e.g., initial commit), the awk sum is still
# bounded by what git diff actually reports; the test will PASS vacuously if
# no .claude/agents/specflow/ path exists in the diff at all.
#
# Bash 3.2 portable. No jq, no mapfile, no readlink -f, no [[ =~ ]].

set -u -o pipefail

# Sandbox discipline — template rule (sandbox-home-in-tests.md) applies uniformly,
# even for read-only scripts, so audits are simple.
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t65)"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# Locate repo root relative to this script — never hardcode the worktree path
# (test-script-path-convention memory).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Move into repo root so git commands resolve against the correct repo.
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Determine the diff base.
# Prefer the feature branch's merge-base against main; fall back to HEAD~1
# if main is not a reachable ref (e.g., worktree detached from origin/main).
# ---------------------------------------------------------------------------
BASE="$(git merge-base HEAD main 2>/dev/null || git rev-parse HEAD~1 2>/dev/null)" || {
  echo "FAIL: could not resolve a diff base (tried merge-base HEAD main and HEAD~1)" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Count inserted + deleted lines under .claude/agents/specflow/ across the
# full range BASE...HEAD (three-dot: union of commits on this branch).
# awk defaults the sum to 0 when git diff produces no output (no match).
# ---------------------------------------------------------------------------
LINES="$(git diff --numstat "$BASE"...HEAD -- .claude/agents/specflow/ \
  | awk '{s+=$1+$2} END {print s+0}')"

if [ "$LINES" != "0" ]; then
  echo "FAIL: .claude/agents/specflow changed by $LINES lines since $BASE" >&2
  echo "  (R4 AC4.a requires zero agent diff throughout this feature)" >&2
  exit 1
fi

echo "PASS: zero lines changed under .claude/agents/specflow/ since $BASE"
exit 0
