#!/usr/bin/env bash
# test/t66_readme_doc_section.sh — STATIC: README "Language preferences" section checks
#
# Verifies:
#   1. README.md contains the section heading "## Language preferences" (exact match).
#   2. That section mentions .spec-workflow/config.yml.
#   3. That section mentions lang.chat.
#   4. That section mentions zh-TW.
#   5. That section contains a YAML block matching the D9 schema shape
#      (lang: on one line followed by "  chat: zh-TW" with 2-space indent).
#   6. Only README.md AND .claude/rules/common/language-preferences.md mention
#      the opt-in concept — no third documentation file duplicates the instructions
#      (AC8.b: one canonical doc surface).
#
# SEQUENCING NOTE: T22 (README edit) lands in parallel in another worktree.
# This test script (T20) is committed first; the test itself runs against README
# post-merge. Acceptance for THIS task is only that the script parses and is
# executable (bash -n + test -x). Running "bash test/t66_readme_doc_section.sh"
# may exit non-zero until T22 merges — that is expected and not gating here.
#
# No sandbox needed: pure grep on static files; no CLI invoked; no HOME writes.
# Bash 3.2 portable: no readlink -f, no mapfile, no [[ =~ ]], no jq.
#
# Usage: bash test/t66_readme_doc_section.sh
# Exits 0 if all checks pass; emits FAIL: <reason> to stderr and exits 1 on failure.

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script — never hardcode worktree paths
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

README="$REPO_ROOT/README.md"
RULE_FILE="$REPO_ROOT/.claude/rules/common/language-preferences.md"

# ---------------------------------------------------------------------------
# Guard: README must exist (T22 not yet merged gives a meaningful message)
# ---------------------------------------------------------------------------
if [ ! -f "$README" ]; then
  echo "FAIL: README.md not found at $README" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 1: section heading "## Language preferences" (exact, grep -F)
# ---------------------------------------------------------------------------
if ! grep -qF '## Language preferences' "$README"; then
  echo "FAIL: README.md missing section heading '## Language preferences'" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 2: section mentions .spec-workflow/config.yml
# ---------------------------------------------------------------------------
if ! grep -qF '.spec-workflow/config.yml' "$README"; then
  echo "FAIL: README.md missing '.spec-workflow/config.yml' in Language preferences section" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 3: section mentions lang.chat
# ---------------------------------------------------------------------------
if ! grep -qF 'lang.chat' "$README"; then
  echo "FAIL: README.md missing 'lang.chat' in Language preferences section" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 4: section mentions zh-TW
# ---------------------------------------------------------------------------
if ! grep -qF 'zh-TW' "$README"; then
  echo "FAIL: README.md missing 'zh-TW' in Language preferences section" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 5: YAML block matches D9 schema shape:
#   lang: on one line immediately followed by "  chat: zh-TW" (2-space indent)
#
# Implementation: scan README line-by-line; when we find a line that is
# exactly "lang:" set a flag; on the very next line check for "  chat: zh-TW".
# Bash 3.2 safe — no [[ =~ ]], no mapfile.
# ---------------------------------------------------------------------------
found_yaml_block=0
prev_lang=0

while IFS= read -r line; do
  if [ $prev_lang -eq 1 ]; then
    case "$line" in
      "  chat: zh-TW"*)
        found_yaml_block=1
        break
        ;;
    esac
    prev_lang=0
  fi
  if [ "$line" = "lang:" ]; then
    prev_lang=1
  fi
done < "$README"

if [ $found_yaml_block -eq 0 ]; then
  echo "FAIL: README.md missing D9 YAML block ('lang:' followed by '  chat: zh-TW')" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 6: AC8.b — only README.md and the rule file mention the opt-in
# concept; no third documentation file duplicates the instructions.
#
# Scope: documentation files only — root-level *.md files plus CLAUDE.md
# if present. Test fixtures and rule files other than language-preferences.md
# are excluded from the "no third file" requirement.
#
# Pattern: 'lang\.chat' or 'lang:' — the canonical opt-in vocabulary.
# (grep -E; escaped dot for literal match.)
# ---------------------------------------------------------------------------
ALLOWED_README="$README"
ALLOWED_RULE="$RULE_FILE"

# Collect root-level .md files (no subdirectory descent — repo-root doc surface)
# plus the one rule file we explicitly allow. Build the list without find -maxdepth
# to stay Bash 3.2 / BSD portable — use a glob via ls piped through a while loop.
extra_hits=""

# Iterate root *.md files
for f in "$REPO_ROOT"/*.md; do
  # Skip if glob returned a literal (no files matched)
  [ -f "$f" ] || continue
  # Allow README.md
  [ "$f" = "$ALLOWED_README" ] && continue
  # Check whether this non-README root doc contains opt-in vocabulary
  if grep -qE 'lang\.chat|lang:' "$f" 2>/dev/null; then
    extra_hits="$extra_hits $f"
  fi
done

# Also check CLAUDE.md at root if it exists (common Claude-project doc surface)
CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
if [ -f "$CLAUDE_MD" ] && [ "$CLAUDE_MD" != "$ALLOWED_README" ]; then
  if grep -qE 'lang\.chat|lang:' "$CLAUDE_MD" 2>/dev/null; then
    extra_hits="$extra_hits $CLAUDE_MD"
  fi
fi

if [ -n "$extra_hits" ]; then
  echo "FAIL: AC8.b — opt-in vocabulary ('lang.chat'/'lang:') found in unexpected doc file(s):$extra_hits" >&2
  exit 1
fi

# Verify the rule file itself exists (T1 dependency)
if [ ! -f "$RULE_FILE" ]; then
  echo "FAIL: rule file $RULE_FILE not found (T1 dependency not yet merged?)" >&2
  exit 1
fi

echo "PASS"
exit 0
