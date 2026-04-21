#!/usr/bin/env bash
# test/t32_stop_hook_dedup.sh — D4 sentinel-based 60s dedup window
# Usage: bash test/t32_stop_hook_dedup.sh
# Exits 0 iff all checks pass.
#
# Platform note: this test exercises the sentinel-read/write path on the
# current platform only.  The to_epoch() wrapper in stop.sh dispatches on
# uname -s: Darwin/*BSD uses `date -j -f "..." +%s`, Linux/* uses
# `date -d "..." +%s`.  The path NOT taken on this run is acknowledged as
# a single-platform gap per PRD §5 / plan §6 risks; the test emits a
# comment line at the bottom reporting which branch was exercised.
#
# TDD note: this test is written red-first alongside T1 (stop.sh).  It
# will fail with "hook not found" until T1 merges.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate script under test (cwd-agnostic — never hardcode worktree paths)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
HOOK="${HOOK:-$REPO_ROOT/.claude/hooks/stop.sh}"

# ---------------------------------------------------------------------------
# Hook preflight — fail loudly if T1 hasn't landed yet
# ---------------------------------------------------------------------------
if [ ! -x "$HOOK" ]; then
  echo "FAIL: hook not found or not executable: $HOOK" >&2
  echo "      (T1 must merge before this test can go green)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sandbox setup (sandbox-HOME discipline per rules/bash/sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t32-test)"
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
trap 'rm -rf "$SANDBOX"' EXIT

# Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Seed a fake feature + git worktree (mirrors T4 fixture shape)
# ---------------------------------------------------------------------------
FEATURE_SLUG="20260418-fixture-dedup"
FEATURE_DIR="$SANDBOX/repo/.specaffold/features/$FEATURE_SLUG"
SENTINEL="$FEATURE_DIR/.stop-hook-last-epoch"

mkdir -p "$FEATURE_DIR"
cd "$SANDBOX/repo"
git init -q
git checkout -q -b "$FEATURE_SLUG"
git config user.email "t@example.com"
git config user.name "t"

# Minimal STATUS.md with ## Notes heading
cat > "$FEATURE_DIR/STATUS.md" <<'STATUS'
# STATUS — 20260418-fixture-dedup

## Notes

- 2026-04-17 init — baseline note
STATUS

git add -A
git commit -q -m "seed fixture"

# Helper: count stop-hook lines in STATUS.md
count_lines() {
  grep -c 'stop-hook — stop event observed' "$FEATURE_DIR/STATUS.md" 2>/dev/null; true
}

# ---------------------------------------------------------------------------
# STEP 1 — First invocation: should append one stop-hook line + write sentinel
# ---------------------------------------------------------------------------
BEFORE_1="$(count_lines)"
echo '{"event":"Stop"}' | "$HOOK"
RC1=$?
if [ "$RC1" -ne 0 ]; then
  echo "FAIL: step1: hook exited $RC1 (expected 0)"
  exit 1
fi

AFTER_1="$(count_lines)"
DELTA_1=$(( AFTER_1 - BEFORE_1 ))
if [ "$DELTA_1" -ne 1 ]; then
  echo "FAIL: step1: expected +1 stop-hook line, got delta=$DELTA_1"
  exit 1
fi

if [ ! -f "$SENTINEL" ]; then
  echo "FAIL: step1: sentinel not created at $SENTINEL"
  exit 1
fi

EPOCH_1="$(cat "$SENTINEL")"
case "$EPOCH_1" in
  *[!0-9]*|"") echo "FAIL: step1: sentinel is not a number: $EPOCH_1"; exit 1 ;;
esac

echo "PASS step1: first invocation appended 1 line, sentinel=$EPOCH_1"

# ---------------------------------------------------------------------------
# STEP 2 — Second invocation within 60s: should NOT append (dedup window)
# ---------------------------------------------------------------------------
BEFORE_2="$(count_lines)"
echo '{"event":"Stop"}' | "$HOOK"
RC2=$?
if [ "$RC2" -ne 0 ]; then
  echo "FAIL: step2: hook exited $RC2 (expected 0)"
  exit 1
fi

AFTER_2="$(count_lines)"
DELTA_2=$(( AFTER_2 - BEFORE_2 ))
if [ "$DELTA_2" -ne 0 ]; then
  echo "FAIL: step2: expected +0 lines (dedup), got delta=$DELTA_2"
  exit 1
fi

echo "PASS step2: second invocation (within 60s) did NOT append"

# ---------------------------------------------------------------------------
# STEP 3 — Age the sentinel >60s, then invoke: should append a second line
# ---------------------------------------------------------------------------
AGED_EPOCH=$(( $(date +%s) - 61 ))
printf '%s\n' "$AGED_EPOCH" > "$SENTINEL"

BEFORE_3="$(count_lines)"
echo '{"event":"Stop"}' | "$HOOK"
RC3=$?
if [ "$RC3" -ne 0 ]; then
  echo "FAIL: step3: hook exited $RC3 (expected 0)"
  exit 1
fi

AFTER_3="$(count_lines)"
DELTA_3=$(( AFTER_3 - BEFORE_3 ))
if [ "$DELTA_3" -ne 1 ]; then
  echo "FAIL: step3: expected +1 line after sentinel aged >60s, got delta=$DELTA_3"
  exit 1
fi

echo "PASS step3: third invocation (sentinel aged >60s) appended 1 line"

# ---------------------------------------------------------------------------
# Platform note — report which date dispatch path was exercised
# ---------------------------------------------------------------------------
PLATFORM="$(uname -s)"
if [ "$PLATFORM" = "Darwin" ] || printf '%s' "$PLATFORM" | grep -q BSD; then
  echo "INFO: date-dispatch path exercised: BSD (Darwin/BSD) — GNU Linux path goes uncovered on this run"
else
  echo "INFO: date-dispatch path exercised: GNU Linux — BSD Darwin path goes uncovered on this run"
fi

echo "PASS"
exit 0
