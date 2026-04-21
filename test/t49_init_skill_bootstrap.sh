#!/usr/bin/env bash
# test/t49_init_skill_bootstrap.sh — STATIC: verify scaff-init skill footprint
# R3 AC3.b: exactly two files, correct frontmatter shape, README bootstrap doc.
# No CLI invoked — no sandbox-HOME required; this is a read-only structural check.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SKILL="$REPO_ROOT/.claude/skills/scaff-init"

# ---------------------------------------------------------------------------
# Check 1: SKILL.md present
# ---------------------------------------------------------------------------
if [ ! -f "$SKILL/SKILL.md" ]; then
  echo "FAIL: SKILL.md missing" >&2; exit 1
fi

# ---------------------------------------------------------------------------
# Check 2: init.sh present and executable
# ---------------------------------------------------------------------------
if [ ! -f "$SKILL/init.sh" ]; then
  echo "FAIL: init.sh missing" >&2; exit 1
fi
if [ ! -x "$SKILL/init.sh" ]; then
  echo "FAIL: init.sh not executable" >&2; exit 1
fi

# ---------------------------------------------------------------------------
# Check 3: SKILL.md frontmatter shape
# The first line must be '---', subsequent lines within the block must contain
# 'name: scaff-init' and 'description:', and the block must close with a
# second '---' before the body.  Using awk to avoid [[ =~ ]] regex.
# ---------------------------------------------------------------------------
has_open=0
has_name=0
has_desc=0
has_close=0
line_no=0

while IFS= read -r line; do
  line_no=$((line_no + 1))
  if [ $line_no -eq 1 ]; then
    if [ "$line" = "---" ]; then
      has_open=1
    else
      echo "FAIL: SKILL.md first line is not '---'" >&2; exit 1
    fi
    continue
  fi
  # Once we have the open fence look for name/desc and the closing fence
  if [ $has_open -eq 1 ] && [ $has_close -eq 0 ]; then
    case "$line" in
      "name: scaff-init"*) has_name=1 ;;
      "description:"*) has_desc=1 ;;
      "---") has_close=1 ;;
    esac
  fi
  # Stop scanning after the first 20 lines — body should not matter here
  [ $line_no -ge 20 ] && break
done < "$SKILL/SKILL.md"

if [ $has_name -eq 0 ]; then
  echo "FAIL: SKILL.md frontmatter missing 'name: scaff-init'" >&2; exit 1
fi
if [ $has_desc -eq 0 ]; then
  echo "FAIL: SKILL.md frontmatter missing 'description:' key" >&2; exit 1
fi
if [ $has_close -eq 0 ]; then
  echo "FAIL: SKILL.md frontmatter closing '---' not found in first 20 lines" >&2; exit 1
fi

# ---------------------------------------------------------------------------
# Check 4: init.sh is syntactically valid bash
# ---------------------------------------------------------------------------
if ! bash -n "$SKILL/init.sh" 2>/dev/null; then
  echo "FAIL: bash -n init.sh failed — syntax error in init.sh" >&2; exit 1
fi

# ---------------------------------------------------------------------------
# Check 5: exactly two files in the skill directory (no stray fixtures)
# Bounding the footprint prevents accidental data file or fixture creep.
# ---------------------------------------------------------------------------
file_count="$(find "$SKILL" -type f | wc -l | tr -d ' ')"
if [ "$file_count" != "2" ]; then
  echo "FAIL: expected exactly 2 files under $SKILL, found $file_count" >&2; exit 1
fi

# ---------------------------------------------------------------------------
# Check 6: README.md documents the cp -R bootstrap command
# T20 lands in the same wave; this check will be RED until T20 merges.
# ---------------------------------------------------------------------------
if ! grep -q 'cp -R.*\.claude/skills/scaff-init.*~/.claude/skills/' "$REPO_ROOT/README.md"; then
  echo "FAIL: README.md missing cp -R bootstrap line for scaff-init" >&2; exit 1
fi

echo PASS
exit 0
