---
name: bug × tiny hits the same plan-plumbing gap as chore × tiny — short-circuit not yet extended
description: /scaff:plan hard-requires 04-tech.md unless work-type=chore; bug × tiny is matrix-skipped on tech but the chore-tiny short-circuit never grew a bug-tiny branch. Until that lands, hand-write 05-plan.md from PRD's R/AC/T fields, mirroring the LEGACY chore-tiny workaround.
type: feedback
created: 2026-04-27
updated: 2026-04-27
---

## Rule

When advancing a `bug × tiny` feature past `prd` to `implement`, the orchestrator hits the same plumbing gap that `chore × tiny` hit pre-fix: matrix marks tech as `skipped` (so no `04-tech.md` exists) but `/scaff:plan` step 1 still requires `04-tech.md` for any `work-type ≠ chore`. TPM's chore-tiny short-circuit (in `.claude/agents/scaff/tpm.md`, landed in `20260426-chore-scaff-plan-chore-aware`) only fires when `work_type = chore`, so it does not cover bug-tiny.

Resolution until the plumbing fix extends to bug-tiny: append `[~] tech ... (skipped — bug × tiny matrix)` and `[x] plan` to STATUS with explicit Notes lines, then **hand-write a minimal `05-plan.md`** that lifts the bug PRD's R-ids, T-ids, and AC-ids into one task block (each with at least one `- [ ]`). This satisfies `/scaff:implement`'s precondition without invoking TPM, who would short-circuit by failing on the missing prereq anyway.

## Why

The `bug × tiny` row of `bin/scaff-stage-matrix` reports:

| stage | verdict |
|---|---|
| design | skipped |
| prd | required |
| tech | skipped |
| plan | optional |
| implement | required |
| validate | required |
| archive | required |

`/scaff:plan` step 1 hard-requires `04-tech.md` whenever `work-type ≠ chore`. The chore-tiny plumbing fix relaxed this to "Require `04-tech.md` ONLY when `work-type` is not `chore`" (per `tpm.md` "Chore-tiny short-circuit"). Bug was not included; the same gap remains for bug-tiny.

`20260426-fix-install-hook-wrong-path` (the first bug-tiny feature shipped end-to-end) hit this wall during `/scaff:next` from prd→implement. Resolution was a hand-written 5-section `05-plan.md` that explicitly documents the gap in §1.3 and lifts the bug PRD's R1–R6 / T1–T3 / AC1–AC4 into one task block.

## How to apply

1. **At /scaff:next dispatch from prd to implement on a bug-tiny feature**:
   - Verify STATUS `work-type: bug` and `tier: tiny`.
   - Verify `03-prd.md` exists and has populated R/AC/T sections.
   - Append `[~]` to the `tech` line in STATUS with Notes line: `<date> next — stage_status bug/tiny/tech = skipped`.
   - Append `[x]` to the `plan` line in STATUS with Notes line: `<date> next — plan stub hand-written from 03-prd.md (bug × tiny plumbing gap: ...)`.
   - Hand-write `05-plan.md` mirroring the chore-tiny stub shape but lifting bug PRD fields (R-ids → task Requirements, T-ids → task Verify regression-test list, AC-ids → task Verify acceptance commands).
   - The §1.3 paragraph must say "bug × tiny plumbing gap mirrors chore × tiny pre-fix" and cite this memory file by name so a future reader doesn't try to "fix" the file by replacing it with a TPM-generated version.

2. **Fold the proper plumbing fix into the next chore that touches `tpm.md` or `plan.md`**. Two equivalent fixes:
   - **Option A**: extend TPM's chore-tiny short-circuit to also fire on `work_type = bug AND tier = tiny`, lifting the bug PRD's R/AC/T into a single-task block.
   - **Option B**: relax `/scaff:plan` step 1 to "Require `04-tech.md` ONLY when `work-type ≠ chore` AND `tier ≠ tiny`".

   Option A keeps the require-tech invariant intact for non-tiny work-types; Option B is one-line in `plan.md`. Either eliminates this memory's How-to-apply step 1.

## Cross-reference

`tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` — the original chore-tiny memory; documents the LEGACY workaround that this bug-tiny case mirrors. The two memories should be retired together when the plumbing fix lands for both work-types.

## Source

`20260426-fix-install-hook-wrong-path` plan stub (§1.3 paragraph). Single shipped occurrence to date. If a second bug-tiny feature ships and re-hits the gap, escalate the plumbing fix priority — the workaround is cheap per-occurrence but the maintenance signal accrues.
