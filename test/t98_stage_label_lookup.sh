#!/usr/bin/env bash
# test/t98_stage_label_lookup.sh
#
# T118 — Seam L: stage-label i18n coverage
#
# Three assertions for each of the 8 advance-to stages:
#
#   1. action.advance_to.<stage> key present in flow-monitor/src/i18n/en.json
#      with a non-empty string value.
#   2. Same key present in flow-monitor/src/i18n/zh-TW.json with non-empty
#      string value.
#   3. grep across flow-monitor/src/components/ returns 0 matches for
#      hardcoded "Advance to (Design|PRD|Tech|Plan|Tasks|Implement|Validate|
#      Archive)" strings (AC2.c — no hardcoded display strings; table-driven).
#
# Sandbox-HOME NOT required: this test only reads JSON/TSX files in the repo
# working tree; no CLI expands or writes $HOME.
# (bash/sandbox-home-in-tests.md — explicitly exempt for read-only repo
# traversal scripts.)
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only flags.
#   JSON parsed via python3 -c.
#   No `case` inside subshells (bash32-case-in-subshell.md).
set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

I18N_DIR="$REPO_ROOT/flow-monitor/src/i18n"
COMPONENTS_DIR="$REPO_ROOT/flow-monitor/src/components"

EN_JSON="$I18N_DIR/en.json"
ZH_JSON="$I18N_DIR/zh-TW.json"

# ---------------------------------------------------------------------------
# Preflight — required paths must exist
# ---------------------------------------------------------------------------
if [ ! -d "$I18N_DIR" ]; then
  printf 'SKIP: %s not found — flow-monitor not present; re-run after app scaffold.\n' \
    "$I18N_DIR" >&2
  exit 0
fi

if [ ! -f "$EN_JSON" ]; then
  printf 'FAIL: %s not found\n' "$EN_JSON" >&2
  exit 1
fi

if [ ! -f "$ZH_JSON" ]; then
  printf 'FAIL: %s not found\n' "$ZH_JSON" >&2
  exit 1
fi

if [ ! -d "$COMPONENTS_DIR" ]; then
  printf 'SKIP: %s not found — components not yet authored; re-run after scaffold.\n' \
    "$COMPONENTS_DIR" >&2
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
# Load both JSON files once — avoid repeated file reads per rule:
#   developer/performance: no re-reading the same file.
# We extract all action.advance_to.* keys in one python3 invocation each.
# Output format per line: <stage>:<value>
# ---------------------------------------------------------------------------
EN_ADVANCE="$(python3 -c "
import json, sys
with open(sys.argv[1]) as fh:
    data = json.load(fh)
prefix = 'action.advance_to.'
for k, v in data.items():
    if k.startswith(prefix):
        stage = k[len(prefix):]
        print(stage + ':' + v)
" "$EN_JSON")"

ZH_ADVANCE="$(python3 -c "
import json, sys
with open(sys.argv[1]) as fh:
    data = json.load(fh)
prefix = 'action.advance_to.'
for k, v in data.items():
    if k.startswith(prefix):
        stage = k[len(prefix):]
        print(stage + ':' + v)
" "$ZH_JSON")"

# ---------------------------------------------------------------------------
# Helper: look up a stage value from the pre-loaded map string.
# Returns the value (after the first colon) or empty string if absent.
# Uses a while-read loop (no mapfile, bash 3.2 safe).
# ---------------------------------------------------------------------------
lookup_stage() {
  local map="$1"
  local target_stage="$2"
  local result=""
  while IFS= read -r entry; do
    local entry_stage
    entry_stage="${entry%%:*}"
    if [ "$entry_stage" = "$target_stage" ]; then
      result="${entry#*:}"
      break
    fi
  done <<MAPEOF
$map
MAPEOF
  printf '%s' "$result"
}

# ---------------------------------------------------------------------------
# Assertions 1 & 2: per-stage i18n key coverage
# ---------------------------------------------------------------------------
printf '=== 1+2: action.advance_to.* key coverage (en + zh-TW) ===\n'

STAGES="design prd tech plan tasks implement validate archive"

for stage in $STAGES; do
  en_val="$(lookup_stage "$EN_ADVANCE" "$stage")"
  if [ -n "$en_val" ]; then
    pass "1 en.json  action.advance_to.$stage = \"$en_val\""
  else
    fail "1 en.json  action.advance_to.$stage missing or empty"
  fi

  zh_val="$(lookup_stage "$ZH_ADVANCE" "$stage")"
  if [ -n "$zh_val" ]; then
    pass "2 zh-TW.json action.advance_to.$stage = \"$zh_val\""
  else
    fail "2 zh-TW.json action.advance_to.$stage missing or empty"
  fi
done

# ---------------------------------------------------------------------------
# Assertion 3: no hardcoded "Advance to <Stage>" strings in components/
#
# AC2.c — display labels must come from the i18n table, never be inlined.
# Run a single grep across all .tsx/.ts files; fail on any match.
# (developer/performance: batch grep rather than one per stage.)
# ---------------------------------------------------------------------------
printf '\n=== 3: no hardcoded "Advance to <Stage>" strings in components/ ===\n'

HARDCODED_PATTERN='"Advance to (Design|PRD|Tech|Plan|Tasks|Implement|Validate|Archive)"'

HARDCODED_MATCHES="$(grep -rE \
  '"Advance to (Design|PRD|Tech|Plan|Tasks|Implement|Validate|Archive)"' \
  "$COMPONENTS_DIR" \
  --include='*.ts' --include='*.tsx' \
  --exclude-dir='__tests__' 2>/dev/null || true)"

if [ -z "$HARDCODED_MATCHES" ]; then
  pass "3 no hardcoded \"Advance to <Stage>\" strings found in components/"
else
  printf 'FAIL: hardcoded display strings found (must use i18n table):\n' >&2
  printf '%s\n' "$HARDCODED_MATCHES" >&2
  fail "3 hardcoded \"Advance to <Stage>\" string(s) found — see lines above"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
