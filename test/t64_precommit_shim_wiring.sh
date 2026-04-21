#!/usr/bin/env bash
# test/t64_precommit_shim_wiring.sh
#
# Integration test for the pre-commit shim installed by bin/specflow-seed init.
#
# Assertions:
#   A1 — .git/hooks/pre-commit exists AND is executable after init.
#   A2 — Its content contains the 'specflow-lint' sentinel string.
#   A3 — git commit with staged zh-TW content is rejected (exit non-zero)
#        because the shim fires lint and lint fires the cjk-hit rejection path.
#   A4 — Second specflow-seed init reports 'already:.git/hooks/pre-commit'
#        (idempotency: no second install).
#   A5 — Pre-existing foreign pre-commit (no sentinel) before init causes
#        installer to report 'skipped:foreign-pre-commit:.git/hooks/pre-commit'
#        and exit non-zero WITHOUT clobbering the foreign file.
#
# Sandbox preflight per .claude/rules/bash/sandbox-home-in-tests.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SEED="${SEED:-$REPO_ROOT/bin/specflow-seed}"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md — non-negotiable)
# Capture real HOME before sandboxing so asdf .tool-versions can be copied in.
# ---------------------------------------------------------------------------
_REAL_HOME="$HOME"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

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
# Helper: fail with label + reason and exit 1
# ---------------------------------------------------------------------------
fail() {
  echo "FAIL: $1: $2" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Capture the source HEAD SHA once; used for --ref flag.
# ---------------------------------------------------------------------------
SRC_REF="$(git -C "$REPO_ROOT" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Helper: build a minimal consumer git repo so repo_root resolves inside it.
# Requires at least one commit so git-related commands work cleanly.
# ---------------------------------------------------------------------------
make_consumer() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "t@example.com"
  git -C "$dir" config user.name "t"
  printf '*.log\n' > "$dir/.gitignore"
  git -C "$dir" add .gitignore
  git -C "$dir" commit -q -m "init"
  # Provide bin/specflow-lint in the consumer so the pre-commit shim can exec
  # it (the shim calls 'exec bin/specflow-lint scan-staged' relative to repo
  # root; specflow-seed does NOT copy bin/ into the consumer).
  mkdir -p "$dir/bin"
  cp "$REPO_ROOT/bin/specflow-lint" "$dir/bin/specflow-lint"
  chmod +x "$dir/bin/specflow-lint"
}

# ===========================================================================
# Assertions A1–A4: fresh consumer
# ===========================================================================
CONSUMER="$SANDBOX/consumer"
make_consumer "$CONSUMER"

# Run init
(cd "$CONSUMER" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > /dev/null 2>&1

# ---------------------------------------------------------------------------
# A1 — .git/hooks/pre-commit exists AND is executable
# ---------------------------------------------------------------------------
HOOK="$CONSUMER/.git/hooks/pre-commit"
[ -f "$HOOK" ] || fail "A1" ".git/hooks/pre-commit does not exist"
[ -x "$HOOK" ] || fail "A1" ".git/hooks/pre-commit is not executable"

# ---------------------------------------------------------------------------
# A2 — Content contains 'specflow-lint' sentinel (grep -F, at least 1 match)
# ---------------------------------------------------------------------------
grep -F 'specflow-lint' "$HOOK" >/dev/null 2>&1 \
  || fail "A2" ".git/hooks/pre-commit does not contain 'specflow-lint' sentinel"

# ---------------------------------------------------------------------------
# A3 — git commit with staged zh-TW content is rejected (exit non-zero).
#      The pre-commit shim fires specflow-lint scan-staged which finds CJK
#      characters and exits 1, causing git commit to abort.
#      Do NOT use --no-verify (R5 AC5.d: bypass must be explicit).
# ---------------------------------------------------------------------------
FIXTURE="$CONSUMER/fixture_zh_tw.txt"
# U+4E2D (中) U+6587 (文) U+5185 (内) U+5BB9 (容) — zh-TW content
printf '\xe4\xb8\xad\xe6\x96\x87\xe5\x86\x85\xe5\xae\xb9\n' > "$FIXTURE"
git -C "$CONSUMER" add "$FIXTURE"

set +e
(cd "$CONSUMER" && git commit -m "test") > /dev/null 2>&1
COMMIT_RC=$?
set -e

[ "$COMMIT_RC" -ne 0 ] \
  || fail "A3" "git commit with zh-TW content was accepted (exit 0) — shim did not fire lint rejection"

# ---------------------------------------------------------------------------
# A4 — Idempotency: second specflow-seed init reports 'already:.git/hooks/pre-commit'
# ---------------------------------------------------------------------------
SECOND_OUT="$SANDBOX/second_init.out"
(cd "$CONSUMER" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > "$SECOND_OUT" 2>&1 || true

grep -F 'already:.git/hooks/pre-commit' "$SECOND_OUT" >/dev/null 2>&1 \
  || fail "A4" "second init did not report 'already:.git/hooks/pre-commit'; output: $(cat "$SECOND_OUT")"

# ===========================================================================
# Assertion A5 — Foreign pre-commit pre-exists before init
# ===========================================================================
CONSUMER_F="$SANDBOX/consumer-foreign"
make_consumer "$CONSUMER_F"

# Pre-create a foreign pre-commit hook WITHOUT the specflow-lint sentinel
mkdir -p "$CONSUMER_F/.git/hooks"
printf '#!/bin/sh\necho foreign\n' > "$CONSUMER_F/.git/hooks/pre-commit"
chmod +x "$CONSUMER_F/.git/hooks/pre-commit"

FOREIGN_OUT="$SANDBOX/foreign_init.out"
set +e
(cd "$CONSUMER_F" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > "$FOREIGN_OUT" 2>&1
FOREIGN_RC=$?
set -e

# Installer must exit non-zero when it skips a foreign hook
[ "$FOREIGN_RC" -ne 0 ] \
  || fail "A5" "init with foreign pre-commit exited 0 — should have exited non-zero"

# Installer must report the skip message
grep -F 'skipped:foreign-pre-commit:.git/hooks/pre-commit' "$FOREIGN_OUT" >/dev/null 2>&1 \
  || fail "A5" "expected 'skipped:foreign-pre-commit:.git/hooks/pre-commit' in output; got: $(cat "$FOREIGN_OUT")"

# Foreign file content must be byte-for-byte unchanged (no clobber)
FOREIGN_CONTENT="$(cat "$CONSUMER_F/.git/hooks/pre-commit")"
EXPECTED_CONTENT="$(printf '#!/bin/sh\necho foreign\n')"
[ "$FOREIGN_CONTENT" = "$EXPECTED_CONTENT" ] \
  || fail "A5" "foreign pre-commit hook was overwritten (content changed)"

echo "PASS"
