---
name: PRD acceptance must scope to the helper, not "anywhere" — upstream callers may defeat literal contracts
description: When writing AC for a fix in helper X, "no .bak written anywhere" reads cleanly but is unachievable if any upstream caller of X performs its own atomic-write-with-backup. Trace upstream first and scope AC to the helper's own execution, not pipeline-wide.
type: feedback
created: 2026-04-27
updated: 2026-04-27
---

## Rule

When writing an acceptance criterion for a fix that lands inside a helper or library function, scope the AC's quantifier to that helper's own execution. Avoid pipeline-wide quantifiers like "no `.bak` written anywhere" or "the file is untouched" — they read cleanly but fail to hold whenever any upstream caller in the same flow performs its own atomic-write-with-backup discipline that runs adjacent to (but is not gated by) the helper.

## Why

In `20260426-fix-install-hook-wrong-path`, PRD AC3 was originally written as: *"Re-running `scaff-seed init` against the same consumer is idempotent: it does not create a `settings.json.bak` (anywhere), and `<consumer>/.claude/settings.json` remains semantically unchanged."* The "anywhere" clause was load-bearing for the bug ("settings.json.bak should not appear at the consumer root") but unachievable as written: `bin/scaff-seed` Step 7's Python merge unconditionally writes `.claude/settings.json.bak` whenever the destination file exists. That backup discipline is *correct* and *unrelated* to the helper-side idempotency fix; it just means "no `.bak` anywhere on second run" is structurally false.

The validate stage caught this (qa-analyst Finding F1, severity should). The test had already substituted byte-identity for the literal contract — defensible — but the PRD text was never amended. Future readers may assume the contract held literally and write follow-up code that depends on the false invariant.

The cleaner AC would have scoped to the helper's own execution: *"the helper, when invoked with an entry that is already present, does NOT write a `.bak`"*. This holds, is testable, and doesn't promise behaviour outside the helper's reach.

## How to apply

1. **Before writing each AC**, identify the *enclosing scope*: is this a helper-level invariant, a callsite-level invariant, or a pipeline-level invariant? Write the quantifier to match.
2. **Watch for "anywhere" / "everywhere" / "never" without a subject**. These are pipeline-level quantifiers; they require evidence that every callsite in the pipeline either (a) does not produce the artefact, or (b) is in scope of the same fix.
3. **Trace upstream callers** of the helper being fixed. For each caller, ask: does this caller produce the same artefact (`.bak`, log line, side-effect file) independently? If yes, the AC's quantifier must exclude that caller's emission, or the fix must extend to that caller.
4. **Prefer scope-narrowed wording**:
   - Bad: "no `.bak` is ever written"
   - Good: "the helper does not write a `.bak` when the operation is a no-op"
   - Better: "calling the helper with an entry already present produces no filesystem change (verified by checksum)"

## Source

`20260426-fix-install-hook-wrong-path` PRD AC3, validate Finding F1. The PRD said "anywhere"; Step 7's `scaff-seed` write dirtied `.claude/settings.json.bak` on every second invocation regardless of the helper's idempotency. The test substituted byte-identity (correct invariant) but the PRD text remained literally false. Recommended follow-up: amend AC3 wording in the archived PRD or add a §Constraints note acknowledging Step 7's behaviour.

## Cross-reference

- `qa-analyst/task-acceptance-stricter-than-prd-allowance.md` — sibling memory: when the test is *stricter* than the PRD allows, prefer the PRD wording. This memory is the inverse: when the PRD is *broader* than the helper's reach, narrow the PRD.
