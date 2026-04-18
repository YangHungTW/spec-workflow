#!/usr/bin/env bash
# test/t30_stop_hook_happy_path.sh — stop hook happy-path integration test
# Tests: stop.sh appends exactly one STATUS note and writes .stop-hook-last-epoch
# Requires: T1 merged (.claude/hooks/stop.sh must exist and be executable)

set -u

# ---------------------------------------------------------------------------
# Locate repo root relative to this test file
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
HOOK="$REPO_ROOT/.claude/hooks/stop.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# 1. Sandbox — HOME isolation (per sandbox-home-in-tests rule)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t30-test)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Sanity: hook must exist and be executable
# ---------------------------------------------------------------------------
if [ ! -x "$HOOK" ]; then
  fail "stop hook not executable or missing: $HOOK"
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Seed a sandbox git worktree with matching branch
# ---------------------------------------------------------------------------
FEAT_SLUG="20260418-fixture-feature"
FEAT_DIR="$SANDBOX/repo/.spec-workflow/features/$FEAT_SLUG"
REPO_SANDBOX="$SANDBOX/repo"

mkdir -p "$REPO_SANDBOX"
cd "$REPO_SANDBOX"

git init -q
git checkout -q -b "$FEAT_SLUG"
git config user.email "t@example.com"
git config user.name "t"

mkdir -p "$FEAT_DIR"

# ---------------------------------------------------------------------------
# 3. Write minimal STATUS.md with ## Notes heading and one pre-existing note
# ---------------------------------------------------------------------------
STATUS_FILE="$FEAT_DIR/STATUS.md"
cat > "$STATUS_FILE" <<'EOF'
# STATUS

- **slug**: 20260418-fixture-feature
- **stage**: implement

## Notes
- 2026-04-18 TPM — fixture note for t30 test
EOF

git add .
git commit -q -m "fixture: seed STATUS.md for t30 test"

# ---------------------------------------------------------------------------
# 4. Run the stop hook with a valid JSON payload
# ---------------------------------------------------------------------------
PRE_COUNT=$(grep -c 'stop-hook' "$STATUS_FILE" 2>/dev/null; true)
SENTINEL="$FEAT_DIR/.stop-hook-last-epoch"

echo '{"event":"Stop"}' | "$HOOK"
HOOK_RC=$?

# ---------------------------------------------------------------------------
# 5. Assert exit code 0
# ---------------------------------------------------------------------------
if [ "$HOOK_RC" -eq 0 ]; then
  pass "Check 1: hook exited 0"
else
  fail "Check 1: hook exited $HOOK_RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# 6. Assert exactly one new stop-hook line was appended
# ---------------------------------------------------------------------------
POST_COUNT=$(grep -c 'stop-hook' "$STATUS_FILE" 2>/dev/null; true)
NEW_COUNT=$(( POST_COUNT - PRE_COUNT ))

if [ "$NEW_COUNT" -eq 1 ]; then
  pass "Check 2: exactly one new stop-hook line appended (pre=$PRE_COUNT post=$POST_COUNT)"
else
  fail "Check 2: expected 1 new stop-hook line, got $NEW_COUNT (pre=$PRE_COUNT post=$POST_COUNT)"
fi

# ---------------------------------------------------------------------------
# 7. Assert the new line matches expected format
#    Format: - YYYY-MM-DD stop-hook — stop event observed
# ---------------------------------------------------------------------------
TODAY="$(date +%Y-%m-%d)"
if grep -q "^- ${TODAY} stop-hook — stop event observed$" "$STATUS_FILE"; then
  pass "Check 3: appended line matches expected format for today ($TODAY)"
else
  # Try any date (in case clock ticks past midnight)
  if grep -q '^- [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] stop-hook — stop event observed$' "$STATUS_FILE"; then
    pass "Check 3: appended line matches expected format (date shifted past midnight — accepted)"
  else
    APPENDED=$(grep 'stop-hook' "$STATUS_FILE" | tail -1)
    fail "Check 3: appended line format mismatch (got: $APPENDED)"
  fi
fi

# ---------------------------------------------------------------------------
# 8. Assert sentinel file exists and contains a numeric epoch
# ---------------------------------------------------------------------------
if [ -f "$SENTINEL" ]; then
  EPOCH_VAL=$(cat "$SENTINEL")
  case "$EPOCH_VAL" in
    *[!0-9]*) fail "Check 4: sentinel exists but contains non-numeric value: $EPOCH_VAL" ;;
    '')       fail "Check 4: sentinel exists but is empty" ;;
    *)        pass "Check 4: sentinel $SENTINEL exists with numeric epoch ($EPOCH_VAL)" ;;
  esac
else
  fail "Check 4: sentinel file not created: $SENTINEL"
fi

# ---------------------------------------------------------------------------
# 9. /usr/bin/time spot-check (R15 soft target — log wall-clock, no assertion)
# ---------------------------------------------------------------------------
if [ -x /usr/bin/time ]; then
  echo ""
  echo "INFO: R15 wall-clock spot-check (informational only — not gating):"
  { /usr/bin/time -p "$HOOK" <<< '{"event":"Stop"}'; } 2>&1 | awk '/^real/ {print "  wall-clock: " $2 "s"}'
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
