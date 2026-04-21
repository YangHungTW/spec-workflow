#!/usr/bin/env bash
# test/t15_rules_schema.sh — verify frontmatter schema for rule files
# Usage: bash test/t15_rules_schema.sh
# Exits 0 iff all checks pass.
#
# For each .md file under .claude/rules/{common,bash,markdown,git}/
# (i.e. files in subdirs only — README.md and index.md at rules root
#  are administrative files without frontmatter and are excluded),
# verify:
#   - First line is ---
#   - All 5 frontmatter keys: name, scope, severity, created, updated
#   - Body has ## Rule, ## Why, ## How to apply sections

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ---------------------------------------------------------------------------
# Sandbox / HOME preflight (template discipline)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t scaff-t15)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

RULES="$REPO_ROOT/.claude/rules"

echo "=== t15_rules_schema ==="

# Collect all rule files (in subdirs only, not root-level README/index)
RULE_FILES=""
for subdir in common bash markdown git; do
  if [ -d "$RULES/$subdir" ]; then
    for f in "$RULES/$subdir"/*.md; do
      [ -f "$f" ] || continue
      RULE_FILES="$RULE_FILES $f"
    done
  fi
done

if [ -z "$RULE_FILES" ]; then
  fail "No rule files found under .claude/rules subdirectories"
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

for filepath in $RULE_FILES; do
  relpath="${filepath#$REPO_ROOT/}"
  label="$relpath"

  # Check: first line is ---
  first_line="$(head -1 "$filepath" 2>/dev/null)"
  if [ "$first_line" != "---" ]; then
    fail "$label: first line is not '---' (got: '$first_line')"
    continue
  fi

  # Check: all 5 frontmatter keys present
  key_count="$(grep -c '^name:\|^scope:\|^severity:\|^created:\|^updated:' "$filepath" 2>/dev/null || true)"
  if [ "$key_count" -ge 5 ]; then
    pass "$label: has all 5 frontmatter keys (name, scope, severity, created, updated)"
  else
    fail "$label: missing frontmatter keys (found $key_count/5)"
  fi

  # Check: required body sections
  section_count="$(grep -cE '^## (Rule|Why|How to apply)' "$filepath" 2>/dev/null || true)"
  if [ "$section_count" -ge 3 ]; then
    pass "$label: has required body sections (## Rule, ## Why, ## How to apply)"
  else
    fail "$label: missing required body sections (found $section_count/3)"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
