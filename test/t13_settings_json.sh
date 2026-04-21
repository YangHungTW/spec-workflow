#!/usr/bin/env bash
# test/t13_settings_json.sh — verify settings.json at repo root
# Usage: bash test/t13_settings_json.sh
# Exits 0 iff all checks pass.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# ---------------------------------------------------------------------------
# Sandbox / HOME preflight (template discipline — carried even for read-only)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t scaff-t13)"
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

SETTINGS="$REPO_ROOT/settings.json"

echo "=== t13_settings_json ==="

# Check 1: settings.json exists
if [ -f "$SETTINGS" ]; then
  pass "Check 1: settings.json exists at repo root"
else
  fail "Check 1: settings.json not found at $SETTINGS"
fi

# Check 2: valid JSON
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$SETTINGS" 2>/dev/null; then
    pass "Check 2: settings.json is valid JSON (python3)"
  else
    fail "Check 2: settings.json failed JSON parse"
  fi
else
  # Fallback: grep for a basic JSON structure indicator
  if grep -q '{' "$SETTINGS" 2>/dev/null; then
    pass "Check 2: settings.json appears to be JSON (grep fallback — python3 not available)"
  else
    fail "Check 2: settings.json does not look like JSON"
  fi
fi

# Check 3: references session-start.sh
if grep -q 'session-start\.sh' "$SETTINGS" 2>/dev/null; then
  pass "Check 3: settings.json references .claude/hooks/session-start.sh"
else
  fail "Check 3: settings.json does not reference session-start.sh"
fi

# Check 4: has SessionStart key
if grep -q 'SessionStart' "$SETTINGS" 2>/dev/null; then
  pass "Check 4: settings.json contains SessionStart"
else
  fail "Check 4: settings.json missing SessionStart"
fi

# Check 5 (python3 only): hook entry is structurally correct
if command -v python3 >/dev/null 2>&1; then
  RESULT=$(python3 - "$SETTINGS" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
ok = any(
    h.get("command") == ".claude/hooks/session-start.sh"
    for g in d.get("hooks", {}).get("SessionStart", [])
    for h in g.get("hooks", [])
)
print("ok" if ok else "missing")
PY
)
  if [ "$RESULT" = "ok" ]; then
    pass "Check 5: SessionStart hook entry has correct command field"
  else
    fail "Check 5: SessionStart hook entry missing or malformed"
  fi
else
  echo "SKIP: Check 5 (python3 not available)"
  PASS=$((PASS + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
