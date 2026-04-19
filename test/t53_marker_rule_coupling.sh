#!/usr/bin/env bash
# test/t53_marker_rule_coupling.sh
#
# Guards D5 tradeoff: the marker string LANG_CHAT=zh-TW must stay coupled
# between the hook (.claude/hooks/session-start.sh) and the rule body
# (.claude/rules/common/language-preferences.md). Any drift in either side
# fails this test.
#
# No sandbox required — this test only reads source files; it does not
# invoke any CLI that writes under $HOME.
#
# Requirements: D5 (marker-plus-conditional-prose coupling), risk R2.
# Dependencies: T1, T2.

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOOK="$REPO_ROOT/.claude/hooks/session-start.sh"
RULE="$REPO_ROOT/.claude/rules/common/language-preferences.md"

PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# AC-1: rule body must contain the literal marker LANG_CHAT=zh-TW
# ---------------------------------------------------------------------------
if grep -qF 'LANG_CHAT=zh-TW' "$RULE" 2>/dev/null; then
  echo "PASS: rule body contains literal LANG_CHAT=zh-TW"
  PASS=$((PASS + 1))
else
  echo "FAIL: rule body does not contain literal LANG_CHAT=zh-TW: $RULE" >&2
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# AC-2: hook must contain the LANG_CHAT= key prefix (T2 coupling side)
# The hook emits LANG_CHAT=<value> dynamically (printf '%s\nLANG_CHAT=%s')
# rather than a hardcoded literal, so we verify the key prefix is present.
# ---------------------------------------------------------------------------
if grep -qF 'LANG_CHAT=' "$HOOK" 2>/dev/null; then
  echo "PASS: hook contains LANG_CHAT= key prefix"
  PASS=$((PASS + 1))
else
  echo "FAIL: hook does not contain LANG_CHAT= key prefix: $HOOK" >&2
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# AC-3: hook must recognise zh-TW as a valid case value (coupling drift guard)
# If someone renames the marker value in the hook but forgets the rule, this
# assertion fails.
# ---------------------------------------------------------------------------
if grep -qF 'zh-TW' "$HOOK" 2>/dev/null; then
  echo "PASS: hook recognises zh-TW as a valid marker value"
  PASS=$((PASS + 1))
else
  echo "FAIL: hook does not reference zh-TW as a valid value: $HOOK" >&2
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# AC-4: scan the whole repo for unexpected files containing the literal marker
# Excludes: .git/, .spec-workflow/archive/, this test file itself, and the
# feature spec dir (.spec-workflow/features/20260419-language-preferences/).
# The rule is the only file expected to carry the literal string; the hook
# emits it dynamically.
# ---------------------------------------------------------------------------
cd "$REPO_ROOT"
unexpected=$(grep -rlF 'LANG_CHAT=zh-TW' . \
  --exclude-dir=.git \
  --exclude-dir=archive \
  2>/dev/null \
  | grep -v '^\./\.claude/rules/common/language-preferences\.md$' \
  | grep -v '^\./test/t53_' \
  | grep -v '^\./\.spec-workflow/features/20260419-language-preferences/' \
  || true)

if [ -z "$unexpected" ]; then
  echo "PASS: literal LANG_CHAT=zh-TW appears in no unexpected files"
  PASS=$((PASS + 1))
else
  echo "FAIL: literal LANG_CHAT=zh-TW appears in unexpected files:" >&2
  printf '%s\n' "$unexpected" >&2
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
