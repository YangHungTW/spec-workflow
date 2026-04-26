---
name: STATUS [x] tech / [x] plan on chore-tiny features means "skipped" — flag the asymmetry only when no Notes line records the skip
description: On chore-tiny features, the established convention is [x] tech and [x] plan checked (STATUS template) with a Notes line "stage_status chore/tiny/<stage> = skipped" being authoritative; future analysts should accept silently UNLESS the matching Notes line is absent. Three analyst runs flagged inconsistently (t108/seed-copies-settings silently accepted, t114 flagged as should-drift); document the convention until the STATUS template plumbing-fix lands.
type: reference
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When analysing a chore × tiny feature's STATUS, the checkbox `[x] tech (04-tech.md)` paired with a Notes line `stage_status chore/tiny/tech = skipped` (or equivalent) is the established convention — checked-means-done-or-skipped, Notes are authoritative. Same for `[x] plan` (paired with the chore-tiny-plan-short-circuit hand-write Notes line). Do NOT flag as drift when both the checkbox and the matching Notes line are present. DO flag if (a) the checkbox is `[x]` but no Notes line records the skip, (b) `04-tech.md` / `05-plan.md` content is genuinely present despite the skip claim, or (c) the convention itself is being changed (template plumbing-fix landing).

## Why

Three consecutive chore-tiny features (`20260426-chore-t108-migrate-coverage`, `20260426-chore-seed-copies-settings`, `20260426-chore-t114-migrate-coverage`) all have `[x] tech (04-tech.md)` checked with `04-tech.md` absent. Analysts handled this inconsistently — t108 and seed-copies-settings analysts silently accepted; t114 analyst flagged it as should-drift. The asymmetric handling produces noise without action because the underlying STATUS template is fixed (the `_template/STATUS.md` initialises every stage as `[ ]`; the chore-tiny short-circuit at `/scaff:next` flips them to `[x]` with a Notes line). Future analysts should treat the convention as established and only flag genuine inconsistencies. Consistent acceptance lets the analyst axis surface real drift instead of re-litigating a known convention every chore-tiny.

## How to apply

1. **Accept silently** when both are present:
   - Checkbox: `[x] tech (04-tech.md)` and/or `[x] plan (05-plan.md)`.
   - Notes line: `<date> next — stage_status chore/tiny/<stage> = skipped` (or the chore-tiny-plan-short-circuit variant for `plan`).
2. **Flag (should-drift)** when:
   - Checkbox is `[x]` but no Notes line records the skip — checkbox is unsupported.
   - `04-tech.md` exists despite the checkbox-Notes skip claim — the artefact contradicts the claim.
   - The work-type is feature, not chore (different matrix; the convention does not transfer).
3. **New convention (post-`20260426-chore-status-template-skip-stages`)**: the orchestrator now writes `[~] <stage> ... (skipped — chore × tiny matrix)` (or `(skipped — has-ui: false)` for the design-skip path) instead of `[x]` for matrix-skipped stages. Accept `[~]` silently — it is self-describing and intentional. Legacy archived chore-tiny features (`20260426-chore-t108-migrate-coverage`, `20260426-chore-seed-copies-settings`, `20260426-chore-t114-migrate-coverage`) retain the `[x]` form; the acceptance criteria in step 1 still apply when reviewing those archives. This memory is no longer a candidate for retirement on the plumbing-fix landing; it remains as a reference for the legacy `[x]` shape and the transition to `[~]`.

## Example

Three archived chore-tiny features show the pattern at STATUS line 15-16:
- `.specaffold/archive/20260426-chore-t108-migrate-coverage/STATUS.md` line 15 — `[x] tech` paired with skip Notes; analyst silently accepted.
- `.specaffold/archive/20260426-chore-seed-copies-settings/STATUS.md` line 15 — `[x] tech` paired with skip Notes; analyst silently accepted ("checked-means-done-or-skipped, Notes are authoritative" verbatim in 08-validate.md).
- `.specaffold/archive/20260426-chore-t114-migrate-coverage/STATUS.md` line 16 — `[x] tech` paired with skip Notes; analyst Finding 2 flagged as should-drift. Disposition at archive retro: accept-with-rationale + file plumbing follow-up chore.

Cross-references:
- `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` (the parent plumbing-gap memory; this one specialises to the analyst-axis disposition).
- `bin/scaff-stage-matrix` (the helper that classifies stages as `skipped` for chore × tiny).
