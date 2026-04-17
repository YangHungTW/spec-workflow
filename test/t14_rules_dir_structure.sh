#!/usr/bin/env bash
# test/t14_rules_dir_structure.sh — verify .claude/rules/ directory layout
# Usage: bash test/t14_rules_dir_structure.sh
# Exits 0 iff all checks pass.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ---------------------------------------------------------------------------
# Sandbox / HOME preflight (template discipline)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t specflow-t14)"
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

echo "=== t14_rules_dir_structure ==="

# Check 1–4: required subdirectories exist
for subdir in common bash markdown git; do
  if [ -d "$RULES/$subdir" ]; then
    pass "Check: .claude/rules/$subdir/ exists"
  else
    fail "Check: .claude/rules/$subdir/ missing"
  fi
done

# Check 5–9: the 5 R3 rule slug filenames are present under their scope subdir
# absolute-symlink-targets -> common
# bash-32-portability      -> bash
# classify-before-mutate   -> common
# no-force-on-user-paths   -> common
# sandbox-home-in-tests    -> bash
RULES_TO_CHECK="\
common/absolute-symlink-targets.md
bash/bash-32-portability.md
common/classify-before-mutate.md
common/no-force-on-user-paths.md
bash/sandbox-home-in-tests.md"

while IFS= read -r relpath; do
  [ -z "$relpath" ] && continue
  filepath="$RULES/$relpath"
  if [ -f "$filepath" ]; then
    pass "Check: .claude/rules/$relpath exists"
  else
    fail "Check: .claude/rules/$relpath missing"
  fi
done <<EOF
$RULES_TO_CHECK
EOF

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
