# PRD — chore: chore-aware /scaff:plan + TPM chore-tiny short-circuit (Option A)

- **Slug**: `20260426-chore-scaff-plan-chore-aware`
- **Work-type**: chore
- **Tier**: standard
- **Has-UI**: false
- **Author**: PM
- **Date**: 2026-04-26

## Summary

Adopt Option A from `.claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md`: relax `.claude/commands/scaff/plan.md` step 1 to require `03-prd.md` always but only require `04-tech.md` when `work-type ≠ chore`, and add a chore-tiny short-circuit path inside `.claude/agents/scaff/tpm.md` so TPM produces the same 5-section minimal `05-plan.md` stub the orchestrator currently hand-writes. After this chore lands, `/scaff:next` on a chore × tiny feature dispatches `/scaff:plan` like any other tier and TPM short-circuits internally — no more hand-written stub by the orchestrator. `/scaff:implement`'s input contract (always `05-plan.md`) is preserved.

## Scope

- **`.claude/commands/scaff/plan.md`** (canonical edit) — relax step 1 input-validation gate. Current line 18: `1. Read STATUS. Require ` + "`03-prd.md`" + ` AND ` + "`04-tech.md`" + ` exist.` Replace with a conditional gate: `03-prd.md` is always required; `04-tech.md` is required only when STATUS `work-type ≠ chore`. STATUS reading mechanism mirrors `.claude/commands/scaff/next.md` step 4's `work_type` extraction (the `grep -m1 '^\- \*\*work-type\*\*:'` form), defaulting to `feature` when the field is absent (legacy feature default per tech-D3, R10.1). Keep the rest of step 1 (preflight resolution, abort semantics) unchanged.

- **`.claude/agents/scaff/tpm.md`** (canonical edit) — add a chore-tiny short-circuit path under the existing `## When invoked for /scaff:plan` section. The new path: when invoked on a feature with STATUS `work-type=chore` AND `04-tech.md` is absent, TPM produces a minimal `05-plan.md` stub matching the 5-section shape pinned in §Decisions (b) below. The stub's §1.3 paragraph is the canonical short-circuit text lifted near-verbatim from `.specaffold/archive/20260426-chore-status-template-skip-stages/05-plan.md` §1.3 (see §Decisions (c)). When `04-tech.md` is present, TPM follows the existing full-narrative authoring path unchanged.

- **`.claude/commands/scaff/next.md`** — update the matrix-driven skip pseudocode (step 4 `case "$status" in skipped)` arm) so the chore-tiny path no longer expects the orchestrator to hand-write `05-plan.md`. The new flow: `/scaff:next` dispatches `/scaff:plan` on chore-tiny like any other tier (no special-case orchestrator hand-write); TPM's chore-tiny short-circuit handles the missing `04-tech.md` internally. Remove or rewrite any doc-block / pseudocode that references the orchestrator hand-writing the stub. The `[~]` render shape from sibling chore `20260426-chore-status-template-skip-stages` is preserved unchanged.

- **`.claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md`** — update `updated:` frontmatter date to 2026-04-26 and append a section / paragraph noting the plumbing fix has landed (Option A chosen). Recommendation: update, not retire — the memory documents WHY TPM has chore-tiny-specific logic and the rationale forward is load-bearing for future readers (see §Decisions (d)).

## Reason

**Empirical**: four chore-tiny features have shipped under the orchestrator-hand-writes-stub workaround (`t108-migrate-coverage`, `seed-copies-settings`, `t114-migrate-coverage`, `status-template-skip-stages`). The memory `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` was bumped at the seed-copies-settings archive retro to "three chore-tiny shipped, plumbing fix overdue"; the count is now four. The workaround pattern is empirically stable enough to template into TPM.

**Cost**: each chore-tiny pays ~50 lines of orchestrator token-budget hand-writing the 5-section stub, plus the cognitive load of remembering the §1.3 paragraph shape on each invocation. Templating in TPM eliminates both.

**Triage**: Option A is more conservative than Option B. Option A preserves `/scaff:implement`'s input contract (always `05-plan.md`) and localises the chore-aware logic to `/scaff:plan` + TPM. Option B would relax `/scaff:implement` to accept `03-prd.md` as a checklist source — broader change-radius (touches a downstream input contract many tasks depend on) for the same outcome. Option B is explicitly rejected (see §Out-of-scope).

**Sibling chore brief**: `20260426-chore-status-template-skip-stages` §Decisions(e) filed this follow-up explicitly: "a separate `/scaff:chore` will pick up the Options A/B plumbing fix from `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md`."

## Checklist

- [ ] **C1** — `.claude/commands/scaff/plan.md` step 1 gate is conditional on `work-type`: `03-prd.md` always required; `04-tech.md` required only when `work-type ≠ chore`. **Verify**: `grep -F 'work-type' .claude/commands/scaff/plan.md` returns the conditional gate (at least one match in step 1's input-validation block referencing `work-type` and `chore`).

- [ ] **C2** — `.claude/agents/scaff/tpm.md` `## When invoked for /scaff:plan` section names the chore-tiny short-circuit path: when `work-type=chore` and no `04-tech.md`, TPM emits a 5-section minimal `05-plan.md` matching the canonical shape pinned in §Decisions (b)–(c) (header block + §1 Approach with §1.1/§1.2/§1.3/§1.4 + §2 Tasks with one task block including all required fields and one `- [ ]` checkbox + §3 Risks + §4 Open questions). **Verify**: `grep -F 'chore-tiny short-circuit' .claude/agents/scaff/tpm.md` returns at least one match in the `/scaff:plan` section AND `grep -F '§1.3' .claude/agents/scaff/tpm.md` returns at least one match (the canonical §1.3 paragraph reference).

- [ ] **C3** — `.claude/commands/scaff/next.md` no longer instructs the orchestrator to hand-write `05-plan.md` on chore-tiny; the chore-tiny path dispatches `/scaff:plan` (which TPM short-circuits) like any other tier. **Verify**: `grep -F 'hand-written' .claude/commands/scaff/next.md` and `grep -F 'hand-write' .claude/commands/scaff/next.md` both return no matches in the chore-tiny / matrix-skip arm (or the doc-block clearly states the orchestrator delegates to `/scaff:plan` + TPM rather than writing the stub itself).

- [ ] **C4** — `.claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` `updated:` frontmatter is `2026-04-26` and the body acknowledges the Option A plumbing fix has landed. **Verify**: `grep -F 'plumbing fix landed' .claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` returns at least one match (or equivalent wording naming Option A as the chosen resolution).

- [ ] **C5** (forward-only) — The next chore × tiny feature initialised after this chore lands has its `05-plan.md` produced by `/scaff:plan` → TPM (not hand-written by the orchestrator). **Verify** (runs on the post-deploy chore-tiny when one ships): `git log --oneline -10 -- .specaffold/features/<next-chore-tiny-slug>/05-plan.md` shows a commit authored by TPM (commit message naming TPM, e.g. `T... TPM: ...` or `plan: TPM short-circuit ...`), NOT a "plan stub" or "hand-written" orchestrator commit.

## Verify assertions

Rolled-up commands run from repo root after the chore lands:

```bash
# C1: /scaff:plan gate is conditional on work-type
grep -F 'work-type' .claude/commands/scaff/plan.md

# C2: TPM agent prompt names the chore-tiny short-circuit
grep -F 'chore-tiny short-circuit' .claude/agents/scaff/tpm.md
grep -F '§1.3' .claude/agents/scaff/tpm.md

# C3: orchestrator no longer hand-writes the stub
! grep -F 'hand-written' .claude/commands/scaff/next.md
! grep -F 'hand-write' .claude/commands/scaff/next.md

# C4: memory acknowledges plumbing fix landed
grep -F 'plumbing fix landed' .claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md

# C5 (forward-only; runs on next chore-tiny shipped):
# git log --oneline -10 -- .specaffold/features/<next-chore-tiny-slug>/05-plan.md
# expect: TPM-authored commit, not "plan stub" / "hand-written"
```

## Out-of-scope

- **Option B** — relaxing `/scaff:implement` step 1 to accept `03-prd.md` as the checklist source on chore-tiny. Rejected per §Reason: broader change-radius (touches a downstream input contract many tasks depend on) for the same outcome; Option A keeps the chore-aware logic localised to `/scaff:plan` + TPM. `/scaff:implement`'s input contract stays "always `05-plan.md`".

- **Backfilling the four already-archived chore-tiny features' `05-plan.md` files** to be regenerated by TPM. Archive immutability — the convention applies forward, not retroactively. The archived stubs remain as historical record; their §1.3 paragraphs cite the same memory and document the workaround era.

- **Changing the chore PRD template** (`.specaffold/prd-templates/chore.md`). The chore PRD format is unchanged; only the plan-authoring path that consumes it changes.

- **Retiring the chore-tiny short-circuit memory** (`.claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md`). Recommend update, not retire — the memory now documents WHY TPM has chore-tiny-specific logic, which is load-bearing for future readers who encounter the special-case path. See §Decisions (d).

- **Editing `bin/scaff-stage-matrix`** — it is a pure verdict emitter that reports `required|optional|skipped`; the chore-tiny `plan = optional` cell is correct as-is. The fix lives in `/scaff:plan` and TPM, not in the matrix helper.

- **Touching `/scaff:implement`** — explicitly preserved unchanged per Option A's conservatism principle.

- **Adding new tests beyond what the verify clause requires** — this is a doc/agent-instruction change, not a binary change. Verification is via grep + a forward check on the next chore-tiny.

## Decisions

- **(a) Option A chosen** (raw ask). Option B rejected; rationale documented in §Reason and §Out-of-scope.

- **(b) TPM short-circuit template location**: embed the 5-section template directly in `.claude/agents/scaff/tpm.md` under `## When invoked for /scaff:plan`, not in a separate `.specaffold/prd-templates/05-plan-chore-tiny.md` file. Rationale:
  1. TPM's agent prompt is already the source of truth for the full-narrative `05-plan.md` shape (the existing `### 05-plan.md — merged narrative + task checklist` section). Putting the chore-tiny variant adjacent keeps both shapes co-located and reviewable side-by-side; the contrast between "full narrative" and "chore-tiny short-circuit" is itself instructive.
  2. A separate prd-templates file would create a fourth file the chore touches and a parallel canonical source — TPM would still need agent-prompt instructions to know when to consult the template, and the indirection adds no value when the template is short (~30 lines).
  3. Symmetry with existing pattern: full-narrative authoring rules live in `tpm.md` itself, not in `.specaffold/prd-templates/`. The chore-tiny short-circuit follows the same convention.

- **(c) Canonical §1.3 paragraph**: the §1.3 from `.specaffold/archive/20260426-chore-status-template-skip-stages/05-plan.md` lines 22–26 is pinned as the canonical short-circuit shape TPM must reproduce (near-verbatim — TPM may substitute the feature slug and any feature-specific phrasing in §1.1/§1.2 but §1.3's load-bearing claim — "this file exists primarily to satisfy `/scaff:implement`'s contract; see `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` for the plumbing-fix history" — must remain). After this chore lands, the §1.3 paragraph evolves: instead of "this file should not be regenerated by TPM — it is intentionally hand-written until the plumbing lands", TPM emits "this file is auto-generated by TPM's chore-tiny short-circuit (Option A landed `20260426-chore-scaff-plan-chore-aware`); see `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` for the rationale."

- **(d) Memory disposition — update, not retire**: `.claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` is updated, not removed. Rationale: the memory now documents (i) why TPM has chore-tiny-specific logic at all, (ii) the four archived features that pre-date the fix, and (iii) the rejected Option B for future readers asking "why didn't we just relax /scaff:implement?". Retiring the memory would erase that paper trail. Developer (T1) updates the memory body's How-to-apply step 1 to point at the new TPM short-circuit path instead of the orchestrator hand-write recipe; the §Why section gains a "plumbing fix landed 2026-04-26 (Option A)" line.

- **(e) STATUS reading mechanism in `/scaff:plan`**: mirror the existing `work-type` extraction pattern from `.claude/commands/scaff/next.md` step 4 (`grep -m1 '^\- \*\*work-type\*\*:'` form, default `feature` when absent per R10.1). Do not introduce a new helper. The plan.md gate is a small bash conditional (~6–8 lines) inline in step 1; no new sourced helper is justified.

- **(f) Plan stub shape pinned**: TPM's chore-tiny output reproduces the precedent stub shape from `.specaffold/archive/20260426-chore-status-template-skip-stages/05-plan.md` — header block + §1 Approach (§1.1 Scope, §1.2 Why one task / N tasks, §1.3 Chore-tiny short-circuit, §1.4 Wave shape) + §2 Tasks (one or N task blocks with all required fields including the `- [ ]` checkbox) + §3 Risks + §4 Open questions. Field shape on each task block matches the existing TPM appendix task-block convention (Milestone, Requirements, Decisions, Scope, Deliverables, Verify, Depends on, Parallel-safe-with, `- [ ]`). This shape is unchanged from the four precedents; no novel structure is introduced.

## Open questions

None.
