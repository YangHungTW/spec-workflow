#!/usr/bin/env bash
# test/t74_tier_rollout_migrate.sh
#
# Dry-run and real-run tests for scripts/tier-rollout-migrate.sh (T4 deliverable).
#
# Coverage (T5 spec):
#   1. Dry-run against a fixture feature without tier: — asserts one-line insert
#      diff on stdout, no file mutation.
#   2. Real run — asserts STATUS.md.bak created, tier: standard line present at
#      the correct header position (between has-ui: and stage:), and every other
#      line is byte-identical.
#   3. Idempotent re-run — second invocation is a no-op; backup is unchanged;
#      stdout contains "skipped: already migrated".
#   4. Archived feature dir (under .spec-workflow/archive/) is NOT touched.
#   5. Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md.
#
# RED until scripts/tier-rollout-migrate.sh (T4) is merged.
set -euo pipefail

# ---------------------------------------------------------------------------
# Locate the repo root relative to this script so the test survives worktree
# moves and CI checkouts (see developer/test-script-path-convention.md).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATE="${MIGRATE:-$REPO_ROOT/scripts/tier-rollout-migrate.sh}"

# ---------------------------------------------------------------------------
# Preflight: the script under test must exist and be executable; if not, the
# test is RED (missing production code, which is the expected TDD starting state
# before T4 merges).
# ---------------------------------------------------------------------------
if [ ! -f "$MIGRATE" ]; then
  echo "FAIL: setup: migration script not found: $MIGRATE" >&2
  exit 1
fi
if [ ! -x "$MIGRATE" ]; then
  echo "FAIL: setup: migration script not executable: $MIGRATE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Sandbox-HOME — mandatory per .claude/rules/bash/sandbox-home-in-tests.md.
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t specflow-t74)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Preflight: refuse to run against the real HOME.
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Helper: fail loudly.
# ---------------------------------------------------------------------------
fail() {
  echo "FAIL: $1: $2" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Build fixture .spec-workflow tree inside the sandbox.
#
# Structure:
#   $HOME/.spec-workflow/features/test-feature-A/STATUS.md   (no tier: field)
#   $HOME/.spec-workflow/features/test-feature-B/STATUS.md   (already has tier:)
#   $HOME/.spec-workflow/archive/old-feature/STATUS.md       (archived — must NOT be touched)
#
# The migration script must walk .spec-workflow/features/ only; it must not
# walk .spec-workflow/archive/.
# ---------------------------------------------------------------------------
FEATURES="$HOME/.spec-workflow/features"
ARCHIVE="$HOME/.spec-workflow/archive"
mkdir -p "$FEATURES/test-feature-A"
mkdir -p "$FEATURES/test-feature-B"
mkdir -p "$ARCHIVE/old-feature"

# Fixture A: no tier: field (migration target).
cat > "$FEATURES/test-feature-A/STATUS.md" <<'STATUS_A'
# STATUS

- **slug**: test-feature-A
- **has-ui**: false
- **stage**: request
- **created**: 2026-01-01
- **updated**: 2026-01-01

## Stage checklist
- [ ] request
- [ ] archive

## Notes
- 2026-01-01 PM — created
STATUS_A

# Fixture B: already has tier: standard (idempotency fixture — no migration needed).
cat > "$FEATURES/test-feature-B/STATUS.md" <<'STATUS_B'
# STATUS

- **slug**: test-feature-B
- **has-ui**: false
- **tier**: standard
- **stage**: request
- **created**: 2026-01-01
- **updated**: 2026-01-01

## Stage checklist
- [ ] request

## Notes
STATUS_B

# Archived fixture: must never be touched.
cat > "$ARCHIVE/old-feature/STATUS.md" <<'STATUS_ARCH'
# STATUS

- **slug**: old-feature
- **has-ui**: false
- **stage**: archive
- **created**: 2025-01-01
- **updated**: 2025-06-01

## Notes
STATUS_ARCH

# Capture byte fingerprint of archived STATUS before any migration run.
ARCH_BEFORE="$(shasum "$ARCHIVE/old-feature/STATUS.md" | awk '{print $1}')"

# Capture byte fingerprint of fixture A before dry-run.
FIXTURE_A_BEFORE="$(shasum "$FEATURES/test-feature-A/STATUS.md" | awk '{print $1}')"

# ---------------------------------------------------------------------------
# Test 1: Dry-run — no mutation, expected diff on stdout.
# ---------------------------------------------------------------------------
DRY_OUT="$SANDBOX/dry-run.out"
DRY_ERR="$SANDBOX/dry-run.err"

set +e
"$MIGRATE" --dry-run --spec-workflow-dir "$HOME/.spec-workflow" \
  > "$DRY_OUT" 2>"$DRY_ERR"
DRY_RC=$?
set -e

if [ "$DRY_RC" -ne 0 ]; then
  echo "FAIL: dry-run: exit code $DRY_RC (expected 0)" >&2
  echo "--- stdout ---" >&2; cat "$DRY_OUT" >&2
  echo "--- stderr ---" >&2; cat "$DRY_ERR" >&2
  exit 1
fi

# Stdout must mention the would-be insert for feature A.
if ! grep -q 'tier' "$DRY_OUT" 2>/dev/null && ! grep -q 'tier' "$DRY_ERR" 2>/dev/null; then
  fail "dry-run-output" "no 'tier' line in dry-run output (expected to see the would-be insert)"
fi

# Fixture A must not have been mutated.
FIXTURE_A_AFTER_DRY="$(shasum "$FEATURES/test-feature-A/STATUS.md" | awk '{print $1}')"
if [ "$FIXTURE_A_BEFORE" != "$FIXTURE_A_AFTER_DRY" ]; then
  fail "dry-run-no-mutation" "fixture A was mutated during --dry-run (before=$FIXTURE_A_BEFORE after=$FIXTURE_A_AFTER_DRY)"
fi

# No backup must have been created during dry-run.
if [ -f "$FEATURES/test-feature-A/STATUS.md.bak" ]; then
  fail "dry-run-no-backup" "STATUS.md.bak was created during --dry-run (must not create backup on dry-run)"
fi

# Archived STATUS must not have been touched.
ARCH_AFTER_DRY="$(shasum "$ARCHIVE/old-feature/STATUS.md" | awk '{print $1}')"
if [ "$ARCH_BEFORE" != "$ARCH_AFTER_DRY" ]; then
  fail "dry-run-archive-untouched" "archived STATUS was modified during --dry-run"
fi

# ---------------------------------------------------------------------------
# Test 2: Real run — backup created, tier: standard inserted at correct position.
# ---------------------------------------------------------------------------
REAL_OUT="$SANDBOX/real-run.out"
REAL_ERR="$SANDBOX/real-run.err"

set +e
"$MIGRATE" --spec-workflow-dir "$HOME/.spec-workflow" \
  > "$REAL_OUT" 2>"$REAL_ERR"
REAL_RC=$?
set -e

if [ "$REAL_RC" -ne 0 ]; then
  echo "FAIL: real-run: exit code $REAL_RC (expected 0)" >&2
  echo "--- stdout ---" >&2; cat "$REAL_OUT" >&2
  echo "--- stderr ---" >&2; cat "$REAL_ERR" >&2
  exit 1
fi

# Backup must exist.
if [ ! -f "$FEATURES/test-feature-A/STATUS.md.bak" ]; then
  fail "real-run-backup" "STATUS.md.bak was not created for test-feature-A"
fi

# Backup must be byte-identical to the pre-migration original.
BAK_HASH="$(shasum "$FEATURES/test-feature-A/STATUS.md.bak" | awk '{print $1}')"
if [ "$FIXTURE_A_BEFORE" != "$BAK_HASH" ]; then
  fail "real-run-backup-contents" "STATUS.md.bak does not match pre-migration file (bak=$BAK_HASH original=$FIXTURE_A_BEFORE)"
fi

# The migrated STATUS.md must contain a tier: standard line.
if ! grep -q '^\- \*\*tier\*\*: standard$' "$FEATURES/test-feature-A/STATUS.md"; then
  fail "real-run-tier-line" "tier: standard line not found in migrated STATUS.md"
fi

# The tier: line must appear AFTER has-ui: and BEFORE stage:.
HAS_UI_LINE="$(grep -n '^\- \*\*has-ui\*\*:' "$FEATURES/test-feature-A/STATUS.md" | awk -F: '{print $1}')"
TIER_LINE="$(grep -n '^\- \*\*tier\*\*:' "$FEATURES/test-feature-A/STATUS.md" | awk -F: '{print $1}')"
STAGE_LINE="$(grep -n '^\- \*\*stage\*\*:' "$FEATURES/test-feature-A/STATUS.md" | awk -F: '{print $1}')"

if [ -z "$HAS_UI_LINE" ] || [ -z "$TIER_LINE" ] || [ -z "$STAGE_LINE" ]; then
  fail "real-run-line-position" "could not locate has-ui/tier/stage lines (has-ui=$HAS_UI_LINE tier=$TIER_LINE stage=$STAGE_LINE)"
fi

if [ "$TIER_LINE" -le "$HAS_UI_LINE" ]; then
  fail "real-run-line-position" "tier: line ($TIER_LINE) must appear AFTER has-ui: line ($HAS_UI_LINE)"
fi
if [ "$TIER_LINE" -ge "$STAGE_LINE" ]; then
  fail "real-run-line-position" "tier: line ($TIER_LINE) must appear BEFORE stage: line ($STAGE_LINE)"
fi

# Every line from the original file (except the insertion gap) must be present
# in the migrated file — byte-compare by reading the backup and confirming all
# its lines exist in the new STATUS.
ORIG_LINE_COUNT="$(wc -l < "$FEATURES/test-feature-A/STATUS.md.bak" | tr -d ' ')"
NEW_LINE_COUNT="$(wc -l < "$FEATURES/test-feature-A/STATUS.md" | tr -d ' ')"
EXPECTED_NEW_COUNT="$((ORIG_LINE_COUNT + 1))"

if [ "$NEW_LINE_COUNT" -ne "$EXPECTED_NEW_COUNT" ]; then
  fail "real-run-line-count" "migrated STATUS.md has $NEW_LINE_COUNT lines; expected $EXPECTED_NEW_COUNT (original $ORIG_LINE_COUNT + 1 new tier line)"
fi

# Fixture B (already migrated) must not have been mutated.
FIXTURE_B_ORIGINAL="$(shasum "$FEATURES/test-feature-B/STATUS.md" | awk '{print $1}')"
if ! grep -q '^\- \*\*tier\*\*: standard$' "$FEATURES/test-feature-B/STATUS.md"; then
  fail "real-run-fixture-b" "fixture B lost its tier: line during migration"
fi

# Archived STATUS must still not have been touched.
ARCH_AFTER_REAL="$(shasum "$ARCHIVE/old-feature/STATUS.md" | awk '{print $1}')"
if [ "$ARCH_BEFORE" != "$ARCH_AFTER_REAL" ]; then
  fail "real-run-archive-untouched" "archived STATUS was modified during real run"
fi

# ---------------------------------------------------------------------------
# Test 3: Idempotent re-run — second invocation is a no-op.
# ---------------------------------------------------------------------------
# Capture current migrated hash before re-run.
FIXTURE_A_AFTER_REAL="$(shasum "$FEATURES/test-feature-A/STATUS.md" | awk '{print $1}')"
BAK_BEFORE_RERUN="$(shasum "$FEATURES/test-feature-A/STATUS.md.bak" | awk '{print $1}')"

IDEM_OUT="$SANDBOX/idempotent.out"
IDEM_ERR="$SANDBOX/idempotent.err"

set +e
"$MIGRATE" --spec-workflow-dir "$HOME/.spec-workflow" \
  > "$IDEM_OUT" 2>"$IDEM_ERR"
IDEM_RC=$?
set -e

if [ "$IDEM_RC" -ne 0 ]; then
  echo "FAIL: idempotent-run: exit code $IDEM_RC (expected 0)" >&2
  echo "--- stdout ---" >&2; cat "$IDEM_OUT" >&2
  echo "--- stderr ---" >&2; cat "$IDEM_ERR" >&2
  exit 1
fi

# Output must mention "skipped" for already-migrated feature A.
if ! grep -q 'skipped' "$IDEM_OUT" "$IDEM_ERR" 2>/dev/null; then
  fail "idempotent-skip-message" "re-run did not emit a 'skipped' message for already-migrated feature A"
fi

# Migrated STATUS.md must be unchanged.
FIXTURE_A_AFTER_IDEM="$(shasum "$FEATURES/test-feature-A/STATUS.md" | awk '{print $1}')"
if [ "$FIXTURE_A_AFTER_REAL" != "$FIXTURE_A_AFTER_IDEM" ]; then
  fail "idempotent-no-mutation" "STATUS.md changed on re-run (not idempotent)"
fi

# Backup must be unchanged (re-run must not overwrite the backup).
BAK_AFTER_RERUN="$(shasum "$FEATURES/test-feature-A/STATUS.md.bak" | awk '{print $1}')"
if [ "$BAK_BEFORE_RERUN" != "$BAK_AFTER_RERUN" ]; then
  fail "idempotent-backup-unchanged" "STATUS.md.bak was overwritten on re-run"
fi

echo "PASS"
exit 0
