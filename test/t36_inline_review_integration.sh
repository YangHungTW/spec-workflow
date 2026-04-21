#!/usr/bin/env bash
# test/t36_inline_review_integration.sh — T13 inline-review structural contract test
# Usage: bash test/t36_inline_review_integration.sh
# Exits 0 iff all checks pass; 1 on assertion failure; 2 on preflight failure.
#
# Validates the structural contract for the inline review flow described in
# .claude/commands/scaff/implement.md — all assertions are grepping that file.
# Also stubs a fake reviewer output and parses it with the same awk/grep the
# aggregator uses, asserting the parser extracts the verdict correctly.
#
# This test does NOT require LLM calls; it validates the documented contract shape.
# RED → green once T9 (implement.md inline-review injection) is merged.

set -u -o pipefail

# ---------------------------------------------------------------------------
# Locate files under test (cwd-agnostic per test-script-path-convention.md)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMPLEMENT_MD="$REPO_ROOT/.claude/commands/scaff/implement.md"

# ---------------------------------------------------------------------------
# Sandbox setup (sandbox-HOME discipline per sandbox-home-in-tests.md)
# ---------------------------------------------------------------------------
SANDBOX="$(mktemp -d 2>/dev/null || mktemp -d -t t36-test)"
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
trap 'rm -rf "$SANDBOX"' EXIT

# Preflight — refuse to run against real HOME
case "$HOME" in
  "$SANDBOX"*) ;;
  *) echo "FAIL: HOME not isolated: $HOME" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Preflight: implement.md must exist
# ---------------------------------------------------------------------------
if [ ! -f "$IMPLEMENT_MD" ]; then
  echo "FAIL: implement.md not found at $IMPLEMENT_MD" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 1: --skip-inline-review flag documented in frontmatter/usage
# ---------------------------------------------------------------------------
if grep -q -- '--skip-inline-review' "$IMPLEMENT_MD"; then
  pass "C1: --skip-inline-review flag documented in implement.md"
else
  fail "C1: --skip-inline-review flag not found in implement.md"
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 2: reviewer agents named (reviewer-security, -performance, -style)
# ---------------------------------------------------------------------------
if grep -q 'reviewer-security' "$IMPLEMENT_MD" && \
   grep -q 'reviewer-performance' "$IMPLEMENT_MD" && \
   grep -q 'reviewer-style' "$IMPLEMENT_MD"; then
  pass "C2: all three reviewer agents named in implement.md"
else
  fail "C2: one or more reviewer agent names missing from implement.md"
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 3: "Reviewer verdict" section marker documented (D1 footer shape)
# ---------------------------------------------------------------------------
if grep -q '## Reviewer verdict' "$IMPLEMENT_MD"; then
  pass "C3: '## Reviewer verdict' D1 footer shape present in implement.md"
else
  fail "C3: '## Reviewer verdict' marker not found in implement.md"
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 4: aggregator emits wave:BLOCK | wave:NITS | wave:PASS
# ---------------------------------------------------------------------------
if grep -q 'wave:BLOCK' "$IMPLEMENT_MD" && \
   grep -q 'wave:NITS' "$IMPLEMENT_MD" && \
   grep -q 'wave:PASS' "$IMPLEMENT_MD"; then
  pass "C4: aggregator wave-state tags (wave:BLOCK, wave:NITS, wave:PASS) present"
else
  fail "C4: one or more wave-state tags missing from implement.md"
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 5: malformed footer treated as BLOCK (fail-loud documented)
# ---------------------------------------------------------------------------
if grep -q 'malformed' "$IMPLEMENT_MD"; then
  pass "C5: malformed footer → BLOCK posture documented in implement.md"
else
  fail "C5: malformed footer BLOCK posture not found in implement.md"
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 6: retry re-runs all 3 reviewers (D6)
# ---------------------------------------------------------------------------
if grep -q 'all 3 reviewers' "$IMPLEMENT_MD"; then
  pass "C6: retry re-runs all 3 reviewers documented in implement.md"
else
  fail "C6: 'all 3 reviewers' retry semantics not found in implement.md"
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 7: max retries documented (max 2 per D6)
# ---------------------------------------------------------------------------
if grep -q 'Max retries = 2\|max retries.*2\|2 retries' "$IMPLEMENT_MD"; then
  pass "C7: max-2-retries limit documented in implement.md"
else
  fail "C7: max retries limit not found in implement.md"
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 8: BLOCK classification leads to merge halt (no git merge --no-ff on BLOCK)
# ---------------------------------------------------------------------------
if grep -q 'do NOT run the.*git merge\|do not.*git merge\|NOT.*merge' "$IMPLEMENT_MD"; then
  pass "C8: BLOCK halts git merge --no-ff (documented in implement.md)"
else
  fail "C8: BLOCK → merge halt behavior not clearly documented in implement.md"
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 9: NITS proceeds with "Reviewer notes" in commit body
# ---------------------------------------------------------------------------
if grep -q 'Reviewer notes' "$IMPLEMENT_MD"; then
  pass "C9: NITS → 'Reviewer notes' commit body section documented"
else
  fail "C9: 'Reviewer notes' section for NITS verdict not found in implement.md"
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 10: inline review step appears BEFORE git merge --no-ff
# (injection-point check — step 7 precedes step 8 with the merge loop)
# ---------------------------------------------------------------------------
REVIEW_LINE=""
MERGE_LINE=""
REVIEW_LINE="$(grep -n 'Inline review\|inline.review\|Inline.review' "$IMPLEMENT_MD" | head -1 | awk -F: '{print $1}')"
MERGE_LINE="$(grep -n 'git merge --no-ff' "$IMPLEMENT_MD" | head -1 | awk -F: '{print $1}')"

if [ -n "$REVIEW_LINE" ] && [ -n "$MERGE_LINE" ] && [ "$REVIEW_LINE" -lt "$MERGE_LINE" ]; then
  pass "C10: inline review step (line $REVIEW_LINE) appears before git merge --no-ff (line $MERGE_LINE)"
else
  fail "C10: inline review step not found before 'git merge --no-ff' in implement.md (review_line='$REVIEW_LINE', merge_line='$MERGE_LINE')"
fi

# ---------------------------------------------------------------------------
# CONTRACT CHECK 11: skip-inline-review logs to STATUS Notes
# ---------------------------------------------------------------------------
if grep -q 'STATUS Notes\|STATUS.Notes\|status notes' "$IMPLEMENT_MD"; then
  pass "C11: skip-inline-review diagnostic logged to STATUS Notes (documented)"
else
  fail "C11: STATUS Notes logging not found in implement.md"
fi

# ---------------------------------------------------------------------------
# PARSER STUB TEST: stub a valid D1 verdict footer, parse it with the same
# awk/grep shape as the aggregator, assert correct extraction.
# This catches parser-shape drift between implement.md pseudocode and reality.
# ---------------------------------------------------------------------------

VERDICT_DIR="$SANDBOX/verdicts"
mkdir -p "$VERDICT_DIR"

# --- Stub A: BLOCK verdict (must-severity finding) ---
cat > "$VERDICT_DIR/T1-security.txt" << 'EOF'
Some preamble text from the reviewer.

## Reviewer verdict
axis: security
verdict: BLOCK
findings:
  - severity: must
    file: bin/example-script.sh
    line: 42
    rule: injection-attacks
    message: String-built shell command — use argv-form instead.
EOF

# --- Stub B: NITS verdict (should-severity finding) ---
cat > "$VERDICT_DIR/T1-performance.txt" << 'EOF'
## Reviewer verdict
axis: performance
verdict: NITS
findings:
  - severity: should
    file: bin/example-script.sh
    line: 14
    rule: reviewer-performance
    message: Cache git rev-parse result instead of calling per iteration.
EOF

# --- Stub C: PASS verdict (zero findings) ---
cat > "$VERDICT_DIR/T1-style.txt" << 'EOF'
## Reviewer verdict
axis: style
verdict: PASS
findings:
EOF

# --- Stub D: MALFORMED footer (no ## Reviewer verdict header) ---
cat > "$VERDICT_DIR/T2-security.txt" << 'EOF'
Reviewer output but missing the verdict section entirely.
axis: security
verdict: PASS
EOF

# Run the aggregator logic inline (mirrors the pseudocode in implement.md)
# We implement the same while-read-case loop here to validate the parser shape.
parse_verdict_dir() {
  local vdir="$1"
  local WAVE_STATE="wave:PASS"
  local BLOCK_TASKS=""
  local NITS_LINES=""

  for verdict_file in "$vdir"/*.txt; do
    local IN_VERDICT=0
    local VERDICT_VALUE=""
    local TASK_LABEL=""
    local AXIS_VALUE=""
    local FOUND_HEADER=0

    TASK_LABEL="$(basename "$verdict_file" .txt)"

    while IFS= read -r line; do
      if [ "$line" = "## Reviewer verdict" ]; then
        IN_VERDICT=1
        FOUND_HEADER=1
      fi
      if [ "$IN_VERDICT" = "1" ]; then
        case "$line" in
          "axis: "*)    AXIS_VALUE="${line#axis: }" ;;
          "verdict: "*) VERDICT_VALUE="${line#verdict: }" ;;
          "  - severity: must"*)
            WAVE_STATE="wave:BLOCK"
            BLOCK_TASKS="$BLOCK_TASKS $TASK_LABEL"
            ;;
          "  - severity: should"*|"  - severity: advisory"*)
            if [ "$WAVE_STATE" = "wave:PASS" ]; then
              WAVE_STATE="wave:NITS"
            fi
            NITS_LINES="$NITS_LINES
$TASK_LABEL($AXIS_VALUE): $line"
            ;;
        esac
      fi
    done < "$verdict_file"

    # Malformed footer (no header or no verdict value) → BLOCK
    if [ "$FOUND_HEADER" = "0" ] || [ -z "$VERDICT_VALUE" ]; then
      WAVE_STATE="wave:BLOCK"
      BLOCK_TASKS="$BLOCK_TASKS $TASK_LABEL(malformed)"
    fi

    # Explicit verdict: BLOCK at file level also forces wave:BLOCK
    if [ "$VERDICT_VALUE" = "BLOCK" ]; then
      WAVE_STATE="wave:BLOCK"
      BLOCK_TASKS="$BLOCK_TASKS $TASK_LABEL($AXIS_VALUE)"
    fi
  done

  echo "$WAVE_STATE"
}

# --- Parser test: BLOCK verdict file should produce wave:BLOCK ---
BLOCK_DIR="$SANDBOX/verdicts_block"
mkdir -p "$BLOCK_DIR"
cat > "$BLOCK_DIR/T1-security.txt" << 'EOF'
## Reviewer verdict
axis: security
verdict: BLOCK
findings:
  - severity: must
    file: bin/example.sh
    line: 5
    rule: injection-attacks
    message: String-built command.
EOF

RESULT_BLOCK="$(parse_verdict_dir "$BLOCK_DIR")"
if [ "$RESULT_BLOCK" = "wave:BLOCK" ]; then
  pass "P1: must-severity finding → parser produces wave:BLOCK"
else
  fail "P1: expected wave:BLOCK from must-severity finding, got: $RESULT_BLOCK"
fi

# --- Parser test: NITS verdict (should only) should produce wave:NITS ---
NITS_DIR="$SANDBOX/verdicts_nits"
mkdir -p "$NITS_DIR"
cat > "$NITS_DIR/T1-performance.txt" << 'EOF'
## Reviewer verdict
axis: performance
verdict: NITS
findings:
  - severity: should
    file: bin/example.sh
    line: 20
    rule: reviewer-performance
    message: Cache result.
EOF

RESULT_NITS="$(parse_verdict_dir "$NITS_DIR")"
if [ "$RESULT_NITS" = "wave:NITS" ]; then
  pass "P2: should-severity finding only → parser produces wave:NITS"
else
  fail "P2: expected wave:NITS from should-severity finding, got: $RESULT_NITS"
fi

# --- Parser test: PASS verdict (zero findings) should produce wave:PASS ---
PASS_DIR="$SANDBOX/verdicts_pass"
mkdir -p "$PASS_DIR"
cat > "$PASS_DIR/T1-style.txt" << 'EOF'
## Reviewer verdict
axis: style
verdict: PASS
findings:
EOF

RESULT_PASS="$(parse_verdict_dir "$PASS_DIR")"
if [ "$RESULT_PASS" = "wave:PASS" ]; then
  pass "P3: no findings → parser produces wave:PASS"
else
  fail "P3: expected wave:PASS from empty findings, got: $RESULT_PASS"
fi

# --- Parser test: malformed footer (no ## Reviewer verdict) → wave:BLOCK ---
MALFORMED_DIR="$SANDBOX/verdicts_malformed"
mkdir -p "$MALFORMED_DIR"
cat > "$MALFORMED_DIR/T2-security.txt" << 'EOF'
Reviewer output without the verdict section header.
axis: security
verdict: PASS
EOF

RESULT_MALFORMED="$(parse_verdict_dir "$MALFORMED_DIR")"
if [ "$RESULT_MALFORMED" = "wave:BLOCK" ]; then
  pass "P4: malformed footer (no '## Reviewer verdict' header) → parser produces wave:BLOCK"
else
  fail "P4: expected wave:BLOCK from malformed footer, got: $RESULT_MALFORMED"
fi

# --- Parser test: explicit verdict:BLOCK at task level forces wave:BLOCK
#     even when no must-severity finding line is present ---
EXPLICIT_BLOCK_DIR="$SANDBOX/verdicts_explicit_block"
mkdir -p "$EXPLICIT_BLOCK_DIR"
cat > "$EXPLICIT_BLOCK_DIR/T1-security.txt" << 'EOF'
## Reviewer verdict
axis: security
verdict: BLOCK
findings:
EOF

RESULT_EXPLICIT="$(parse_verdict_dir "$EXPLICIT_BLOCK_DIR")"
if [ "$RESULT_EXPLICIT" = "wave:BLOCK" ]; then
  pass "P5: explicit verdict:BLOCK (no must-line) → parser produces wave:BLOCK"
else
  fail "P5: expected wave:BLOCK from explicit verdict:BLOCK, got: $RESULT_EXPLICIT"
fi

# --- Parser test: NITS does not downgrade to PASS when mixed with PASS ---
MIXED_DIR="$SANDBOX/verdicts_mixed_nits_pass"
mkdir -p "$MIXED_DIR"
cat > "$MIXED_DIR/T1-security.txt" << 'EOF'
## Reviewer verdict
axis: security
verdict: PASS
findings:
EOF
cat > "$MIXED_DIR/T1-performance.txt" << 'EOF'
## Reviewer verdict
axis: performance
verdict: NITS
findings:
  - severity: should
    file: bin/example.sh
    line: 10
    rule: reviewer-performance
    message: Cache expensive call.
EOF

RESULT_MIXED="$(parse_verdict_dir "$MIXED_DIR")"
if [ "$RESULT_MIXED" = "wave:NITS" ]; then
  pass "P6: NITS + PASS mix → wave:NITS (NITS is not downgraded)"
else
  fail "P6: expected wave:NITS from mixed NITS+PASS, got: $RESULT_MIXED"
fi

# --- Parser test: BLOCK is not downgraded by a subsequent PASS ---
BLOCK_THEN_PASS_DIR="$SANDBOX/verdicts_block_then_pass"
mkdir -p "$BLOCK_THEN_PASS_DIR"
cat > "$BLOCK_THEN_PASS_DIR/T1-security.txt" << 'EOF'
## Reviewer verdict
axis: security
verdict: BLOCK
findings:
  - severity: must
    file: bin/example.sh
    line: 5
    rule: injection-attacks
    message: String-built command.
EOF
cat > "$BLOCK_THEN_PASS_DIR/T1-style.txt" << 'EOF'
## Reviewer verdict
axis: style
verdict: PASS
findings:
EOF

RESULT_BLOCK_PASS="$(parse_verdict_dir "$BLOCK_THEN_PASS_DIR")"
if [ "$RESULT_BLOCK_PASS" = "wave:BLOCK" ]; then
  pass "P7: BLOCK + PASS mix → wave:BLOCK (BLOCK is not downgraded)"
else
  fail "P7: expected wave:BLOCK from BLOCK+PASS mix, got: $RESULT_BLOCK_PASS"
fi

echo ""
echo "PASS"
exit 0
