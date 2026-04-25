#!/usr/bin/env bash
# test/t107_preflight_lint_and_body.sh
#
# T3 — Structural test: gate body (.specaffold/preflight.md) + lint subcommand
#      (bin/scaff-lint preflight-coverage) negative-path check.
#
# Assertions:
#   A1 — .specaffold/preflight.md exists and carries the open/close sentinels
#        plus required tokens (REFUSED:PREFLIGHT, /scaff-init, .specaffold/config.yml)
#        between them.
#   A2 — The fenced shell block extracted from preflight.md passes bash -n
#        (syntax check) and, when smoke-run from a fixture directory that has no
#        .specaffold/config.yml, exits 70 and prints REFUSED:PREFLIGHT.
#   A3 — Ternary lint state (see comment block below):
#        0 markers   → exit 1 + total_count missing-marker: lines (W1-close state)
#        18 markers  → exit 0 + total_count ok: lines         (post-W3 state)
#        1-17 markers → FAIL — lint mid-state is a planning bug
#
# Ternary assertion rationale (A3):
#   At W1 close no command file carries '<!-- preflight: required -->'; the lint
#   must report all 18 as missing-marker: and exit 1.  After W3 merges all 18
#   files carry the marker; the lint exits 0 with 18 ok: lines.  Checking a
#   live marker count lets this test auto-adapt: it runs green at W1 close
#   (negative state) and continues to run green after W3 (positive state).
#   Any intermediate count (1-17) is a planning bug because §4 requires markers
#   to land atomically in one bulk commit (T6).
#
#   At W1 close: 18 missing-marker lines, exit 1.  After W3 merges: 18 ok lines,
#   exit 0.  The ternary auto-adapts.
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only flags.
#   No `case` inside subshells (bash32-case-in-subshell.md).
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md:
#   applied uniformly even though the test is primarily read-only.

set -euo pipefail

# ---------------------------------------------------------------------------
# Sandbox HOME — uniform discipline per sandbox-home-in-tests.md
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

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
cd "$REPO_ROOT"

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
# A1 — Gate body presence + sentinels + required tokens
# ---------------------------------------------------------------------------
printf '=== A1: .specaffold/preflight.md existence + sentinels + tokens ===\n'

PREFLIGHT_MD="$REPO_ROOT/.specaffold/preflight.md"

if [ ! -f "$PREFLIGHT_MD" ]; then
  fail "A1: .specaffold/preflight.md not found (T1 has not merged yet)"
  # Cannot continue A1/A2 checks without the file
  printf 'SKIP: A2 skipped — preflight.md absent\n' >&2
else
  pass "A1: .specaffold/preflight.md exists"

  # Open sentinel
  if grep -qF '# === SCAFF PREFLIGHT — DO NOT INLINE OR DUPLICATE ===' "$PREFLIGHT_MD"; then
    pass "A1: open sentinel present"
  else
    fail "A1: open sentinel '# === SCAFF PREFLIGHT — DO NOT INLINE OR DUPLICATE ===' not found in preflight.md"
  fi

  # Close sentinel
  if grep -qF '# === END SCAFF PREFLIGHT ===' "$PREFLIGHT_MD"; then
    pass "A1: close sentinel present"
  else
    fail "A1: close sentinel '# === END SCAFF PREFLIGHT ===' not found in preflight.md"
  fi

  # Extract the block between sentinels and check required tokens
  BLOCK="$(awk '/^# === SCAFF PREFLIGHT/,/^# === END SCAFF PREFLIGHT/' "$PREFLIGHT_MD")"

  if printf '%s\n' "$BLOCK" | grep -qF 'REFUSED:PREFLIGHT'; then
    pass "A1: block contains token REFUSED:PREFLIGHT"
  else
    fail "A1: block does not contain token REFUSED:PREFLIGHT"
  fi

  if printf '%s\n' "$BLOCK" | grep -qF '.specaffold/config.yml'; then
    pass "A1: block contains token .specaffold/config.yml"
  else
    fail "A1: block does not contain token .specaffold/config.yml"
  fi

  if printf '%s\n' "$BLOCK" | grep -qF '/scaff-init'; then
    pass "A1: block contains token /scaff-init"
  else
    fail "A1: block does not contain token /scaff-init"
  fi

  # ---------------------------------------------------------------------------
  # A2 — Extracted-block syntax check + smoke-run
  # ---------------------------------------------------------------------------
  printf '\n=== A2: extracted shell block syntax check + smoke-run ===\n'

  printf '%s\n' "$BLOCK" > "$SANDBOX/extracted.sh"

  # Syntax check
  if bash -n "$SANDBOX/extracted.sh"; then
    pass "A2: extracted block passes bash -n syntax check"
  else
    fail "A2: extracted block has bash syntax errors"
  fi

  # Smoke-run: run the block from a temp dir that has no .specaffold/config.yml
  # Expect exit code 70 and output containing REFUSED:PREFLIGHT
  mkdir -p "$SANDBOX/run-fixture"
  SMOKE_OUTPUT="$(cd "$SANDBOX/run-fixture" && bash "$SANDBOX/extracted.sh" 2>&1)" \
    && SMOKE_EXIT=0 || SMOKE_EXIT=$?

  if [ "$SMOKE_EXIT" = "70" ]; then
    pass "A2: smoke-run exits 70 (refusal exit code)"
  else
    fail "A2: smoke-run expected exit 70, got exit $SMOKE_EXIT"
  fi

  if printf '%s\n' "$SMOKE_OUTPUT" | grep -qF 'REFUSED:PREFLIGHT'; then
    pass "A2: smoke-run output contains REFUSED:PREFLIGHT"
  else
    fail "A2: smoke-run output does not contain REFUSED:PREFLIGHT (output: $(printf '%s' "$SMOKE_OUTPUT" | head -5))"
  fi
fi

# ---------------------------------------------------------------------------
# A3 — Ternary lint state
# ---------------------------------------------------------------------------
printf '\n=== A3: ternary lint state (0-markers W1 / 18-markers post-W3 / mid = bug) ===\n'

LINT_BIN="$REPO_ROOT/bin/scaff-lint"

if [ ! -x "$LINT_BIN" ]; then
  fail "A3: bin/scaff-lint not executable or not found (T2 has not merged yet)"
else
  # Count how many command files currently carry the marker.
  # grep -lF exits 1 when no files match — capture with `|| true` so set -e/pipefail
  # don't abort the test in the W1-close state (zero markers = expected, not error).
  marker_count=0
  if ls "$REPO_ROOT/.claude/commands/scaff/"*.md > /dev/null 2>&1; then
    matched_files="$(grep -lF '<!-- preflight: required -->' \
      "$REPO_ROOT/.claude/commands/scaff/"*.md 2>/dev/null || true)"
    if [ -n "$matched_files" ]; then
      marker_count="$(printf '%s\n' "$matched_files" | grep -c '^' | tr -d ' ')"
    fi
  fi

  # Count total command files
  total_count=0
  if ls "$REPO_ROOT/.claude/commands/scaff/"*.md > /dev/null 2>&1; then
    total_count="$(ls "$REPO_ROOT/.claude/commands/scaff/"*.md 2>/dev/null \
      | wc -l | tr -d ' ')"
  fi

  # Run lint, capture output and exit code
  LINT_OUTPUT="$("$LINT_BIN" preflight-coverage 2>&1)" && LINT_EXIT=0 || LINT_EXIT=$?

  if [ "$marker_count" = "0" ]; then
    # W1-close state: all markers missing — lint must exit 1 with total_count missing-marker: lines
    if [ "$LINT_EXIT" = "1" ]; then
      pass "A3[W1-close]: bin/scaff-lint preflight-coverage exits 1 (no markers present)"
    else
      fail "A3[W1-close]: expected exit 1 (no markers), got exit $LINT_EXIT"
    fi

    # Assert stdout has total_count lines
    LINT_LINE_COUNT="$(printf '%s\n' "$LINT_OUTPUT" | grep -c '' || true)"
    if [ "$LINT_LINE_COUNT" = "$total_count" ]; then
      pass "A3[W1-close]: lint output has $LINT_LINE_COUNT lines (matches total_count=$total_count)"
    else
      fail "A3[W1-close]: lint output has $LINT_LINE_COUNT lines, expected $total_count"
    fi

    # Assert every line starts with missing-marker:
    BAD_LINES="$(printf '%s\n' "$LINT_OUTPUT" | grep -v '^missing-marker:' || true)"
    if [ -z "$BAD_LINES" ]; then
      pass "A3[W1-close]: every lint output line starts with missing-marker:"
    else
      fail "A3[W1-close]: some lint output lines do not start with missing-marker: — $(printf '%s' "$BAD_LINES" | head -3)"
    fi

  elif [ "$marker_count" = "$total_count" ]; then
    # Post-W3 state: all markers present — lint must exit 0 with total_count ok: lines
    if [ "$LINT_EXIT" = "0" ]; then
      pass "A3[post-W3]: bin/scaff-lint preflight-coverage exits 0 (all markers present)"
    else
      fail "A3[post-W3]: expected exit 0 (all markers present), got exit $LINT_EXIT"
    fi

    # Assert stdout has total_count lines
    LINT_LINE_COUNT="$(printf '%s\n' "$LINT_OUTPUT" | grep -c '' || true)"
    if [ "$LINT_LINE_COUNT" = "$total_count" ]; then
      pass "A3[post-W3]: lint output has $LINT_LINE_COUNT lines (matches total_count=$total_count)"
    else
      fail "A3[post-W3]: lint output has $LINT_LINE_COUNT lines, expected $total_count"
    fi

    # Assert every line starts with ok:
    BAD_LINES="$(printf '%s\n' "$LINT_OUTPUT" | grep -v '^ok:' || true)"
    if [ -z "$BAD_LINES" ]; then
      pass "A3[post-W3]: every lint output line starts with ok:"
    else
      fail "A3[post-W3]: some lint output lines do not start with ok: — $(printf '%s' "$BAD_LINES" | head -3)"
    fi

  else
    # Intermediate state — planning bug: §4 requires markers to land atomically in T6
    fail "A3: lint mid-state: marker_count=$marker_count / total=$total_count — planning bug per plan §4 atomicity. Markers must land atomically in one bulk commit (T6); partial state means the wave-merge violated the plan's atomicity constraint."
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: t107\n'
  exit 0
else
  printf 'FAIL: t107 — %d assertion(s) failed\n' "$FAIL_COUNT" >&2
  exit 1
fi
