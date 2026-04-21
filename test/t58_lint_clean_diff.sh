#!/usr/bin/env bash
# test/t58_lint_clean_diff.sh — integration test: clean ASCII diff passes scan-staged
#
# Stages ASCII-only files across .claude/**, .specaffold/features/**, and bin/**
# inside a sandbox git repo, then runs bin/scaff-lint scan-staged.
#
# Assertions (AC5.b, D6 ok-path):
#   1. Exit code 0.
#   2. Stdout emits one ok:<path> line per staged file.
#   3. Stderr is clean or contains only a benign success summary.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script (test-script-path-convention).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINT="$REPO_ROOT/bin/scaff-lint"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1" >&2; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Preflight: lint binary must exist and be executable.
# ---------------------------------------------------------------------------
if [ ! -x "$LINT" ]; then
  echo "FAIL: setup: bin/scaff-lint not found or not executable: $LINT" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Resolve python3 concrete path before HOME changes.
# asdf/pyenv shims consult $HOME for version selection; sandboxing HOME would
# make the shim unable to resolve the runtime. Ask python3 itself for its
# executable path (sys.executable), then prepend that directory to PATH so
# scaff-lint can spawn python3 inside the sandboxed environment.
# ---------------------------------------------------------------------------
PYTHON3_REAL="$(python3 -c 'import sys; print(sys.executable)' 2>/dev/null || true)"
if [ -n "$PYTHON3_REAL" ]; then
  PYTHON3_DIR="$(cd "$(dirname "$PYTHON3_REAL")" && pwd)"
  export PATH="$PYTHON3_DIR:$PATH"
fi

# ---------------------------------------------------------------------------
# Sandbox — HOME isolation (sandbox-home-in-tests.md mandatory preflight).
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t58-test)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight — refuse to run against real HOME.
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Build a minimal sandbox git consumer repo.
# All git operations happen inside this consumer so scaff-lint's
# git rev-parse resolves the consumer, not the source repo
# (consumer-cwd-discipline memory).
# ---------------------------------------------------------------------------
CONSUMER="$SANDBOX/consumer"
mkdir -p "$CONSUMER"

(
  cd "$CONSUMER"
  git init -q
  git config user.email "test@local"
  git config user.name "test"

  # Create ASCII-only fixture files across the three required path namespaces.
  mkdir -p ".claude/rules/common"
  mkdir -p ".specaffold/features/my-feature"
  mkdir -p "bin"

  printf 'ascii-only rules content\n' > ".claude/rules/common/example.md"
  printf 'feature spec content\n'     > ".specaffold/features/my-feature/01-brainstorm.md"
  printf '#!/usr/bin/env bash\necho hello\n' > "bin/helper.sh"

  git add ".claude/rules/common/example.md" \
          ".specaffold/features/my-feature/01-brainstorm.md" \
          "bin/helper.sh"
)

# ---------------------------------------------------------------------------
# Run scaff-lint scan-staged from inside the consumer repo so that
# git rev-parse --show-toplevel resolves to $CONSUMER.
# ---------------------------------------------------------------------------
STAGED_FILES=(
  ".claude/rules/common/example.md"
  ".specaffold/features/my-feature/01-brainstorm.md"
  "bin/helper.sh"
)

STDOUT_LOG="$SANDBOX/stdout.log"
STDERR_LOG="$SANDBOX/stderr.log"

RC=0
(cd "$CONSUMER" && "$LINT" scan-staged) \
  > "$STDOUT_LOG" \
  2> "$STDERR_LOG" \
  || RC=$?

# ---------------------------------------------------------------------------
# Assertion 1: exit code 0 (AC5.b — clean-diff passes).
# ---------------------------------------------------------------------------
if [ "$RC" -eq 0 ]; then
  pass "Check 1: exit code 0"
else
  fail "Check 1: exit code $RC (expected 0)"
fi

# ---------------------------------------------------------------------------
# Assertion 2: stdout contains one ok:<path> line per staged file.
# ---------------------------------------------------------------------------
STDOUT_CONTENT="$(cat "$STDOUT_LOG")"

for f in "${STAGED_FILES[@]}"; do
  case "$STDOUT_CONTENT" in
    *"ok:$f"*)
      pass "Check 2: stdout contains ok:$f"
      ;;
    *)
      fail "Check 2: stdout missing ok:$f (got: $STDOUT_CONTENT)"
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Assertion 3: stderr contains no cjk-hit mention (benign summary only).
# ---------------------------------------------------------------------------
STDERR_CONTENT="$(cat "$STDERR_LOG")"
case "$STDERR_CONTENT" in
  *"cjk-hit"*)
    fail "Check 3: stderr mentions cjk-hit in a clean-diff run (stderr: $STDERR_CONTENT)"
    ;;
  *)
    pass "Check 3: stderr is clean (no cjk-hit)"
    ;;
esac

# ---------------------------------------------------------------------------
# Summary.
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
