#!/usr/bin/env bash
# test/t52_rule_index_row.sh — verify index.md row for language-preferences
# Usage: bash test/t52_rule_index_row.sh
# Exits 0 iff all checks pass.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

INDEX="$REPO_ROOT/.claude/rules/index.md"

echo "=== t52_rule_index_row ==="

# Check 1: row present with correct scope and severity
if grep -E '^\| language-preferences \| common \| should \|' "$INDEX" > /dev/null 2>&1; then
  echo "PASS: row present with scope=common severity=should"
else
  echo "FAIL: row-present — no matching row in $INDEX" >&2
  exit 1
fi

# Check 2: link target is common/language-preferences.md
if grep -E '^\| language-preferences \|' "$INDEX" | grep -F 'common/language-preferences.md' > /dev/null 2>&1; then
  echo "PASS: link target is common/language-preferences.md"
else
  echo "FAIL: link-target — row does not reference common/language-preferences.md" >&2
  exit 1
fi

# Check 3: alphabetical placement — classify-before-mutate < language-preferences < no-force-on-user-paths
line_classify=$(grep -n 'classify-before-mutate' "$INDEX" | awk -F: '{print $1}' | head -1)
line_lang=$(grep -n 'language-preferences' "$INDEX" | awk -F: '{print $1}' | head -1)
line_noforce=$(grep -n 'no-force-on-user-paths' "$INDEX" | awk -F: '{print $1}' | head -1)

if [ -z "$line_classify" ] || [ -z "$line_lang" ] || [ -z "$line_noforce" ]; then
  echo "FAIL: sort-order — could not find all three anchor rows in $INDEX" >&2
  exit 1
fi

if [ "$line_classify" -lt "$line_lang" ] && [ "$line_lang" -lt "$line_noforce" ]; then
  echo "PASS: sort-order — classify-before-mutate (L${line_classify}) < language-preferences (L${line_lang}) < no-force-on-user-paths (L${line_noforce})"
else
  echo "FAIL: sort-order — expected classify-before-mutate < language-preferences < no-force-on-user-paths; got L${line_classify}, L${line_lang}, L${line_noforce}" >&2
  exit 1
fi

echo ""
echo "PASS"
exit 0
