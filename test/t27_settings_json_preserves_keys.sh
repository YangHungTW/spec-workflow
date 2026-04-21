#!/usr/bin/env bash
# test/t27_settings_json_preserves_keys.sh — D12 key-preservation invariant
# Usage: bash test/t27_settings_json_preserves_keys.sh
# Exits 0 iff all checks pass.
#
# Scenario: seed settings.json with unrelated keys, run add, assert keys survive
# AND the SessionStart entry is present.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate script under test (cwd-agnostic)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SCRIPT="$REPO_ROOT/bin/scaff-install-hook"

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
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t27-test)"
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
# Setup: create a sandbox settings.json dir with pre-seeded unrelated keys
# ---------------------------------------------------------------------------
WORK="$SANDBOX/work"
mkdir -p "$WORK"
cat > "$WORK/settings.json" <<'JSON'
{"permissions":{"allow":["Bash(ls:*)"]},"env":{"FOO":"bar"}}
JSON

# ---------------------------------------------------------------------------
# RED check: run the installer
# ---------------------------------------------------------------------------
(cd "$WORK" && "$SCRIPT" add SessionStart .claude/hooks/session-start.sh)
RC=$?
if [ "$RC" -ne 0 ]; then
  echo "FAIL: scaff-install-hook exited $RC (expected 0)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Assert: permissions.allow and env.FOO survive AND SessionStart entry present
# ---------------------------------------------------------------------------
RESULT="$(python3 - "$WORK/settings.json" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("parse-error: " + str(e))
    sys.exit(1)

# Check unrelated keys preserved
allow = d.get("permissions", {}).get("allow")
if allow != ["Bash(ls:*)"]:
    print("FAIL: permissions.allow lost or changed: " + repr(allow))
    sys.exit(1)

foo = d.get("env", {}).get("FOO")
if foo != "bar":
    print("FAIL: env.FOO lost or changed: " + repr(foo))
    sys.exit(1)

# Check SessionStart hook entry present
session_hooks = d.get("hooks", {}).get("SessionStart", [])
found = any(
    h.get("command") == ".claude/hooks/session-start.sh"
    for g in session_hooks
    for h in g.get("hooks", [])
)
if not found:
    print("FAIL: SessionStart hook entry not present")
    sys.exit(1)

print("ok")
PY
)"

if [ "$RESULT" = "ok" ]; then
  echo "PASS: permissions.allow and env.FOO preserved; SessionStart entry present"
  exit 0
else
  echo "FAIL: $RESULT"
  exit 1
fi
