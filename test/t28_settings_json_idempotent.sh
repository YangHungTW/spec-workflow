#!/usr/bin/env bash
# test/t28_settings_json_idempotent.sh — D12 idempotence invariant
# Usage: bash test/t28_settings_json_idempotent.sh
# Exits 0 iff all checks pass.
#
# Scenario: run add twice in a sandbox, assert exactly one SessionStart entry
# in the resulting hooks array (no duplicate groups, no duplicate command fields).

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate script under test (cwd-agnostic)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SCRIPT="$REPO_ROOT/bin/specflow-install-hook"

# ---------------------------------------------------------------------------
# python3 preflight — skip if unavailable (CI-friendly per T22 spec)
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 required"
  exit 0
fi

# ---------------------------------------------------------------------------
# Sandbox setup (sandbox-HOME discipline)
# ---------------------------------------------------------------------------
REAL_HOME="$HOME"
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t28-test)"
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
trap 'rm -rf "$SANDBOX"' EXIT

# Copy tool-version files into sandbox HOME so asdf shims still resolve
# (asdf looks in HOME for ~/.tool-versions; without this, python3 shim fails)
if [ -f "$REAL_HOME/.tool-versions" ]; then
  cp "$REAL_HOME/.tool-versions" "$HOME/.tool-versions"
fi

# Preflight: refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Setup: fresh working directory (no pre-existing settings.json)
# ---------------------------------------------------------------------------
WORK="$SANDBOX/work"
mkdir -p "$WORK"

# ---------------------------------------------------------------------------
# Run add twice
# ---------------------------------------------------------------------------
(cd "$WORK" && "$SCRIPT" add SessionStart .claude/hooks/session-start.sh)
RC1=$?
if [ "$RC1" -ne 0 ]; then
  echo "FAIL: first add exited $RC1 (expected 0)"
  exit 1
fi

(cd "$WORK" && "$SCRIPT" add SessionStart .claude/hooks/session-start.sh)
RC2=$?
if [ "$RC2" -ne 0 ]; then
  echo "FAIL: second add exited $RC2 (expected 0)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Assert: exactly one matching entry in the hooks array
# ---------------------------------------------------------------------------
COUNT="$(python3 - "$WORK/settings.json" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("parse-error: " + str(e))
    sys.exit(1)

session_hooks = d.get("hooks", {}).get("SessionStart", [])
n = sum(
    1
    for g in session_hooks
    for h in g.get("hooks", [])
    if h.get("command") == ".claude/hooks/session-start.sh"
)
print(n)
PY
)"

if [ "$COUNT" = "1" ]; then
  echo "PASS: exactly one SessionStart entry after two adds (idempotent)"
  exit 0
else
  echo "FAIL: expected exactly 1 SessionStart entry, got $COUNT"
  exit 1
fi
