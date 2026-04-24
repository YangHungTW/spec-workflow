#!/usr/bin/env bash
# test/t85_archive_merge_check.sh
#
# Behaviour tests for T23: archive.md merge-check + --allow-unmerged REASON.
#
# Unlike t82 (structural grep), this test exercises the actual git-based
# logic specified in archive.md by constructing a mock git repo in a sandbox,
# sourcing bin/scaff-tier for get_tier, and running the git commands
# directly (same code blocks as archive.md).
#
# Coverage (T27 spec):
#   1. unmerged branch + tier=standard     → refuse (exit non-zero, diagnostic)
#   2. unmerged branch + tier=standard
#        + --allow-unmerged "test reason"  → accept + STATUS Notes line added
#   3. --allow-unmerged without reason     → usage error (exit non-zero)
#   4. unmerged branch + tier=tiny         → accept (no merge-check)
#   5. unmerged branch + tier=missing      → accept (legacy, tiny-equivalent)
#
# Fixture paths: mktemp -d "$REPO_ROOT/.test-t85.XXXXXX"
# Sandbox-HOME: per .claude/rules/bash/sandbox-home-in-tests.md
# Bash 3.2 / BSD portable — no readlink -f, realpath, jq, mapfile, [[ =~ ]].

set -u -o pipefail

# ---------------------------------------------------------------------------
# Self-locate (developer/test-script-path-convention.md).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TIER_LIB="${TIER_LIB:-$REPO_ROOT/bin/scaff-tier}"

# ---------------------------------------------------------------------------
# Sandbox-HOME (sandbox-home-in-tests.md).
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t85.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to proceed if HOME is not isolated.
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Guard: scaff-tier library must exist (RED until T2 merges).
# ---------------------------------------------------------------------------
if [ ! -f "$TIER_LIB" ]; then
  printf 'SKIP: %s not found — T2 not yet merged; re-run post-wave.\n' \
    "$TIER_LIB" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Test harness.
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Helper: build a mock git repo inside SANDBOX with the structure required
# to exercise the archive merge-check logic.
#
# Layout:
#   $GIT_REPO/
#     .specaffold/features/<slug>/STATUS.md
#
# On entry:
#   - main branch exists with one commit
#   - feature-branch exists with one additional commit (unmerged into main)
#   - caller is left on feature-branch
#
# Usage: setup_mock_repo <git_repo_dir> <slug> <tier_value|"_missing">
# ---------------------------------------------------------------------------
setup_mock_repo() {
  local git_repo="$1"
  local slug="$2"
  local tier_spec="$3"

  mkdir -p "$git_repo"

  # Initialise git repo and configure minimal identity so commits succeed.
  git -C "$git_repo" init -q
  git -C "$git_repo" config user.email "test@example.com"
  git -C "$git_repo" config user.name  "Test"

  # Create a base commit on main so the branch has a common ancestor.
  printf 'initial\n' > "$git_repo/README"
  git -C "$git_repo" add README
  git -C "$git_repo" commit -q -m "initial"

  # Rename default branch to main (git init may default to master).
  current_branch="$(git -C "$git_repo" rev-parse --abbrev-ref HEAD)"
  if [ "$current_branch" != "main" ]; then
    git -C "$git_repo" branch -m "$current_branch" main
  fi

  # Create an unmerged feature branch.
  git -C "$git_repo" checkout -q -b feature-branch

  # Build the STATUS.md fixture inside the feature branch commit.
  local feat_dir="$git_repo/.specaffold/features/$slug"
  mkdir -p "$feat_dir"

  if [ "$tier_spec" = "_missing" ]; then
    printf -- '- **slug**: %s\n- **has-ui**: false\n- **stage**: prd\n\n## Notes\n' \
      "$slug" > "$feat_dir/STATUS.md"
  else
    printf -- '- **slug**: %s\n- **has-ui**: false\n- **tier**: %s\n- **stage**: prd\n\n## Notes\n' \
      "$slug" "$tier_spec" > "$feat_dir/STATUS.md"
  fi

  git -C "$git_repo" add .specaffold
  git -C "$git_repo" commit -q -m "add feature $slug"
  # Caller is now on feature-branch, which has NOT been merged into main.
}

# ---------------------------------------------------------------------------
# Helper: run the archive merge-check logic from archive.md against a given
# feature directory.
#
# Implements exactly the dispatch from archive.md §2 (resolves tier, runs
# git merge-base --is-ancestor, handles --allow-unmerged REASON).
#
# Arguments:
#   $1  GIT_REPO   — root of the mock git repo (REPO_ROOT for git commands)
#   $2  FEAT_DIR   — absolute path to the feature dir inside the mock repo
#   $3  ALLOW_UNMERGED_REASON
#       ""          → no --allow-unmerged flag
#       "__empty__" → flag present but REASON is empty (usage error)
#       "<text>"    → flag present with non-empty REASON
#
# Returns:
#   0  → archive would proceed (accepted)
#   1  → merge-check blocked (refused, exit 1)
#   2  → usage error (slug/REASON validation failure)
#
# Side effect: if accepted with a non-empty reason, appends STATUS Notes line.
#
# Note: we load scaff-tier with REPO_ROOT pointing at the mock git repo so
# the boundary check inside _tier_resolve_and_check accepts paths under it.
# ---------------------------------------------------------------------------
run_archive_check() {
  local git_repo="$1"
  local feat_dir="$2"
  local allow_reason="$3"

  # Load tier library with REPO_ROOT = mock git repo root.
  # Re-source each call to reset state (SCAFF_TIER_LOADED guard bypassed
  # by unsetting the flag first).
  SCAFF_TIER_LOADED=0
  REPO_ROOT="$git_repo"
  # shellcheck source=/dev/null
  . "$TIER_LIB"

  # --allow-unmerged with empty REASON → usage error (exit 2).
  if [ "$allow_reason" = "__empty__" ]; then
    printf 'ERROR: --allow-unmerged requires a non-empty REASON argument\n' >&2
    return 2
  fi

  # Resolve tier for the feature dir.
  local tier
  tier="$(get_tier "$feat_dir")"

  # Dispatch on tier.
  if [ "$tier" = "malformed" ]; then
    printf 'ERROR: tier field in STATUS.md is malformed — fix before archiving\n' >&2
    return 2
  fi

  if [ "$tier" = "tiny" ] || [ "$tier" = "missing" ]; then
    # Merge-check is skipped entirely.
    return 0
  fi

  # tier ∈ {standard, audited}: run the merge-check (or bypass with reason).
  if [ -n "$allow_reason" ]; then
    # --allow-unmerged REASON supplied: append STATUS Notes line and accept.
    local status_md="$feat_dir/STATUS.md"
    local status_bak="$feat_dir/STATUS.md.bak"
    local status_tmp="$feat_dir/STATUS.md.tmp"
    cp "$status_md" "$status_bak"
    cp "$status_md" "$status_tmp"
    printf '%s archive — --allow-unmerged USED: %s\n' \
      "$(date +%Y-%m-%d)" "$allow_reason" >> "$status_tmp"
    mv "$status_tmp" "$status_md"
    return 0
  fi

  # No bypass: run git merge-base --is-ancestor check.
  local branch
  branch="$(git -C "$git_repo" rev-parse --abbrev-ref HEAD)"
  if ! git -C "$git_repo" merge-base --is-ancestor "$branch" main 2>/dev/null; then
    printf 'ERROR: branch %s has not been merged into main.\n' "$branch" >&2
    printf 'Merge or rebase onto main before archiving, or pass --allow-unmerged REASON.\n' >&2
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Test 1: unmerged branch + tier=standard → refuse, exit non-zero.
# The diagnostic must mention the branch name.
# ---------------------------------------------------------------------------
REPO1="$SANDBOX/repo1"
SLUG1="test-standard"
setup_mock_repo "$REPO1" "$SLUG1" "standard"
FEAT1="$REPO1/.specaffold/features/$SLUG1"

OUT1="$SANDBOX/t1.err"
set +e
run_archive_check "$REPO1" "$FEAT1" "" 2>"$OUT1"
RC1=$?
set -e

if [ "$RC1" -ne 0 ]; then
  pass "test-1: unmerged+standard refuses (exit $RC1 != 0)"
else
  fail "test-1: unmerged+standard should refuse but got exit 0"
fi

if grep -q 'feature-branch\|not been merged\|main' "$OUT1" 2>/dev/null; then
  pass "test-1: diagnostic mentions branch or main"
else
  fail "test-1: diagnostic missing branch/main reference (stderr: $(cat "$OUT1"))"
fi

# ---------------------------------------------------------------------------
# Test 2: unmerged branch + tier=standard + --allow-unmerged "test reason"
#   → accept (exit 0) + STATUS Notes line added.
# ---------------------------------------------------------------------------
REPO2="$SANDBOX/repo2"
SLUG2="test-standard-bypass"
setup_mock_repo "$REPO2" "$SLUG2" "standard"
FEAT2="$REPO2/.specaffold/features/$SLUG2"

STATUS_BEFORE="$(wc -l < "$FEAT2/STATUS.md" | tr -d ' ')"

set +e
run_archive_check "$REPO2" "$FEAT2" "test reason" 2>"$SANDBOX/t2.err"
RC2=$?
set -e

if [ "$RC2" -eq 0 ]; then
  pass "test-2: unmerged+standard+--allow-unmerged accepts (exit 0)"
else
  fail "test-2: unmerged+standard+--allow-unmerged should accept but got exit $RC2 ($(cat "$SANDBOX/t2.err"))"
fi

# STATUS Notes line must have been appended.
STATUS_AFTER="$(wc -l < "$FEAT2/STATUS.md" | tr -d ' ')"
STATUS_CONTENT="$(cat "$FEAT2/STATUS.md")"

if [ "$STATUS_AFTER" -gt "$STATUS_BEFORE" ]; then
  pass "test-2: STATUS.md has more lines after --allow-unmerged"
else
  fail "test-2: STATUS.md line count unchanged (before=$STATUS_BEFORE after=$STATUS_AFTER)"
fi

if printf '%s\n' "$STATUS_CONTENT" | grep -q 'allow-unmerged USED'; then
  pass "test-2: STATUS Notes contains 'allow-unmerged USED'"
else
  fail "test-2: STATUS Notes missing 'allow-unmerged USED' (content: $STATUS_CONTENT)"
fi

if printf '%s\n' "$STATUS_CONTENT" | grep -q 'test reason'; then
  pass "test-2: STATUS Notes contains supplied reason text"
else
  fail "test-2: STATUS Notes missing reason text 'test reason'"
fi

# Backup must exist (atomic write discipline).
if [ -f "$FEAT2/STATUS.md.bak" ]; then
  pass "test-2: STATUS.md.bak created by atomic write"
else
  fail "test-2: STATUS.md.bak not created — atomic write pattern not followed"
fi

# ---------------------------------------------------------------------------
# Test 3: --allow-unmerged without reason → usage error (exit non-zero).
# ---------------------------------------------------------------------------
REPO3="$SANDBOX/repo3"
SLUG3="test-no-reason"
setup_mock_repo "$REPO3" "$SLUG3" "standard"
FEAT3="$REPO3/.specaffold/features/$SLUG3"

set +e
run_archive_check "$REPO3" "$FEAT3" "__empty__" 2>"$SANDBOX/t3.err"
RC3=$?
set -e

if [ "$RC3" -ne 0 ]; then
  pass "test-3: --allow-unmerged without reason exits non-zero (exit $RC3)"
else
  fail "test-3: --allow-unmerged without reason should exit non-zero but got 0"
fi

# ---------------------------------------------------------------------------
# Test 4: unmerged branch + tier=tiny → accept (no merge-check).
# ---------------------------------------------------------------------------
REPO4="$SANDBOX/repo4"
SLUG4="test-tiny"
setup_mock_repo "$REPO4" "$SLUG4" "tiny"
FEAT4="$REPO4/.specaffold/features/$SLUG4"

STATUS4_BEFORE="$(cat "$FEAT4/STATUS.md")"

set +e
run_archive_check "$REPO4" "$FEAT4" "" 2>"$SANDBOX/t4.err"
RC4=$?
set -e

if [ "$RC4" -eq 0 ]; then
  pass "test-4: unmerged+tiny accepts (exit 0)"
else
  fail "test-4: unmerged+tiny should accept but got exit $RC4 ($(cat "$SANDBOX/t4.err"))"
fi

# No STATUS notes line must have been appended (no reason supplied).
STATUS4_AFTER="$(cat "$FEAT4/STATUS.md")"
if [ "$STATUS4_BEFORE" = "$STATUS4_AFTER" ]; then
  pass "test-4: tiny tier: STATUS.md unchanged (no spurious append)"
else
  fail "test-4: tiny tier: STATUS.md was modified unexpectedly"
fi

# ---------------------------------------------------------------------------
# Test 5: unmerged branch + tier=missing (no tier field) → accept (legacy).
# ---------------------------------------------------------------------------
REPO5="$SANDBOX/repo5"
SLUG5="test-missing"
setup_mock_repo "$REPO5" "$SLUG5" "_missing"
FEAT5="$REPO5/.specaffold/features/$SLUG5"

set +e
run_archive_check "$REPO5" "$FEAT5" "" 2>"$SANDBOX/t5.err"
RC5=$?
set -e

if [ "$RC5" -eq 0 ]; then
  pass "test-5: unmerged+missing tier accepts (exit 0, legacy)"
else
  fail "test-5: unmerged+missing tier should accept but got exit $RC5 ($(cat "$SANDBOX/t5.err"))"
fi

# ---------------------------------------------------------------------------
# Summary.
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
