#!/usr/bin/env bash
# test/t35_reviewer_rubric_schema.sh — validate frontmatter schema for reviewer rubric files
# Usage: bash test/t35_reviewer_rubric_schema.sh
# Exits 0 iff all checks pass; FAIL: <file>: <reason> on miss.
#
# For each of security.md, performance.md, style.md under .claude/rules/reviewer/:
#   - File exists
#   - Frontmatter has 5 required keys: name, scope, severity, created, updated
#   - scope: reviewer
#   - name matches filename stem
#   - severity is one of must|should|avoid
#   - 4 body sections in order: ## Rule, ## Why, ## How to apply, ## Example
#   - >= 6 checklist entries (numbered or bulleted) in ## How to apply block

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ---------------------------------------------------------------------------
# Sandbox / HOME preflight (sandbox-home-in-tests rule — NON-NEGOTIABLE)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t specflow-t35)"
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
FAIL=0

fail() {
  echo "FAIL: $1"
  FAIL=$((FAIL + 1))
}

REVIEWER_DIR="$REPO_ROOT/.claude/rules/reviewer"
RUBRICS="security performance style"

echo "=== t35_reviewer_rubric_schema ==="

for stem in $RUBRICS; do
  filepath="$REVIEWER_DIR/${stem}.md"
  label="${stem}.md"

  # 1. File exists
  if [ ! -f "$filepath" ]; then
    fail "$label: file not found at $filepath"
    continue
  fi

  # 2. Frontmatter: first line must be ---
  first_line="$(head -1 "$filepath" 2>/dev/null)"
  if [ "$first_line" != "---" ]; then
    fail "$label: first line is not '---' (got: '$first_line')"
    continue
  fi

  # Extract frontmatter block (between first and second ---)
  frontmatter="$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$filepath")"

  # 3. All 5 required keys present
  key_count=0
  for key in name scope severity created updated; do
    if printf '%s\n' "$frontmatter" | grep -q "^${key}:"; then
      key_count=$((key_count + 1))
    fi
  done
  if [ "$key_count" -lt 5 ]; then
    fail "$label: frontmatter missing keys (found $key_count/5; need name, scope, severity, created, updated)"
    continue
  fi

  # 4. scope: reviewer
  scope_val="$(printf '%s\n' "$frontmatter" | awk '/^scope:/{print; exit}' | sed 's/^scope: *//')"
  if [ "$scope_val" != "reviewer" ]; then
    fail "$label: scope is '$scope_val', expected 'reviewer'"
    continue
  fi

  # 5. name matches filename stem
  name_val="$(printf '%s\n' "$frontmatter" | awk '/^name:/{print; exit}' | sed 's/^name: *//')"
  if [ "$name_val" != "$stem" ]; then
    fail "$label: name is '$name_val', expected '$stem'"
    continue
  fi

  # 6. severity is one of must|should|avoid
  sev_val="$(printf '%s\n' "$frontmatter" | awk '/^severity:/{print; exit}' | sed 's/^severity: *//')"
  case "$sev_val" in
    must|should|avoid) ;;
    *) fail "$label: severity is '$sev_val', must be one of must|should|avoid"; continue ;;
  esac

  # 7. Body sections exist in correct order: ## Rule, ## Why, ## How to apply, ## Example
  # Extract line numbers of each required heading
  rule_line="$(grep -n '^## Rule$' "$filepath" | head -1 | cut -d: -f1)"
  why_line="$(grep -n '^## Why$' "$filepath" | head -1 | cut -d: -f1)"
  apply_line="$(grep -n '^## How to apply$' "$filepath" | head -1 | cut -d: -f1)"
  example_line="$(grep -n '^## Example$' "$filepath" | head -1 | cut -d: -f1)"

  if [ -z "$rule_line" ] || [ -z "$why_line" ] || [ -z "$apply_line" ] || [ -z "$example_line" ]; then
    fail "$label: missing one or more required body sections (need ## Rule, ## Why, ## How to apply, ## Example)"
    continue
  fi

  # Check order: rule < why < apply < example
  order_ok=1
  if [ "$rule_line" -ge "$why_line" ]; then order_ok=0; fi
  if [ "$why_line" -ge "$apply_line" ]; then order_ok=0; fi
  if [ "$apply_line" -ge "$example_line" ]; then order_ok=0; fi
  if [ "$order_ok" -eq 0 ]; then
    fail "$label: body sections out of order (lines: Rule=$rule_line Why=$why_line 'How to apply'=$apply_line Example=$example_line)"
    continue
  fi

  # 8. >= 6 checklist entries in ## How to apply block
  # Extract the block between ## How to apply and the next ## heading
  checklist_count="$(awk '/^## How to apply$/{flag=1; next} /^## /{flag=0} flag' "$filepath" | grep -cE '^[0-9]+\.|^[[:space:]]*[-*]' || true)"
  if [ "$checklist_count" -lt 6 ]; then
    fail "$label: ## How to apply has only $checklist_count checklist entries (need >= 6)"
    continue
  fi

  echo "PASS: $label (scope=reviewer name=$name_val severity=$sev_val sections=4 checklist=$checklist_count)"
done

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "Results: $FAIL check(s) failed"
  exit 1
fi
