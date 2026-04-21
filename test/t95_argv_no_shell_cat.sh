#!/usr/bin/env bash
# test/t95_argv_no_shell_cat.sh
#
# T115 — Seam I: no-shell-string-cat grep assertions
#
# Two assertions against flow-monitor/src-tauri/src/**/*.rs:
#
#   A. No Command::new("sh") / Command::new("/bin/sh") / exec("sh …) —
#      any match means a Rust caller is spawning a shell interpreter,
#      bypassing argv-form invocation.  Zero matches expected.
#
#   B. No .arg("-c") — any match means a Rust caller is passing a shell
#      command string via -c, which enables injection.  Zero matches expected.
#
# Vacuous-pass behaviour:
#   After W1 T93 retry, src-tauri/src contains no shell-string-cat patterns.
#   The assertions pass vacuously (0 matches = 0 violations).  These tests
#   act as ratchet guards: they FAIL if any future commit re-introduces the
#   pattern.
#
# Sandbox-HOME NOT required: this script only runs grep against the repo
# working tree and never invokes any CLI that expands or writes $HOME.
# (bash/sandbox-home-in-tests.md — explicitly exempt for read-only repo
# traversal scripts.)
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only
#   flags, no `case` inside subshells (bash32-case-in-subshell.md).
set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

SRC_DIR="$REPO_ROOT/flow-monitor/src-tauri/src"

# ---------------------------------------------------------------------------
# Preflight — src-tauri/src directory must exist
# ---------------------------------------------------------------------------
if [ ! -d "$SRC_DIR" ]; then
  printf 'SKIP: %s not found — src-tauri not present; re-run after scaffold.\n' \
    "$SRC_DIR" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Test harness helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# A. No shell-interpreter spawn
#
# Pattern catches:
#   Command::new("sh")       — direct sh invocation
#   Command::new("/bin/sh")  — absolute-path sh invocation
#   exec("sh               — exec-form sh invocation (trailing space catches
#                             exec("sh ", …) before quote closes)
#
# grep || true: suppress exit 1 when there are zero matches so that
# set -o pipefail / no set -e does not abort on a vacuous-pass result.
# ---------------------------------------------------------------------------
printf '=== A: no Command::new("sh") / exec("sh …) in src-tauri/src ===\n'

SHELL_SPAWN_MATCHES="$(grep -rE \
  'Command::new\("sh"|Command::new\("/bin/sh"|exec\("sh ' \
  "$SRC_DIR" 2>/dev/null || true)"

if [ -z "$SHELL_SPAWN_MATCHES" ]; then
  pass "A: no shell-interpreter spawn found in src-tauri/src — Seam I clean"
else
  printf '%s\n' "$SHELL_SPAWN_MATCHES" >&2
  fail "A: shell-interpreter spawn found — remove Command::new(\"sh\") patterns above"
fi

# ---------------------------------------------------------------------------
# B. No .arg("-c") — shell -c string injection vector
#
# Any .arg("-c") in Rust src means a caller is passing a shell command
# string to a spawned process, opening an injection surface.
# ---------------------------------------------------------------------------
printf '\n=== B: no .arg("-c") in src-tauri/src ===\n'

ARG_C_MATCHES="$(grep -rE '\.arg\("-c"\)' \
  "$SRC_DIR" 2>/dev/null || true)"

if [ -z "$ARG_C_MATCHES" ]; then
  pass "B: no .arg(\"-c\") found in src-tauri/src — Seam I clean"
else
  printf '%s\n' "$ARG_C_MATCHES" >&2
  fail "B: .arg(\"-c\") found — remove shell-string-cat invocations above"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
