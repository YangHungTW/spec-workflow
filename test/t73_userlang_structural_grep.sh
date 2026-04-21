#!/usr/bin/env bash
# test/t73_userlang_structural_grep.sh
#
# STATIC structural test — R2 AC2.a + AC2.b + portability guard.
#
# Greps .claude/hooks/session-start.sh to verify:
#   AC2.a — sniff_lang_chat() defined exactly once; in_lang=1 token
#            appears exactly once (single awk-sniff definition, not
#            duplicated per candidate).
#   AC2.b — each awk rule line required by D7 is present inside the
#            sniff_lang_chat helper block (grep-structural approach;
#            see commit body for approach rationale).
#   portability — no readlink -f, realpath, jq, mapfile, or =~  token.
#   candidate-list structure — XDG_CONFIG_HOME and
#            .config/scaff/config.yml are both referenced.
#
# No sandbox required — this test only reads source files; it does not
# invoke any CLI that writes under $HOME.
#
# Requirements: R2 AC2.a, R2 AC2.b, R5 AC5.a (structural).
# Dependencies: T1 (greps the edited hook file).

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script — never hardcode worktree paths
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

HOOK="$REPO_ROOT/.claude/hooks/session-start.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Sanity: hook file must exist
# ---------------------------------------------------------------------------
if [ ! -f "$HOOK" ]; then
  echo "FAIL: hook file not found: $HOOK" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# AC1: bash -n syntax check
# ---------------------------------------------------------------------------
if bash -n "$HOOK" 2>/dev/null; then
  pass "AC1: bash -n syntax OK"
else
  fail "AC1: bash -n reports syntax error in $HOOK"
fi

# ---------------------------------------------------------------------------
# AC2.a — in_lang=1 appears exactly once (single awk-sniff definition)
# ---------------------------------------------------------------------------
in_lang_count=$(grep -c 'in_lang=1' "$HOOK" || true)
if [ "$in_lang_count" = "1" ]; then
  pass "AC2.a: in_lang=1 appears exactly once (count=$in_lang_count)"
else
  fail "AC2.a: in_lang=1 count is $in_lang_count (expected 1) — awk-sniff definition may be duplicated or missing"
fi

# ---------------------------------------------------------------------------
# AC2.a — sniff_lang_chat() helper defined exactly once
# ---------------------------------------------------------------------------
helper_count=$(grep -c '^sniff_lang_chat()' "$HOOK" || true)
if [ "$helper_count" = "1" ]; then
  pass "AC2.a: sniff_lang_chat() defined exactly once (count=$helper_count)"
else
  fail "AC2.a: sniff_lang_chat() count is $helper_count (expected 1)"
fi

# ---------------------------------------------------------------------------
# AC2.b — grep-structural: each awk rule line from D7 is present inside
# the sniff_lang_chat helper block.
#
# Approach: grep-structural (option b from the task brief).
# Rationale: extracting the raw awk text and byte-diffing it against a
# known-good string embedded in this file would require escaping every
# special character and is fragile under indentation drift. Instead, we
# grep each of the six semantic tokens that uniquely identify the D7 awk
# body inside the sniff_lang_chat block.  This is bash 3.2 portable
# (no mapfile, no [[ =~ ]], no jq) and survives minor whitespace
# reformatting of surrounding lines while still catching substantive drift.
#
# The six required tokens (from D7 awk body verbatim):
#   1. /^lang:/  {in_lang=1; next}          — state-machine entry
#   2. in_lang && /^  chat:/                — state-machine body trigger
#   3. sub(/^  chat:[[:space:]]*/           — leading-whitespace strip
#   4. gsub(/"/, ""); gsub(/#.*$/, "")      — quote+comment strip
#   5. gsub(/[[:space:]]+$/, "")            — trailing-whitespace strip
#   6. /^[^ ]/  {in_lang=0}                 — state-machine reset
#
# Each grep is scoped to the sniff_lang_chat block (from its opening
# line to the closing '}' that ends the function) via awk extraction.
# ---------------------------------------------------------------------------

# Extract the sniff_lang_chat function body into a variable
sniff_block=$(awk '/^sniff_lang_chat\(\)/,/^}/' "$HOOK" 2>/dev/null)

if [ -z "$sniff_block" ]; then
  fail "AC2.b: could not extract sniff_lang_chat() block from $HOOK"
else
  pass "AC2.b: sniff_lang_chat() block extracted (non-empty)"

  # Token 1: state-machine entry
  if printf '%s\n' "$sniff_block" | grep -qF 'in_lang=1; next'; then
    pass "AC2.b token-1: in_lang=1; next present"
  else
    fail "AC2.b token-1: in_lang=1; next missing from sniff_lang_chat block"
  fi

  # Token 2: state-machine body trigger
  if printf '%s\n' "$sniff_block" | grep -qF 'in_lang && /^  chat:/'; then
    pass "AC2.b token-2: in_lang && /^  chat:/ present"
  else
    fail "AC2.b token-2: in_lang && /^  chat:/ missing from sniff_lang_chat block"
  fi

  # Token 3: leading-whitespace strip
  if printf '%s\n' "$sniff_block" | grep -qF 'sub(/^  chat:[[:space:]]*/'; then
    pass "AC2.b token-3: sub(/^  chat:[[:space:]]*/ present"
  else
    fail "AC2.b token-3: sub(/^  chat:[[:space:]]*/ missing from sniff_lang_chat block"
  fi

  # Token 4: quote+comment strip (two gsub calls on the same line)
  if printf '%s\n' "$sniff_block" | grep -qF 'gsub(/"/, ""); gsub(/#.*$/, "")'; then
    pass "AC2.b token-4: gsub quote+comment strip present"
  else
    fail "AC2.b token-4: gsub quote+comment strip missing from sniff_lang_chat block"
  fi

  # Token 5: trailing-whitespace strip
  if printf '%s\n' "$sniff_block" | grep -qF 'gsub(/[[:space:]]+$/, "")'; then
    pass "AC2.b token-5: gsub trailing-whitespace strip present"
  else
    fail "AC2.b token-5: gsub trailing-whitespace strip missing from sniff_lang_chat block"
  fi

  # Token 6: state-machine reset
  if printf '%s\n' "$sniff_block" | grep -qF '{in_lang=0}'; then
    pass "AC2.b token-6: {in_lang=0} state-machine reset present"
  else
    fail "AC2.b token-6: {in_lang=0} state-machine reset missing from sniff_lang_chat block"
  fi
fi

# ---------------------------------------------------------------------------
# AC2.a proxy — portability guard: no bash-3.2-incompatible tokens
# (R2 AC2.a: portability preserved; cross-ref bash-32-portability.md)
# ---------------------------------------------------------------------------
portability_hits=$(grep -Ec 'readlink -f|realpath|jq|mapfile| =~ ' "$HOOK" || true)
if [ "$portability_hits" = "0" ]; then
  pass "portability: no readlink -f/realpath/jq/mapfile/=~ tokens (count=0)"
else
  fail "portability: $portability_hits forbidden token(s) found — bash 3.2 portability violated"
fi

# ---------------------------------------------------------------------------
# Candidate-list structure — XDG_CONFIG_HOME branch present
# ---------------------------------------------------------------------------
xdg_count=$(grep -c 'XDG_CONFIG_HOME' "$HOOK" || true)
if [ "$xdg_count" -ge 1 ] 2>/dev/null; then
  pass "candidate-list: XDG_CONFIG_HOME referenced (count=$xdg_count)"
else
  fail "candidate-list: XDG_CONFIG_HOME not found in $HOOK (count=$xdg_count)"
fi

# ---------------------------------------------------------------------------
# Candidate-list structure — tilde fallback path present
# ---------------------------------------------------------------------------
tilde_count=$(grep -c '\.config/scaff/config\.yml' "$HOOK" || true)
if [ "$tilde_count" -ge 1 ] 2>/dev/null; then
  pass "candidate-list: .config/scaff/config.yml tilde fallback referenced (count=$tilde_count)"
else
  fail "candidate-list: .config/scaff/config.yml not found in $HOOK (count=$tilde_count)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
