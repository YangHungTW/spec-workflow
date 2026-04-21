#!/usr/bin/env bash
# test/t59_lint_cjk_hit.sh
#
# Integration test — bin/scaff-lint scan-staged rejects a staged .md file
# containing CJK codepoints (U+4E00–U+9FFF main block).
#
# Assertions:
#   1. Exit code 1 (AC5.a: rejection when cjk-hit found).
#   2. Stdout contains at least one line matching D6 format:
#      cjk-hit:<file>:<line>:<col>:U+[0-9A-F]+
#   3. Stderr contains a human-readable summary referencing cjk-hit.
#
# Fixture: .specaffold/features/fixture/notes.md with zh-TW sentence
# "這是中文" — codepoints U+9019, U+662F, U+4E2D, U+6587, all in U+4E00–U+9FFF.
# Path is not under archive/ and not a 00-request.md, so no allowlist applies.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
LINT="${LINT:-$REPO_ROOT/bin/scaff-lint}"

# ---------------------------------------------------------------------------
# Capture real HOME before sandboxing — needed to copy asdf .tool-versions so
# python3 shim resolves inside the sandbox (no-op on non-asdf setups).
# ---------------------------------------------------------------------------
_REAL_HOME="$HOME"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t scaff-t59)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# asdf compatibility: preserve real user's python version config inside sandbox.
if [ -f "$_REAL_HOME/.tool-versions" ]; then
  cp "$_REAL_HOME/.tool-versions" "$HOME/.tool-versions" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Setup — minimal git repo inside sandbox
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"

git init -q "$CONSUMER"
git -C "$CONSUMER" config user.email "test@example.com"
git -C "$CONSUMER" config user.name "Test"

# asdf: also copy .tool-versions into consumer so python3 resolves when cwd
# switches to $CONSUMER for the lint invocation.
if [ -f "$_REAL_HOME/.tool-versions" ]; then
  cp "$_REAL_HOME/.tool-versions" "$CONSUMER/.tool-versions" 2>/dev/null || true
fi

# Stage the fixture: a .md file with zh-TW content (four CJK codepoints).
# Codepoints: U+9019(這) U+662F(是) U+4E2D(中) U+6587(文) — all in U+4E00–U+9FFF.
# Path is under .specaffold/features/fixture/ — not archive/, not 00-request.md.
FIXTURE_DIR="$CONSUMER/.specaffold/features/fixture"
mkdir -p "$FIXTURE_DIR"
printf '# Notes\n\n%s\n' '這是中文' > "$FIXTURE_DIR/notes.md"

git -C "$CONSUMER" add ".specaffold/features/fixture/notes.md"

# ---------------------------------------------------------------------------
# Run lint from the consumer repo root (scan-staged uses git diff --cached
# and git cat-file which require a valid git working tree as cwd).
# ---------------------------------------------------------------------------
STDOUT_FILE="$SANDBOX/lint.stdout"
STDERR_FILE="$SANDBOX/lint.stderr"

cd "$CONSUMER"
EXIT_CODE=0
"$LINT" scan-staged > "$STDOUT_FILE" 2> "$STDERR_FILE" || EXIT_CODE=$?

# ---------------------------------------------------------------------------
# Assertion 1 — exit code must be 1 (cjk-hit found)
# ---------------------------------------------------------------------------
if [ "$EXIT_CODE" -ne 1 ]; then
  echo "FAIL: expected exit code 1, got $EXIT_CODE" >&2
  echo "  stdout: $(cat "$STDOUT_FILE")" >&2
  echo "  stderr: $(cat "$STDERR_FILE")" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertion 2 — stdout must contain at least one cjk-hit line in D6 format:
#   cjk-hit:<file>:<line>:<col>:U+[0-9A-F]+
# Each CJK codepoint produces one line; the fixture has four, so we expect
# four lines but the contract requires at least one in the correct format.
# ---------------------------------------------------------------------------
CJK_HIT_COUNT=0
while IFS= read -r line; do
  case "$line" in
    cjk-hit:*:*:*:U+[0-9A-F]*)
      CJK_HIT_COUNT=$((CJK_HIT_COUNT + 1))
      ;;
    cjk-hit:*)
      echo "FAIL: cjk-hit line does not match D6 format: $line" >&2
      exit 1
      ;;
  esac
done < "$STDOUT_FILE"

if [ "$CJK_HIT_COUNT" -lt 1 ]; then
  echo "FAIL: expected at least one cjk-hit line in stdout, got $CJK_HIT_COUNT" >&2
  echo "  stdout: $(cat "$STDOUT_FILE")" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Assertion 3 — stderr must contain a human-readable summary referencing cjk-hit
# ---------------------------------------------------------------------------
STDERR_CONTENT="$(cat "$STDERR_FILE")"
case "$STDERR_CONTENT" in
  *cjk-hit*) ;;
  *)
    echo "FAIL: stderr does not contain 'cjk-hit' summary" >&2
    echo "  stderr: $STDERR_CONTENT" >&2
    exit 1
    ;;
esac

echo "PASS: exit=1; cjk-hit lines=$CJK_HIT_COUNT; stderr summary present"
exit 0
