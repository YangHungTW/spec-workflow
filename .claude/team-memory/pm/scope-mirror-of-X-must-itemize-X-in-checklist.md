---
name: PRD §Scope "mirror of <existing-block>" must itemise that block's full assertion set in §Checklist
description: When a chore PRD §Scope says "mirror of A2c" (or any sibling test block), the binding §Checklist must enumerate every assertion the referenced block makes — Developer writes to the checklist, not the prose; gaps become should-class drift findings at validate.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When a chore or test-extension PRD §Scope references an existing block as the shape to copy ("mirror of A2c", "parallel to A1/A2", "match A5"), the §Checklist (the binding acceptance text) must enumerate every distinct assertion the referenced block makes. Prose-level "mirror of X" without checklist itemisation produces a partial-mirror at validate, flagged as should-class drift.

## Why

Developer implements against §Checklist, not §Scope. Analyst measures against §Checklist. If §Scope promises N assertions but §Checklist only requires N-1, the resulting partial mirror is technically PRD-compliant (Developer met every checklist item) but reduces regression confidence on the un-checklisted assertions. The resulting analyst should-finding is then advisory rather than a hard fail, but it accumulates: every "mirror of X" PRD pattern that omits checklist itemisation produces one new should-drift, and the noise drowns out genuinely actionable findings.

## How to apply

1. When drafting a §Scope clause "mirror of `<block>`", grep the referenced test or production file for the assertion shape: `pass "` lines inside the referenced block, `assert*` calls, or equivalent. Each maps to one assertion the mirror is expected to carry.
2. Ensure §Checklist has one binding item per assertion, OR one item that names the full set explicitly: `mirrors A2c — asserts file existence AND byte-identity`.
3. If you want only a subset mirrored (e.g. existence but not content fidelity, because the underlying mechanism is identical), say so explicitly: `mirror of A2c except content fidelity (deferred per <reason>)`.
4. At validate, the analyst will measure the diff against §Checklist; the prose §Scope is advisory framing, not enforcement.

## Example

Feature `20260426-chore-t114-migrate-coverage` PRD: §Scope line 17 said "(c) on the merge sub-case `.claude/settings.json.bak` exists with the original content" (implicit content fidelity, "mirror of A2c"). §Checklist item 4 said only "asserts `.claude/settings.json.bak` is present" (existence only). Developer wrote A4 to the looser checklist; analyst Finding 1 flagged the partial mirror as should-class drift. The wording asymmetry between §Scope and §Checklist is the upstream cause; this rule prevents the recurrence at intake time.

Source: `.specaffold/archive/20260426-chore-t114-migrate-coverage/03-prd.md` line 17 vs line 30; `.specaffold/archive/20260426-chore-t114-migrate-coverage/08-validate.md` analyst Finding 1.
