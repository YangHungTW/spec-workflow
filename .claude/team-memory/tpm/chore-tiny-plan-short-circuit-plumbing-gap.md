---
name: Chore-tiny plan short-circuit — /scaff:plan + /scaff:implement plumbing gap
description: On work-type=chore × tier=tiny, /scaff:plan hard-requires 04-tech.md (matrix-skipped on this combo) and /scaff:implement hard-requires 05-plan.md with `- [ ]` lines; until the plumbing is fixed, the orchestrator must skip /scaff:plan formally and hand-write a minimal 05-plan.md derived from the chore PRD checklist to satisfy implement's contract.
type: pattern
created: 2026-04-26
updated: 2026-04-26
---

## Rule

When advancing a `chore × tiny` feature past `prd` to `implement`, the orchestrator cannot dispatch `/scaff:plan` (it errors on missing `04-tech.md`) and cannot dispatch `/scaff:implement` without `05-plan.md` (it errors on missing checklist). Resolution: append `[x] tech` (matrix-skipped) and `[x] plan` (matrix-optional + missing-prereq) to STATUS with explicit Notes lines, then **hand-write a minimal `05-plan.md`** that lifts the chore PRD's checklist into one or more task blocks (each with at least one `- [ ]`). This satisfies `/scaff:implement`'s precondition without invoking TPM, who would short-circuit anyway.

## Why

The `chore × tiny` row of the stage matrix (`bin/scaff-stage-matrix`) reports:

| stage | verdict |
|---|---|
| design | skipped |
| prd | required (PM writes during /scaff:chore intake) |
| tech | skipped |
| plan | optional |
| implement | required |
| validate | required |
| archive | required |

`/scaff:plan` (`.claude/commands/scaff/plan.md` step 1) hard-requires both `03-prd.md` AND `04-tech.md` exist. On chore-tiny, `04-tech.md` is matrix-skipped — it does not and should not exist. Dispatching `/scaff:plan` fails fast.

`/scaff:implement` (`.claude/commands/scaff/implement.md` step 1) hard-requires `05-plan.md` with at least one `^- \[ \]` line. Without `05-plan.md` the orchestrator cannot drive implement.

The first chore-tiny feature shipped end-to-end (`20260426-chore-t108-migrate-coverage`) hit this wall at runtime. Resolution was a hand-written 5-section `05-plan.md` that explicitly documents the short-circuit in §1.3 and lifts the chore PRD's 2 checklist items into one task block T1.

The plumbing fix (one of the two below) is owed to a future chore feature; capturing the workaround here saves the next TPM from re-deriving it and surfaces the gap as an actionable followup.

As of 2026-04-26, three chore-tiny features shipped end-to-end with this hand-written stub (`20260426-chore-t108-migrate-coverage`, `20260426-chore-seed-copies-settings`, `20260426-chore-t114-migrate-coverage`), plus one chore × standard variant (`20260426-chore-scaff-plan-chore-aware` itself). The Option A plumbing fix landed in `20260426-chore-scaff-plan-chore-aware` on 2026-04-26: plumbing fix landed — `/scaff:plan` now accepts missing `04-tech.md` when `work-type=chore`, and TPM's chore-tiny short-circuit path auto-generates `05-plan.md` without orchestrator hand-writing. The workaround in §How-to-apply step 1 is now **legacy** (applicable only when reading the four archived precedents).

## How to apply

1. **[LEGACY — applicable only when reading the four archived precedents: `20260426-chore-t108-migrate-coverage`, `20260426-chore-seed-copies-settings`, `20260426-chore-t114-migrate-coverage`, `20260426-chore-scaff-plan-chore-aware`] At /scaff:next dispatch from prd to implement on a chore-tiny feature**:
   - Verify STATUS `work-type: chore` and `tier: tiny`.
   - Verify `03-prd.md` exists and has a `## Checklist` section with `- [ ]` items.
   - Append `[x]` to the `tech` line in STATUS with Notes line: `<date> next — tech skipped (stage_status chore/tiny/tech = skipped)`.
   - Append `[x]` to the `plan` line in STATUS with Notes line: `<date> next — plan skipped (stage_status chore/tiny/plan = optional; /scaff:plan hard-requires 04-tech.md which is matrix-skipped; minimal 05-plan.md hand-written from 03-prd.md checklist for implement consumption)`.
   - Hand-write `05-plan.md` with this minimal shape:
     ```markdown
     # Plan — chore: <short title>

     - **Feature**: `<slug>`
     - **Stage**: plan
     - **Author**: orchestrator (hand-written; chore-tiny short-circuit — see §1.3)
     - **Date**: <date>
     - **Tier**: tiny
     - **Work-type**: chore

     PRD: `03-prd.md` (chore checklist).

     ## 1. Approach
     ### 1.1 Scope
     <one-paragraph summary lifted from chore PRD §Summary + §Scope>
     ### 1.2 Why one task (or N tasks)
     <justification — most chore-tiny will fold the whole checklist into one task>
     ### 1.3 Chore-tiny short-circuit
     <verbatim or near-verbatim copy of the §1.3 in this entry's Example below>
     ### 1.4 Wave shape
     Single wave, single (or N) task. No inline review (R16 default for tier=tiny). No worktree needed for one task.

     ## 2. Tasks
     ## T1 — <chore PRD checklist item, rolled up>
     - **Milestone**: M1
     - **Requirements**: chore PRD checklist items (folded)
     - **Decisions**: chore PRD §Scope
     - **Scope**: <verbatim from chore PRD §Scope>
     - **Deliverables**: <files touched>
     - **Verify**: <chore PRD §Verify assertions, rolled up>
     - **Depends on**: —
     - **Parallel-safe-with**: —
     - [ ]

     ## 3. Risks
     <small risks; usually 1-2 lines>

     ## 4. Open questions
     None.
     ```
   - Commit the plan stub with a message that names the short-circuit explicitly:
     ```
     plan stub: chore-tiny short-circuit (1 task, no Architect/TPM dispatch)

     design/tech matrix-skipped; plan stub hand-written from chore PRD checklist
     because /scaff:plan hard-requires 04-tech.md which is matrix-skipped on chore-tiny.

     Surfaced for archive retro: /scaff:plan should accept missing 04-tech.md
     when work-type=chore, or /scaff:implement should accept 03-prd.md as the
     checklist source on chore-tiny.
     ```

2. **[CURRENT — for all new chore × any-tier features] Dispatch `/scaff:plan` normally.** The Option A plumbing fix (`20260426-chore-scaff-plan-chore-aware`, 2026-04-26) wired TPM's chore-tiny short-circuit path in `.claude/agents/scaff/tpm.md`. When STATUS has `work-type: chore` and `04-tech.md` is absent, TPM auto-generates a minimal `05-plan.md` without orchestrator hand-writing. No special handling needed at `/scaff:next` dispatch.

3. **[ARCHIVED — for historical reference only] The plumbing fix options that were under consideration** — pick ONE:
   - **Option A**: `/scaff:plan` step 1 becomes "Require `03-prd.md`; require `04-tech.md` ONLY if work-type ≠ chore". TPM short-circuits to a minimal 05-plan.md when no 04-tech.md is present (lifts the chore PRD checklist).
   - **Option B**: `/scaff:implement` step 1 becomes "Require `05-plan.md` OR (work-type=chore AND `03-prd.md` with `^- \[ \]` items)". The implement reader treats the chore PRD's checklist as the task list directly when no plan exists.

   Option A is more conservative (preserves implement's input shape); Option B avoids the hand-written stub entirely. Either eliminates this memory's How-to-apply step 1.

## Example

The hand-written `05-plan.md` from `20260426-chore-t108-migrate-coverage` (now archived) is the canonical reference. Its §1.3 reads:

> The stage matrix for `chore × tiny` reports: `design = skipped`, `tech = skipped`, `plan = optional`. The `/scaff:plan` command hard-requires `04-tech.md` (its step 1: "Require 03-prd.md AND 04-tech.md exist"), but tech is matrix-skipped on this tier. Rather than (a) error out at /scaff:plan dispatch or (b) have TPM short-circuit on missing prereq, the orchestrator hand-writes this minimal plan from the chore PRD's checklist. This file exists primarily to satisfy `/scaff:implement`'s contract (it requires `05-plan.md` with at least one `- [ ]` line).

The §1.3 paragraph is itself the load-bearing artefact — it documents WHY the file is hand-written so future readers don't try to "fix" it by replacing with a TPM-generated version. Until the plumbing fix lands, every chore-tiny feature's `05-plan.md` should carry an equivalent §1.3 block.

Cross-references: `architect/setup-hook-wired-commitment-must-be-explicit-plan-task.md` (orthogonal — that one is about feature plans not chore plans), `qa-analyst/partial-wiring-trace-every-entry-point.md` (the discipline that motivated the first chore-tiny shipped, but unrelated to the plumbing gap itself).
