#!/usr/bin/env bash
# test/t91_capability_manifest.sh
#
# T92-cap-test — Seam G: structural test for the Tauri capability manifest.
#
# Parses flow-monitor/src-tauri/capabilities/default.json with python3
# (no jq — bash-32-portability.md) and asserts:
#
#   A. permissions[] contains 4 plain strings:
#        core:default, dialog:default, clipboard-manager:default, notification:default
#   B. permissions[] contains an object with identifier == "shell:allow-execute"
#      whose allow[] has exactly 1 entry with:
#        name == "open-terminal"
#        cmd  == "/usr/bin/open"
#        args beginning with ["-a", "Terminal.app", <regex-validator-object>]
#   C. permissions[] contains identifier == "fs:allow-write-file"
#      with exactly 2 allow entries, targeting audit.log and audit.log.1
#   D. Malformed JSON → exit 2 (fail-loud)
#
# SKIP behaviour:
#   - If shell:allow-execute or fs:allow-write-file blocks are absent
#     (T91 not yet merged), the B and C assertions skip gracefully and
#     exit 0.  A is always asserted (those 4 strings pre-exist T91).
#
# Sandbox-HOME NOT required: this test only reads a repo file and never
# invokes any CLI that expands $HOME.  (plan §167 — explicitly exempt)
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile, [[ =~ ]], GNU-only flags.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

MANIFEST="${MANIFEST:-$REPO_ROOT/flow-monitor/src-tauri/capabilities/default.json}"

# ---------------------------------------------------------------------------
# Input validation — canonicalise MANIFEST and assert path is under REPO_ROOT
# (security: path-traversal on user-supplied env var, rule: input-validation-at-boundaries).
# Uses cd+dirname+pwd-P (BSD-safe; no readlink -f).
# Falls back to raw value when parent dir is absent; sub-test will SKIP on
# [ ! -f ] — boundary check still fires on whatever value is presented.
# ---------------------------------------------------------------------------
_resolve_file_path() {
  local p="$1"
  local dir base resolved_dir
  dir="$(dirname "$p")"
  base="$(basename "$p")"
  if resolved_dir="$(cd "$dir" 2>/dev/null && pwd -P)"; then
    printf '%s/%s\n' "$resolved_dir" "$base"
  else
    printf '%s\n' "$p"
  fi
}

MANIFEST="$(_resolve_file_path "$MANIFEST")"
if [ "${MANIFEST#$REPO_ROOT/}" = "$MANIFEST" ]; then
  printf 'ERROR: MANIFEST must be under %s (got: %s)\n' "$REPO_ROOT" "$MANIFEST" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Preflight — skip gracefully when T91 has not yet been merged
# ---------------------------------------------------------------------------
if [ ! -f "$MANIFEST" ]; then
  printf 'SKIP: %s not found — capabilities/default.json absent; re-run after T91.\n' \
    "$MANIFEST" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
skip() { printf 'SKIP: %s\n' "$1" >&2; SKIP=$((SKIP + 1)); }

# ---------------------------------------------------------------------------
# D. Malformed JSON guard — exit 2 fail-loud; must precede all JSON assertions
# ---------------------------------------------------------------------------
if ! python3 - "$MANIFEST" <<'PYEOF' 2>/dev/null
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        json.load(f)
except (json.JSONDecodeError, ValueError) as e:
    print("MALFORMED JSON: {}".format(e), file=sys.stderr)
    sys.exit(2)
PYEOF
then
  printf 'FAIL: %s contains malformed JSON — exit 2\n' "$MANIFEST" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Read the manifest once into a shell variable (perf: no-re-reading rule)
# ---------------------------------------------------------------------------
MANIFEST_CONTENT="$(cat "$MANIFEST")"

# ---------------------------------------------------------------------------
# A. permissions[] must contain all 4 baseline string permissions
#    These exist before T91 so this assertion is never skipped.
# ---------------------------------------------------------------------------
printf '=== A: baseline string permissions ===\n'

# Batch all 4 string-permission checks into a single python3 invocation
# (perf: avoids spawning 4 separate interpreter processes for 4 checks).
A_RESULTS="$(printf '%s' "$MANIFEST_CONTENT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
perms = data.get('permissions', [])
checks = ['core:default', 'dialog:default', 'clipboard-manager:default', 'notification:default']
for c in checks:
    if c in perms:
        print('PASS:' + c)
    else:
        print('FAIL:' + c)
" 2>/dev/null)"

while IFS= read -r line; do
  case "$line" in
    PASS:*)
      perm="${line#PASS:}"
      pass "A: '$perm' present in permissions[]"
      ;;
    FAIL:*)
      perm="${line#FAIL:}"
      fail "A: '$perm' missing from permissions[]"
      ;;
    *)
      fail "A: unexpected python3 output: '$line'"
      ;;
  esac
done <<EOF
$A_RESULTS
EOF

# ---------------------------------------------------------------------------
# B. shell:allow-execute object — skip if absent (T91 not yet merged)
# ---------------------------------------------------------------------------
printf '\n=== B: shell:allow-execute permission object ===\n'

SHELL_ALLOW_RESULT="$(printf '%s' "$MANIFEST_CONTENT" | python3 -c "
import json, sys

data = json.load(sys.stdin)
perms = data.get('permissions', [])

# Find the shell:allow-execute object
obj = None
for p in perms:
    if isinstance(p, dict) and p.get('identifier') == 'shell:allow-execute':
        obj = p
        break

if obj is None:
    print('SKIP_NOT_FOUND')
    sys.exit(0)

allow = obj.get('allow', [])

# Assert exactly 1 allow entry
if len(allow) != 1:
    print('FAIL_ALLOW_COUNT:{}'.format(len(allow)))
    sys.exit(0)

entry = allow[0]

# Assert name
if entry.get('name') != 'open-terminal':
    print('FAIL_NAME:{}'.format(entry.get('name')))
    sys.exit(0)

# Assert cmd
if entry.get('cmd') != '/usr/bin/open':
    print('FAIL_CMD:{}'.format(entry.get('cmd')))
    sys.exit(0)

# Assert args shape: first 3 entries are '-a', 'Terminal.app', then a dict (regex-validator)
args = entry.get('args', [])
if len(args) < 3:
    print('FAIL_ARGS_LEN:{}'.format(len(args)))
    sys.exit(0)

if args[0] != '-a':
    print('FAIL_ARGS_0:{}'.format(args[0]))
    sys.exit(0)

if args[1] != 'Terminal.app':
    print('FAIL_ARGS_1:{}'.format(args[1]))
    sys.exit(0)

if not isinstance(args[2], dict):
    print('FAIL_ARGS_2_NOT_DICT:{}'.format(type(args[2]).__name__))
    sys.exit(0)

print('PASS')
" 2>/dev/null)"

case "$SHELL_ALLOW_RESULT" in
  SKIP_NOT_FOUND)
    skip "B: shell:allow-execute object not present — T91 not yet merged; re-run post-wave"
    ;;
  PASS)
    pass "B: shell:allow-execute has 1 allow entry: name=open-terminal, cmd=/usr/bin/open, args=[-a, Terminal.app, <validator>]"
    ;;
  FAIL_ALLOW_COUNT:*)
    count="${SHELL_ALLOW_RESULT#FAIL_ALLOW_COUNT:}"
    fail "B: shell:allow-execute allow[] has $count entries — expected exactly 1"
    ;;
  FAIL_NAME:*)
    name="${SHELL_ALLOW_RESULT#FAIL_NAME:}"
    fail "B: shell:allow-execute allow[0].name is '$name' — expected 'open-terminal'"
    ;;
  FAIL_CMD:*)
    cmd="${SHELL_ALLOW_RESULT#FAIL_CMD:}"
    fail "B: shell:allow-execute allow[0].cmd is '$cmd' — expected '/usr/bin/open'"
    ;;
  FAIL_ARGS_LEN:*)
    alen="${SHELL_ALLOW_RESULT#FAIL_ARGS_LEN:}"
    fail "B: shell:allow-execute allow[0].args has $alen entries — expected at least 3"
    ;;
  FAIL_ARGS_0:*)
    v="${SHELL_ALLOW_RESULT#FAIL_ARGS_0:}"
    fail "B: shell:allow-execute allow[0].args[0] is '$v' — expected '-a'"
    ;;
  FAIL_ARGS_1:*)
    v="${SHELL_ALLOW_RESULT#FAIL_ARGS_1:}"
    fail "B: shell:allow-execute allow[0].args[1] is '$v' — expected 'Terminal.app'"
    ;;
  FAIL_ARGS_2_NOT_DICT:*)
    typ="${SHELL_ALLOW_RESULT#FAIL_ARGS_2_NOT_DICT:}"
    fail "B: shell:allow-execute allow[0].args[2] is type '$typ' — expected a dict (regex-validator object)"
    ;;
  *)
    fail "B: unexpected python3 output: '$SHELL_ALLOW_RESULT'"
    ;;
esac

# ---------------------------------------------------------------------------
# C. fs:allow-write-file object — skip if absent (T91 not yet merged)
# ---------------------------------------------------------------------------
printf '\n=== C: fs:allow-write-file permission object ===\n'

FS_ALLOW_RESULT="$(printf '%s' "$MANIFEST_CONTENT" | python3 -c "
import json, sys

data = json.load(sys.stdin)
perms = data.get('permissions', [])

# Find the fs:allow-write-file object
obj = None
for p in perms:
    if isinstance(p, dict) and p.get('identifier') == 'fs:allow-write-file':
        obj = p
        break

if obj is None:
    print('SKIP_NOT_FOUND')
    sys.exit(0)

allow = obj.get('allow', [])

# Assert exactly 2 allow entries
if len(allow) != 2:
    print('FAIL_ALLOW_COUNT:{}'.format(len(allow)))
    sys.exit(0)

# Collect the path values from both entries (expect audit.log and audit.log.1)
# Each entry is expected to be a dict with a 'path' key (may be nested).
# Accept either {'path': 'audit.log'} or {'path': {'value': 'audit.log'}} shapes.
def extract_path(entry):
    p = entry.get('path', '')
    if isinstance(p, dict):
        return p.get('value', '')
    return str(p)

paths = sorted([extract_path(e) for e in allow])

# Normalise: accept relative or filename-only forms ending with audit.log / audit.log.1
def ends_with(s, suffix):
    return s == suffix or s.endswith('/' + suffix)

has_audit_log   = any(ends_with(p, 'audit.log')   for p in paths)
has_audit_log_1 = any(ends_with(p, 'audit.log.1') for p in paths)

if not has_audit_log:
    print('FAIL_MISSING_AUDIT_LOG:{}'.format(','.join(paths)))
    sys.exit(0)

if not has_audit_log_1:
    print('FAIL_MISSING_AUDIT_LOG_1:{}'.format(','.join(paths)))
    sys.exit(0)

print('PASS')
" 2>/dev/null)"

case "$FS_ALLOW_RESULT" in
  SKIP_NOT_FOUND)
    skip "C: fs:allow-write-file object not present — T91 not yet merged; re-run post-wave"
    ;;
  PASS)
    pass "C: fs:allow-write-file has 2 allow entries targeting audit.log and audit.log.1"
    ;;
  FAIL_ALLOW_COUNT:*)
    count="${FS_ALLOW_RESULT#FAIL_ALLOW_COUNT:}"
    fail "C: fs:allow-write-file allow[] has $count entries — expected exactly 2"
    ;;
  FAIL_MISSING_AUDIT_LOG:*)
    paths="${FS_ALLOW_RESULT#FAIL_MISSING_AUDIT_LOG:}"
    fail "C: fs:allow-write-file missing audit.log target — found: $paths"
    ;;
  FAIL_MISSING_AUDIT_LOG_1:*)
    paths="${FS_ALLOW_RESULT#FAIL_MISSING_AUDIT_LOG_1:}"
    fail "C: fs:allow-write-file missing audit.log.1 target — found: $paths"
    ;;
  *)
    fail "C: unexpected python3 output: '$FS_ALLOW_RESULT'"
    ;;
esac

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n=== Results: %d passed, %d failed, %d skipped ===\n' \
  "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
