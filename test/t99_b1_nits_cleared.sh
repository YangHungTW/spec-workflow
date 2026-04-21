#!/usr/bin/env bash
# test/t99_b1_nits_cleared.sh
#
# T119 — Seam M B1 retrospective: verify all five nit-sweep outcomes from
# T114 are present in the working tree.
#
# Five assertions:
#
#   A. ipc.rs line-length: no line exceeds 100 characters.
#
#   B. WHAT-comments removed from ipc.rs: pattern-grep for one-word WHAT
#      comments returns zero matches.
#
#   C. navigatedPaths unused-state removed: no matches in production
#      .ts/.tsx files under flow-monitor/src/ (excluding __tests__/).
#
#   D. markdown.footer dead key removed: grep for "markdown.footer" in
#      en.json and zh-TW.json returns zero matches.
#
#   E. Non-BEM classes handled: for each of the six classes listed in T114
#      (settings-section-title, settings-radio-label, settings-toggle-label,
#      btn-add-repo, repo-list, repo-item) — either the class is absent from
#      all CSS selectors, OR a keep-with-justification comment that names the
#      class exists somewhere in the CSS file. A single grouped comment (as
#      T114 authored for btn-add-repo / repo-list / repo-item) satisfies the
#      condition because the comment explicitly names each class.
#
# Sandbox-HOME NOT required: this test only runs read-only operations against
# the repo working tree and never invokes any CLI that expands or writes $HOME.
# (bash/sandbox-home-in-tests.md — explicitly exempt for read-only repo
# traversal scripts.)
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only
#   flags.  No `case` inside subshells (bash32-case-in-subshell.md).
set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

IPC_RS="$REPO_ROOT/flow-monitor/src-tauri/src/ipc.rs"
SRC_DIR="$REPO_ROOT/flow-monitor/src"
EN_JSON="$SRC_DIR/i18n/en.json"
ZH_JSON="$SRC_DIR/i18n/zh-TW.json"
COMPONENTS_CSS="$SRC_DIR/styles/components.css"

# ---------------------------------------------------------------------------
# Preflight — required files must exist
# ---------------------------------------------------------------------------
for f in "$IPC_RS" "$EN_JSON" "$ZH_JSON" "$COMPONENTS_CSS"; do
  if [ ! -f "$f" ]; then
    printf 'SKIP: %s not found — flow-monitor artefact missing; re-run after build.\n' \
      "$f" >&2
    exit 0
  fi
done

if [ ! -d "$SRC_DIR" ]; then
  printf 'SKIP: %s not found — flow-monitor not present; re-run after app scaffold.\n' \
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
# A. ipc.rs line-length: no line longer than 100 chars
# ---------------------------------------------------------------------------
printf '=== A: ipc.rs line-length (max 100 chars) ===\n'

LONG_LINES="$(awk 'length>100' "$IPC_RS" | wc -l | tr -d ' ')"

if [ "$LONG_LINES" -eq 0 ]; then
  pass "A: ipc.rs has no lines over 100 characters"
else
  printf 'FAIL A: %s line(s) in ipc.rs exceed 100 characters:\n' "$LONG_LINES" >&2
  awk 'length>100 { printf "  line %d (%d chars): %s\n", NR, length, $0 }' "$IPC_RS" >&2
  fail "A: ipc.rs line-length violation — $LONG_LINES over-100-char line(s) remain"
fi

# ---------------------------------------------------------------------------
# B. WHAT-comments removed from ipc.rs
#
# Pattern: a comment whose entire content is a single imperative verb followed
# by an identifier — e.g. "// set flag", "// emit event", "// close window".
# Tolerate false-positive misses; the core assertion is that the four specific
# WHAT-comments T114 targeted are gone.
# ---------------------------------------------------------------------------
printf '\n=== B: WHAT-comments removed from ipc.rs ===\n'

WHAT_COUNT="$(grep -cE '^\s*//\s*(increment|decrement|set|assign|update|apply|create|close|emit) [a-zA-Z]+\.?$' \
  "$IPC_RS" 2>/dev/null || true)"

if [ "$WHAT_COUNT" -eq 0 ]; then
  pass "B: no WHAT-comments found in ipc.rs"
else
  printf 'FAIL B: %s WHAT-comment(s) found in ipc.rs:\n' "$WHAT_COUNT" >&2
  grep -nE '^\s*//\s*(increment|decrement|set|assign|update|apply|create|close|emit) [a-zA-Z]+\.?$' \
    "$IPC_RS" >&2
  fail "B: WHAT-comments still present in ipc.rs — $WHAT_COUNT match(es)"
fi

# ---------------------------------------------------------------------------
# C. navigatedPaths unused-state removed from production TypeScript files
#
# Production files: .ts and .tsx under $SRC_DIR, excluding __tests__/ dirs.
# Test-local variables in __tests__/ are acceptable.
# ---------------------------------------------------------------------------
printf '\n=== C: navigatedPaths absent from production TypeScript files ===\n'

# Collect matching lines from production files only.
# We search then filter out any line whose path contains __tests__.
NAV_MATCHES="$(grep -rn 'navigatedPaths' "$SRC_DIR" \
  --include='*.ts' --include='*.tsx' 2>/dev/null || true)"

# Filter to production-only matches (exclude __tests__ directory paths).
NAV_PROD_MATCHES=""
if [ -n "$NAV_MATCHES" ]; then
  while IFS= read -r line; do
    filepath="${line%%:*}"
    # Check whether the path contains __tests__ segment.
    # POSIX parameter expansion — no sed/awk subprocess.
    case "$filepath" in
      */__tests__/*) ;;  # skip test files
      *) NAV_PROD_MATCHES="$NAV_PROD_MATCHES$line
";;
    esac
  done <<EOF
$NAV_MATCHES
EOF
fi

# Strip trailing newline from accumulator.
NAV_PROD_MATCHES="${NAV_PROD_MATCHES%
}"

if [ -z "$NAV_PROD_MATCHES" ]; then
  pass "C: navigatedPaths not present in production TypeScript files"
else
  printf 'FAIL C: navigatedPaths found in production file(s):\n' >&2
  printf '%s\n' "$NAV_PROD_MATCHES" >&2
  fail "C: navigatedPaths still referenced in production code"
fi

# ---------------------------------------------------------------------------
# D. markdown.footer dead key removed from i18n files
# ---------------------------------------------------------------------------
printf '\n=== D: markdown.footer key removed from i18n files ===\n'

FOOTER_MATCHES="$(grep -nE '"markdown\.footer"' "$EN_JSON" "$ZH_JSON" 2>/dev/null || true)"

if [ -z "$FOOTER_MATCHES" ]; then
  pass "D: \"markdown.footer\" key is absent from en.json and zh-TW.json"
else
  printf 'FAIL D: "markdown.footer" key still present:\n' >&2
  printf '%s\n' "$FOOTER_MATCHES" >&2
  fail "D: dead \"markdown.footer\" key was not removed"
fi

# ---------------------------------------------------------------------------
# E. Non-BEM classes handled (keep-with-justification OR absent)
#
# Six classes from T114's B1 nits sweep:
#   settings-section-title, settings-radio-label, settings-toggle-label,
#   btn-add-repo, repo-list, repo-item
#
# For each class: pass if either
#   (a) the class name does not appear as a CSS selector in the file, OR
#   (b) the file contains a keep-with-justification comment that names the
#       class on the same line (a grouped comment explicitly listing the
#       class name satisfies this condition regardless of line distance to
#       the selector).
#
# This correctly handles T114's grouped comment for btn-add-repo / repo-list
# / repo-item, which mentions all three classes on line 1151 before
# .btn-add-repo (line 1154), .repo-list (line 1174), and .repo-item (line
# 1182).  The ±3-line heuristic would miss .repo-list and .repo-item; the
# named-in-comment check is the canonical one.
# ---------------------------------------------------------------------------
printf '\n=== E: Non-BEM classes have keep-with-justification or are absent ===\n'

BEM_CLASSES="settings-section-title settings-radio-label settings-toggle-label btn-add-repo repo-list repo-item"

E_FAIL=0
for cls in $BEM_CLASSES; do
  # Check whether the class appears as a CSS selector (pattern: .classname followed
  # by whitespace, { or pseudo-selector colon — not just inside a comment).
  SELECTOR_MATCH="$(grep -nE "^\s*\.${cls}(\s|\{|:)" "$COMPONENTS_CSS" 2>/dev/null || true)"

  if [ -z "$SELECTOR_MATCH" ]; then
    pass "E[$cls]: class absent from CSS selectors"
    continue
  fi

  # Class exists as a selector — check for a keep-with-justification comment
  # anywhere in the file that names this class on the same line.
  KWJ_MATCH="$(grep -n 'keep-with-justification' "$COMPONENTS_CSS" 2>/dev/null \
    | grep "\b${cls}\b" || true)"

  if [ -n "$KWJ_MATCH" ]; then
    pass "E[$cls]: class present in CSS with keep-with-justification comment"
  else
    printf 'FAIL E[%s]: class appears as CSS selector but has no keep-with-justification comment:\n' \
      "$cls" >&2
    printf '  selector: %s\n' "$SELECTOR_MATCH" >&2
    fail "E[$cls]: non-BEM class without justification comment"
    E_FAIL=$((E_FAIL + 1))
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
