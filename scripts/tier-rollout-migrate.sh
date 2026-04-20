#!/usr/bin/env bash
# scripts/tier-rollout-migrate.sh
#
# One-shot W0 migration: adds `- **tier**: standard` to every in-flight
# feature STATUS.md that is missing the tier: field.
#
# Usage:
#   bash scripts/tier-rollout-migrate.sh [--dry-run] [--features-dir <dir>]
#
# Options:
#   --dry-run        Print what would change without mutating any files; exit 0.
#   --features-dir   Path to the features root (default: auto-detected from
#                    repo root as .spec-workflow/features).
#
# Exit codes:
#   0  All done (all skipped or all migrated, or dry-run completed).
#   2  Unexpected diff after a write, OR one or more features failed to build
#      migrated content (full pass completes before exiting).
#
# Idempotent: STATUS files that already contain a `tier:` field are skipped.
# Archive directory (.spec-workflow/archive/) is never walked.
#
# Backup discipline (no-force-on-user-paths.md):
#   Before each real write, the original STATUS.md is copied to STATUS.md.bak.
#   If STATUS.md.bak already exists it is overwritten with the pre-mutation
#   content (the backup always reflects the state just before THIS run; the
#   old .bak is a previous run's safety copy and is superseded).
#
# Atomic write (classify-before-mutate.md + no-force-on-user-paths.md):
#   New content is written to a .tmp file beside the target and renamed into
#   place, so the live file is never partially written.

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
DRY_RUN=0
FEATURES_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --features-dir)
      if [ $# -lt 2 ]; then
        echo "ERROR: --features-dir requires a path argument" >&2
        exit 2
      fi
      FEATURES_DIR="$2"
      shift 2
      ;;
    --features-dir=*)
      FEATURES_DIR="${1#--features-dir=}"
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Locate the repo root (the directory containing .spec-workflow/) relative to
# this script's own location — works from any cwd and survives worktree moves.
# Never uses readlink -f (GNU-only); uses cd + pwd -P (BSD-safe).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

if [ -z "$FEATURES_DIR" ]; then
  FEATURES_DIR="$REPO_ROOT/.spec-workflow/features"
fi

if [ ! -d "$FEATURES_DIR" ]; then
  echo "ERROR: features directory not found: $FEATURES_DIR" >&2
  exit 2
fi

# Resolve to a canonical absolute path (BSD-safe: cd + pwd -P, no readlink -f).
# Then enforce that the resolved path sits inside REPO_ROOT — this prevents a
# caller from passing ../../ or an unrelated absolute path to escape the repo
# boundary (security: path-traversal on user-supplied --features-dir).
FEATURES_DIR="$(cd "$FEATURES_DIR" && pwd -P)"
case "$FEATURES_DIR" in
  "$REPO_ROOT"/*)
    ;;
  *)
    echo "ERROR: --features-dir must be inside $REPO_ROOT (got: $FEATURES_DIR)" >&2
    exit 2
    ;;
esac

# ---------------------------------------------------------------------------
# classify_status_file: pure classifier — no side effects.
# Outputs one of: missing-has-ui | needs-migration | already-migrated
#
# States:
#   missing-has-ui    STATUS.md exists but lacks a `- **has-ui**:` line;
#                     cannot safely determine insertion point — skip.
#   needs-migration   STATUS.md exists, has `- **has-ui**:` but no `tier:`.
#   already-migrated  STATUS.md already contains a `- **tier**:` line.
# ---------------------------------------------------------------------------
classify_status_file() {
  local f="$1"
  # Read once with a builtin redirect (no cat fork) then use pure-bash case
  # pattern matching — no printf|grep pipeline per check, so zero extra forks
  # inside the main while-read loop (no-shell-out-in-tight-loops rule).
  local content
  content=$(< "$f") || return 1
  # Wrap content with leading/trailing newlines so patterns anchor to full lines.
  case $'\n'"$content"$'\n' in
    *$'\n'"- **tier**: "*) echo "already-migrated"; return ;;
  esac
  case $'\n'"$content"$'\n' in
    *$'\n'"- **has-ui**: "*) echo "needs-migration"; return ;;
  esac
  echo "missing-has-ui"
}

# ---------------------------------------------------------------------------
# build_migrated_content: pure transform — reads STATUS.md content from stdin,
# inserts `- **tier**: standard` after the `- **has-ui**:` line, writes to
# stdout.  No file I/O — caller owns reading/writing.
# ---------------------------------------------------------------------------
build_migrated_content() {
  local inserted=0
  while IFS= read -r line; do
    printf '%s\n' "$line"
    if [ "$inserted" -eq 0 ]; then
      case "$line" in
        '- **has-ui**:'*)
          printf '%s\n' "- **tier**: standard"
          inserted=1
          ;;
      esac
    fi
  done
  if [ "$inserted" -eq 0 ]; then
    echo "ERROR: build_migrated_content: has-ui line not found in content" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# verify_diff: asserts the diff between original and migrated content is
# exactly one inserted line (the tier: line) and nothing else.
# Exits 2 on unexpected diff — fail-loud posture (tech §4.1).
# ---------------------------------------------------------------------------
verify_diff() {
  local original="$1"
  local migrated="$2"
  local status_path="$3"

  # Count added lines (lines in migrated not in original after context).
  # diff exit code is 0 (identical) or 1 (different) — both are expected here.
  local diff_output
  diff_output="$(diff "$original" "$migrated" || true)"

  # Single awk pass: count insertions/deletions AND capture the added line text
  # (stripping the "> " diff prefix).  This eliminates a second printf|grep|sed
  # pipeline that would otherwise run for every migrated file.
  local awk_out
  awk_out="$(printf '%s\n' "$diff_output" | awk '
    BEGIN { a=0; d=0; added_line="" }
    /^>/ { a++; added_line=substr($0, 3) }
    /^</ { d++ }
    END  { printf "%d %d %s\n", a, d, added_line }
  ')"
  local added_count deleted_count added_line rest
  added_count="${awk_out%% *}"
  rest="${awk_out#* }"
  deleted_count="${rest%% *}"
  added_line="${rest#* }"

  if [ "$added_count" -ne 1 ] || [ "$deleted_count" -ne 0 ]; then
    echo "ERROR: unexpected diff for $status_path" >&2
    echo "  expected: exactly 1 insertion, 0 deletions" >&2
    echo "  got: $added_count insertion(s), $deleted_count deletion(s)" >&2
    printf '%s\n' "$diff_output" >&2
    exit 2
  fi

  # Assert the single added line is the tier: line (captured from awk pass above)
  if [ "$added_line" != "- **tier**: standard" ]; then
    echo "ERROR: unexpected inserted line for $status_path" >&2
    echo "  expected: '- **tier**: standard'" >&2
    echo "  got:      '$added_line'" >&2
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Main loop: collect all STATUS.md files under features/ (excluding _template
# which is the schema prototype, and any path under archive/).
# ---------------------------------------------------------------------------
MIGRATED=0
SKIPPED=0
ERRORS=0

# Build candidate list — use find with pruning to avoid archive/ entirely.
# BSD find is POSIX-compatible here: -path with -prune.
# Collect results into a temp file to avoid subshell issues with counters.
CANDIDATES="$(mktemp)"
trap 'rm -f "$CANDIDATES"' EXIT

find "$FEATURES_DIR" \
  -path "$FEATURES_DIR/_template" -prune -o \
  -name "STATUS.md" -not -path "*/archive/*" -print \
  | sort > "$CANDIDATES"

while IFS= read -r status_file; do
  # Pure-bash parameter expansion — no dirname/basename fork per iteration.
  feature_dir="${status_file%/*}"
  slug="${feature_dir##*/}"

  state="$(classify_status_file "$status_file")"

  if [ "$state" = "already-migrated" ]; then
    echo "skipped: already migrated — $slug"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if [ "$state" = "missing-has-ui" ]; then
    echo "skipped: no has-ui field (cannot determine insertion point) — $slug"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # state = needs-migration
  if [ "$DRY_RUN" -eq 1 ]; then
    # --dry-run must never write to the features tree so users can safely preview
    # changes on a live repo without risk of a half-migrated state on interrupt.
    TMP_MIGRATED="$(mktemp)"
    # Subshell trap to clean temp file even on error
    (
      trap 'rm -f "$TMP_MIGRATED"' EXIT
      build_migrated_content < "$status_file" > "$TMP_MIGRATED"
      echo "would-migrate: $slug"
      diff "$status_file" "$TMP_MIGRATED" || true
    )
    continue
  fi

  # Real run: backup → build content → verify diff → atomic rename.
  bak_file="${status_file}.bak"
  tmp_file="${status_file}.tmp"

  # Step 1: backup (no-force-on-user-paths.md).
  # Warn if a previous .bak exists so the caller knows it is being overwritten;
  # the policy is: the .bak always reflects the state just before THIS run —
  # we do not silently discard the warning because losing data silently violates
  # no-force-on-user-paths.md §4.
  if [ -f "$bak_file" ]; then
    echo "WARNING: overwriting existing backup $bak_file (previous run's copy superseded)" >&2
  fi
  cp "$status_file" "$bak_file"

  # Step 2: build migrated content into tmp file.
  # On failure: record the error, clean up, and continue the loop so the full
  # pass completes before we exit; the ERRORS counter drives the final exit 2.
  if ! build_migrated_content < "$status_file" > "$tmp_file"; then
    echo "ERROR: failed to build migrated content for $slug — skipping" >&2
    rm -f "$tmp_file"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Step 3: verify the diff is exactly what we expect (tech §4.1 fail-loud)
  verify_diff "$status_file" "$tmp_file" "$status_file"

  # Step 4: atomic rename (no partial-write window)
  mv "$tmp_file" "$status_file"

  echo "migrated: $slug"
  MIGRATED=$((MIGRATED + 1))

done < "$CANDIDATES"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "done: migrated=$MIGRATED skipped=$SKIPPED"

if [ "$ERRORS" -gt 0 ]; then
  exit 2
fi

exit 0
