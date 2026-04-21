#!/usr/bin/env bash
# test/t97_theme_token_reuse.sh
#
# T117 — Seam K: no net-new theme tokens in B2
#
# Asserts that the set of CSS custom properties declared under the
# --color-*, --space-*, --font-*, and --radius-* prefixes in
# flow-monitor/src/styles/ is a subset of the B1 baseline.
#
# B1 archive path:
#   .spec-workflow/archive/20260419-flow-monitor/
# The B1 archive is docs-only (no CSS files were preserved); the archive
# contains only *.md and 02-design/mockup.html.  The mockup.html uses
# un-prefixed tokens (--primary, --page-bg, etc.) — none matching the
# --color-|--space-|--font-|--radius- prefix pattern.  Therefore the B1
# baseline is inlined here as an empty set.
#
# Grep pattern: ^\s*--(color|space|font|radius)-[a-zA-Z0-9_-]+:
#
# If any token matching that pattern is found in the current styles tree,
# it is by definition net-new (not present in B1) and the test fails with
# a grep -n diagnostic showing file:line of each offending declaration.
#
# Vacuous-pass behaviour:
#   W5a added no such prefixed tokens; the grep produces empty output
#   and the test passes.  If a future wave adds a --color-* token the
#   test will catch it here, before the wave merges.
#
# Sandbox-HOME NOT required: this test only greps the repo working tree
# and never invokes any CLI that expands or writes $HOME.
# (bash/sandbox-home-in-tests.md — explicitly exempt for read-only repo
# traversal scripts.)
#
# Bash 3.2 / BSD portable:
#   no readlink -f, realpath, jq, mapfile/readarray, [[ =~ ]], GNU-only
#   flags.  No `case` inside subshells (bash32-case-in-subshell.md).
set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# (developer/test-script-path-convention.md — never hardcode worktree path)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

STYLES_DIR="$REPO_ROOT/flow-monitor/src/styles"

# ---------------------------------------------------------------------------
# Preflight — styles directory must exist
# ---------------------------------------------------------------------------
if [ ! -d "$STYLES_DIR" ]; then
  printf 'SKIP: %s not found — flow-monitor styles not present; re-run after app scaffold.\n' \
    "$STYLES_DIR" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# B1 baseline — inlined because the B1 archive is docs-only.
#
# The B1 feature archive (.spec-workflow/archive/20260419-flow-monitor/)
# contains no CSS source files.  The 02-design/mockup.html uses un-prefixed
# tokens (--primary, --page-bg, --text-muted, etc.) that do not match the
# --color-|--space-|--font-|--radius- prefix.  Running the same grep against
# the archive returns zero matches.  Consequently the B1 baseline for this
# prefix family is the empty set — expressed here as the empty string so that
# any match in the CURRENT set is, by definition, net-new.
# ---------------------------------------------------------------------------
B1_BASELINE=""   # empty — B1 declared no --color-/--space-/--font-/--radius- tokens

# ---------------------------------------------------------------------------
# Gather CURRENT token declarations
# ---------------------------------------------------------------------------
CURRENT="$(grep -rhE '^\s*--(color|space|font|radius)-[a-zA-Z0-9_-]+:' \
  "$STYLES_DIR" 2>/dev/null | sort -u || true)"

# ---------------------------------------------------------------------------
# Subset check
#
# For each token name found in CURRENT, verify it is present in B1_BASELINE.
# Because B1_BASELINE is empty, ANY match in CURRENT is a violation.
# ---------------------------------------------------------------------------
VIOLATIONS=0

if [ -n "$CURRENT" ]; then
  # At least one prefixed token exists — all are net-new relative to B1.
  # Re-run grep with -rn to get file:line diagnostics.
  printf 'FAIL: net-new theme token(s) found (not present in B1 baseline):\n' >&2
  grep -rnE '^\s*--(color|space|font|radius)-[a-zA-Z0-9_-]+:' \
    "$STYLES_DIR" 2>/dev/null >&2 || true
  VIOLATIONS=$(printf '%s\n' "$CURRENT" | grep -c '.' || true)
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------
if [ "$VIOLATIONS" -eq 0 ]; then
  printf 'PASS: no net-new --color-/--space-/--font-/--radius-* tokens in B2 styles\n'
  exit 0
else
  printf 'FAIL: %d net-new token declaration(s) found — B2 must reuse B1 tokens only\n' \
    "$VIOLATIONS" >&2
  exit 1
fi
