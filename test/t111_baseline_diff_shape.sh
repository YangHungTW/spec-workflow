#!/usr/bin/env bash
# test/t111_baseline_diff_shape.sh
#
# T10 — Baseline-diff structural test for AC12 and AC13.
#
# WARNING: this test asserts the W3 baseline diff shape; if a future feature
# edits any file in .claude/commands/scaff/, this test must be updated to
# track the new baseline. See plan §4 for the bulk-vs-split rationale.
#
# Assertions:
#   A1 (AC12 per-file diff shape) — for each of the 18 gated command files,
#       the diff from the pre-T6 baseline is a pure addition (no deletions);
#       the added lines are exactly the 6-line wiring block (HTML comment +
#       4 directive lines + 1 blank separator).
#   A2 (AC12 bulk diff stat)    — git diff --shortstat BASELINE..HEAD over
#       .claude/commands/scaff/ reports exactly +108, -0.
#   A3 (AC13 byte-identical bodies modulo wiring) — for each file, after
#       stripping the 6-line wiring block via awk, the remainder is
#       byte-identical to the pre-T6 baseline content.
#
# BASELINE_REF resolution:
#   Find the T6 task commit by its message and take its first parent.
#   The plan's head-2|tail-1 pattern is documented as the lookup hint but
#   is unreliable when earlier features also touched the same files; the
#   commit-message grep is robust.
#
# Performance discipline (developer/batch-by-default-when-test-iterates-over-item-lists.md):
#   All git I/O is batched OUTSIDE the per-file loops:
#   - BASELINE_REF: one git-log call.
#   - Baseline file content: one git-archive + tar call extracts all 18 files.
#   - A2: one git-diff --shortstat call.
#   The per-file loop body operates only on local filesystem files (no git forks).
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only flags.
#   No `case` inside subshells (bash32-case-in-subshell.md).
#
# Sandbox-HOME discipline per .claude/rules/bash/sandbox-home-in-tests.md:
#   applied uniformly even though the test is read-only against the on-disk tree.

set -euo pipefail

# ---------------------------------------------------------------------------
# Sandbox HOME — uniform discipline per sandbox-home-in-tests.md
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

export HOME="$SANDBOX/home"
mkdir -p "$HOME"

case "$HOME" in
  "$SANDBOX"*) ;;  # OK — HOME is inside sandbox
  *) printf 'FAIL: HOME not isolated: %s\n' "$HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Authoritative array of gated command filenames (18 files, no glob)
# ---------------------------------------------------------------------------
GATED=(
  archive bug chore design implement next plan prd promote remember
  request review tech update-plan update-req update-task update-tech validate
)

# ---------------------------------------------------------------------------
# Resolve BASELINE_REF — T6 task commit parent (batched: one git-log call)
# Find T6 by its commit message; use first parent as pre-T6 baseline.
# ---------------------------------------------------------------------------
printf '=== Resolving pre-T6 BASELINE_REF ===\n'

T6_COMMIT="$(git log --pretty=format:'%H' --grep='T6: 18 .claude/commands/scaff' -- .claude/commands/scaff/archive.md | head -1)"

if [ -z "$T6_COMMIT" ]; then
  printf 'FAIL: cannot resolve T6 commit (T10 expects W3 bulk commit to be present)\n' >&2
  exit 1
fi

# First parent of T6 task commit is the pre-T6 baseline
BASELINE_REF="$(git show --no-patch --format='%P' "$T6_COMMIT" | awk '{print $1}')"

if [ -z "$BASELINE_REF" ]; then
  printf 'FAIL: cannot resolve pre-T6 baseline (T10 expects W3 bulk commit to be present)\n' >&2
  exit 1
fi

printf 'T6 commit:    %s\n' "$T6_COMMIT"
printf 'BASELINE_REF: %s\n' "$BASELINE_REF"

# ---------------------------------------------------------------------------
# Batch: extract all 18 baseline files in ONE git-archive call
# No per-file git shell-outs in the loops below.
# ---------------------------------------------------------------------------
BASELINE_DIR="$SANDBOX/baseline"
mkdir -p "$BASELINE_DIR"
git archive "$BASELINE_REF" .claude/commands/scaff/ | tar -xC "$BASELINE_DIR"

# ---------------------------------------------------------------------------
# A1 — AC12 per-file diff shape:
#   Each file must have additions only (no deletions) and those additions
#   must contain the exact wiring lines.
# ---------------------------------------------------------------------------
printf '\n=== A1: AC12 per-file diff shape — pure additions with wiring block ===\n'

a1_fail=0
for name in "${GATED[@]}"; do
  cur_file="$REPO_ROOT/.claude/commands/scaff/${name}.md"
  base_file="$BASELINE_DIR/.claude/commands/scaff/${name}.md"

  if [ ! -f "$base_file" ]; then
    printf 'FAIL: A1 — baseline file missing for %s.md (git archive did not produce it)\n' "$name" >&2
    a1_fail=$((a1_fail + 1))
    continue
  fi

  # Extract added lines (lines in NEW but not OLD)
  ADDED="$(diff "$base_file" "$cur_file" | grep '^>' | sed 's/^> //' || true)"

  # Assert: no deleted lines
  DEL_COUNT="$(diff "$base_file" "$cur_file" | grep -c '^<' || true)"
  if [ "$DEL_COUNT" != "0" ]; then
    printf 'FAIL: A1 — %s.md has %s deleted line(s) from baseline (expected 0)\n' "$name" "$DEL_COUNT" >&2
    a1_fail=$((a1_fail + 1))
    continue
  fi

  # Assert: added lines contain the wiring marker
  if ! printf '%s\n' "$ADDED" | grep -qF '<!-- preflight: required -->'; then
    printf 'FAIL: A1 — %s.md missing <!-- preflight: required --> in additions\n' "$name" >&2
    a1_fail=$((a1_fail + 1))
    continue
  fi

  # Assert: added lines contain the four directive lines
  if ! printf '%s\n' "$ADDED" | grep -qF 'Run the preflight from'; then
    printf 'FAIL: A1 — %s.md missing "Run the preflight from" directive\n' "$name" >&2
    a1_fail=$((a1_fail + 1))
    continue
  fi
  if ! printf '%s\n' "$ADDED" | grep -qF 'If preflight refuses'; then
    printf 'FAIL: A1 — %s.md missing "If preflight refuses" directive\n' "$name" >&2
    a1_fail=$((a1_fail + 1))
    continue
  fi
  if ! printf '%s\n' "$ADDED" | grep -qF 'this command immediately'; then
    printf 'FAIL: A1 — %s.md missing "this command immediately" directive\n' "$name" >&2
    a1_fail=$((a1_fail + 1))
    continue
  fi
  if ! printf '%s\n' "$ADDED" | grep -qF 'no file writes'; then
    printf 'FAIL: A1 — %s.md missing "no file writes" directive\n' "$name" >&2
    a1_fail=$((a1_fail + 1))
    continue
  fi

  printf 'ok: %s.md\n' "$name"
done

if [ "$a1_fail" -eq 0 ]; then
  printf 'PASS: A1 — all 18 files have pure-addition wiring block, no deletions\n'
else
  printf 'FAIL: A1 — %d file(s) failed per-file diff shape check\n' "$a1_fail" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# A2 — AC12 bulk diff stat: exactly +108, -0 over .claude/commands/scaff/
# Single git call; parse insertions and deletions from --shortstat output.
# ---------------------------------------------------------------------------
printf '\n=== A2: AC12 bulk diff stat — +108 insertions, 0 deletions ===\n'

STAT="$(git diff --shortstat "${BASELINE_REF}..HEAD" -- .claude/commands/scaff/)"
printf 'shortstat: %s\n' "$STAT"

# Parse insertions count (may be absent if 0)
INS="$(printf '%s\n' "$STAT" | grep -o '[0-9]* insertion' | awk '{print $1}' || true)"
# Parse deletions count (absent from output when 0)
DEL="$(printf '%s\n' "$STAT" | grep -o '[0-9]* deletion' | awk '{print $1}' || true)"

# Treat absent deletion count as 0
if [ -z "$DEL" ]; then
  DEL=0
fi

if [ "$INS" != "108" ]; then
  printf 'FAIL: A2 — expected 108 insertions, got "%s"\n' "$INS" >&2
  exit 1
fi

if [ "$DEL" != "0" ]; then
  printf 'FAIL: A2 — expected 0 deletions, got "%s"\n' "$DEL" >&2
  exit 1
fi

printf 'PASS: A2 — bulk diff stat: +%s insertions, -%s deletions\n' "$INS" "$DEL"

# ---------------------------------------------------------------------------
# A3 — AC13 byte-identical bodies modulo wiring:
#   Strip the 6-line wiring block (marker + 4 directives + blank separator)
#   from each current file; the result must be byte-identical to baseline.
#   The awk rule: when <!-- preflight: required --> is found, consume it and
#   skip the next 5 lines (4 directive lines + 1 blank separator).
# ---------------------------------------------------------------------------
printf '\n=== A3: AC13 byte-identical bodies modulo wiring block ===\n'

a3_fail=0
for name in "${GATED[@]}"; do
  cur_file="$REPO_ROOT/.claude/commands/scaff/${name}.md"
  base_file="$BASELINE_DIR/.claude/commands/scaff/${name}.md"

  NEW_STRIPPED="$(awk '
    /^<!-- preflight: required -->/ { skip=5; next }
    skip > 0 { skip--; next }
    { print }
  ' "$cur_file")"

  OLD="$(cat "$base_file")"

  if [ "$NEW_STRIPPED" = "$OLD" ]; then
    printf 'ok: %s.md\n' "$name"
  else
    printf 'FAIL: A3 — %s.md body differs from baseline after wiring strip:\n' "$name" >&2
    diff <(printf '%s\n' "$NEW_STRIPPED") <(printf '%s\n' "$OLD") | head -20 >&2
    a3_fail=$((a3_fail + 1))
  fi
done

if [ "$a3_fail" -eq 0 ]; then
  printf 'PASS: A3 — all 18 files are byte-identical to baseline after stripping wiring block\n'
else
  printf 'FAIL: A3 — %d file(s) failed byte-identity check\n' "$a3_fail" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\nPASS: t111\n'
exit 0
