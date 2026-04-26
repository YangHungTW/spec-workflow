# PRD — chore: STATUS render shape for matrix-skipped stages

- **Slug**: `20260426-chore-status-template-skip-stages`
- **Work-type**: chore
- **Tier**: tiny
- **Has-UI**: false
- **Author**: PM
- **Date**: 2026-04-26

## Summary

Change the orchestrator's chore × tiny short-circuit (`.claude/commands/scaff/next.md`) so matrix-skipped stages render in STATUS as `[~] <stage> (skipped — chore × tiny matrix)` instead of `[x] <stage>`. The new shape is visually distinct from a genuinely-completed stage and resolves analyst Finding 2 from archived feature `20260426-chore-t114-migrate-coverage`.

## Scope

- **`.canonical edit`**: `.claude/commands/scaff/next.md` — update the matrix-driven skip pseudocode (around step 4's `case "$status" in skipped)` block, lines ~54–69 in current file) so that when `stage_status` returns `skipped`, the orchestrator writes `- [~] <stage> ... — <role>     (skipped — chore × tiny matrix)` to STATUS instead of flipping the checkbox to `[x]`. The original right-hand annotation on the checklist line (`(02-design/) — Designer (skip if has-ui: false)` etc.) is preserved; only the leading `[ ]` is rewritten to `[~]` and a trailing ` (skipped — chore × tiny matrix)` (or the matching `(has-ui: false)` reason for the existing has-ui design-skip path, kept consistent) is appended.
- The matching STATUS Notes line (`<date> next — stage_status <wt>/<tier>/<stage> = skipped`) is unchanged.
- The same shape is applied to the `has-ui: false` design-skip path (next.md step 4 second-to-last bullet) for consistency, suffixing `(skipped — has-ui: false)`.
- **No edit to `.specaffold/features/_template/STATUS.md`** — see §Decisions (d).
- **No edit to `bin/scaff-stage-matrix`** — it is a pure verdict helper that emits only `required|optional|skipped`; rendering belongs in the orchestrator.
- **Memory update**: `.claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md` — update §How to apply step 3 to reflect the new convention (or retire entirely once the plumbing-fix is verified to apply forward).

## Reason

Closes analyst Finding 2 from archived feature `20260426-chore-t114-migrate-coverage` (`08-validate.md` lines 98–102, 134–137). Three consecutive chore × tiny features (`t108-migrate-coverage`, `seed-copies-settings`, `t114-migrate-coverage`) shipped with `[x] tech (04-tech.md)` rendered despite `04-tech.md` never being authored; analyst flagging was inconsistent (1-of-3 flagged). Cites memory `.claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md`. The archive retro for t114 filed this plumbing follow-up explicitly (STATUS.md line 39: "plumbing follow-up chore filed to update _template/STATUS.md so chore × tiny initialises [ ] for design/tech/plan").

The rendering-only fix is the smallest change that makes the checklist line self-describing — analysts and humans can tell, from the line alone, that the stage was matrix-skipped (not done).

## Checklist

- [ ] **C1** — `.claude/commands/scaff/next.md` step 4 `case "$status" in skipped)` arm describes writing `- [~] <stage> ... (skipped — chore × tiny matrix)` (or the canonical reason suffix when not chore-tiny) instead of flipping to `[x]`. **Verify**: `grep -F '[~]' .claude/commands/scaff/next.md` returns at least one line in the matrix-skip pseudocode block.
- [ ] **C2** — `.claude/commands/scaff/next.md` `has-ui: false` design-skip path (step 4 penultimate bullet) similarly emits `[~] design ... (skipped — has-ui: false)` for consistency. **Verify**: `grep -F 'skipped — has-ui: false' .claude/commands/scaff/next.md` returns the doc-block describing the new shape.
- [ ] **C3** — A freshly-initialised chore × tiny feature, advanced past `prd` via `/scaff:next` after this chore lands, renders skipped stages as `[~]`, not `[x]`. **Verify** (forward-only; runs on the next chore-tiny feature shipped): `grep -E '^\- \[~\] (design|tech|plan)' .specaffold/features/<next-chore-tiny-slug>/STATUS.md` returns the lines, AND `grep -E '^\- \[x\] (design|tech|plan)' .specaffold/features/<next-chore-tiny-slug>/STATUS.md` returns no matches before any of those stages execute.
- [ ] **C4** — `.claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md` updated to reflect the new convention (either §How to apply step 3 names `[~]` as the new shape, or the file is removed entirely now that the asymmetry is resolved). **Verify**: `grep -F '[~]' .claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md` matches OR the file is absent (`[ ! -f .claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md ]`).

## Verify assertions

Rolled-up commands run from repo root after the chore lands:

```bash
# C1: orchestrator describes the [~] render for matrix-skipped stages
grep -F '[~]' .claude/commands/scaff/next.md

# C2: orchestrator describes the [~] render for has-ui design-skip path
grep -F 'skipped — has-ui: false' .claude/commands/scaff/next.md

# C3: forward verification on the next chore × tiny feature initialised after this chore
# (run on the post-deploy chore-tiny STATUS.md when one ships)
grep -E '^\- \[~\] (design|tech|plan)' .specaffold/features/<next-chore-tiny-slug>/STATUS.md
! grep -E '^\- \[x\] (design|tech|plan)' .specaffold/features/<next-chore-tiny-slug>/STATUS.md

# C4: memory updated or retired
grep -F '[~]' .claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md \
  || [ ! -f .claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md ]
```

## Out-of-scope

- **The Options A/B plumbing fix** in `.claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` (eliminating the hand-written `05-plan.md` stub by relaxing `/scaff:plan`'s `04-tech.md` requirement OR teaching `/scaff:implement` to consume the chore PRD checklist directly). Larger scope; touches `/scaff:plan` and/or `/scaff:implement` semantics across all work-types. Surfaced as a follow-up chore brief in §Decisions (e).
- **Backfilling the three already-archived chore-tiny features' `STATUS.md`** to use the new render shape. Archive immutability — the convention applies forward, not retroactively. The archived files document the prior convention as historical record.
- **Editing `.specaffold/features/_template/STATUS.md`** to change the line text or initial-state shape. The template's current `[ ]` initial state is correct (it is the orchestrator's flip-on-skip output that needed changing, not the template). See §Decisions (d).
- **The `validate` and `archive` stages on chore-tiny**, which are matrix-`required` and execute normally — only `design`, `tech`, and `plan` are matrix-skipped on chore × tiny, so the new render shape only ever appears on those three lines.
- **Bumping `bin/scaff-stage-matrix`** — it is a pure helper that emits a verdict string; rendering is the orchestrator's job.

## Decisions

- **(a) Chosen render shape**: `[~] <stage> (<original right-side annotation>) (skipped — chore × tiny matrix)` for matrix-skipped stages on chore × tiny; `[~] <stage> (<original right-side annotation>) (skipped — has-ui: false)` for the orthogonal has-ui design-skip path. Rationale: `[~]` is a markdown-checkbox extension that GitHub renders as a tilde-marked box (visually distinct from both `[x]` and `[ ]`); preserves the same line shape (no template alignment churn); the trailing `(skipped — <reason>)` is human-readable and grep-friendly. Alternative `[-]` was considered (struck-through in some renderers) but rejected because GitHub does not render `[-]` distinctively from `[ ]` in all themes.
- **(b) Flip mechanic**: orchestrator rewrites only the leading checkbox (`[ ]` → `[~]`) and appends a `(skipped — <reason>)` suffix to the existing line; it does NOT replace the entire line text or strip the original right-side annotation (`— PM`, `— Architect`, etc.). This keeps the diff minimal and preserves role attribution for grep-based audits.
- **(c) Touched-files list**: `.claude/commands/scaff/next.md` (the canonical place) and `.claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md` (memory update or retirement). `bin/scaff-stage-matrix` is NOT touched — it is a pure verdict emitter; the rendering is the orchestrator's job.
- **(d) `_template/STATUS.md` posture**: NO change. The template correctly initialises every stage as `[ ]`; the bug is that the orchestrator's chore-tiny short-circuit was flipping skipped stages to `[x]`. Fixing the flip is the right place; changing the template line text would force every non-chore-tiny feature to also carry the `[~]` shape, which is incorrect (their stages execute normally).
- **(e) Follow-up chore brief (for a future intake)**: a separate `/scaff:chore` will pick up the Options A/B plumbing fix from `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md`. Suggested title: `chore: relax /scaff:plan or /scaff:implement to drop chore-tiny 05-plan.md hand-write`. That chore eliminates the 5-section hand-written `05-plan.md` stub and is independent of this rendering fix.

## Open questions

None.
