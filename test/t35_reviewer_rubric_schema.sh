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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t scaff-t35)"
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

  # Single awk pass: extract all needed values from the file in one traversal.
  # Emits labeled key=value lines consumed below.
  awk_out="$(awk '
    BEGIN {
      fm_open=0; fm_done=0; fm_keycount=0
      fm_name=""; fm_scope=""; fm_severity=""
      rule_line=0; why_line=0; apply_line=0; example_line=0
      checklist_count=0; in_apply=0
      dash_count=0
    }
    NR==1 {
      print "first_line=" $0
      if ($0 == "---") { dash_count=1; fm_open=1; next }
      next
    }
    /^---$/ && (fm_open || dash_count==0) {
      dash_count++
      if (dash_count==2) { fm_open=0; fm_done=1; next }
      if (dash_count==1) { fm_open=1; next }
    }
    fm_open {
      if ($0 ~ /^name:/) {
        val=substr($0, 6); gsub(/^ +/, "", val); fm_name=val
        fm_keycount++
      } else if ($0 ~ /^scope:/) {
        val=substr($0, 7); gsub(/^ +/, "", val); fm_scope=val
        fm_keycount++
      } else if ($0 ~ /^severity:/) {
        val=substr($0, 10); gsub(/^ +/, "", val); fm_severity=val
        fm_keycount++
      } else if ($0 ~ /^created:/) {
        fm_keycount++
      } else if ($0 ~ /^updated:/) {
        fm_keycount++
      }
      next
    }
    fm_done {
      if ($0 == "## Rule"         && rule_line==0)  { rule_line=NR }
      if ($0 == "## Why"          && why_line==0)   { why_line=NR }
      if ($0 == "## How to apply" && apply_line==0) { apply_line=NR; in_apply=1; next }
      if ($0 == "## Example"      && example_line==0) { example_line=NR; in_apply=0 }
      if (in_apply) {
        if ($0 ~ /^## /) { in_apply=0 }
        else if ($0 ~ /^[0-9]+\./ || $0 ~ /^[[:space:]]*[-*]/) { checklist_count++ }
      }
    }
    END {
      print "fm_keycount=" fm_keycount
      print "fm_name="     fm_name
      print "fm_scope="    fm_scope
      print "fm_severity=" fm_severity
      print "rule_line="   rule_line
      print "why_line="    why_line
      print "apply_line="  apply_line
      print "example_line=" example_line
      print "checklist_count=" checklist_count
    }
  ' "$filepath")"

  # Parse awk output into shell variables
  first_line=""
  fm_keycount=0
  fm_name=""
  fm_scope=""
  fm_severity=""
  rule_line=0
  why_line=0
  apply_line=0
  example_line=0
  checklist_count=0

  while IFS= read -r awkline; do
    case "$awkline" in
      first_line=*)      first_line="${awkline#first_line=}" ;;
      fm_keycount=*)     fm_keycount="${awkline#fm_keycount=}" ;;
      fm_name=*)         fm_name="${awkline#fm_name=}" ;;
      fm_scope=*)        fm_scope="${awkline#fm_scope=}" ;;
      fm_severity=*)     fm_severity="${awkline#fm_severity=}" ;;
      rule_line=*)       rule_line="${awkline#rule_line=}" ;;
      why_line=*)        why_line="${awkline#why_line=}" ;;
      apply_line=*)      apply_line="${awkline#apply_line=}" ;;
      example_line=*)    example_line="${awkline#example_line=}" ;;
      checklist_count=*) checklist_count="${awkline#checklist_count=}" ;;
    esac
  done <<EOF
$awk_out
EOF

  # 2. Frontmatter: first line must be ---
  if [ "$first_line" != "---" ]; then
    fail "$label: first line is not '---' (got: '$first_line')"
    continue
  fi

  # 3. All 5 required keys present
  if [ "$fm_keycount" -lt 5 ]; then
    fail "$label: frontmatter missing keys (found $fm_keycount/5; need name, scope, severity, created, updated)"
    continue
  fi

  # 4. scope: reviewer
  if [ "$fm_scope" != "reviewer" ]; then
    fail "$label: scope is '$fm_scope', expected 'reviewer'"
    continue
  fi

  # 5. name matches filename stem
  if [ "$fm_name" != "$stem" ]; then
    fail "$label: name is '$fm_name', expected '$stem'"
    continue
  fi

  # 6. severity is one of must|should|avoid
  case "$fm_severity" in
    must|should|avoid) ;;
    *) fail "$label: severity is '$fm_severity', must be one of must|should|avoid"; continue ;;
  esac

  # 7. Body sections exist in correct order: ## Rule, ## Why, ## How to apply, ## Example
  if [ "$rule_line" -eq 0 ] || [ "$why_line" -eq 0 ] || [ "$apply_line" -eq 0 ] || [ "$example_line" -eq 0 ]; then
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
  if [ "$checklist_count" -lt 6 ]; then
    fail "$label: ## How to apply has only $checklist_count checklist entries (need >= 6)"
    continue
  fi

  echo "PASS: $label (scope=reviewer name=$fm_name severity=$fm_severity sections=4 checklist=$checklist_count)"
done

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "PASS"
  exit 0
else
  echo "Results: $FAIL check(s) failed"
  exit 1
fi
