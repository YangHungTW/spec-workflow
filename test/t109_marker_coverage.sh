#!/usr/bin/env bash
# test/t109_marker_coverage.sh
#
# T7 — Structural test: marker coverage (AC2) + AC3 vacuous (scaff-init not
#      in scope) for the preflight gate feature.
#
# Assertions:
#   A1 (AC2 coverage)  — each of the 18 gated command files carries the
#                         <!-- preflight: required --> marker at least once.
#   A2 (AC2 count)     — .claude/commands/scaff/ contains exactly 18 *.md files.
#                         If different, the GATED array below must be updated.
#   A3 (lint exit-zero) — bin/scaff-lint preflight-coverage exits 0 and stdout
#                          has exactly 18 lines all starting with "ok:".
#   A4 (AC3 vacuous)   — .claude/commands/scaff/scaff-init.md does NOT exist.
#   A5 (AC3 sanity)    — grep -rF '<!-- preflight: required -->' .claude/skills/
#                         returns no matches (skills don't carry the marker).
#   A6 (mutation)      — fixture-level negative-path: copy archive.md to sandbox,
#                         delete the marker line, confirm grep finds no match.
#
# Pre-condition note (W3 sequencing):
#   A1 and A3 require markers to be in place (T6, W3). Running this test before
#   T6 lands will fail at A1/A3 — that is the expected red state. The test is
#   authored in parallel with T6 per plan §2 W3 parallel-safety analysis.
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only flags.
#   No `case` inside subshells (bash32-case-in-subshell.md).
#   BSD sed: sed -i '' for in-place edits; see A6.
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
# Authoritative array of gated command filenames (no glob — explicit contract)
# Per plan §1.1: 18 is authoritative; update this array if directory shape drifts.
# ---------------------------------------------------------------------------
GATED=(
  archive bug chore design implement next plan prd promote remember
  request review tech update-plan update-req update-task update-tech validate
)

# ---------------------------------------------------------------------------
# A1 — AC2 marker coverage: each named file must contain the marker
# ---------------------------------------------------------------------------
printf '=== A1: AC2 marker coverage — each of 18 files carries the preflight marker ===\n'

a1_fail=0
for name in "${GATED[@]}"; do
  filepath="$REPO_ROOT/.claude/commands/scaff/${name}.md"
  if grep -qF '<!-- preflight: required -->' "$filepath" 2>/dev/null; then
    printf 'ok: %s.md\n' "$name"
  else
    printf 'FAIL: missing-marker: %s.md\n' "$name" >&2
    a1_fail=$((a1_fail + 1))
  fi
done

if [ "$a1_fail" -eq 0 ]; then
  printf 'PASS: A1 — all 18 files carry the preflight marker\n'
else
  printf 'FAIL: A1 — %d file(s) missing the preflight marker\n' "$a1_fail" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# A2 — AC2 directory-count contract: exactly 18 *.md files in the gated dir
# ---------------------------------------------------------------------------
printf '\n=== A2: AC2 directory-count — .claude/commands/scaff/ has exactly 18 *.md files ===\n'

dir_count="$(ls "$REPO_ROOT/.claude/commands/scaff/"*.md 2>/dev/null | wc -l | tr -d ' ')"
if [ "$dir_count" = "18" ]; then
  printf 'PASS: A2 — directory contains %s *.md files\n' "$dir_count"
else
  printf 'FAIL: directory shape drifted (got %s, expected 18). Update GATED array in this test.\n' "$dir_count" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# A3 — lint exit-zero: bin/scaff-lint preflight-coverage exits 0, 18 ok: lines
# ---------------------------------------------------------------------------
printf '\n=== A3: lint exit-zero — bin/scaff-lint preflight-coverage exits 0 with 18 ok: lines ===\n'

LINT_BIN="$REPO_ROOT/bin/scaff-lint"

if [ ! -x "$LINT_BIN" ]; then
  printf 'FAIL: A3 — bin/scaff-lint not executable or not found (T2 has not merged yet)\n' >&2
  exit 1
fi

LINT_OUTPUT="$("$LINT_BIN" preflight-coverage 2>&1)" && LINT_EXIT=0 || LINT_EXIT=$?

if [ "$LINT_EXIT" != "0" ]; then
  printf 'FAIL: A3 — bin/scaff-lint preflight-coverage exited %s (expected 0)\n' "$LINT_EXIT" >&2
  printf '%s\n' "$LINT_OUTPUT" >&2
  exit 1
fi

LINT_LINE_COUNT="$(printf '%s\n' "$LINT_OUTPUT" | grep -c '' || true)"
if [ "$LINT_LINE_COUNT" != "18" ]; then
  printf 'FAIL: A3 — lint output has %s lines, expected 18\n' "$LINT_LINE_COUNT" >&2
  printf '%s\n' "$LINT_OUTPUT" >&2
  exit 1
fi

BAD_LINES="$(printf '%s\n' "$LINT_OUTPUT" | grep -v '^ok:' || true)"
if [ -n "$BAD_LINES" ]; then
  printf 'FAIL: A3 — some lint output lines do not start with ok:\n' >&2
  printf '%s\n' "$BAD_LINES" >&2
  exit 1
fi

printf 'PASS: A3 — bin/scaff-lint preflight-coverage exits 0 with 18 ok: lines\n'

# ---------------------------------------------------------------------------
# A4 — AC3 vacuous: .claude/commands/scaff/scaff-init.md must NOT exist
# ---------------------------------------------------------------------------
printf '\n=== A4: AC3 vacuous — .claude/commands/scaff/scaff-init.md does not exist ===\n'

if [ ! -e "$REPO_ROOT/.claude/commands/scaff/scaff-init.md" ]; then
  printf 'PASS: A4 — scaff-init.md is absent from the gated directory (vacuous AC3)\n'
else
  printf 'FAIL: A4 — .claude/commands/scaff/scaff-init.md exists but must not (AC3 violated)\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# A5 — AC3 sanity: .claude/skills/ must not carry the marker
# ---------------------------------------------------------------------------
printf '\n=== A5: AC3 sanity — .claude/skills/ does not carry the preflight marker ===\n'

SKILLS_MATCH="$(grep -rF '<!-- preflight: required -->' "$REPO_ROOT/.claude/skills/" 2>/dev/null || true)"
if [ -z "$SKILLS_MATCH" ]; then
  printf 'PASS: A5 — no preflight marker found in .claude/skills/ (correct: skills are outside scan scope)\n'
else
  printf 'FAIL: A5 — preflight marker found in .claude/skills/ (dead code — marker must only appear in .claude/commands/scaff/):\n' >&2
  printf '%s\n' "$SKILLS_MATCH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# A6 — mutation test: fixture-level negative-path detection
#       Copy archive.md to sandbox, delete the marker line, confirm no match.
# ---------------------------------------------------------------------------
printf '\n=== A6: mutation test — lint negative-path detection at fixture level ===\n'

mkdir -p "$SANDBOX/cmd-fixture"
cp "$REPO_ROOT/.claude/commands/scaff/archive.md" "$SANDBOX/cmd-fixture/archive.md"

# Delete the marker line from the fixture copy (BSD-portable sed -i '')
sed -i '' '/<!-- preflight: required -->/d' "$SANDBOX/cmd-fixture/archive.md"

# grep -lF returns the filename if found; should be empty (no match) after deletion
GREP_MATCH="$(grep -lF '<!-- preflight: required -->' "$SANDBOX/cmd-fixture/archive.md" 2>/dev/null || true)"
if [ -z "$GREP_MATCH" ]; then
  printf 'PASS: A6 — fixture without marker produces no grep match (lint negative-path verified)\n'
else
  printf 'FAIL: A6 — grep still found the marker in the stripped fixture: %s\n' "$GREP_MATCH" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\nPASS: t109\n'
exit 0
