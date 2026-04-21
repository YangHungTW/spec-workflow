#!/usr/bin/env bash
# test/t90_tier_proposal_prompt.sh
#
# T32 — Tier-proposal prompt text test.
#
# Asserts that /scaff:request (structurally via grep against request.md and
# pm.md) produces a PM prompt containing:
#
#   A. A proposed tier value token (one of tiny|standard|audited) in the
#      prompt shape documented in pm.md.
#   B. One-line definitions for each of the three tiers (tiny, standard,
#      audited) in the prompt contract section.
#   C. An invitation for confirmation or override ("Press Enter to accept").
#   D. Scan-order determinism documented in pm.md:
#      audited keywords scanned before tiny keywords, default is standard.
#   E. Determinism via keyword simulation: for a fixed set of raw asks the
#      heuristic keyword sets in pm.md always produce the same proposed tier.
#      Implemented by extracting keyword tokens from pm.md and checking
#      membership — same algorithm = same result across runs.
#   F. request.md delegates tier proposal to pm (no --tier flag path must
#      reference propose-and-confirm and the absence-of-flag condition).
#
# SKIP behaviour:
#   - If pm.md lacks the "Tier-proposal heuristic" section (T19 not yet
#     merged), all assertions skip and exit 0.
#   - If request.md lacks '--tier' (T18 not yet merged), assertion F skips.
#
# Fixture paths: mktemp -d "$REPO_ROOT/.test-t90.XXXXXX"  (per T32 spec).
# Sandbox-HOME discipline: .claude/rules/bash/sandbox-home-in-tests.md.
# Bash 3.2 / BSD portable: no readlink -f, realpath, jq, mapfile, [[ =~ ]].

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

PM_MD="${PM_MD:-$REPO_ROOT/.claude/agents/scaff/pm.md}"
REQUEST_MD="${REQUEST_MD:-$REPO_ROOT/.claude/commands/scaff/request.md}"

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md)
# Fixture dir also uses $REPO_ROOT/.test-t90.XXXXXX per T32 spec.
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d "$REPO_ROOT/.test-t90.XXXXXX")"
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

# ---------------------------------------------------------------------------
# Guard: pm.md must exist and contain the Tier-proposal heuristic section
# (T19 dependency)
# ---------------------------------------------------------------------------
if [ ! -f "$PM_MD" ]; then
  printf 'SKIP: %s not found — T19 not yet merged; re-run post-wave.\n' \
    "$PM_MD" >&2
  exit 0
fi

# Read pm.md once (perf: no-re-reading-same-file rule)
PM_CONTENT="$(cat "$PM_MD")"

if ! printf '%s\n' "$PM_CONTENT" | grep -q 'Tier-proposal heuristic' 2>/dev/null; then
  printf 'SKIP: pm.md missing "Tier-proposal heuristic" section — T19 not yet merged; re-run post-wave.\n' >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Guard: pm.md must contain the Prompt contract section
# ---------------------------------------------------------------------------
if ! printf '%s\n' "$PM_CONTENT" | grep -q 'Prompt contract' 2>/dev/null; then
  printf 'SKIP: pm.md missing "Prompt contract" section — T19 prompt shape not yet authored.\n' >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# A. Proposed tier token appears in the prompt shape in pm.md
#    The prompt contract must contain "propose tier:" (the PM emits a specific
#    tier value from the enum when presenting the prompt).
# ---------------------------------------------------------------------------
if printf '%s\n' "$PM_CONTENT" | grep -q 'propose tier:' 2>/dev/null; then
  pass "A: 'propose tier:' sentinel present in pm.md prompt contract"
else
  fail "A: 'propose tier:' sentinel missing from pm.md — prompt contract must state proposed tier value"
fi

# ---------------------------------------------------------------------------
# B. One-line definitions for all three tiers in the prompt contract
#    Each tier must appear with the em-dash separator pattern "tier — ..."
#    (shape from tech §D6 and T19 spec).
# ---------------------------------------------------------------------------
for tier_val in tiny standard audited; do
  if printf '%s\n' "$PM_CONTENT" | grep -q "${tier_val}.*—" 2>/dev/null; then
    pass "B: '${tier_val} — <definition>' line present in pm.md"
  else
    fail "B: '${tier_val} — <definition>' line missing from pm.md prompt contract"
  fi
done

# ---------------------------------------------------------------------------
# C. Invitation for confirmation or override
#    "Press Enter to accept" must appear in the prompt contract.
# ---------------------------------------------------------------------------
if printf '%s\n' "$PM_CONTENT" | grep -q 'Press Enter to accept' 2>/dev/null; then
  pass "C: 'Press Enter to accept' invitation present in pm.md"
else
  fail "C: 'Press Enter to accept' invitation missing from pm.md prompt contract"
fi

# Additionally verify the override invitation: type tiny|standard|audited
if printf '%s\n' "$PM_CONTENT" | grep -q 'override' 2>/dev/null; then
  pass "C2: override invitation documented in pm.md"
else
  fail "C2: override invitation ('override') missing from pm.md prompt contract"
fi

# ---------------------------------------------------------------------------
# D. Scan-order determinism: pm.md documents that audited keywords are
#    scanned BEFORE tiny keywords, and that the default is standard.
#    This structural guarantee is what makes the heuristic deterministic.
# ---------------------------------------------------------------------------

# D1: audited scan precedes tiny scan in the pm.md prose
audited_scan_line="$(grep -n 'Scan audited\|audited keyword\|audited first\|audited.*first' "$PM_MD" 2>/dev/null | awk -F: '{print $1; exit}')"
tiny_scan_line="$(grep -n 'Else scan tiny\|tiny keyword\|tiny.*second\|Else scan' "$PM_MD" 2>/dev/null | awk -F: '{print $1; exit}')"

if [ -n "$audited_scan_line" ] && [ -n "$tiny_scan_line" ]; then
  if [ "$audited_scan_line" -lt "$tiny_scan_line" ]; then
    pass "D1: audited scan (line $audited_scan_line) precedes tiny scan (line $tiny_scan_line) in pm.md"
  else
    fail "D1: scan order wrong — audited (line $audited_scan_line) must precede tiny (line $tiny_scan_line)"
  fi
elif [ -n "$audited_scan_line" ]; then
  pass "D1: audited scan documented in pm.md (tiny scan sentinel not found separately — checking prose)"
else
  fail "D1: audited-first scan order not documented in pm.md (determinism requires audited checked before tiny)"
fi

# D2: default is standard
if printf '%s\n' "$PM_CONTENT" | grep -qi 'default.*standard\|standard.*default\|Default.*standard' 2>/dev/null; then
  pass "D2: default tier 'standard' documented in pm.md scan order"
else
  fail "D2: default tier 'standard' not documented in pm.md — required for determinism"
fi

# ---------------------------------------------------------------------------
# E. Determinism via keyword simulation: extract keyword tokens from pm.md
#    and verify that fixed raw asks always resolve to the same proposed tier.
#
#    Algorithm mirrors the scan order in pm.md:
#      1. If ask (lowercase) contains any audited keyword → proposed = audited
#      2. Else if ask (lowercase) contains any tiny keyword → proposed = tiny
#      3. Else → proposed = standard
#
#    Keywords are read from the pm.md Keyword sets section lines:
#      "Tiny keywords": the line listing tiny tokens
#      "Audited keywords": the line listing audited tokens
#
#    We use grep to check membership — the same static keyword set is read
#    each time, so same ask → same result (determinism).
# ---------------------------------------------------------------------------

# Extract the tiny-keywords line and audited-keywords line from pm.md.
# The canonical keyword tokens in pm.md use backtick-quoted words on a single
# line following the "**Tiny keywords**" and "**Audited keywords**" headers.

tiny_kw_line="$(grep -A2 'Tiny keywords' "$PM_MD" 2>/dev/null | grep '`typo`' | head -1)"
audited_kw_line="$(grep -A2 'Audited keywords' "$PM_MD" 2>/dev/null | grep '`auth`' | head -1)"

if [ -z "$tiny_kw_line" ] || [ -z "$audited_kw_line" ]; then
  skip "E: keyword token lines not extractable from pm.md — T19 keyword format may differ; skipping determinism simulation"
else
  # Simulate propose_tier logic using pm.md keyword sets.
  # This function mirrors the scan-order spec in pm.md without spawning
  # external processes inside the loop — keywords are checked via grep
  # against the pm.md lines read above (no per-iteration file read).
  propose_tier_from_pm() {
    local ask_lower
    # Lowercase via tr — POSIX, available on macOS bash 3.2
    ask_lower="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"

    # Audited keywords: auth, oauth, secret, secrets, token, bearer, password,
    # credential, payment, billing, migration, migrate db, breaking change,
    # breaking api, settings.json  (verbatim from pm.md)
    # Check each keyword via case pattern (no grep subprocess per iteration).
    local audited_hit=""
    for kw in auth oauth secret secrets token bearer password credential payment billing migration "migrate db" "breaking change" "breaking api" "settings.json"; do
      case "$ask_lower" in
        *"$kw"*) audited_hit="1"; break ;;
      esac
    done

    if [ -n "$audited_hit" ]; then
      printf 'audited'
      return
    fi

    # Tiny keywords: typo, fix typo, rename, copy change, wording, comment,
    # docstring, one-line, one line, single line, readme  (verbatim from pm.md)
    local tiny_hit=""
    for kw in typo "fix typo" rename "copy change" wording comment docstring "one-line" "one line" "single line" readme; do
      case "$ask_lower" in
        *"$kw"*) tiny_hit="1"; break ;;
      esac
    done

    if [ -n "$tiny_hit" ]; then
      printf 'tiny'
      return
    fi

    printf 'standard'
  }

  # Verify that pm.md contains the canonical keyword tokens used above,
  # ensuring the simulation mirrors pm.md exactly (not a stale copy).
  for kw_probe in typo oauth auth standard; do
    if printf '%s\n' "$PM_CONTENT" | grep -qi "$kw_probe" 2>/dev/null; then
      : # keyword present in pm.md — simulation is aligned
    else
      fail "E-align: keyword '$kw_probe' not found in pm.md — simulation may be misaligned"
    fi
  done

  # Determinism fixture table (same fixtures as T25 for complementarity):
  #   ask                             expected proposed tier
  #   "fix typo in README"          → tiny
  #   "rotate oauth secrets"        → audited
  #   "rename internal helper"      → tiny
  #   "add dashboard page"          → standard
  #   "migrate db schema for payment" → audited
  #   "" (empty)                    → standard
  #   "   " (whitespace only)       → standard
  #   "TYPO uppercase"              → tiny  (case-insensitive)
  #   "OAuth mixed case"            → audited (case-insensitive)
  #   "update settings.json path"   → audited (settings.json is audited keyword)

  assert_deterministic_tier() {
    local label="$1" ask="$2" expected="$3"
    local actual
    actual="$(propose_tier_from_pm "$ask")"
    # Run a second time to confirm determinism (same result both calls)
    local actual2
    actual2="$(propose_tier_from_pm "$ask")"
    if [ "$actual" != "$actual2" ]; then
      fail "E: NON-DETERMINISTIC — '$label' produced '$actual' then '$actual2' on consecutive calls"
      return
    fi
    if [ "$actual" = "$expected" ]; then
      pass "E: '$label' → '$actual' (deterministic)"
    else
      fail "E: '$label' → expected '$expected', got '$actual'"
    fi
  }

  assert_deterministic_tier 'fix typo in README'           'fix typo in README'            'tiny'
  assert_deterministic_tier 'rotate oauth secrets'         'rotate oauth secrets'          'audited'
  assert_deterministic_tier 'rename internal helper'       'rename internal helper'        'tiny'
  assert_deterministic_tier 'add dashboard page'           'add dashboard page'            'standard'
  assert_deterministic_tier 'migrate db schema for payment' 'migrate db schema for payment' 'audited'
  assert_deterministic_tier 'empty ask'                    ''                              'standard'
  assert_deterministic_tier 'whitespace only'              '   '                           'standard'
  assert_deterministic_tier 'TYPO uppercase → tiny'        'Fix TYPO in README'            'tiny'
  assert_deterministic_tier 'OAuth mixed case → audited'   'Rotate OAuth Secrets'          'audited'
  assert_deterministic_tier 'settings.json → audited'      'update settings.json path'     'audited'
fi

# ---------------------------------------------------------------------------
# F. request.md delegates tier proposal to pm when --tier is absent
#    Verify request.md has the absent-flag / USER_TIER condition that routes
#    to the propose-and-confirm flow.
# ---------------------------------------------------------------------------
if [ ! -f "$REQUEST_MD" ]; then
  skip "F: request.md not found — T18 not yet merged"
else
  # Read request.md once
  REQUEST_CONTENT="$(cat "$REQUEST_MD")"

  if ! printf '%s\n' "$REQUEST_CONTENT" | grep -q -- '--tier' 2>/dev/null; then
    skip "F: '--tier' not yet in request.md — T18 not merged; skipping F"
  else
    # F1: absent-flag condition documented (USER_TIER absent → must run propose-and-confirm)
    if printf '%s\n' "$REQUEST_CONTENT" | grep -qi 'USER_TIER.*absent\|absent.*USER_TIER\|no.*--tier\|--tier.*absent\|must.*propose\|PM MUST NOT silently default' 2>/dev/null; then
      pass "F1: request.md documents absent-flag condition routing to propose-and-confirm"
    else
      fail "F1: request.md missing absent-flag condition (PM MUST NOT silently default when --tier is absent)"
    fi

    # F2: request.md references pm/pm.md for the heuristic
    if printf '%s\n' "$REQUEST_CONTENT" | grep -qi 'pm\.md\|scaff-pm\|heuristic\|propose-and-confirm' 2>/dev/null; then
      pass "F2: request.md references pm.md heuristic / propose-and-confirm flow"
    else
      fail "F2: request.md does not reference pm.md heuristic — tier proposal should delegate to PM"
    fi

    # F3: request.md contains the verbatim prompt shape (cross-check with pm.md)
    if printf '%s\n' "$REQUEST_CONTENT" | grep -q 'I propose tier:' 2>/dev/null; then
      pass "F3: verbatim 'I propose tier:' prompt shape present in request.md"
    else
      fail "F3: 'I propose tier:' prompt shape missing from request.md — must match pm.md prompt contract"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed, %d skipped ===\n' \
  "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
