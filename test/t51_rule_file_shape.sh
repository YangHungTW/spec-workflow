#!/usr/bin/env bash
# test/t51_rule_file_shape.sh — structural grep assertions on
#   .claude/rules/common/language-preferences.md
# Usage: bash test/t51_rule_file_shape.sh
# Exits 0 iff all checks pass; FAIL:<label> to stderr + exit 1 on any miss.
# Pure static assertions — no sandbox needed (no $HOME mutation).

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
RULE="$REPO_ROOT/.claude/rules/common/language-preferences.md"

fail() { echo "FAIL: $1" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. File exists
# ---------------------------------------------------------------------------
[ -f "$RULE" ] || fail "file-exists: .claude/rules/common/language-preferences.md not found"

# ---------------------------------------------------------------------------
# 2. Frontmatter has exactly the five required keys
# ---------------------------------------------------------------------------
for key in name scope severity created updated; do
  grep -qF "${key}:" "$RULE" || fail "frontmatter-key-missing: ${key}"
done

# ---------------------------------------------------------------------------
# 3. Frontmatter values
# ---------------------------------------------------------------------------
grep -qF "name: language-preferences" "$RULE" || fail "frontmatter-value: name: language-preferences not found"
grep -qF "scope: common"              "$RULE" || fail "frontmatter-value: scope: common not found"
grep -qF "severity: should"           "$RULE" || fail "frontmatter-value: severity: should not found"

# ---------------------------------------------------------------------------
# 4. Body sections present in the required order
#    ## Rule must appear before ## Why, which must appear before ## How to apply
# ---------------------------------------------------------------------------
line_rule=$(grep -n "^## Rule$" "$RULE" | awk -F: '{print $1}' | head -1)
line_why=$(grep -n "^## Why$" "$RULE" | awk -F: '{print $1}' | head -1)
line_how=$(grep -n "^## How to apply$" "$RULE" | awk -F: '{print $1}' | head -1)

[ -n "$line_rule" ] || fail "section-order: '## Rule' section missing"
[ -n "$line_why"  ] || fail "section-order: '## Why' section missing"
[ -n "$line_how"  ] || fail "section-order: '## How to apply' section missing"

[ "$line_rule" -lt "$line_why" ] || fail "section-order: '## Rule' must appear before '## Why'"
[ "$line_why"  -lt "$line_how" ] || fail "section-order: '## Why' must appear before '## How to apply'"

# ---------------------------------------------------------------------------
# 5. Self-lint: body is English-only (no CJK hits)
#    bin/scaff-lint scan-paths exits 0 on a clean file
# ---------------------------------------------------------------------------
LINT="$REPO_ROOT/bin/scaff-lint"
[ -x "$LINT" ] || fail "self-lint: bin/scaff-lint not executable or missing"
"$LINT" scan-paths "$RULE" >/dev/null || fail "self-lint: bin/scaff-lint scan-paths returned non-zero (CJK hit in rule body)"

# ---------------------------------------------------------------------------
# 6. Conditional documentation: LANG_CHAT=zh-TW and a no-op/otherwise phrase
# ---------------------------------------------------------------------------
grep -qF "LANG_CHAT=zh-TW" "$RULE" || fail "conditional-pattern: LANG_CHAT=zh-TW not found"
grep -qE "otherwise|no-op" "$RULE"  || fail "conditional-pattern: 'otherwise' or 'no-op' phrase not found"

# ---------------------------------------------------------------------------
# 7. Six carve-outs (a)–(f) enumerated
#    The briefing names: file writes, tool-call arguments, commit messages,
#    CLI stdout, STATUS Notes, team-memory
# ---------------------------------------------------------------------------
grep -qE "\(a\)" "$RULE" || fail "carve-outs: (a) marker missing"
grep -qE "\(b\)" "$RULE" || fail "carve-outs: (b) marker missing"
grep -qE "\(c\)" "$RULE" || fail "carve-outs: (c) marker missing"
grep -qE "\(d\)" "$RULE" || fail "carve-outs: (d) marker missing"
grep -qE "\(e\)" "$RULE" || fail "carve-outs: (e) marker missing"
grep -qE "\(f\)" "$RULE" || fail "carve-outs: (f) marker missing"

# Verify the six expected carve-out subjects are present (case-insensitive friendly)
grep -qiE "file (content|writ)" "$RULE"   || fail "carve-outs: file-writes/content carve-out not found"
grep -qiE "tool.call|tool call" "$RULE"   || fail "carve-outs: tool-call-arguments carve-out not found"
grep -qiE "commit message"      "$RULE"   || fail "carve-outs: commit-messages carve-out not found"
grep -qiE "CLI stdout|stdout"   "$RULE"   || fail "carve-outs: CLI-stdout carve-out not found"
grep -qiE "STATUS Note"         "$RULE"   || fail "carve-outs: STATUS-Notes carve-out not found"
grep -qiE "team.memory"         "$RULE"   || fail "carve-outs: team-memory carve-out not found"

# ---------------------------------------------------------------------------
# 8. No reverse directive (AC3.b): rule must declare that file content must NOT
#    be written in zh-TW; verify by the presence of the explicit negation phrase.
#    A positive-only "write files in zh-TW" imperative (without negation guard)
#    would be absent from a conforming rule.
# ---------------------------------------------------------------------------
grep -qiE "No reverse directive|no condition under which file content" "$RULE" || \
  fail "no-reverse-directive: rule body missing the explicit negation of zh-TW file-content directive (AC3.b)"

# ---------------------------------------------------------------------------
# 9. Seven subagent roles named
# ---------------------------------------------------------------------------
for role in PM Architect TPM Developer QA-analyst QA-tester Designer; do
  grep -qF "$role" "$RULE" || fail "subagent-roles: '$role' not found in rule body"
done

# ---------------------------------------------------------------------------
# 10. Positive scope example (AC6.a) and ≥3 negative scope examples (AC6.b)
# ---------------------------------------------------------------------------

# Positive example: the rule includes an example of correct zh-TW chat use
grep -qi "positive" "$RULE" || fail "scope-examples: no positive scope example found"

# Negative examples: look for numbered negative items (1. / 2. / 3. within example section)
neg_count=$(grep -cE "^[0-9]+\." "$RULE" || true)
[ "$neg_count" -ge 3 ] || fail "scope-examples: fewer than 3 negative scope examples (found ${neg_count})"

# ---------------------------------------------------------------------------
echo PASS
exit 0
