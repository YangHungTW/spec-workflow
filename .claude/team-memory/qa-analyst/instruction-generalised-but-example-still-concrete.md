---
name: instruction-generalised-but-example-still-concrete
description: A piggyback generalisation that lifts an active instruction line from a concrete value to a template placeholder must also lift any adjacent `Before:` / `After:` example block to the same level of generality; swapping the example concrete-A→concrete-B instead of using `<placeholder>` produces a drifted-example finding the reviewer-style axis does not catch.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

At validate (gap-check), when a feature includes a piggyback edit that generalises an instruction line (e.g. `chore × tiny matrix` → `chore × <tier> matrix`), grep the surrounding lines for `Before:` / `After:` / example blocks and confirm any concrete value that was generalised in the instruction is also a placeholder in the example. An example that was swapped from concrete-A to concrete-B (instead of being promoted to `<placeholder>`) is a `should`-severity drifted-example finding: the instruction governs runtime behaviour, but a future agent reading the example as normative may emit the wrong concrete value.

## Why

Reviewer-style and reviewer-performance both passed clean on T2 of `20260426-chore-scaff-plan-chore-aware`; the drift surfaced only at validate. The piggyback edit at `.claude/commands/scaff/next.md` line 59 generalised the active instruction from `chore × tiny matrix` to `<work-type> × <tier> matrix`; the `After:` example two lines below was changed from `chore × tiny matrix` to `chore × standard matrix` — a swap, not a generalisation. The instruction's behaviour-controlling generality and the example's concrete tier name no longer agreed.

Reviewer-style's checklist focuses on diff-line correctness in isolation: `chore × standard matrix` is a valid line, no naming-convention drift, no commented-out code. The diff-style axis cannot detect that an adjacent line went template-form while this one stayed concrete. Validate's analyst axis is the right place because it reads PRD/plan against the diff and can spot semantic-not-syntactic drift.

This is adjacent to but distinct from `dead-code-orphan-after-simplification`: that one detects orphan helper functions; this one detects orphan example concretisations.

## How to apply

At validate, for any feature whose plan §1.x contains a piggyback / drive-by generalisation clause:

1. **Grep the touched file for example markers**: `grep -nE 'Before:|After:|example:|^>' <file>`.
2. **For each example hit, look up 5 lines and down 5 lines** for the corresponding active instruction. Compare the level of generality.
3. **If the instruction uses `<placeholder>` form and the example uses a concrete value**, flag as `should`-severity drifted-example: the example was edited at the same time but with the wrong shape.
4. **Reportable phrase**: "instruction at line N generalised to `<placeholder>`, but example at line M still hardcodes `concrete-value`; future readers may emit the wrong concrete."
5. **Distinguish from intentional concrete examples**: an example that was concrete BEFORE the piggyback edit and remains concrete AFTER is fine; only swapped concretes (where the piggyback touched the example but kept it concrete with a different value) are findings. `git blame` or `git log -p` on the example line confirms.

## Example

`.claude/commands/scaff/next.md` after T2 of `20260426-chore-scaff-plan-chore-aware`:

- Line 59 (active instruction): `(skipped — <work-type> × <tier> matrix)` — template form, governs runtime emission.
- Line 63 (`After:` example): `(skipped — chore × standard matrix)` — concrete; T2's diff swapped `tiny` → `standard` instead of promoting to `<work-type> × <tier>`.

Filed as `should`-severity drifted-example in `08-validate.md`. No runtime regression today (instruction controls behaviour); risk is forward-only — a future orchestrator on chore × tiny or chore × audited reading line 63 as normative could emit the wrong tier.
