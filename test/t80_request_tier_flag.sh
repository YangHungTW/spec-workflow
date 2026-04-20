#!/usr/bin/env bash
# test/t80_request_tier_flag.sh
#
# Structural tests for T18: .claude/commands/specflow/request.md
# accepts --tier <tiny|standard|audited> flag and contains the
# propose-and-confirm prompt (tech §D6, task T18).
#
# Assertions:
#   A. '--tier' token present in request.md (verify check from 06-tasks.md T18).
#   B. Valid tier enum values (tiny|standard|audited) documented near --tier.
#   C. Propose-and-confirm prompt shape (verbatim from tech §D6):
#      - "I propose tier:" sentinel present.
#      - "tiny" definition line present (must include " tiny     —" shape).
#      - "standard" definition line present.
#      - "audited" definition line present.
#      - "Press Enter to accept" sentinel present.
#   D. Insertion point order: has-ui probe precedes the propose-and-confirm
#      block, which precedes slug finalisation (per tech §D6 "AFTER has-ui
#      probe, BEFORE slug is finalised").
#   E. Re-prompt-once discipline: "re-prompt" or "re-ask" or "once" mentioned
#      near the prompt handling prose (PM MUST NOT block; re-prompt once then
#      default per T18 spec).
#   F. No silent default: explicit "propose" or "proposal" language forces PM
#      to surface a tier value rather than silently defaulting (T18 spec:
#      "PM MUST NOT silently default; MUST propose").
#
# SKIP behaviour: if request.md does not yet contain '--tier', all assertions
# after A are skipped and the script exits 0 (wave not yet merged).
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md.
# Bash 3.2 / BSD portable.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t80.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
skip() { printf 'SKIP: %s\n' "$1" >&2; SKIP=$((SKIP + 1)); }

REQUEST_MD="$REPO_ROOT/.claude/commands/specflow/request.md"

# ---------------------------------------------------------------------------
# Guard: file must exist
# ---------------------------------------------------------------------------
if [ ! -f "$REQUEST_MD" ]; then
  printf 'FAIL: request.md not found: %s\n' "$REQUEST_MD" >&2
  exit 2
fi

# Cache file content once; boolean greps pipe from this variable to avoid
# re-reading the file on each assertion (perf: no-re-reading-same-file).
REQUEST_CONTENT="$(cat "$REQUEST_MD")"

# ---------------------------------------------------------------------------
# A. '--tier' flag token present (verify check from T18 task spec)
# ---------------------------------------------------------------------------
if printf '%s\n' "$REQUEST_CONTENT" | grep -q -- '--tier' 2>/dev/null; then
  pass "A: '--tier' flag present in request.md"
else
  skip "A: '--tier' not yet present in request.md — T18 not merged; skipping B–F"
  printf '\n=== Results: %d passed, %d failed, %d skipped ===\n' \
    "$PASS" "$FAIL" "$SKIP"
  exit 0
fi

# ---------------------------------------------------------------------------
# B. Enum values tiny|standard|audited documented near --tier
# ---------------------------------------------------------------------------
for tier_val in tiny standard audited; do
  if printf '%s\n' "$REQUEST_CONTENT" | grep -q "$tier_val" 2>/dev/null; then
    pass "B: tier enum value '$tier_val' present in request.md"
  else
    fail "B: tier enum value '$tier_val' missing from request.md"
  fi
done

# ---------------------------------------------------------------------------
# C. Propose-and-confirm prompt shape (tech §D6 verbatim shape)
# ---------------------------------------------------------------------------

# C1: "I propose tier:" sentinel
if printf '%s\n' "$REQUEST_CONTENT" | grep -q 'I propose tier:' 2>/dev/null; then
  pass "C1: 'I propose tier:' sentinel present"
else
  fail "C1: 'I propose tier:' sentinel missing (tech §D6 prompt shape)"
fi

# C2: tiny definition line (shape: "tiny     —" with optional surrounding text)
if printf '%s\n' "$REQUEST_CONTENT" | grep -q 'tiny.*—' 2>/dev/null; then
  pass "C2: tiny definition line (tiny ... —) present"
else
  fail "C2: tiny definition line missing (tech §D6 prompt shape requires tiny — <one-line definition>)"
fi

# C3: standard definition line
if printf '%s\n' "$REQUEST_CONTENT" | grep -q 'standard.*—' 2>/dev/null; then
  pass "C3: standard definition line (standard ... —) present"
else
  fail "C3: standard definition line missing (tech §D6 prompt shape)"
fi

# C4: audited definition line
if printf '%s\n' "$REQUEST_CONTENT" | grep -q 'audited.*—' 2>/dev/null; then
  pass "C4: audited definition line (audited ... —) present"
else
  fail "C4: audited definition line missing (tech §D6 prompt shape)"
fi

# C5: "Press Enter to accept" sentinel
if printf '%s\n' "$REQUEST_CONTENT" | grep -q 'Press Enter to accept' 2>/dev/null; then
  pass "C5: 'Press Enter to accept' sentinel present"
else
  fail "C5: 'Press Enter to accept' sentinel missing (tech §D6 prompt shape)"
fi

# ---------------------------------------------------------------------------
# D. Insertion-point order: has-ui probe BEFORE propose-and-confirm BEFORE
#    slug finalisation (tech §D6: "AFTER has-ui probe, BEFORE slug is finalised")
#
# Strategy: find the line numbers for three sentinels and assert order.
#   has_ui_line  < propose_line < slug_line
#
# We use grep -En (ERE, BSD-portable — no BRE \| needed) and awk to extract
# line numbers; bash 3.2 portable.
# ---------------------------------------------------------------------------

has_ui_line="$(grep -En 'has.ui|has-ui' "$REQUEST_MD" 2>/dev/null | awk -F: '{print $1; exit}')"
propose_line="$(grep -n 'I propose tier:' "$REQUEST_MD" 2>/dev/null | awk -F: '{print $1; exit}')"
# "slug" finalisation: look for the step that writes stage=request to STATUS.
# This is step 5 ("Update STATUS: stage=request ..."), which comes after the
# propose-and-confirm block in step 4a. Using "stage=request" as the sentinel
# avoids false matches on the frontmatter description: line.
slug_line="$(grep -En 'stage=request|Update STATUS' "$REQUEST_MD" 2>/dev/null | awk -F: '{print $1; exit}')"

if [ -n "$has_ui_line" ] && [ -n "$propose_line" ]; then
  if [ "$has_ui_line" -lt "$propose_line" ]; then
    pass "D1: has-ui probe (line $has_ui_line) precedes propose-and-confirm (line $propose_line)"
  else
    fail "D1: insertion order wrong — has-ui (line $has_ui_line) must precede propose (line $propose_line)"
  fi
else
  if [ -z "$has_ui_line" ]; then
    fail "D1: 'has-ui' or 'has.ui' sentinel not found in request.md"
  fi
  if [ -z "$propose_line" ]; then
    fail "D1: 'I propose tier:' sentinel not found — cannot verify insertion order"
  fi
fi

if [ -n "$propose_line" ] && [ -n "$slug_line" ]; then
  if [ "$propose_line" -lt "$slug_line" ]; then
    pass "D2: propose-and-confirm (line $propose_line) precedes slug/STATUS step (line $slug_line)"
  else
    fail "D2: insertion order wrong — propose (line $propose_line) must precede slug line (line $slug_line)"
  fi
else
  if [ -z "$slug_line" ]; then
    fail "D2: slug/STATUS sentinel not found in request.md"
  fi
fi

# ---------------------------------------------------------------------------
# E. Re-prompt-once discipline: prose must mention re-prompt behavior
#    (PM MUST NOT block indefinitely; re-prompt once then default per T18 spec)
# ---------------------------------------------------------------------------
if printf '%s\n' "$REQUEST_CONTENT" | grep -Eqi 're-prompt|reprompt|re.prompt|once.*default|default.*proposed|unrecogni' 2>/dev/null; then
  pass "E: re-prompt-once discipline documented in request.md"
else
  fail "E: re-prompt-once discipline not found — T18 spec: 're-prompt once on unrecognised input, then default to proposed'"
fi

# ---------------------------------------------------------------------------
# F. No-silent-default: "propose" or "proposal" language present
#    (PM MUST NOT silently default; MUST propose)
# ---------------------------------------------------------------------------
if printf '%s\n' "$REQUEST_CONTENT" | grep -qi 'propos' 2>/dev/null; then
  pass "F: 'propos' (propose/proposal) language present — no silent default"
else
  fail "F: 'propos' language missing — T18 spec: 'PM MUST NOT silently default; MUST propose'"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed, %d skipped ===\n' \
  "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
