#!/usr/bin/env bash
# t112 — regression test for 20260426-fix-init-missing-preflight-files
# Asserts that bin/scaff-seed init AND migrate both create
# .specaffold/config.yml and .specaffold/preflight.md, that they are
# idempotent and respect no-force-on-user-paths, and that the resulting
# preflight is functionally correct (passthrough on init'd repo).
# Source bug: parent feature 20260426-scaff-init-preflight shipped a gate
# that fires REFUSED:PREFLIGHT on freshly-init'd repos because scaff-seed
# init didn't create the sentinel files. Closes the partial-wiring-trace
# gap (A7 covers the migrate path mirror; cf. team memory
# qa-analyst/partial-wiring-trace-every-entry-point.md).

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SEED="${SEED:-$REPO_ROOT/bin/scaff-seed}"

# ---------------------------------------------------------------------------
# Sandbox HOME — uniform discipline per .claude/rules/bash/sandbox-home-in-tests.md
# ---------------------------------------------------------------------------
_REAL_HOME="$HOME"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME (POSIX case, no `[[`)
case "$HOME" in
  "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# asdf compatibility: preserve real user's python version config so the
# shim can resolve python3 inside the sandboxed HOME. No-op on non-asdf setups.
if [ -f "$_REAL_HOME/.tool-versions" ]; then
  cp "$_REAL_HOME/.tool-versions" "$HOME/.tool-versions" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Helper: fail with label + reason and exit 1
# ---------------------------------------------------------------------------
fail() {
  printf 'FAIL: %s: %s\n' "$1" "$2" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Capture the source HEAD SHA once; used for --ref flag.
# ---------------------------------------------------------------------------
SRC_REF="$(git -C "$REPO_ROOT" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Helper: build a minimal consumer git repo so repo_root resolves inside it.
# Requires at least one commit so git-related commands work cleanly.
# Mirrors t108's make_consumer pattern exactly.
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
  # Provide bin/scaff-lint in the consumer so the pre-commit shim can exec it.
  mkdir -p "$dir/bin"
  cp "$REPO_ROOT/bin/scaff-lint" "$dir/bin/scaff-lint"
  chmod +x "$dir/bin/scaff-lint"
}

# ===========================================================================
# A1 — AC1: after scaff-seed init, both files exist as regular files
# ===========================================================================
printf '=== A1: AC1 — both files created by init ===\n'

CONSUMER="$SANDBOX/consumer-init"
make_consumer "$CONSUMER"

(cd "$CONSUMER" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > /dev/null 2>&1

[ -f "$CONSUMER/.specaffold/config.yml" ] \
  || fail "A1" ".specaffold/config.yml not present after scaff-seed init"

[ -f "$CONSUMER/.specaffold/preflight.md" ] \
  || fail "A1" ".specaffold/preflight.md not present after scaff-seed init"

printf 'PASS: A1 — both .specaffold/config.yml and .specaffold/preflight.md created\n'

# ===========================================================================
# A2 — AC2: preflight.md is byte-identical to the source copy
# ===========================================================================
printf '\n=== A2: AC2 — preflight.md byte-identical to source ===\n'

cmp "$REPO_ROOT/.specaffold/preflight.md" "$CONSUMER/.specaffold/preflight.md" \
  || fail "A2" "consumer .specaffold/preflight.md differs from source (cmp exited non-zero)"

printf 'PASS: A2 — .specaffold/preflight.md is byte-identical to source\n'

# ===========================================================================
# A3 — AC3: config.yml has lang.chat keys with default value of 'en'
# ===========================================================================
printf '\n=== A3: AC3 — config.yml has lang.chat keys ===\n'

grep -E '^lang:' "$CONSUMER/.specaffold/config.yml" > /dev/null \
  || fail "A3" "config.yml missing top-level 'lang:' key"

grep -E '^[[:space:]]+chat:' "$CONSUMER/.specaffold/config.yml" > /dev/null \
  || fail "A3" "config.yml missing 'chat:' sub-key under lang:"

grep -F 'chat: en' "$CONSUMER/.specaffold/config.yml" > /dev/null \
  || fail "A3" "config.yml 'chat:' value is not 'en' (expected default)"

printf 'PASS: A3 — config.yml has lang: chat: en\n'

# ===========================================================================
# A4 — AC4: second init is idempotent (already: tokens; shasum unchanged)
# ===========================================================================
printf '\n=== A4: AC4 — idempotency on second init ===\n'

SHA_CFG_BEFORE="$(shasum < "$CONSUMER/.specaffold/config.yml" | awk '{print $1}')"
SHA_PRE_BEFORE="$(shasum < "$CONSUMER/.specaffold/preflight.md" | awk '{print $1}')"

SECOND_OUT="$SANDBOX/second_init.out"
(cd "$CONSUMER" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > "$SECOND_OUT" 2>&1 || true

grep -F 'already:.specaffold/config.yml' "$SECOND_OUT" > /dev/null \
  || fail "A4" "second init did not report 'already:.specaffold/config.yml'; output: $(cat "$SECOND_OUT")"

grep -F 'already: .specaffold/preflight.md' "$SECOND_OUT" > /dev/null \
  || fail "A4" "second init did not report 'already: .specaffold/preflight.md'; output: $(cat "$SECOND_OUT")"

SHA_CFG_AFTER="$(shasum < "$CONSUMER/.specaffold/config.yml" | awk '{print $1}')"
SHA_PRE_AFTER="$(shasum < "$CONSUMER/.specaffold/preflight.md" | awk '{print $1}')"

[ "$SHA_CFG_BEFORE" = "$SHA_CFG_AFTER" ] \
  || fail "A4" "config.yml content changed between first and second init (not idempotent)"

[ "$SHA_PRE_BEFORE" = "$SHA_PRE_AFTER" ] \
  || fail "A4" "preflight.md content changed between first and second init (not idempotent)"

printf 'PASS: A4 — second init reports already: for both files; content unchanged\n'

# ===========================================================================
# A5 — AC5: pre-existing user-edited config.yml is not clobbered (no-force)
# ===========================================================================
printf '\n=== A5: AC5 — no-force on foreign config.yml ===\n'

CONSUMER_F="$SANDBOX/consumer-foreign-cfg"
make_consumer "$CONSUMER_F"

# Pre-create a user-edited config.yml before init runs
mkdir -p "$CONSUMER_F/.specaffold"
printf 'lang:\n  chat: zh-TW\nuser_added: true\n' > "$CONSUMER_F/.specaffold/config.yml"

SHA_FOREIGN_BEFORE="$(shasum < "$CONSUMER_F/.specaffold/config.yml" | awk '{print $1}')"

FOREIGN_OUT="$SANDBOX/foreign_cfg_init.out"
set +e
(cd "$CONSUMER_F" && "$SEED" init --from "$REPO_ROOT" --ref "$SRC_REF") > "$FOREIGN_OUT" 2>&1
set -e

grep -F 'skipped:user-modified:.specaffold/config.yml' "$FOREIGN_OUT" > /dev/null \
  || fail "A5" "expected 'skipped:user-modified:.specaffold/config.yml' in output; got: $(cat "$FOREIGN_OUT")"

SHA_FOREIGN_AFTER="$(shasum < "$CONSUMER_F/.specaffold/config.yml" | awk '{print $1}')"

[ "$SHA_FOREIGN_BEFORE" = "$SHA_FOREIGN_AFTER" ] \
  || fail "A5" "user-edited config.yml content changed after init (no-force-on-user-paths violated)"

printf 'PASS: A5 — init skipped user-edited config.yml; content byte-identical\n'

# ===========================================================================
# A6 — AC6: SCAFF PREFLIGHT block from consumer preflight.md is passthrough
#           on an init'd repo (exit 0, empty output)
# ===========================================================================
printf '\n=== A6: AC6 — preflight passthrough on init'"'"'d consumer ===\n'

# Extract the SCAFF PREFLIGHT block from the consumer's preflight.md
# (same awk extraction pattern as t110)
PREFLIGHT_MD="$CONSUMER/.specaffold/preflight.md"
BLOCK="$(awk '/^# === SCAFF PREFLIGHT/,/^# === END SCAFF PREFLIGHT/' "$PREFLIGHT_MD")"

[ -n "$BLOCK" ] \
  || fail "A6" "SCAFF PREFLIGHT block not found in consumer's .specaffold/preflight.md"

printf '%s\n' "$BLOCK" > "$SANDBOX/consumer_preflight.sh"

# Run the gate from the consumer's CWD (config.yml is present → passthrough)
OUT6="$(cd "$CONSUMER" && bash "$SANDBOX/consumer_preflight.sh" 2>&1)" \
  && EXIT6=0 || EXIT6=$?

[ "$EXIT6" = "0" ] \
  || fail "A6" "preflight gate exited $EXIT6 (expected 0 passthrough); output: $OUT6"

[ -z "$OUT6" ] \
  || fail "A6" "preflight gate produced output on passthrough (expected empty); got: $OUT6"

printf 'PASS: A6 — preflight exits 0 with empty output on init'"'"'d consumer\n'

# ===========================================================================
# A7 — AC7 / R3 partial-wiring-trace: scaff-seed migrate also creates both files
#      This assertion closes the gap that allowed the parent feature bug to ship.
#      Cross-references qa-analyst/partial-wiring-trace-every-entry-point.md.
# ===========================================================================
printf '\n=== A7: AC7 — migrate path parity (partial-wiring-trace gap closer) ===\n'

CONSUMER_M="$SANDBOX/consumer-migrate"
make_consumer "$CONSUMER_M"

(cd "$CONSUMER_M" && "$SEED" migrate --from "$REPO_ROOT" --ref "$SRC_REF") > /dev/null 2>&1

[ -f "$CONSUMER_M/.specaffold/config.yml" ] \
  || fail "A7" ".specaffold/config.yml not present after scaff-seed migrate"

[ -f "$CONSUMER_M/.specaffold/preflight.md" ] \
  || fail "A7" ".specaffold/preflight.md not present after scaff-seed migrate"

# Verify config.yml default value matches what init produces (lang.chat: en)
grep -F 'chat: en' "$CONSUMER_M/.specaffold/config.yml" > /dev/null \
  || fail "A7" "migrate-produced config.yml does not contain 'chat: en' (default mismatch)"

# Verify preflight.md is byte-identical to source (same as A2 but via migrate)
cmp "$REPO_ROOT/.specaffold/preflight.md" "$CONSUMER_M/.specaffold/preflight.md" \
  || fail "A7" "migrate-produced .specaffold/preflight.md differs from source (byte mismatch)"

# Verify both files are byte-identical to what init produced
SHA_INIT_CFG="$(shasum < "$CONSUMER/.specaffold/config.yml" | awk '{print $1}')"
SHA_MIG_CFG="$(shasum < "$CONSUMER_M/.specaffold/config.yml" | awk '{print $1}')"
[ "$SHA_INIT_CFG" = "$SHA_MIG_CFG" ] \
  || fail "A7" "migrate config.yml sha differs from init config.yml sha (emit-site drift)"

printf 'PASS: A7 — migrate produces same files as init; partial-wiring-trace gap covered\n'

# ===========================================================================
# Summary
# ===========================================================================
printf '\nPASS: t112\n'
exit 0
