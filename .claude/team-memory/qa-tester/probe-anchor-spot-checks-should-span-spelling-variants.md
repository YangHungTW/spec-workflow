---
name: Probe-anchor spot checks should span spelling variants — use a regex, not a literal
description: Probe-anchor assertions (the test that a PM/TPM agent prompt contains a key phrase) should use a regex that admits hyphen vs space vs other valid spelling variants; literal greps falsely flag a benign rewording as a missing anchor.
type: feedback
created: 2026-04-24
updated: 2026-04-24
---

## Rule

When writing a test that asserts the presence of an anchor phrase in an agent prompt or template (e.g., "the PM probe MUST mention 'why now'"), use a regex that admits the natural spelling variants of the anchor — hyphen vs space, single vs double quote, plural vs singular — rather than a literal string match. The whole point of an anchor probe is that the *concept* is present; the test should not fail because the author wrote `why-now` where the probe template said `why now`.

## Why

Discovered during `20260424-entry-type-split` validate run:

- t105_request_backward_compat.sh asserted `grep -q "why now" .claude/commands/scaff/request.md` as part of the legacy-compat probe.
- request.md actually contained the phrase `why-now` (with a hyphen, matching the noun-form convention used in pm.md).
- pm.md used `why now` (space form, matching the question-prompt convention).
- The two spellings are semantically identical. The literal grep in t105 failed; the test reported "missing anchor phrase" even though both forms were present and pointed at the same concept.

The shallow fix is to pick one canonical spelling and rewrite all sites to match. The deep fix is to acknowledge that anchor phrases are *concepts*, and concept-tests should use concept-tolerant matching. A test is an anti-regression net for behaviour, not a style-guide enforcer for orthography.

Companion observation: an anchor probe that asserts a *literal* string is implicitly asserting two things — the concept is present AND the spelling has not drifted. If the latter is what the test wants to enforce, it should say so in a comment ("# canonical spelling check, not concept check"). Otherwise, the test should match the concept.

## How to apply

1. **Pick the regex form by default.** For two-word anchor phrases that have a natural punctuation alternation, write `grep -E 'why[- ]now'`. For anchors with an `s/-` alternation (e.g., `set up` vs `setup`), write `grep -E 'set[- ]?up'`. For anchors with optional articles, write `grep -Ei 'the?[[:space:]]+gate'`.
2. **Add `-i` (case-insensitive) by default** unless the test is deliberately checking casing. Anchor probes care about presence, not case.
3. **Comment the regex's intent next to it**, especially the variants admitted: `# accepts "why now" or "why-now" — both forms appear in repo`. Future maintainers shouldn't have to reverse-engineer why the regex is loose.
4. **If the test's purpose is canonical-spelling enforcement** (which is occasionally legitimate — e.g., commit-message linters), keep the literal grep but say so explicitly with a `# CANONICAL SPELLING CHECK:` header comment.
5. **At the boundary between concept-test and spelling-test, bias toward concept-test.** Validate findings rarely benefit from forcing one spelling over another; they benefit from confirming the anchor *idea* survived editing.

## Example

The fix that landed at validate-time during `20260424-entry-type-split`:

```diff
 # t105_request_backward_compat.sh
-if ! grep -q "why now" "$REPO_ROOT/.claude/commands/scaff/request.md"; then
-    echo "FAIL: request.md missing 'why now' probe anchor"
+# accepts "why now" or "why-now" — both forms appear (request.md uses
+# hyphen, pm.md uses space; both point to the same probe concept)
+if ! grep -Eq 'why[- ]now' "$REPO_ROOT/.claude/commands/scaff/request.md"; then
+    echo "FAIL: request.md missing 'why[- ]now' probe anchor"
     exit 1
 fi
```

This pattern generalises across every probe-anchor assertion in t103/t104/t105/t106. After the fix, a deliberate spelling change (e.g., switching pm.md's "why now" to "why-now" for consistency) won't break the probe-anchor net — only a deletion of the *idea* will.

Source: `20260424-entry-type-split` validate cycle, t105 false-negative caught by structural assertion run; remediation in same wave (no separate update-task cycle needed because the test was being authored in the same wave that surfaced the variant).

Cross-reference: the structural-vs-runtime split (`shared/dogfood-paradox-third-occurrence.md`) means anchor probes are the only mechanism for verifying that PM/TPM prompts retain key concepts after self-shipping refactors. Their fragility — and this rule's relaxation — directly affects whether dogfood-paradox features can be validated at all.
