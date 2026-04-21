#!/usr/bin/env bash
# test/t31_stop_hook_failsafe.sh — stop hook fail-safe variants
#
# Six variants, each must:
#   - exit 0
#   - produce zero STATUS.md mutation
#   - NOT write a .stop-hook-last-epoch sentinel
#
# Requires: T1 (.claude/hooks/stop.sh) merged before this test goes green.

set -u

# ---------------------------------------------------------------------------
# Locate repo root relative to this test file (never hardcode worktree paths)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
HOOK="${HOOK:-$REPO_ROOT/.claude/hooks/stop.sh}"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests rule)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t31-test)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Pre-flight: hook must exist and be executable
# ---------------------------------------------------------------------------
if [ ! -x "$HOOK" ]; then
  echo "FAIL: hook not found or not executable: $HOOK" >&2
  echo "      (T1 must be merged before this test goes green)"
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# Helper: hash all STATUS.md files under sandbox (for mutation detection)
# ---------------------------------------------------------------------------
status_hash() {
  find "$SANDBOX" -name "STATUS.md" | sort | xargs shasum 2>/dev/null | shasum | awk '{print $1}'
}

# Helper: assert no STATUS.md mutation occurred
# Usage: assert_no_mutation "$before_hash" "$after_hash" "$label"
assert_no_mutation() {
  local before="$1" after="$2" label="$3"
  if [ "$before" = "$after" ]; then
    pass "$label: no STATUS.md mutation"
  else
    fail "$label: STATUS.md was mutated (before=$before after=$after)"
  fi
}

# ---------------------------------------------------------------------------
# Variant A — empty stdin
# ---------------------------------------------------------------------------
{
  GIT_DIR="$SANDBOX/vA"
  mkdir -p "$GIT_DIR"
  cd "$GIT_DIR"

  STDERR_A="$SANDBOX/stderr_A.txt"
  BEFORE_A="$(status_hash)"
  RC_A=0
  "$HOOK" < /dev/null 2>"$STDERR_A" || RC_A=$?

  if [ "$RC_A" -eq 0 ]; then
    pass "Variant A: exit 0 on empty stdin"
  else
    fail "Variant A: exited $RC_A (expected 0)"
  fi

  if grep -qi 'stdin not a valid' "$STDERR_A" 2>/dev/null; then
    pass "Variant A: stderr mentions invalid stdin"
  else
    fail "Variant A: stderr missing invalid-stdin message (got: $(cat "$STDERR_A"))"
  fi

  AFTER_A="$(status_hash)"
  assert_no_mutation "$BEFORE_A" "$AFTER_A" "Variant A"

  # Sentinel must NOT be written
  SENTINEL_COUNT=$(find "$SANDBOX/vA" -name ".stop-hook-last-epoch" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SENTINEL_COUNT" -eq 0 ]; then
    pass "Variant A: no sentinel written"
  else
    fail "Variant A: sentinel was written unexpectedly"
  fi
}

# ---------------------------------------------------------------------------
# Variant B — malformed (non-JSON) stdin
# ---------------------------------------------------------------------------
{
  GIT_DIR="$SANDBOX/vB"
  mkdir -p "$GIT_DIR"
  cd "$GIT_DIR"

  STDERR_B="$SANDBOX/stderr_B.txt"
  BEFORE_B="$(status_hash)"
  RC_B=0
  echo 'not json at all' | "$HOOK" 2>"$STDERR_B" || RC_B=$?

  if [ "$RC_B" -eq 0 ]; then
    pass "Variant B: exit 0 on malformed stdin"
  else
    fail "Variant B: exited $RC_B (expected 0)"
  fi

  if grep -qi 'stdin not a valid' "$STDERR_B" 2>/dev/null; then
    pass "Variant B: stderr mentions invalid stdin"
  else
    fail "Variant B: stderr missing invalid-stdin message (got: $(cat "$STDERR_B"))"
  fi

  AFTER_B="$(status_hash)"
  assert_no_mutation "$BEFORE_B" "$AFTER_B" "Variant B"

  SENTINEL_COUNT=$(find "$SANDBOX/vB" -name ".stop-hook-last-epoch" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SENTINEL_COUNT" -eq 0 ]; then
    pass "Variant B: no sentinel written"
  else
    fail "Variant B: sentinel was written unexpectedly"
  fi
}

# ---------------------------------------------------------------------------
# Variant C — non-git cwd (no .git/)
# ---------------------------------------------------------------------------
{
  WORKDIR="$SANDBOX/vC"
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  STDERR_C="$SANDBOX/stderr_C.txt"
  BEFORE_C="$(status_hash)"
  RC_C=0
  echo '{}' | "$HOOK" 2>"$STDERR_C" || RC_C=$?

  if [ "$RC_C" -eq 0 ]; then
    pass "Variant C: exit 0 in non-git cwd"
  else
    fail "Variant C: exited $RC_C (expected 0)"
  fi

  if grep -qi 'not a git' "$STDERR_C" 2>/dev/null; then
    pass "Variant C: stderr mentions not-a-git-worktree"
  else
    fail "Variant C: stderr missing not-git message (got: $(cat "$STDERR_C"))"
  fi

  AFTER_C="$(status_hash)"
  assert_no_mutation "$BEFORE_C" "$AFTER_C" "Variant C"

  SENTINEL_COUNT=$(find "$WORKDIR" -name ".stop-hook-last-epoch" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SENTINEL_COUNT" -eq 0 ]; then
    pass "Variant C: no sentinel written"
  else
    fail "Variant C: sentinel was written unexpectedly"
  fi
}

# ---------------------------------------------------------------------------
# Variant D — branch matches no feature slug
# ---------------------------------------------------------------------------
{
  WORKDIR="$SANDBOX/vD"
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  git init -q
  git config user.email "t@example.com"
  git config user.name "t"
  git checkout -q -b "20260418-unrelated-branch" 2>/dev/null || git checkout -q -b "20260418-unrelated-branch"

  # Seed a feature with a slug that does NOT appear in the branch name
  SLUG_D="20260418-some-other-feature"
  mkdir -p ".specaffold/features/$SLUG_D"
  cat > ".specaffold/features/$SLUG_D/STATUS.md" <<'EOF'
# Status

## Notes

- 2026-04-17 initial note
EOF
  git add -A 2>/dev/null
  git commit -q -m "seed" 2>/dev/null

  BEFORE_D="$(status_hash)"
  STDERR_D="$SANDBOX/stderr_D.txt"
  RC_D=0
  echo '{}' | "$HOOK" 2>"$STDERR_D" || RC_D=$?

  if [ "$RC_D" -eq 0 ]; then
    pass "Variant D: exit 0 when branch matches no feature"
  else
    fail "Variant D: exited $RC_D (expected 0)"
  fi

  if grep -qi 'branch\|no.match\|no-match' "$STDERR_D" 2>/dev/null; then
    pass "Variant D: stderr mentions branch/no-match"
  else
    fail "Variant D: stderr missing branch-mismatch message (got: $(cat "$STDERR_D"))"
  fi

  AFTER_D="$(status_hash)"
  assert_no_mutation "$BEFORE_D" "$AFTER_D" "Variant D"

  SENTINEL_COUNT=$(find "$WORKDIR/.specaffold/features/$SLUG_D" -name ".stop-hook-last-epoch" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SENTINEL_COUNT" -eq 0 ]; then
    pass "Variant D: no sentinel written"
  else
    fail "Variant D: sentinel was written unexpectedly"
  fi
}

# ---------------------------------------------------------------------------
# Variant E — STATUS.md missing for the matched feature
# ---------------------------------------------------------------------------
{
  WORKDIR="$SANDBOX/vE"
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  SLUG_E="20260418-fixture-e"
  git init -q
  git config user.email "t@example.com"
  git config user.name "t"
  git checkout -q -b "20260418-fixture-e-branch" 2>/dev/null || git checkout -q -b "20260418-fixture-e-branch"

  # Feature dir exists but NO STATUS.md inside it
  mkdir -p ".specaffold/features/$SLUG_E"
  git add -A 2>/dev/null
  git commit -q -m "seed-no-status" --allow-empty 2>/dev/null

  BEFORE_E="$(status_hash)"
  STDERR_E="$SANDBOX/stderr_E.txt"
  RC_E=0
  echo '{}' | "$HOOK" 2>"$STDERR_E" || RC_E=$?

  if [ "$RC_E" -eq 0 ]; then
    pass "Variant E: exit 0 when STATUS.md absent"
  else
    fail "Variant E: exited $RC_E (expected 0)"
  fi

  # Accept either "STATUS.md not present" OR "no-match" (implementation may vary)
  if grep -qi 'STATUS.md\|no.match\|no-match\|not present\|missing' "$STDERR_E" 2>/dev/null; then
    pass "Variant E: stderr mentions missing STATUS.md or no-match"
  else
    # Silent skip is also acceptable — the spec says "silent skip" in case 4
    pass "Variant E: silent skip (no stderr required per spec)"
  fi

  AFTER_E="$(status_hash)"
  assert_no_mutation "$BEFORE_E" "$AFTER_E" "Variant E"

  # No new STATUS.md must have been created
  if [ ! -f "$WORKDIR/.specaffold/features/$SLUG_E/STATUS.md" ]; then
    pass "Variant E: no STATUS.md created"
  else
    fail "Variant E: STATUS.md was created where none existed"
  fi

  SENTINEL_COUNT=$(find "$WORKDIR/.specaffold/features/$SLUG_E" -name ".stop-hook-last-epoch" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SENTINEL_COUNT" -eq 0 ]; then
    pass "Variant E: no sentinel written"
  else
    fail "Variant E: sentinel was written unexpectedly"
  fi
}

# ---------------------------------------------------------------------------
# Variant F — STATUS.md present but missing ## Notes heading
# ---------------------------------------------------------------------------
{
  WORKDIR="$SANDBOX/vF"
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"

  SLUG_F="20260418-fixture-f"
  git init -q
  git config user.email "t@example.com"
  git config user.name "t"
  git checkout -q -b "20260418-fixture-f-branch" 2>/dev/null || git checkout -q -b "20260418-fixture-f-branch"

  mkdir -p ".specaffold/features/$SLUG_F"
  # STATUS.md with NO ## Notes heading
  cat > ".specaffold/features/$SLUG_F/STATUS.md" <<'EOF'
# Status

## Tasks

- [ ] T1 — placeholder
EOF
  git add -A 2>/dev/null
  git commit -q -m "seed-no-notes-heading" 2>/dev/null

  # Snapshot byte content of STATUS.md before invocation
  BEFORE_BYTES="$(cat "$WORKDIR/.specaffold/features/$SLUG_F/STATUS.md")"
  BEFORE_F="$(status_hash)"
  STDERR_F="$SANDBOX/stderr_F.txt"
  RC_F=0
  echo '{}' | "$HOOK" 2>"$STDERR_F" || RC_F=$?

  if [ "$RC_F" -eq 0 ]; then
    pass "Variant F: exit 0 when ## Notes heading absent"
  else
    fail "Variant F: exited $RC_F (expected 0)"
  fi

  if grep -qi 'Notes\|heading' "$STDERR_F" 2>/dev/null; then
    pass "Variant F: stderr mentions missing Notes heading"
  else
    fail "Variant F: stderr missing Notes-heading warning (got: $(cat "$STDERR_F"))"
  fi

  AFTER_BYTES="$(cat "$WORKDIR/.specaffold/features/$SLUG_F/STATUS.md")"
  if [ "$BEFORE_BYTES" = "$AFTER_BYTES" ]; then
    pass "Variant F: STATUS.md byte-identical"
  else
    fail "Variant F: STATUS.md was mutated"
  fi

  AFTER_F="$(status_hash)"
  assert_no_mutation "$BEFORE_F" "$AFTER_F" "Variant F (hash)"

  SENTINEL_COUNT=$(find "$WORKDIR/.specaffold/features/$SLUG_F" -name ".stop-hook-last-epoch" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SENTINEL_COUNT" -eq 0 ]; then
    pass "Variant F: no sentinel written"
  else
    fail "Variant F: sentinel was written unexpectedly"
  fi
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
