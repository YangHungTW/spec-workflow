#!/usr/bin/env bash
# test/t62_lint_archive_ignored.sh — archive paths excluded from scan
# R5 AC5.c; PRD Non-goals (archive excluded); D6 (out-of-scope path)
# Assert: a zh-TW file staged under .spec-workflow/archive/** produces
# exit 0 and no cjk-hit: line in stdout.

set -u

# ---------------------------------------------------------------------------
# Locate repo root relative to this test file
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
LINT="$REPO_ROOT/bin/specflow-lint"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (mandatory per sandbox-home-in-tests rule)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t62-test)"
trap 'rm -rf "$SANDBOX"' EXIT

# Preserve any tool-version files so asdf/pyenv can still resolve python3
# after HOME is redirected to the sandbox. Without this, asdf shims exit
# 126 ("No version is set") because ~/.tool-versions is unreachable.
REAL_HOME="$HOME"
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
if [ -f "$REAL_HOME/.tool-versions" ]; then
  cp "$REAL_HOME/.tool-versions" "$HOME/.tool-versions"
fi

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Sanity: lint script must exist and be executable
# ---------------------------------------------------------------------------
if [ ! -x "$LINT" ]; then
  fail "lint script not executable: $LINT"
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# Build a minimal consumer git repo
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
cd "$CONSUMER"
git init -q
git config user.email "test@example.com"
git config user.name "Test"

# Create and stage a zh-TW file under the archive path.
# The scanner's is_out_of_scope() check matches paths starting with
# .spec-workflow/archive/ — this file must be silently skipped.
ARCHIVE_DIR=".spec-workflow/archive/20260101-example"
mkdir -p "$ARCHIVE_DIR"
# Write a file containing zh-TW characters (CJK range 0x4E00-0x9FFF)
printf '這是中文歸檔內容\n' > "$ARCHIVE_DIR/foo.md"
git add "$ARCHIVE_DIR/foo.md"

# ---------------------------------------------------------------------------
# Run scan-staged; capture stdout and exit code separately.
# The scanner reads staged content via git cat-file --batch;
# running from $CONSUMER ensures git diff --cached sees the staged file.
# ---------------------------------------------------------------------------
STDOUT_FILE="$SANDBOX/stdout.txt"
"$LINT" scan-staged > "$STDOUT_FILE" 2>/dev/null
RC=$?

# ---------------------------------------------------------------------------
# Check 1: exit code is 0 (archive path is out of scope — no cjk-hit)
# ---------------------------------------------------------------------------
if [ "$RC" -eq 0 ]; then
  pass "Check 1: scan-staged exits 0 for archive-only staged file"
else
  fail "Check 1: scan-staged exited $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Check 2: stdout does NOT contain cjk-hit: for the archive path
# ---------------------------------------------------------------------------
STDOUT_CONTENT="$(cat "$STDOUT_FILE")"
case "$STDOUT_CONTENT" in
  *"cjk-hit:.spec-workflow/archive/"*)
    fail "Check 2: stdout contains cjk-hit: for archive path (must be excluded)"
    ;;
  *)
    pass "Check 2: stdout has no cjk-hit: line for archive path"
    ;;
esac

# ---------------------------------------------------------------------------
# Check 3: stdout does NOT contain any cjk-hit: at all
# (belt-and-suspenders — only one file was staged)
# ---------------------------------------------------------------------------
case "$STDOUT_CONTENT" in
  *"cjk-hit:"*)
    fail "Check 3: stdout contains unexpected cjk-hit: line"
    ;;
  *)
    pass "Check 3: stdout contains no cjk-hit: lines"
    ;;
esac

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
