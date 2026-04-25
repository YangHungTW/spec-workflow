#!/usr/bin/env bash
# test/t108_precommit_preflight_wiring.sh
#
# Structural test: pre-commit shim wiring for the preflight-coverage lint
# subcommand added in T4.  Covers AC4 (by-construction inheritance via the
# pre-commit shim installed by bin/scaff-seed init).
#
# Assertions:
#   A1 — bin/scaff-seed's shim heredoc references both lint subcommands
#        ('scan-staged' and 'preflight-coverage') within the same heredoc block.
#   A2 — Sandboxed init produces a pre-commit hook containing both invocations.
#   A3 — Idempotency: second init reports 'already:.git/hooks/pre-commit' and
#        hook is byte-identical between runs.
#   A4 — Foreign hook (no scaff-lint sentinel) is left untouched and init
#        reports 'skipped:foreign-pre-commit:.git/hooks/pre-commit'.
#
# Sandbox preflight per .claude/rules/bash/sandbox-home-in-tests.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SEED="${SEED:-$REPO_ROOT/bin/scaff-seed}"

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
# Reproduced inline from test/t64_precommit_shim_wiring.sh lines 64-79.
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
  # Provide bin/scaff-lint in the consumer so the pre-commit shim can exec
  # it (the shim calls 'exec bin/scaff-lint scan-staged' relative to repo
  # root; scaff-seed does NOT copy bin/ into the consumer).
  mkdir -p "$dir/bin"
  cp "$REPO_ROOT/bin/scaff-lint" "$dir/bin/scaff-lint"
  chmod +x "$dir/bin/scaff-lint"
}

# ===========================================================================
# A1 — Template: both lint subcommands appear in the shim heredoc block
# ===========================================================================

# Confirm 'preflight-coverage' appears at least once in bin/scaff-seed
grep -F 'preflight-coverage' "$REPO_ROOT/bin/scaff-seed" >/dev/null 2>&1 \
  || fail "A1" "'preflight-coverage' not found in bin/scaff-seed"

# Confirm 'scan-staged' appears at least once in bin/scaff-seed
grep -F 'scan-staged' "$REPO_ROOT/bin/scaff-seed" >/dev/null 2>&1 \
  || fail "A1" "'scan-staged' not found in bin/scaff-seed"

# Both literals must appear within ~5 lines of the comment sentinel
# 'pre-commit shim — installed by bin/scaff-seed'.  This verifies they
# are co-located in the same heredoc block rather than scattered elsewhere.
ANCHOR_LINE="$(grep -n 'pre-commit shim — installed by bin/scaff-seed' "$REPO_ROOT/bin/scaff-seed" | head -1 | awk -F: '{print $1}')"
[ -n "$ANCHOR_LINE" ] \
  || fail "A1" "anchor comment 'pre-commit shim — installed by bin/scaff-seed' not found in bin/scaff-seed"

SCAN_LINE="$(grep -n 'scan-staged' "$REPO_ROOT/bin/scaff-seed" | head -1 | awk -F: '{print $1}')"
PREFLIGHT_LINE="$(grep -n 'preflight-coverage' "$REPO_ROOT/bin/scaff-seed" | head -1 | awk -F: '{print $1}')"

SCAN_DIST=$(( SCAN_LINE - ANCHOR_LINE ))
[ "$SCAN_DIST" -lt 0 ] && SCAN_DIST=$(( -SCAN_DIST ))
[ "$SCAN_DIST" -le 5 ] \
  || fail "A1" "'scan-staged' is $SCAN_DIST lines from the shim comment (threshold: 5); not in the same heredoc block"

PREFLIGHT_DIST=$(( PREFLIGHT_LINE - ANCHOR_LINE ))
[ "$PREFLIGHT_DIST" -lt 0 ] && PREFLIGHT_DIST=$(( -PREFLIGHT_DIST ))
[ "$PREFLIGHT_DIST" -le 5 ] \
  || fail "A1" "'preflight-coverage' is $PREFLIGHT_DIST lines from the shim comment (threshold: 5); not in the same heredoc block"

# ===========================================================================
# A2 — Sandboxed init produces a hook with both invocations
# ===========================================================================
CONSUMER="$SANDBOX/consumer"
make_consumer "$CONSUMER"

(cd "$CONSUMER" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > /dev/null 2>&1

HOOK="$CONSUMER/.git/hooks/pre-commit"

[ -x "$HOOK" ] \
  || fail "A2" ".git/hooks/pre-commit is missing or not executable after init"

grep -F 'scaff-lint scan-staged' "$HOOK" >/dev/null 2>&1 \
  || fail "A2" ".git/hooks/pre-commit does not contain 'scaff-lint scan-staged'"

grep -F 'scaff-lint preflight-coverage' "$HOOK" >/dev/null 2>&1 \
  || fail "A2" ".git/hooks/pre-commit does not contain 'scaff-lint preflight-coverage'"

# ===========================================================================
# A3 — Idempotency: second init reports 'already:' and hook is byte-identical
# ===========================================================================
BEFORE_HASH="$(shasum "$HOOK" | awk '{print $1}')"

SECOND_OUT="$SANDBOX/second_init.out"
(cd "$CONSUMER" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > "$SECOND_OUT" 2>&1 || true

grep -F 'already:.git/hooks/pre-commit' "$SECOND_OUT" >/dev/null 2>&1 \
  || fail "A3" "second init did not report 'already:.git/hooks/pre-commit'; output: $(cat "$SECOND_OUT")"

AFTER_HASH="$(shasum "$HOOK" | awk '{print $1}')"
[ "$BEFORE_HASH" = "$AFTER_HASH" ] \
  || fail "A3" "hook content changed between first and second init (not byte-identical)"

# ===========================================================================
# A4 — Foreign hook pre-exists: init skips and leaves content untouched
# ===========================================================================
CONSUMER_F="$SANDBOX/consumer-foreign"
make_consumer "$CONSUMER_F"

# Pre-create a foreign pre-commit hook WITHOUT the scaff-lint sentinel
mkdir -p "$CONSUMER_F/.git/hooks"
printf '#!/bin/sh\necho foreign\n' > "$CONSUMER_F/.git/hooks/pre-commit"
chmod +x "$CONSUMER_F/.git/hooks/pre-commit"

FOREIGN_EXPECTED="$(printf '#!/bin/sh\necho foreign\n')"

FOREIGN_OUT="$SANDBOX/foreign_init.out"
set +e
(cd "$CONSUMER_F" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > "$FOREIGN_OUT" 2>&1
set -e

grep -F 'skipped:foreign-pre-commit:.git/hooks/pre-commit' "$FOREIGN_OUT" >/dev/null 2>&1 \
  || fail "A4" "expected 'skipped:foreign-pre-commit:.git/hooks/pre-commit' in output; got: $(cat "$FOREIGN_OUT")"

FOREIGN_ACTUAL="$(cat "$CONSUMER_F/.git/hooks/pre-commit")"
[ "$FOREIGN_ACTUAL" = "$FOREIGN_EXPECTED" ] \
  || fail "A4" "foreign pre-commit hook content was changed by init (no-force rule violated)"

# ===========================================================================
# A5 — scaff-seed migrate produces hook with both invocations
# ===========================================================================
CONSUMER_M="$SANDBOX/consumer-migrate"
make_consumer "$CONSUMER_M"

(cd "$CONSUMER_M" && "$SEED" migrate --from "$REPO_ROOT" --ref "$SRC_REF") > /dev/null 2>&1

HOOK_M="$CONSUMER_M/.git/hooks/pre-commit"

[ -x "$HOOK_M" ] \
  || fail "A5" ".git/hooks/pre-commit is missing or not executable after migrate"

grep -F 'scaff-lint scan-staged' "$HOOK_M" >/dev/null 2>&1 \
  || fail "A5" ".git/hooks/pre-commit does not contain 'scaff-lint scan-staged'"

grep -F 'scaff-lint preflight-coverage' "$HOOK_M" >/dev/null 2>&1 \
  || fail "A5" ".git/hooks/pre-commit does not contain 'scaff-lint preflight-coverage'"

echo "PASS: t108"
