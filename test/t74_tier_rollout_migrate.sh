#!/usr/bin/env bash
# test/t74_tier_rollout_migrate.sh — tests for scripts/tier-rollout-migrate.sh
#
# Covers:
#   - Path-traversal guard: --features-dir outside REPO_ROOT is rejected (exit 2).
#   - .bak clobber warning: when STATUS.md.bak already exists before a run,
#     a warning is emitted to stderr (no silent overwrite).
#   - Dry-run does not mutate files.
#   - Real run: backup created, tier: standard inserted, idempotent second run.
#   - Archived features are not touched.
#   - missing-has-ui features are skipped (script exits 0).
#
# Fixture dirs for real-run tests must live inside REPO_ROOT because the
# path-traversal guard rejects --features-dir paths outside the repo boundary.
# We create a tmp/ subdir under the repo root and remove it on EXIT.
#
# Sandbox-HOME: HOME is sandboxed per sandbox-home-in-tests.md even though
# the script under test does not itself read/write $HOME.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
MIGRATE="${MIGRATE:-$REPO_ROOT/scripts/tier-rollout-migrate.sh}"

# ---------------------------------------------------------------------------
# Sandbox + HOME isolation (sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t specflow-t74)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# Fixture dirs for real-run tests go inside REPO_ROOT (path-traversal guard
# requires --features-dir to be under REPO_ROOT).  A unique tmp subdir keeps
# the worktree clean and is removed by the EXIT trap below.
FIXTURES="$REPO_ROOT/.test-t74-$$"
mkdir -p "$FIXTURES"
# Extend the trap to also clean the in-repo fixtures dir
trap 'rm -rf "$SANDBOX" "$FIXTURES"' EXIT

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# Helper: build a minimal feature dir with STATUS.md (no tier: field)
# ---------------------------------------------------------------------------
make_feature() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/STATUS.md" <<'EOF'
# Status

- **owner**: developer
- **has-ui**: no
- **stage**: implement
EOF
}

# ---------------------------------------------------------------------------
# Test 1: --features-dir outside REPO_ROOT is rejected with exit 2
# (Security must — path-traversal check)
# ---------------------------------------------------------------------------
OUTSIDE_DIR="$SANDBOX/outside-features"
mkdir -p "$OUTSIDE_DIR/some-feature"
make_feature "$OUTSIDE_DIR/some-feature"

if bash "$MIGRATE" --features-dir "$OUTSIDE_DIR" >/dev/null 2>&1; then
  fail "path-traversal guard: expected exit 2 for --features-dir outside REPO_ROOT, got exit 0"
else
  pass "path-traversal guard: --features-dir outside REPO_ROOT rejected"
fi

# ---------------------------------------------------------------------------
# Test 2: --dry-run does not mutate files (uses an in-repo fixture dir)
# ---------------------------------------------------------------------------
DRYRUN_DIR="$FIXTURES/dryrun-features"
mkdir -p "$DRYRUN_DIR/alpha"
make_feature "$DRYRUN_DIR/alpha"

BEFORE_SUM="$(cksum "$DRYRUN_DIR/alpha/STATUS.md")"
bash "$MIGRATE" --dry-run --features-dir "$DRYRUN_DIR" >/dev/null 2>&1 || true
AFTER_SUM="$(cksum "$DRYRUN_DIR/alpha/STATUS.md")"

if [ "$BEFORE_SUM" = "$AFTER_SUM" ]; then
  pass "dry-run: STATUS.md not mutated"
else
  fail "dry-run: STATUS.md was mutated"
fi

if [ ! -f "$DRYRUN_DIR/alpha/STATUS.md.bak" ]; then
  pass "dry-run: no .bak created"
else
  fail "dry-run: .bak created unexpectedly"
fi

# ---------------------------------------------------------------------------
# Test 3: real run inserts tier: standard and creates backup
# ---------------------------------------------------------------------------
REAL_DIR="$FIXTURES/real-features"
mkdir -p "$REAL_DIR/beta"
make_feature "$REAL_DIR/beta"

bash "$MIGRATE" --features-dir "$REAL_DIR" >/dev/null 2>&1

if grep -q '^- \*\*tier\*\*: standard$' "$REAL_DIR/beta/STATUS.md"; then
  pass "real-run: tier: standard inserted"
else
  fail "real-run: tier: standard not found in STATUS.md"
fi

if [ -f "$REAL_DIR/beta/STATUS.md.bak" ]; then
  pass "real-run: .bak created"
else
  fail "real-run: .bak not created"
fi

# Verify no other field changed: new file should have exactly one more line
ORIG_LINES=$(wc -l < "$REAL_DIR/beta/STATUS.md.bak")
NEW_LINES=$(wc -l < "$REAL_DIR/beta/STATUS.md")
EXPECTED_NEW=$((ORIG_LINES + 1))
if [ "$NEW_LINES" -eq "$EXPECTED_NEW" ]; then
  pass "real-run: exactly one line added"
else
  fail "real-run: expected $EXPECTED_NEW lines, got $NEW_LINES"
fi

# ---------------------------------------------------------------------------
# Test 4: idempotent — second run is no-op, .bak unchanged
# ---------------------------------------------------------------------------
BAK_SUM_BEFORE="$(cksum "$REAL_DIR/beta/STATUS.md.bak")"
bash "$MIGRATE" --features-dir "$REAL_DIR" >/dev/null 2>&1
BAK_SUM_AFTER="$(cksum "$REAL_DIR/beta/STATUS.md.bak")"

if [ "$BAK_SUM_BEFORE" = "$BAK_SUM_AFTER" ]; then
  pass "idempotent: .bak unchanged on second run"
else
  fail "idempotent: .bak changed on second run"
fi

# ---------------------------------------------------------------------------
# Test 5: .bak clobber warning — when .bak already exists, warns to stderr
# (Security should — no silent .bak clobber per no-force-on-user-paths.md)
# ---------------------------------------------------------------------------
BAK_DIR="$FIXTURES/bak-features"
mkdir -p "$BAK_DIR/gamma"
make_feature "$BAK_DIR/gamma"
# Pre-seed a .bak file to simulate a previous run
echo "old backup content" > "$BAK_DIR/gamma/STATUS.md.bak"

STDERR_OUT="$SANDBOX/bak_stderr.txt"
bash "$MIGRATE" --features-dir "$BAK_DIR" >/dev/null 2>"$STDERR_OUT" || true

if grep -qi "warning\|overwrite\|exists" "$STDERR_OUT"; then
  pass ".bak clobber: warning emitted to stderr when .bak pre-exists"
else
  fail ".bak clobber: no warning on stderr when pre-existing .bak overwritten (got: $(cat "$STDERR_OUT"))"
fi

# ---------------------------------------------------------------------------
# Test 6: archived features (paths containing /archive/) are NOT touched
# ---------------------------------------------------------------------------
ARCH_BASE="$FIXTURES/arch-test"
FEAT_ROOT="$ARCH_BASE/features"
ARCH_ROOT="$ARCH_BASE/features/archive"
mkdir -p "$FEAT_ROOT/active"
mkdir -p "$ARCH_ROOT/old-feature"
make_feature "$FEAT_ROOT/active"
make_feature "$ARCH_ROOT/old-feature"

bash "$MIGRATE" --features-dir "$FEAT_ROOT" >/dev/null 2>&1

if [ ! -f "$ARCH_ROOT/old-feature/STATUS.md.bak" ]; then
  pass "archive skip: archived feature not touched"
else
  fail "archive skip: archived feature was mutated"
fi

if grep -q '^- \*\*tier\*\*: standard$' "$FEAT_ROOT/active/STATUS.md"; then
  pass "archive skip: active feature was migrated"
else
  fail "archive skip: active feature was not migrated"
fi

# ---------------------------------------------------------------------------
# Test 7: missing-has-ui features are skipped; script exits 0
# ---------------------------------------------------------------------------
SKIP_DIR="$FIXTURES/skip-features"
mkdir -p "$SKIP_DIR/no-has-ui"
cat > "$SKIP_DIR/no-has-ui/STATUS.md" <<'EOF'
# Status

- **owner**: developer
- **stage**: implement
EOF

EXIT_CODE=0
bash "$MIGRATE" --features-dir "$SKIP_DIR" >/dev/null 2>&1 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
  pass "missing-has-ui: script exits 0 (skipped, no errors)"
else
  fail "missing-has-ui: script exited $EXIT_CODE, expected 0"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
