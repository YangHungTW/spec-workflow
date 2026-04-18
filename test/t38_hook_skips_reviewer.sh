#!/usr/bin/env bash
# test/t38_hook_skips_reviewer.sh
# Verify D7 — SessionStart hook digest does NOT contain reviewer-scoped rules.
# Reviewer rules are agent-triggered, not session-wide (SKIP_SUBDIRS guard).
#
# Depends on: T2 (SKIP_SUBDIRS guard in hook), T3-T5 (reviewer/*.md exist).

set -u

# ---------------------------------------------------------------------------
# Locate repo root relative to this test file
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
HOOK="$REPO_ROOT/.claude/hooks/session-start.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (per sandbox-home-in-tests rule)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t38-test)"
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
  fail "hook not executable: $HOOK"
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# Set up sandbox repo with .claude/rules mirror
# (contains populated reviewer/ dir from M2 rubric files)
# ---------------------------------------------------------------------------
REPO="$SANDBOX/repo"
mkdir -p "$REPO"

# Init a git repo so lang_heuristic git commands don't error
(cd "$REPO" && git init -q && git config user.email "t@example.com" && \
 git config user.name "t" && touch test.sh test.md && \
 git add . && git commit -qm "init" 2>/dev/null)

# Copy rules directory from real repo into sandbox repo
mkdir -p "$REPO/.claude"
cp -r "$REPO_ROOT/.claude/rules" "$REPO/.claude/rules"

# Verify reviewer rubric files are present in the snapshot (test sanity)
REVIEWER_COUNT=0
for f in "$REPO/.claude/rules/reviewer/"*.md; do
  [ -f "$f" ] && REVIEWER_COUNT=$((REVIEWER_COUNT + 1))
done
if [ "$REVIEWER_COUNT" -lt 1 ]; then
  fail "setup: no reviewer/*.md files found in sandbox — T3-T5 may not be merged"
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# Copy hook into sandbox (we invoke from REPO so RULES_DIR=.claude/rules resolves)
SANDBOX_HOOK="$SANDBOX/session-start.sh"
cp "$HOOK" "$SANDBOX_HOOK"
chmod +x "$SANDBOX_HOOK"

STDOUT_LOG="$SANDBOX/stdout.log"
STDERR_LOG="$SANDBOX/stderr.log"

# ---------------------------------------------------------------------------
# Invoke hook from the sandbox repo (so .claude/rules found via RULES_DIR)
# ---------------------------------------------------------------------------
(cd "$REPO" && bash "$SANDBOX_HOOK" < /dev/null > "$STDOUT_LOG" 2> "$STDERR_LOG")
HOOK_RC=$?

# ---------------------------------------------------------------------------
# Assertion A: hook exits 0
# ---------------------------------------------------------------------------
if [ "$HOOK_RC" -eq 0 ]; then
  pass "A: hook exits 0"
else
  fail "A: hook exited $HOOK_RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Assertion B: 'reviewer/' does NOT appear anywhere in stdout
# ---------------------------------------------------------------------------
if grep -q 'reviewer/' "$STDOUT_LOG" 2>/dev/null; then
  fail "B: stdout contains 'reviewer/' reference — hook did not skip reviewer subdir"
else
  pass "B: stdout contains no 'reviewer/' references"
fi

# ---------------------------------------------------------------------------
# Assertion B2: reviewer rule names do not appear in stdout
# (security, performance, style names from rubric frontmatter names)
# ---------------------------------------------------------------------------
REVIEWER_NAME_MISS=1
if grep -q 'reviewer-security\|reviewer-performance\|reviewer-style' "$STDOUT_LOG" 2>/dev/null; then
  REVIEWER_NAME_MISS=0
fi
if [ "$REVIEWER_NAME_MISS" -eq 1 ]; then
  pass "B2: reviewer rule names absent from digest"
else
  fail "B2: reviewer rule name(s) found in digest (security.md / performance.md / style.md names present)"
fi

# Also check individual rubric names as they appear in the name: frontmatter (not prefixed)
RUBRIC_NAME_HIT=0
for rubric_name in security performance style; do
  # A rubric rule's name field is just 'security', 'performance', or 'style'.
  # The digest emits "• [severity] <name> — ..." — check if these names appear
  # in a bullet context that would only come from reviewer/ subdir.
  # We check whether the reviewer subdir path appears — already covered by B.
  # Here we additionally verify the names aren't embedded via any path reference.
  if grep -q "reviewer/${rubric_name}" "$STDOUT_LOG" 2>/dev/null; then
    RUBRIC_NAME_HIT=$((RUBRIC_NAME_HIT + 1))
  fi
done
if [ "$RUBRIC_NAME_HIT" -eq 0 ]; then
  pass "B3: no reviewer/<name> path references in stdout"
else
  fail "B3: $RUBRIC_NAME_HIT reviewer/<name> path reference(s) found in stdout"
fi

# ---------------------------------------------------------------------------
# Assertion C: SKIP_SUBDIRS variable is declared in the hook script
# ---------------------------------------------------------------------------
if grep -q 'SKIP_SUBDIRS=' "$HOOK"; then
  pass "C: SKIP_SUBDIRS variable declared in hook script"
else
  fail "C: SKIP_SUBDIRS not declared in hook script — T2 may not be merged"
fi

# ---------------------------------------------------------------------------
# Assertion C2: digest DID emit common/ rules (sanity — hook still works)
# stdout should contain at least one '[' from bullet lines like: • [severity] name
# ---------------------------------------------------------------------------
if grep -q '\[' "$STDOUT_LOG" 2>/dev/null; then
  pass "C2: digest contains common/ rules (sanity — hook still functional)"
else
  fail "C2: digest has no '[' markers — common/ rules missing or hook broken (stdout: $(cat "$STDOUT_LOG"))"
fi

# ---------------------------------------------------------------------------
# Assertion D (B1 regression): t17_hook_happy_path.sh still exits 0
# ---------------------------------------------------------------------------
T17="$REPO_ROOT/test/t17_hook_happy_path.sh"
if [ -x "$T17" ]; then
  D_OUT=$(bash "$T17" 2>&1)
  D_RC=$?
  if [ "$D_RC" -eq 0 ]; then
    pass "D: B1 regression — t17_hook_happy_path.sh exits 0"
  else
    fail "D: B1 regression — t17_hook_happy_path.sh exited $D_RC"
    printf '%s\n' "$D_OUT" | head -20
  fi
else
  fail "D: B1 regression — t17_hook_happy_path.sh not found or not executable: $T17"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
