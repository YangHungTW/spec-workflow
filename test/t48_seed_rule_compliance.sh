#!/usr/bin/env bash
# test/t48_seed_rule_compliance.sh — static portability + no-force compliance check
# for bin/scaff-seed and .claude/skills/scaff-init/
#
# STATIC test: pure grep + bash -n, no CLI invocation, no HOME mutation.
# sandbox-HOME preamble is intentionally omitted — the rule targets tests
# that invoke a CLI reading/writing $HOME; this test does neither.
#
# Usage: bash test/t48_seed_rule_compliance.sh
# Exits 0 iff all checks pass; FAIL: <reason> to stderr + exit 1 on failure.

set -euo pipefail

# ---------------------------------------------------------------------------
# Locate repo root relative to this script — never hardcode worktree paths
# (developer/test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

SEED="$REPO_ROOT/bin/scaff-seed"
SKILL_DIR="$REPO_ROOT/.claude/skills/scaff-init"
SKILL_INIT="$SKILL_DIR/init.sh"

# ---------------------------------------------------------------------------
# Check 1: prohibited-token grep across scaff-seed + skill dir (if present)
#
# Pattern rationale:
#   readlink -f / realpath — GNU-only (bash-32-portability.md)
#   jq[^\.]               — jq binary invocation; tolerates "jq." in doc refs
#   mapfile / readarray   — bash 4+ builtins not available on macOS bash 3.2
#   rm -rf                — unconditional recursive delete violates no-force rule
#    --force              — leading space catches flag usage, not word fragments
# ---------------------------------------------------------------------------
GREP_TARGETS="$SEED"
if [ -d "$SKILL_DIR" ]; then
  GREP_TARGETS="$GREP_TARGETS $SKILL_DIR"
fi

# Pipe through a second grep to exclude lines where the token appears only inside
# a shell comment (optional whitespace then '#'). Doc comments explaining what
# NOT to use (e.g. "no readlink -f") are informative, not violations.
HITS="$(grep -rEn 'readlink -f|realpath|jq[^\.]|mapfile|readarray|rm -rf|--force' \
  $GREP_TARGETS 2>/dev/null \
  | grep -Ev '^[^:]+:[0-9]+:[[:space:]]*#' || true)"

if [ -n "$HITS" ]; then
  echo "FAIL: prohibited-token found:" >&2
  echo "$HITS" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 2: bash -n syntax check on scaff-seed
# ---------------------------------------------------------------------------
if ! bash -n "$SEED" 2>/tmp/t48_bash_n_seed.err; then
  echo "FAIL: bash -n failed on bin/scaff-seed:" >&2
  cat /tmp/t48_bash_n_seed.err >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 3: bash -n syntax check on init.sh — skip if T15 not yet merged
# ---------------------------------------------------------------------------
if [ -f "$SKILL_INIT" ]; then
  if ! bash -n "$SKILL_INIT" 2>/tmp/t48_bash_n_init.err; then
    echo "FAIL: bash -n failed on .claude/skills/scaff-init/init.sh:" >&2
    cat /tmp/t48_bash_n_init.err >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Check 4: strict-mode marker — scaff-seed must contain 'set -u'
#
# set -u prevents unbound variable expansion bugs; verifying its presence
# enforces the strict-mode convention across all repo-shipped scripts.
# ---------------------------------------------------------------------------
STRICT_COUNT="$(grep -c 'set -u' "$SEED" || true)"
if [ "$STRICT_COUNT" -lt 1 ]; then
  echo "FAIL: strict-mode: 'set -u' not found in bin/scaff-seed" >&2
  exit 1
fi

echo "PASS"
exit 0
