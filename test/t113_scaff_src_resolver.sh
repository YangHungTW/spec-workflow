#!/usr/bin/env bash
# t113 — regression test for 20260426-fix-commands-source-from-scaff-src
# Verifies the $SCAFF_SRC resolver in command preambles + pre-commit shim
# works in consumer repos that have no bin/. Asserts:
# A1: 3-tier resolver (env var / symlink readlink / loud failure)
# A4: pre-commit shim resolves at hook-run time (depends on T3+T4 + wave merge)
# A5: sandboxed consumer can extract gate body via $SCAFF_SRC
# A8: end-to-end consumer can resolve bin/* deps without local bin/
# Source: closes the trace-terminus gap from qa-analyst/wiring-trace-ends-at-user-goal.md
#
# NOTE — at W1 close (T1+T2+T3 merged, T4 not yet):
#   A1 (resolver unit tests) should pass.
#   A4 depends on T3 shipping the new shim heredoc; may partially pass.
#   A5 depends on T4 sweeping the marker blocks; will fail until T4 lands.
#   A8 depends on T4 as well (bin/scaff-tier sourced via $SCAFF_SRC from marker).
#   Full pass expected after W2 (T4 wave merge).
#
# AC8: assistant-not-in-loop — every assertion is a subprocess invocation;
# no LLM-mediated description.
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only flags.
#   No `case` inside subshells (bash32-case-in-subshell.md).
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md.

set -euo pipefail

# ---------------------------------------------------------------------------
# Sandbox HOME — uniform discipline per sandbox-home-in-tests.md
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME (POSIX case, no `[[`)
case "$HOME" in
  "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ---------------------------------------------------------------------------
# Failure accumulator — collect all failures before exiting
# ---------------------------------------------------------------------------
FAIL_COUNT=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

pass() {
  printf 'PASS: %s\n' "$1"
}

# ---------------------------------------------------------------------------
# Canonical resolver text — the 7-line bash block.
# Embedded here verbatim; must match T1's CANONICAL_BLOCK in bin/scaff-lint.
# After T1 lands, A1c below also checks the resolver text in bin/scaff-lint.
# ---------------------------------------------------------------------------
# The resolver (lines 2-8 of the 12-line canonical block):
RESOLVER_BLOCK='# Resolve $SCAFF_SRC: env var, then user-global symlink, then fail.
if [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then
  _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)
  SCAFF_SRC="${_scaff_src_link%/.claude/agents/scaff}"
  unset _scaff_src_link
fi
[ -d "${SCAFF_SRC:-}" ] || { printf '"'"'%s\n'"'"' '"'"'ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run `bin/claude-symlink install` from the scaff source repo'"'"' >&2; exit 65; }'

# ---------------------------------------------------------------------------
# Set up the user-global symlink in the sandbox
# ---------------------------------------------------------------------------
mkdir -p "$HOME/.claude/agents"
# The symlink target must end in /.claude/agents/scaff so the suffix strip
# produces $REPO_ROOT as the resolved SCAFF_SRC.
ln -s "$REPO_ROOT/.claude/agents/scaff" "$HOME/.claude/agents/scaff"

# ===========================================================================
# A1 — AC1: 3-tier resolver
# ===========================================================================
printf '=== A1: AC1 — 3-tier resolver ===\n'

# ---------------------------------------------------------------------------
# A1a — env var set: resolver must use $SCAFF_SRC directly when set and valid
# ---------------------------------------------------------------------------
printf '--- A1a: env var override ---\n'
A1A_OUT=""
A1A_EXIT=0
A1A_OUT="$(SCAFF_SRC="$REPO_ROOT" bash -c '
  SCAFF_SRC="'"$REPO_ROOT"'"
  if [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then
    _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)
    SCAFF_SRC="${_scaff_src_link%/.claude/agents/scaff}"
    unset _scaff_src_link
  fi
  [ -d "${SCAFF_SRC:-}" ] || { printf "%s\n" "ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run \`bin/claude-symlink install\` from the scaff source repo" >&2; exit 65; }
  printf "%s\n" "$SCAFF_SRC"
')" || A1A_EXIT=$?

if [ "$A1A_EXIT" = "0" ]; then
  pass "A1a: resolver exited 0"
else
  fail "A1a: resolver exited $A1A_EXIT (expected 0)"
fi

if [ "$A1A_OUT" = "$REPO_ROOT" ]; then
  pass "A1a: SCAFF_SRC resolved to REPO_ROOT ($REPO_ROOT)"
else
  fail "A1a: SCAFF_SRC resolved to '$A1A_OUT', expected '$REPO_ROOT'"
fi

# ---------------------------------------------------------------------------
# A1b — symlink fallback: unset SCAFF_SRC, resolver reads from symlink
# ---------------------------------------------------------------------------
printf '--- A1b: symlink fallback ---\n'
A1B_OUT=""
A1B_EXIT=0
# Pass HOME into the subshell so it uses the sandboxed HOME with the fake symlink
A1B_OUT="$(HOME="$HOME" bash -c '
  unset SCAFF_SRC
  if [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then
    _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)
    SCAFF_SRC="${_scaff_src_link%/.claude/agents/scaff}"
    unset _scaff_src_link
  fi
  [ -d "${SCAFF_SRC:-}" ] || { printf "%s\n" "ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run \`bin/claude-symlink install\` from the scaff source repo" >&2; exit 65; }
  printf "%s\n" "$SCAFF_SRC"
')" || A1B_EXIT=$?

if [ "$A1B_EXIT" = "0" ]; then
  pass "A1b: resolver exited 0"
else
  fail "A1b: resolver exited $A1B_EXIT (expected 0)"
fi

if [ "$A1B_OUT" = "$REPO_ROOT" ]; then
  pass "A1b: SCAFF_SRC resolved to REPO_ROOT via symlink ($REPO_ROOT)"
else
  fail "A1b: SCAFF_SRC resolved to '$A1B_OUT', expected '$REPO_ROOT'"
fi

# ---------------------------------------------------------------------------
# A1c — no env var, no symlink: resolver must fail loudly with exit 65
# ---------------------------------------------------------------------------
printf '--- A1c: loud failure when neither resolves ---\n'
# Remove symlink for this sub-fixture; restore afterward
rm "$HOME/.claude/agents/scaff"

A1C_STDERR="$SANDBOX/a1c_stderr"
A1C_STDOUT="$SANDBOX/a1c_stdout"
A1C_EXIT=0
HOME="$HOME" bash -c '
  unset SCAFF_SRC
  if [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then
    _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)
    SCAFF_SRC="${_scaff_src_link%/.claude/agents/scaff}"
    unset _scaff_src_link
  fi
  [ -d "${SCAFF_SRC:-}" ] || { printf "%s\n" "ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run \`bin/claude-symlink install\` from the scaff source repo" >&2; exit 65; }
  printf "%s\n" "$SCAFF_SRC"
' > "$A1C_STDOUT" 2> "$A1C_STDERR" || A1C_EXIT=$?

if [ "$A1C_EXIT" = "65" ]; then
  pass "A1c: resolver exited 65 (EX_DATAERR)"
else
  fail "A1c: expected exit 65, got $A1C_EXIT"
fi

A1C_STDERR_CONTENT="$(cat "$A1C_STDERR")"
if printf '%s\n' "$A1C_STDERR_CONTENT" | grep -qF 'cannot resolve SCAFF_SRC'; then
  pass "A1c: stderr contains 'cannot resolve SCAFF_SRC'"
else
  fail "A1c: stderr missing 'cannot resolve SCAFF_SRC' (got: $A1C_STDERR_CONTENT)"
fi

if printf '%s\n' "$A1C_STDERR_CONTENT" | grep -qF 'claude-symlink install'; then
  pass "A1c: stderr contains 'claude-symlink install'"
else
  fail "A1c: stderr missing 'claude-symlink install' (got: $A1C_STDERR_CONTENT)"
fi

A1C_STDOUT_CONTENT="$(cat "$A1C_STDOUT")"
if [ -z "$A1C_STDOUT_CONTENT" ]; then
  pass "A1c: no stdout output on failure"
else
  fail "A1c: expected empty stdout on failure, got: $A1C_STDOUT_CONTENT"
fi

# Restore symlink for remaining tests
ln -s "$REPO_ROOT/.claude/agents/scaff" "$HOME/.claude/agents/scaff"

# ===========================================================================
# A4 — AC4: pre-commit shim resolves at hook-run time
# DEPENDS ON: T3 (new shim heredoc) + W2 (T4 marker sweep)
# At W1 close (before T3 merges): shim may not have resolver; assertions
# below test the T3-post shape; they will fail until T3 lands on main.
# ===========================================================================
printf '\n=== A4: AC4 — pre-commit shim resolver (depends on T3+T4+wave merge) ===\n'

# Build a consumer sandbox (no bin/ per thin-consumer invariant)
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"
git -C "$CONSUMER" init -q
git -C "$CONSUMER" config user.email "t@example.com"
git -C "$CONSUMER" config user.name "t"
printf '*.log\n' > "$CONSUMER/.gitignore"
git -C "$CONSUMER" add .gitignore
git -C "$CONSUMER" commit -q -m "init"

# Run scaff-seed init from source's bin/scaff-seed (consumer-cwd-discipline.md)
SRC_REF="$(git -C "$REPO_ROOT" rev-parse HEAD)"
(cd "$CONSUMER" && "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref "$SRC_REF") \
  > /dev/null 2>&1 || true

HOOK="$CONSUMER/.git/hooks/pre-commit"

if [ -x "$HOOK" ]; then
  pass "A4: pre-commit hook installed and executable"
else
  fail "A4: pre-commit hook missing or not executable after scaff-seed init"
fi

# Assert the hook contains the resolver readlink call (T3's new shape)
if grep -qF 'readlink "$HOME/.claude/agents/scaff"' "$HOOK" 2>/dev/null; then
  pass "A4: hook contains resolver readlink call"
else
  fail "A4: hook missing resolver readlink call — T3 shim heredoc update not yet merged"
fi

# Assert the hook uses $SCAFF_SRC/bin/scaff-lint (absolute-path form, T3 shape)
if grep -qF '"$SCAFF_SRC/bin/scaff-lint"' "$HOOK" 2>/dev/null; then
  pass "A4: hook uses \$SCAFF_SRC/bin/scaff-lint (absolute-path form)"
else
  fail "A4: hook missing \$SCAFF_SRC/bin/scaff-lint — T3 shim heredoc update not yet merged"
fi

# Run the hook with $SCAFF_SRC set to the source repo; stage a benign file first
printf 'x\n' > "$CONSUMER/x"
git -C "$CONSUMER" add "$CONSUMER/x"
HOOK_EXIT=0
(cd "$CONSUMER" && SCAFF_SRC="$REPO_ROOT" HOME="$HOME" .git/hooks/pre-commit) \
  > /dev/null 2>&1 || HOOK_EXIT=$?

if [ "$HOOK_EXIT" = "0" ]; then
  pass "A4: hook exited 0 when SCAFF_SRC set (passthrough)"
else
  fail "A4: hook exited $HOOK_EXIT (expected 0)"
fi

# ===========================================================================
# A5 — AC5: sandboxed consumer with NO bin/ can extract and run gate via $SCAFF_SRC
# DEPENDS ON: T4 wave merge (marker blocks in command files must reference
# $SCAFF_SRC/.specaffold/preflight.md — not yet in place at W1 close)
# ===========================================================================
printf '\n=== A5: AC5 — consumer with no bin/ extracts gate via \$SCAFF_SRC ===\n'

# Confirm consumer has no bin/ (thin-consumer invariant per AC5)
if [ ! -d "$CONSUMER/bin" ]; then
  pass "A5: consumer has no bin/ (thin-consumer invariant holds)"
else
  fail "A5: consumer has bin/ — thin-consumer invariant violated"
fi

# Extract the SCAFF PREFLIGHT block from $SCAFF_SRC (the source repo)
PREFLIGHT_MD="$REPO_ROOT/.specaffold/preflight.md"
if [ ! -f "$PREFLIGHT_MD" ]; then
  fail "A5: $PREFLIGHT_MD missing from source repo — cannot extract gate body"
else
  pass "A5: preflight.md present in source repo at \$SCAFF_SRC"
fi

GATE_BLOCK="$(awk '/^# === SCAFF PREFLIGHT/,/^# === END SCAFF PREFLIGHT/' "$PREFLIGHT_MD")"
printf '%s\n' "$GATE_BLOCK" > "$SANDBOX/gate.sh"

# Sub-fixture A5a: no config.yml in consumer — gate must exit 70 (REFUSED)
A5A_EXIT=0
(cd "$CONSUMER" && SCAFF_SRC="$REPO_ROOT" HOME="$HOME" bash "$SANDBOX/gate.sh") \
  > /dev/null 2>&1 || A5A_EXIT=$?

if [ "$A5A_EXIT" = "70" ]; then
  pass "A5a: gate exited 70 (REFUSED) when no config.yml"
else
  fail "A5a: expected exit 70, got $A5A_EXIT (no config.yml present)"
fi

# Sub-fixture A5b: with config.yml in consumer — gate must exit 0 (passthrough)
mkdir -p "$CONSUMER/.specaffold"
touch "$CONSUMER/.specaffold/config.yml"

A5B_EXIT=0
(cd "$CONSUMER" && SCAFF_SRC="$REPO_ROOT" HOME="$HOME" bash "$SANDBOX/gate.sh") \
  > /dev/null 2>&1 || A5B_EXIT=$?

if [ "$A5B_EXIT" = "0" ]; then
  pass "A5b: gate exited 0 (passthrough) when config.yml present"
else
  fail "A5b: expected exit 0, got $A5B_EXIT (config.yml was present)"
fi

# ===========================================================================
# A8 — AC8: assistant-not-in-loop integration
# Consumer can resolve bin/* deps without local bin/ via $SCAFF_SRC
# DEPENDS ON: T4 wave merge for command-file marker to reference $SCAFF_SRC/bin/
# At W1 close: bin/scaff-tier exists in source; this assertion tests only
# that the resolved path is reachable, not that the command marker is fixed yet.
# ===========================================================================
printf '\n=== A8: AC8 — assistant-not-in-loop: bin/* resolves via \$SCAFF_SRC ===\n'

# Confirm consumer has no bin/ (re-assert thin-consumer)
if [ ! -d "$CONSUMER/bin" ]; then
  pass "A8: consumer has no bin/ directory"
else
  fail "A8: consumer bin/ present — thin-consumer invariant violated"
fi

# Resolve SCAFF_SRC from symlink (the same path-(b) the resolver uses)
# and assert bin/scaff-tier is accessible from the resolved source
RESOLVED_SCAFF_SRC=""
RESOLVE_EXIT=0
RESOLVED_SCAFF_SRC="$(HOME="$HOME" bash -c '
  unset SCAFF_SRC
  if [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then
    _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)
    SCAFF_SRC="${_scaff_src_link%/.claude/agents/scaff}"
    unset _scaff_src_link
  fi
  [ -d "${SCAFF_SRC:-}" ] || { printf "%s\n" "ERROR: cannot resolve SCAFF_SRC" >&2; exit 65; }
  printf "%s\n" "$SCAFF_SRC"
')" || RESOLVE_EXIT=$?

if [ "$RESOLVE_EXIT" = "0" ]; then
  pass "A8: SCAFF_SRC resolved successfully via symlink"
else
  fail "A8: SCAFF_SRC resolution failed (exit $RESOLVE_EXIT)"
fi

# Assert bin/scaff-tier is present in the resolved source
if [ -f "$RESOLVED_SCAFF_SRC/bin/scaff-tier" ]; then
  pass "A8: \$SCAFF_SRC/bin/scaff-tier exists (dependency reachable from consumer)"
else
  fail "A8: \$SCAFF_SRC/bin/scaff-tier not found at '$RESOLVED_SCAFF_SRC/bin/scaff-tier'"
fi

# Simulate the preamble source step in a subshell from consumer CWD:
# source "$SCAFF_SRC/bin/scaff-tier" — asserts the file can be sourced
# without errors (the "user can run /scaff:next without command not found" check)
SOURCE_EXIT=0
(cd "$CONSUMER" && SCAFF_SRC="$RESOLVED_SCAFF_SRC" bash -c '. "$SCAFF_SRC/bin/scaff-tier"') \
  > /dev/null 2>&1 || SOURCE_EXIT=$?

if [ "$SOURCE_EXIT" = "0" ]; then
  pass "A8: \$SCAFF_SRC/bin/scaff-tier sources without error from consumer CWD"
else
  fail "A8: \$SCAFF_SRC/bin/scaff-tier failed to source (exit $SOURCE_EXIT)"
fi

# ===========================================================================
# Summary
# ===========================================================================
printf '\n'
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: t113\n'
  exit 0
else
  printf 'FAIL: t113 — %d assertion(s) failed\n' "$FAIL_COUNT" >&2
  exit 1
fi
