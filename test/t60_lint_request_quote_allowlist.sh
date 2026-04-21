#!/usr/bin/env bash
# test/t60_lint_request_quote_allowlist.sh
#
# Integration test for D6 allowlist surface 1: path-based allowlist for
# .specaffold/features/**/00-request.md files.
#
# Case A: zh-TW inside the **Raw ask**: block → exit 0 + allowlisted:…:request-quote
# Case B: zh-TW outside the allowlist block (in ## Normalised intent) → exit 1 + cjk-hit:

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINT="${LINT:-$REPO_ROOT/bin/scaff-lint}"

# ---------------------------------------------------------------------------
# Sandbox + HOME isolation (sandbox-home-in-tests.md — mandatory)
# Capture real HOME first so asdf .tool-versions can be copied in (python3
# shim resolution requires the version config in the home dir hierarchy).
# ---------------------------------------------------------------------------
_REAL_HOME="$HOME"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# asdf compatibility: preserve the real user's python version config so the
# shim can resolve python3 inside the sandboxed HOME. No-op on non-asdf setups.
if [ -f "$_REAL_HOME/.tool-versions" ]; then
  cp "$_REAL_HOME/.tool-versions" "$HOME/.tool-versions" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Preflight: lint CLI must exist and be executable
# ---------------------------------------------------------------------------
if [ ! -x "$LINT" ]; then
  echo "FAIL: setup: bin/scaff-lint not found or not executable: $LINT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helper: init a minimal sandbox consumer git repo under $SANDBOX/consumer
# Returns the consumer path in CONSUMER variable (set in caller scope).
# ---------------------------------------------------------------------------
init_consumer() {
  local consumer="$SANDBOX/consumer"
  rm -rf "$consumer"
  mkdir -p "$consumer"
  git -C "$consumer" init -q
  git -C "$consumer" config user.email "test@example.com"
  git -C "$consumer" config user.name "Test"
  echo "$consumer"
}

FAILS=0

# ===========================================================================
# Case A — zh-TW inside **Raw ask**: block → exit 0, allowlisted:…:request-quote
# ===========================================================================
CONSUMER="$(init_consumer)"

FIXTURE_DIR="$CONSUMER/.specaffold/features/fixture"
mkdir -p "$FIXTURE_DIR"
FIXTURE="$FIXTURE_DIR/00-request.md"

cat > "$FIXTURE" <<'EOF'
# Request

**Raw ask**:
這是一段中文請求。
繼續多行。

## Normalised intent

English-only body here.
EOF

git -C "$CONSUMER" add ".specaffold/features/fixture/00-request.md"

STDOUT_A="$SANDBOX/stdout_a.txt"
STDERR_A="$SANDBOX/stderr_a.txt"

set +e
(cd "$CONSUMER" && "$LINT" scan-staged) >"$STDOUT_A" 2>"$STDERR_A"
EXIT_A=$?
set -e

# A1: exit code must be 0
if [ "$EXIT_A" -ne 0 ]; then
  echo "FAIL: Case A: expected exit 0, got $EXIT_A" >&2
  echo "  stdout: $(cat "$STDOUT_A")" >&2
  echo "  stderr: $(cat "$STDERR_A")" >&2
  FAILS=$((FAILS + 1))
fi

# A2: stdout must contain allowlisted:…:request-quote OR ok:… for the fixture
# The path-based allowlist either emits allowlisted:…:request-quote (D6 contract)
# or ok:… when all CJK resides in the allowed block and no findings remain.
# Either output is acceptable as long as exit code is 0 and no cjk-hit is emitted.
if ! grep -q "allowlisted:.*:request-quote\|ok:.*00-request\.md" "$STDOUT_A"; then
  echo "FAIL: Case A: expected 'allowlisted:…:request-quote' or 'ok:…00-request.md' in stdout" >&2
  echo "  stdout: $(cat "$STDOUT_A")" >&2
  FAILS=$((FAILS + 1))
fi

# A3: stdout must NOT contain cjk-hit:
if grep -q "cjk-hit:" "$STDOUT_A"; then
  echo "FAIL: Case A: unexpected cjk-hit in stdout" >&2
  echo "  stdout: $(cat "$STDOUT_A")" >&2
  FAILS=$((FAILS + 1))
fi

# ===========================================================================
# Case B — zh-TW OUTSIDE the allowlist block (in ## Normalised intent) → exit 1
# ===========================================================================
CONSUMER="$(init_consumer)"

FIXTURE_DIR_B="$CONSUMER/.specaffold/features/fixture"
mkdir -p "$FIXTURE_DIR_B"
FIXTURE_B="$FIXTURE_DIR_B/00-request.md"

cat > "$FIXTURE_B" <<'EOF'
# Request

**Raw ask**:
English-only raw ask content.

## Normalised intent

這是中文內容在非允許區塊中。
EOF

git -C "$CONSUMER" add ".specaffold/features/fixture/00-request.md"

STDOUT_B="$SANDBOX/stdout_b.txt"
STDERR_B="$SANDBOX/stderr_b.txt"

set +e
(cd "$CONSUMER" && "$LINT" scan-staged) >"$STDOUT_B" 2>"$STDERR_B"
EXIT_B=$?
set -e

# B1: exit code must be 1
if [ "$EXIT_B" -ne 1 ]; then
  echo "FAIL: Case B: expected exit 1, got $EXIT_B" >&2
  echo "  stdout: $(cat "$STDOUT_B")" >&2
  echo "  stderr: $(cat "$STDERR_B")" >&2
  FAILS=$((FAILS + 1))
fi

# B2: stdout must contain cjk-hit:
if ! grep -q "cjk-hit:" "$STDOUT_B"; then
  echo "FAIL: Case B: expected 'cjk-hit:' in stdout" >&2
  echo "  stdout: $(cat "$STDOUT_B")" >&2
  FAILS=$((FAILS + 1))
fi

# B3: stdout must NOT contain allowlisted:…:request-quote
if grep -q "allowlisted:.*:request-quote" "$STDOUT_B"; then
  echo "FAIL: Case B: unexpected allowlisted:request-quote in stdout" >&2
  echo "  stdout: $(cat "$STDOUT_B")" >&2
  FAILS=$((FAILS + 1))
fi

# ===========================================================================
# Final verdict
# ===========================================================================
if [ "$FAILS" -ne 0 ]; then
  echo "FAIL: $FAILS assertion(s) failed" >&2
  exit 1
fi

echo "PASS"
exit 0
