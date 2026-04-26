# Plan — chore: chore-aware /scaff:plan + TPM chore-tiny short-circuit (Option A)

- **Feature**: `20260426-chore-scaff-plan-chore-aware`
- **Stage**: plan
- **Author**: orchestrator (hand-written; chore × standard variant of chore-tiny short-circuit — see §1.3)
- **Date**: 2026-04-26
- **Tier**: standard
- **Work-type**: chore

PRD: `03-prd.md` (chore checklist).

## 1. Approach

### 1.1 Scope

Land Option A from `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md`: edit `.claude/commands/scaff/plan.md` step 1 to make `04-tech.md` conditional on `work-type ≠ chore`; embed a chore-tiny short-circuit path in `.claude/agents/scaff/tpm.md` so TPM produces the 5-section minimal `05-plan.md` stub itself; clean up `.claude/commands/scaff/next.md` to stop instructing the orchestrator to hand-write the stub; update `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` to acknowledge the plumbing fix landed. While touching `.claude/commands/scaff/next.md` for C3, also generalise the matrix-skip pseudocode's hardcoded `(skipped — chore × tiny matrix)` suffix wording to `(skipped — chore × <tier> matrix)` so future chore × standard / audited features render accurately (this PRD-out-of-scope-but-1-line cleanup is justified because the pseudocode is being touched anyway and the hardcoded `tiny` is empirically wrong on chore × standard — see §1.5).

### 1.2 Why two tasks

The work splits cleanly along a dependency seam:
- **T1** (production change): `.claude/commands/scaff/plan.md` step 1 conditional gate + `.claude/agents/scaff/tpm.md` chore-tiny short-circuit template. These two files together implement the chore-aware behaviour. They must land atomically — the plan.md gate without the TPM template would let `/scaff:plan` accept missing 04-tech.md and then TPM would have no instructions for what to produce.
- **T2** (downstream cleanup + documentation): `.claude/commands/scaff/next.md` removes the orchestrator-hand-writes-stub pseudocode (and generalises the suffix wording per §1.5); `.claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` acknowledges plumbing fix landed. T2 references the new TPM behaviour T1 establishes.

T2 depends on T1 (the new TPM path must exist before next.md can delegate to it). Single wave, T1 → T2 serial via `Depends on:`.

### 1.3 Bootstrap workaround — final hand-written stub

This feature is `chore × standard`. The stage matrix reports `design = skipped`, `tech = skipped`, `plan = REQUIRED`. The `/scaff:plan` command currently hard-requires `04-tech.md` (its step 1: "Require 03-prd.md AND 04-tech.md exist"), but tech is matrix-skipped on chore × any-tier. The chore-tiny short-circuit memory's workaround applies semantically: rather than dispatch `/scaff:plan` and fail, the orchestrator hand-writes this minimal plan from the chore PRD's checklist. This file exists primarily to satisfy `/scaff:implement`'s contract.

This is the **fifth and final occurrence** of the workaround — T1 of this feature lands the plumbing fix that means future chore × any-tier features will have TPM auto-generate this shape. After this feature archives, the orchestrator's next.md pseudocode for chore-tiny matrix-skip will delegate to `/scaff:plan` (which TPM short-circuits) instead of hand-writing. This file is the sentinel boundary — it exists to record that the workaround was used and is now retired.

Cross-references: `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` (the parent memory; T2 updates it to mark "plumbing fix landed"). The four prior precedents are `20260426-chore-t108-migrate-coverage`, `20260426-chore-seed-copies-settings`, `20260426-chore-t114-migrate-coverage`, `20260426-chore-status-template-skip-stages`.

### 1.4 Wave shape

Single wave, two tasks (T1 → T2 serial). Tier=standard so inline review is ON by default (R16): each task merge runs reviewer-security + reviewer-performance + reviewer-style. Worktrees not needed for serial pair on a single feature branch — `--serial` mode is acceptable.

### 1.5 Suffix-wording cleanup (piggyback on T2)

The matrix-skip pseudocode in `.claude/commands/scaff/next.md` (landed by `20260426-chore-status-template-skip-stages` T1) hardcodes `(skipped — chore × tiny matrix)` as the suffix for ALL matrix-skipped stages. This is empirically wrong on chore × standard (this very feature's STATUS used `(skipped — chore × standard matrix)` to be accurate). T2 generalises the pseudocode to `(skipped — chore × <tier> matrix)` (or equivalent template form) so the orchestrator emits the correct suffix on any tier. One-line tweak; piggyback on T2's next.md edit. Documenting here because it's PRD-adjacent rather than PRD-explicit.

## 2. Tasks

## T1 — Make /scaff:plan chore-aware + add TPM chore-tiny short-circuit template
- **Milestone**: M1
- **Requirements**: chore PRD §Checklist C1 + C2 (folded)
- **Decisions**: chore PRD §Decisions (a)–(c), (e)–(f); render shape and §1.3 paragraph pinned per PRD §Decisions (c); STATUS reading mechanism mirrors next.md step 4's `work_type` extraction (PRD §Decisions (e)); TPM short-circuit template embedded in `.claude/agents/scaff/tpm.md` not in a separate prd-templates file (PRD §Decisions (b))
- **Scope**:
  - `.claude/commands/scaff/plan.md` step 1 — locate the line currently reading `1. Read STATUS. Require ` + "`03-prd.md`" + ` AND ` + "`04-tech.md`" + ` exist.` Replace with a small bash conditional that:
    1. always asserts `03-prd.md` exists.
    2. extracts `work_type` from STATUS via the `grep -m1 '^\- \*\*work-type\*\*:' "$feature_dir/STATUS.md"` form (default `feature` when absent per R10.1).
    3. asserts `04-tech.md` exists ONLY when `work_type` is not `chore`.
    Keep the rest of step 1 (preflight, abort semantics, error messages) intact. Add a brief comment naming the chore-tiny short-circuit memory.
  - `.claude/agents/scaff/tpm.md` `## When invoked for /scaff:plan` section — add a chore-tiny short-circuit subsection (or inline conditional, agent's discretion as long as the agent can act on it deterministically). The new path: when STATUS has `work-type: chore` AND `04-tech.md` is absent, TPM emits a minimal `05-plan.md` matching the canonical 5-section shape pinned in PRD §Decisions (b)–(c) and (f). The §1.3 paragraph evolves per PRD §Decisions (c): instead of saying the file is intentionally hand-written until plumbing lands, TPM emits "this file is auto-generated by TPM's chore-tiny short-circuit (Option A landed `20260426-chore-scaff-plan-chore-aware`); see `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` for the rationale." Keep the existing full-narrative authoring path unchanged when 04-tech.md is present.
- **Deliverables**:
  - `.claude/commands/scaff/plan.md` (edit step 1 input gate; ~6–10 line diff)
  - `.claude/agents/scaff/tpm.md` (add chore-tiny short-circuit subsection with embedded template; ~30–50 line addition)
- **Verify**:
  - C1: `grep -F 'work-type' .claude/commands/scaff/plan.md` returns at least one match in step 1's input-validation block.
  - C2a: `grep -F 'chore-tiny short-circuit' .claude/agents/scaff/tpm.md` returns at least one match in the `/scaff:plan` section.
  - C2b: `grep -F '§1.3' .claude/agents/scaff/tpm.md` returns at least one match (the canonical §1.3 paragraph reference).
  - Markdown sanity: `head -200 .claude/commands/scaff/plan.md` and `head -300 .claude/agents/scaff/tpm.md` confirm no broken fences / headings.
- **Depends on**: —
- **Parallel-safe-with**: —
- [x]

## T2 — Clean up next.md hand-write pseudocode + update memory + generalise suffix wording
- **Milestone**: M1
- **Requirements**: chore PRD §Checklist C3 + C4 (folded); §1.5 piggyback (suffix wording generalisation)
- **Decisions**: chore PRD §Decisions (d) (memory disposition = update, not retire); §1.5 (suffix wording generalised from `chore × tiny matrix` to `chore × <tier> matrix` template form)
- **Scope**:
  - `.claude/commands/scaff/next.md` step 4 matrix-skip arm — remove or rewrite the doc-block / pseudocode that references the orchestrator hand-writing `05-plan.md`. The new flow: `/scaff:next` dispatches `/scaff:plan` on chore-tiny (and chore × any-tier where tech is matrix-skipped) like any other tier; TPM's chore-tiny short-circuit (T1's deliverable) handles the missing 04-tech.md internally. Preserve the `[~]` render shape unchanged; preserve the matrix-skip + has-ui design-skip arms unchanged except for the hand-write removal.
  - `.claude/commands/scaff/next.md` matrix-skip pseudocode comment — generalise the hardcoded `(skipped — chore × tiny matrix)` suffix to a template form like `(skipped — <work-type> × <tier> matrix)` or `(skipped — chore × <tier> matrix)` so the orchestrator emits the correct suffix on any chore tier (this feature's STATUS used `chore × standard matrix` accurately; the hardcoded `tiny` would have been wrong forward). One-line change inside the comment block at lines 59 / 63.
  - `.claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` — bump `updated:` frontmatter to `2026-04-26` and append (or rewrite §Why's tail) acknowledging the Option A plumbing fix has landed. Concrete wording: include the literal phrase "plumbing fix landed" so the verify grep matches; cite this feature's slug and date; preserve §How-to-apply step 1's existing recipe but mark it as legacy (applicable when reading the four archived precedents) and add a new step pointing readers to TPM's chore-tiny short-circuit path for forward use.
  - `.claude/team-memory/tpm/index.md` — update the hook line for the memory if material (the existing hook says "until plumbing is fixed"; that wording is stale post-fix). Brief one-line update; not strictly required but consistent with the memory body.
- **Deliverables**:
  - `.claude/commands/scaff/next.md` (one or two small edits in step 4's matrix-skip arm and the suffix wording)
  - `.claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` (frontmatter `updated:` bump + §Why "plumbing fix landed" line + §How-to-apply step 1 marked legacy)
  - `.claude/team-memory/tpm/index.md` (one-line hook refresh; optional but recommended)
- **Verify**:
  - C3a: `grep -F 'hand-written' .claude/commands/scaff/next.md` returns no matches in the matrix-skip arm.
  - C3b: `grep -F 'hand-write' .claude/commands/scaff/next.md` returns no matches in the matrix-skip arm.
  - C4: `grep -F 'plumbing fix landed' .claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` returns at least one match.
  - §1.5 piggyback: `grep -F 'chore × tiny matrix' .claude/commands/scaff/next.md` returns no matches OR returns only matches in historical / explanatory prose blocks (not in the active pseudocode comment); the suffix template is generalised to a form that doesn't hardcode `tiny`.
- **Depends on**: T1 (T2's next.md and memory both reference the new TPM short-circuit behaviour T1 establishes)
- **Parallel-safe-with**: —
- [x]

## 3. Risks

- **plan.md grep STATUS reading correctness** — the plan.md gate adds a small bash conditional to read STATUS `work-type`. Risk: subtle parse difference vs. next.md's existing extraction (e.g. trailing whitespace handling). Mitigation: lift the exact `grep -m1 '^\- \*\*work-type\*\*:'` form verbatim per PRD §Decisions (e); do not invent a new helper; do not introduce regex variants.
- **tpm.md template alignment** — TPM's emitted §1.3 paragraph must match the canonical shape pinned in PRD §Decisions (c). Risk: silent drift if the template wording diverges from the precedent. Mitigation: Developer copies the §1.3 from `.specaffold/archive/20260426-chore-status-template-skip-stages/05-plan.md` lines 22–26 verbatim and substitutes only the "auto-generated by TPM" framing per PRD §Decisions (c). Validate's tester axis greps for the canonical phrase.
- **Inline review on tier=standard** — this feature triggers reviewer-security + reviewer-performance + reviewer-style on each task merge. Risk: doc/agent-prompt edits should pass clean, but a security reviewer might flag the `grep -m1` pattern in the new plan.md gate as untrusted-input handling. Mitigation: STATUS file is internal (not external user input); `grep -m1` is safe; the existing next.md uses the same pattern for the same purpose. If the security axis flags it, point at the next.md precedent in the response.
- **Bootstrap recursion** — this feature's `05-plan.md` is hand-written per the very workaround the feature eliminates. The §1.3 here is intentional self-reference. Risk: confusing for a reader cold. Mitigation: §1.3 above explicitly names this as the fifth and final occurrence; T2 of T1 lands the fix.

## 4. Open questions

None. All decisions pinned in PRD §Decisions or this plan §1.
