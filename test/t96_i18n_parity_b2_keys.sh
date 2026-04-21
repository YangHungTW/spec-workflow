#!/usr/bin/env bash
# test/t96_i18n_parity_b2_keys.sh
#
# T116 — Seam J: en/zh-TW parity for the 26 B2 control-plane i18n keys.
#
# Assertions for each of the 26 B2 keys:
#   1. Key is present in BOTH en.json AND zh-TW.json.
#   2. Value is a non-empty string in both.
#   3. Keys with {placeholder} syntax have the SAME SET of placeholders in both
#      locales.  Specific requirements:
#        toast.preflight           must have {command} and {slug}
#        stalled.badge             must have {duration}
#        notification.stalled.body must have {slug} and {duration}
#   4. pill.write  value is "WRITE"   in both files (designer note 11).
#      pill.destroy value is "DESTROY" in both files (designer note 11).
#
# Sandbox-HOME NOT required: this test only reads static JSON files under the
# repo working tree and never invokes any CLI that expands or writes $HOME.
# (bash/sandbox-home-in-tests.md — explicitly exempt for read-only repo
# traversal scripts.)
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only
#   flags.  JSON parsed via python3 (bash-32-portability.md — no jq).
#   No `case` inside subshells (bash32-case-in-subshell.md).
set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

EN_JSON="$REPO_ROOT/flow-monitor/src/i18n/en.json"
ZH_JSON="$REPO_ROOT/flow-monitor/src/i18n/zh-TW.json"

# ---------------------------------------------------------------------------
# Preflight — both JSON files must exist
# ---------------------------------------------------------------------------
if [ ! -f "$EN_JSON" ]; then
  printf 'SKIP: %s not found — i18n not yet scaffolded; re-run after T112a merges.\n' \
    "$EN_JSON" >&2
  exit 0
fi
if [ ! -f "$ZH_JSON" ]; then
  printf 'SKIP: %s not found — zh-TW locale not yet authored; re-run after T112b merges.\n' \
    "$ZH_JSON" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Batch-extract all 26 B2 keys from both locales — 2 python3 forks total.
# (reviewer/performance.md R1/R6 — no shell-out inside the 26-key loop)
#
# Each MAP variable holds tab-separated "key\tvalue" lines, one per key.
# Keys with no string value produce no line (absent from the map).
# The heredoc feeds the key list via stdin; JSON file is read from argv[1].
# (developer/bash-heredoc-stdin-conflict.md — heredoc wins over pipe, so
#  we must NOT also pipe EN_DATA in; reading from file arg avoids the trap.)
# ---------------------------------------------------------------------------
EN_MAP="$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
for line in sys.stdin:
    k = line.rstrip('\n')
    if not k:
        continue
    v = d.get(k)
    if isinstance(v, str):
        sys.stdout.write(k + '\t' + v + '\n')
" "$EN_JSON" <<'PYEOF'
action.advance_to.design
action.advance_to.prd
action.advance_to.tech
action.advance_to.plan
action.advance_to.tasks
action.advance_to.implement
action.advance_to.validate
action.advance_to.archive
action.message
action.send_panel.title
audit.panel.title
audit.entry.via
stalled.badge
palette.group.control
palette.group.specflow
palette.group.destroy
modal.destroy.title
modal.destroy.cancel
modal.destroy.confirm
pill.write
pill.destroy
toast.in_flight
toast.terminal_failed
toast.preflight
notification.stalled.title
notification.stalled.body
PYEOF
)"

ZH_MAP="$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
for line in sys.stdin:
    k = line.rstrip('\n')
    if not k:
        continue
    v = d.get(k)
    if isinstance(v, str):
        sys.stdout.write(k + '\t' + v + '\n')
" "$ZH_JSON" <<'PYEOF'
action.advance_to.design
action.advance_to.prd
action.advance_to.tech
action.advance_to.plan
action.advance_to.tasks
action.advance_to.implement
action.advance_to.validate
action.advance_to.archive
action.message
action.send_panel.title
audit.panel.title
audit.entry.via
stalled.badge
palette.group.control
palette.group.specflow
palette.group.destroy
modal.destroy.title
modal.destroy.cancel
modal.destroy.confirm
pill.write
pill.destroy
toast.in_flight
toast.terminal_failed
toast.preflight
notification.stalled.title
notification.stalled.body
PYEOF
)"

# ---------------------------------------------------------------------------
# Helpers: look up a key from a pre-extracted tab-separated map (no forks)
# ---------------------------------------------------------------------------

# map_get <map_variable_value> <key>
# Prints the string value for the given key, or empty string if missing.
# Uses awk — no subprocess fork beyond the single awk process already running
# as part of the pipeline evaluation.
map_get() {
  local map="$1"
  local key="$2"
  printf '%s\n' "$map" | awk -F'\t' -v k="$key" '$1==k{print $2; exit}'
}

# extract_placeholders <string>
# Prints each {placeholder} name, one per line, sorted, deduped.
# E.g. "{slug} · idle {duration}" -> "duration\nslug"
extract_placeholders() {
  local val="$1"
  printf '%s' "$val" | python3 -c "
import re, sys
text = sys.stdin.read()
ph = sorted(set(re.findall(r'\{(\w+)\}', text)))
for p in ph:
    print(p)
"
}

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# The 26 B2 keys to check
# ---------------------------------------------------------------------------
B2_KEYS="action.advance_to.design
action.advance_to.prd
action.advance_to.tech
action.advance_to.plan
action.advance_to.tasks
action.advance_to.implement
action.advance_to.validate
action.advance_to.archive
action.message
action.send_panel.title
audit.panel.title
audit.entry.via
stalled.badge
palette.group.control
palette.group.specflow
palette.group.destroy
modal.destroy.title
modal.destroy.cancel
modal.destroy.confirm
pill.write
pill.destroy
toast.in_flight
toast.terminal_failed
toast.preflight
notification.stalled.title
notification.stalled.body"

# ---------------------------------------------------------------------------
# Assertions 1 + 2: presence and non-empty value in both locales
# ---------------------------------------------------------------------------
printf '=== A: key presence and non-empty value ===\n'

while IFS= read -r key; do
  [ -z "$key" ] && continue
  en_val="$(map_get "$EN_MAP" "$key")"
  zh_val="$(map_get "$ZH_MAP" "$key")"

  if [ -z "$en_val" ]; then
    fail "A [$key]: missing or empty in en.json"
  elif [ -z "$zh_val" ]; then
    fail "A [$key]: missing or empty in zh-TW.json"
  else
    pass "A [$key]: present and non-empty in both locales"
  fi
done <<EOF
$B2_KEYS
EOF

# ---------------------------------------------------------------------------
# Assertion 3: placeholder parity for keys that carry {placeholders}
# ---------------------------------------------------------------------------
printf '\n=== B: placeholder parity ===\n'

check_placeholders() {
  local key="$1"
  local en_val
  local zh_val
  local en_ph
  local zh_ph
  en_val="$(map_get "$EN_MAP" "$key")"
  zh_val="$(map_get "$ZH_MAP" "$key")"
  en_ph="$(extract_placeholders "$en_val")"
  zh_ph="$(extract_placeholders "$zh_val")"
  if [ "$en_ph" = "$zh_ph" ]; then
    pass "B [$key]: placeholders match in both locales ($en_ph)"
  else
    fail "B [$key]: placeholder mismatch — en={$en_ph} zh-TW={$zh_ph}"
  fi
}

# All keys that are expected to carry placeholders — check parity
check_placeholders "stalled.badge"
check_placeholders "toast.preflight"
check_placeholders "notification.stalled.body"

# Specific placeholder presence requirements
printf '\n=== C: required placeholder membership ===\n'

# toast.preflight must contain {command} and {slug}
PREFLIGHT_EN="$(map_get "$EN_MAP" "toast.preflight")"
PREFLIGHT_ZH="$(map_get "$ZH_MAP" "toast.preflight")"
for locale_val in "$PREFLIGHT_EN" "$PREFLIGHT_ZH"; do
  _ph="$(extract_placeholders "$locale_val")"
  _has_command=0
  _has_slug=0
  while IFS= read -r p; do
    [ "$p" = "command" ] && _has_command=1
    [ "$p" = "slug" ]    && _has_slug=1
  done <<PHEOF
$_ph
PHEOF
  if [ "$_has_command" -eq 1 ] && [ "$_has_slug" -eq 1 ]; then
    pass "C [toast.preflight \"$locale_val\"]: has {command} and {slug}"
  else
    fail "C [toast.preflight \"$locale_val\"]: missing required placeholder(s) — needs {command} and {slug}; found: $_ph"
  fi
done

# stalled.badge must contain {duration}
BADGE_EN="$(map_get "$EN_MAP" "stalled.badge")"
BADGE_ZH="$(map_get "$ZH_MAP" "stalled.badge")"
for locale_val in "$BADGE_EN" "$BADGE_ZH"; do
  _ph="$(extract_placeholders "$locale_val")"
  _has_duration=0
  while IFS= read -r p; do
    [ "$p" = "duration" ] && _has_duration=1
  done <<PHEOF
$_ph
PHEOF
  if [ "$_has_duration" -eq 1 ]; then
    pass "C [stalled.badge \"$locale_val\"]: has {duration}"
  else
    fail "C [stalled.badge \"$locale_val\"]: missing required placeholder {duration}; found: $_ph"
  fi
done

# notification.stalled.body must contain {slug} and {duration}
STALLED_BODY_EN="$(map_get "$EN_MAP" "notification.stalled.body")"
STALLED_BODY_ZH="$(map_get "$ZH_MAP" "notification.stalled.body")"
for locale_val in "$STALLED_BODY_EN" "$STALLED_BODY_ZH"; do
  _ph="$(extract_placeholders "$locale_val")"
  _has_slug=0
  _has_duration=0
  while IFS= read -r p; do
    [ "$p" = "slug" ]     && _has_slug=1
    [ "$p" = "duration" ] && _has_duration=1
  done <<PHEOF
$_ph
PHEOF
  if [ "$_has_slug" -eq 1 ] && [ "$_has_duration" -eq 1 ]; then
    pass "C [notification.stalled.body \"$locale_val\"]: has {slug} and {duration}"
  else
    fail "C [notification.stalled.body \"$locale_val\"]: missing required placeholder(s) — needs {slug} and {duration}; found: $_ph"
  fi
done

# ---------------------------------------------------------------------------
# Assertion 4: pill.write == "WRITE" and pill.destroy == "DESTROY" in both
# (designer note 11 — these are constant labels, not translated)
# ---------------------------------------------------------------------------
printf '\n=== D: pill value literals ===\n'

PILL_WRITE_EN="$(map_get "$EN_MAP" "pill.write")"
PILL_WRITE_ZH="$(map_get "$ZH_MAP" "pill.write")"
PILL_DESTROY_EN="$(map_get "$EN_MAP" "pill.destroy")"
PILL_DESTROY_ZH="$(map_get "$ZH_MAP" "pill.destroy")"

if [ "$PILL_WRITE_EN" = "WRITE" ]; then
  pass "D [pill.write en.json]: value is \"WRITE\""
else
  fail "D [pill.write en.json]: expected \"WRITE\", got \"$PILL_WRITE_EN\""
fi

if [ "$PILL_WRITE_ZH" = "WRITE" ]; then
  pass "D [pill.write zh-TW.json]: value is \"WRITE\""
else
  fail "D [pill.write zh-TW.json]: expected \"WRITE\", got \"$PILL_WRITE_ZH\""
fi

if [ "$PILL_DESTROY_EN" = "DESTROY" ]; then
  pass "D [pill.destroy en.json]: value is \"DESTROY\""
else
  fail "D [pill.destroy en.json]: expected \"DESTROY\", got \"$PILL_DESTROY_EN\""
fi

if [ "$PILL_DESTROY_ZH" = "DESTROY" ]; then
  pass "D [pill.destroy zh-TW.json]: value is \"DESTROY\""
else
  fail "D [pill.destroy zh-TW.json]: expected \"DESTROY\", got \"$PILL_DESTROY_ZH\""
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed ===\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
