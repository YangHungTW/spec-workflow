#!/usr/bin/env bash
# test/t61_lint_inline_marker_allowlist.sh
#
# Requirements: R5 AC5.c — allowlist surface 2: inline HTML-comment marker
# Decision: D6 — <!-- specflow-lint: allow-cjk reason="..." --> suppresses
#           CJK scanning for the entire file that contains the marker line.
#
# Case A: fixture contains the inline marker + zh-TW content → exit 0,
#         stdout has allowlisted:<path>:inline-marker
# Case B: same fixture without the marker line → exit 1, stdout has cjk-hit:
#
# RED pre-T3 (specflow-lint not yet present).
# GREEN post-T3 merge.

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
LINT="${LINT:-$REPO_ROOT/bin/specflow-lint}"

if [ ! -x "$LINT" ]; then
  echo "FAIL: setup: bin/specflow-lint not found or not executable: $LINT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sandbox + HOME isolation (sandbox-home-in-tests.md — mandatory)
# Capture real HOME before sandboxing so asdf .tool-versions can be copied in.
# ---------------------------------------------------------------------------
_REAL_HOME="$HOME"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# asdf compatibility: preserve the real user's python version config so the
# shim can resolve python3 inside the sandboxed HOME. No-op on non-asdf setups.
if [ -f "$_REAL_HOME/.tool-versions" ]; then
  cp "$_REAL_HOME/.tool-versions" "$HOME/.tool-versions" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Build a minimal consumer git repo inside the sandbox
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
git init -q "$CONSUMER"
git -C "$CONSUMER" config user.email "t@example.com"
git -C "$CONSUMER" config user.name "t"

# Need at least one commit so `git diff --cached` works correctly
printf 'placeholder\n' > "$CONSUMER/.gitkeep"
git -C "$CONSUMER" add .gitkeep
git -C "$CONSUMER" commit -q -m "init"

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
fail() {
  echo "FAIL: $1: $2" >&2
  exit 1
}

FIXTURE_REL="test/fixtures/cjk_sample.md"
FIXTURE_ABS="$CONSUMER/$FIXTURE_REL"
mkdir -p "$(dirname "$FIXTURE_ABS")"

# ===========================================================================
# Case A — inline marker present + zh-TW content → exit 0, allowlisted line
# ===========================================================================
printf '<!-- specflow-lint: allow-cjk reason="fixture for t61 integration test" -->\n\n這是測試夾具的中文內容。\n' \
  > "$FIXTURE_ABS"
git -C "$CONSUMER" add "$FIXTURE_REL"

# Run the scanner from inside the consumer repo so git commands resolve correctly
CASE_A_OUT="$SANDBOX/case_a_out.txt"
cd "$CONSUMER"
set +e
"$LINT" scan-staged > "$CASE_A_OUT" 2>/dev/null
CASE_A_EXIT=$?
set -e
cd "$SANDBOX"

# exit code must be 0
[ "$CASE_A_EXIT" -eq 0 ] || \
  fail "case-A" "exit code was $CASE_A_EXIT (expected 0)"

# stdout must contain allowlisted:<path>:inline-marker
grep -q "allowlisted:.*:inline-marker" "$CASE_A_OUT" || \
  fail "case-A" "stdout missing allowlisted:...:inline-marker line (got: $(cat "$CASE_A_OUT"))"

# stdout must NOT contain cjk-hit:
grep -q "cjk-hit:" "$CASE_A_OUT" && \
  fail "case-A" "stdout unexpectedly contains cjk-hit: line" || true

echo "PASS: case-A (inline marker present → allowlisted)"

# ===========================================================================
# Case B — same zh-TW content, marker line removed → exit 1, cjk-hit line
# ===========================================================================

# Unstage the previous version so we start clean
git -C "$CONSUMER" reset HEAD "$FIXTURE_REL" > /dev/null 2>&1 || true

# Write fixture without the marker line
printf '\n這是測試夾具的中文內容。\n' > "$FIXTURE_ABS"
git -C "$CONSUMER" add "$FIXTURE_REL"

CASE_B_OUT="$SANDBOX/case_b_out.txt"
cd "$CONSUMER"
set +e
"$LINT" scan-staged > "$CASE_B_OUT" 2>/dev/null
CASE_B_EXIT=$?
set -e
cd "$SANDBOX"

# exit code must be 1 (cjk-hit detected)
[ "$CASE_B_EXIT" -eq 1 ] || \
  fail "case-B" "exit code was $CASE_B_EXIT (expected 1)"

# stdout must contain cjk-hit:
grep -q "cjk-hit:" "$CASE_B_OUT" || \
  fail "case-B" "stdout missing cjk-hit: line (got: $(cat "$CASE_B_OUT"))"

echo "PASS: case-B (marker absent → cjk-hit)"

echo "PASS"
exit 0
