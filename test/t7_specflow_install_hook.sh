#!/usr/bin/env bash
# test/t7_scaff_install_hook.sh — T7 verify checks for bin/scaff-install-hook
# Usage: bash test/t7_scaff_install_hook.sh
# Exits 0 iff all 7 checks pass; exits non-zero on first failure.
#
# Checks:
#   1. bash -n bin/scaff-install-hook exits 0 (syntax clean)
#   2. test -x bin/scaff-install-hook (exec bit set)
#   3. no-args invocation exits 2 with usage
#   4. sandbox add: creates settings.json with expected hook entry
#   5. idempotence: running add twice yields exactly one matching entry
#   6. preservation: unrelated keys (permissions, env) survive an add
#   7. .bak exists after any add/remove that mutates

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate the script under test (resolve relative to this test file's dir)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SCRIPT="$REPO_ROOT/bin/scaff-install-hook"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Preflight: sandbox (scaff-install-hook operates on CWD, not HOME;
# we mktemp -d sandbox dirs per-check so the real settings.json is never
# touched — no HOME override needed here)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t scaff-hook-test)"
trap 'rm -rf "$SANDBOX"' EXIT

# ---------------------------------------------------------------------------
# Check 1: bash -n syntax
# ---------------------------------------------------------------------------
if bash -n "$SCRIPT" 2>/dev/null; then
  pass "Check 1: bash -n syntax clean"
else
  fail "Check 1: bash -n reported syntax error"
fi

# ---------------------------------------------------------------------------
# Check 2: exec bit
# ---------------------------------------------------------------------------
if test -x "$SCRIPT"; then
  pass "Check 2: exec bit set"
else
  fail "Check 2: exec bit not set"
fi

# ---------------------------------------------------------------------------
# Check 3: no-args exits 2
# ---------------------------------------------------------------------------
"$SCRIPT" >/dev/null 2>&1
RC=$?
if [ "$RC" -eq 2 ]; then
  pass "Check 3: no-args exits 2"
else
  fail "Check 3: no-args exited $RC (expected 2)"
fi

# ---------------------------------------------------------------------------
# Check 4: sandbox add creates settings.json with the hook entry
# ---------------------------------------------------------------------------
SB4="$SANDBOX/sb4"
mkdir -p "$SB4"
(cd "$SB4" && "$SCRIPT" add SessionStart .claude/hooks/session-start.sh) 2>/dev/null
if [ ! -f "$SB4/settings.json" ]; then
  fail "Check 4: settings.json not created"
else
  if python3 - "$SB4/settings.json" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
assert any(
    h.get("command") == ".claude/hooks/session-start.sh"
    for g in d["hooks"]["SessionStart"]
    for h in g.get("hooks", [])
), "hook entry not found"
print("ok")
PY
  then
    pass "Check 4: settings.json contains expected hook entry"
  else
    fail "Check 4: settings.json missing expected hook entry"
  fi
fi

# ---------------------------------------------------------------------------
# Check 5: idempotence — run add twice, expect exactly one matching entry
# ---------------------------------------------------------------------------
SB5="$SANDBOX/sb5"
mkdir -p "$SB5"
(cd "$SB5" && "$SCRIPT" add SessionStart .claude/hooks/session-start.sh) 2>/dev/null
(cd "$SB5" && "$SCRIPT" add SessionStart .claude/hooks/session-start.sh) 2>/dev/null
COUNT=$(python3 - "$SB5/settings.json" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
n = sum(
    1
    for g in d["hooks"]["SessionStart"]
    for h in g.get("hooks", [])
    if h.get("command") == ".claude/hooks/session-start.sh"
)
print(n)
PY
)
if [ "$COUNT" = "1" ]; then
  pass "Check 5: idempotence — exactly one entry after two adds"
else
  fail "Check 5: idempotence — expected 1 entry, got $COUNT"
fi

# ---------------------------------------------------------------------------
# Check 6: preservation — unrelated keys survive an add
# ---------------------------------------------------------------------------
SB6="$SANDBOX/sb6"
mkdir -p "$SB6"
cat > "$SB6/settings.json" <<'JSON'
{"permissions":{"allow":["Bash(ls:*)"]},"env":{"FOO":"bar"}}
JSON
(cd "$SB6" && "$SCRIPT" add SessionStart .claude/hooks/session-start.sh) 2>/dev/null
PRESERVED=$(python3 - "$SB6/settings.json" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("permissions", {}).get("allow") == ["Bash(ls:*)"], "permissions.allow lost"
assert d.get("env", {}).get("FOO") == "bar", "env.FOO lost"
# also assert hook entry present
assert any(
    h.get("command") == ".claude/hooks/session-start.sh"
    for g in d["hooks"]["SessionStart"]
    for h in g.get("hooks", [])
), "hook entry missing"
print("ok")
PY
)
if [ "$PRESERVED" = "ok" ]; then
  pass "Check 6: unrelated keys (permissions, env) preserved after add"
else
  fail "Check 6: unrelated keys NOT preserved (got: $PRESERVED)"
fi

# ---------------------------------------------------------------------------
# Check 7: .bak exists after add/remove that mutates
# ---------------------------------------------------------------------------
SB7="$SANDBOX/sb7"
mkdir -p "$SB7"
(cd "$SB7" && "$SCRIPT" add SessionStart .claude/hooks/session-start.sh) 2>/dev/null
if [ -f "$SB7/settings.json.bak" ]; then
  pass "Check 7: settings.json.bak exists after add"
else
  fail "Check 7: settings.json.bak missing after add"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
