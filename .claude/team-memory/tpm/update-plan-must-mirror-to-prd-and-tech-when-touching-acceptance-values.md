---
name: /scaff:update-plan must mirror to PRD and tech when touching acceptance values
description: update-plan edits that change a value referenced by PRD ACs or tech decisions must mirror-edit those artefacts in the same pass; otherwise analyst drift findings land at validate.
type: feedback
created: 2026-04-21
updated: 2026-04-21
---

## Rule

When `/scaff:update-plan` edits a value that also appears as a concrete acceptance-criterion value in 03-prd.md, or as a decision body in 04-tech.md, the TPM MUST mirror-edit those upstream artefacts in the same pass. The plan file is never the single source of truth for a value that originated in PRD or tech; it is a downstream projection.

## Why

`20260420-flow-monitor-control-plane` 2026-04-21 shipped `update-plan 9a7a45a` that retired the stale `brainstorm/tasks/gap-check/verify` command names from T96's scope and inserted the post-tier-model live 16-command set. The edit was correct and unblocked W1 retry. But three upstream surfaces continued to reference the pre-edit taxonomy:

- 03-prd.md AC5.b listed `request, brainstorm, design, prd, tech, plan, tasks, implement, next, gap-check, verify` as the palette contents.
- 03-prd.md AC8.b + 04-tech.md D3 listed DESTROY as `archive, update-prd, update-plan, update-tech, update-tasks`. The live set is `update-req / update-task` (two names differ).
- 05-plan.md T120 scope text at line 711 retained the pre-edit `SAFE has exactly 4 entries (request, brainstorm, gap-check, verify)` wording.

At validate, the analyst axis filed three `should` findings (M1, M2, DR2) for this drift. The runtime behaviour was correct because T96 + T100 consumed the live set; only the documents drifted.

The `tasks-doc-format-migration` memory already rules out scope re-litigation during format migrations, but this is the inverse case: a value change that MUST re-propagate, not a scope change that must not. Missing memory.

## How to apply

1. Before invoking `/scaff:update-plan` for anything other than a pure task-housekeeping edit (checkbox flip, wave re-order, date touch), grep 03-prd.md and 04-tech.md for any occurrence of the value being changed. If any upstream occurrence is found, the edit is not update-plan-only — it is a three-file coordinated edit.
2. Either (a) do all three edits in the same commit with a subject prefixed `update-plan+prd+tech: …`, or (b) refuse the narrow update-plan edit and escalate to `/scaff:update-req` (PM authoring) or `/scaff:update-tech` (Architect authoring), whichever owns the upstream value.
3. Never silently narrow the edit to the plan file alone on the theory that "the test enforces the live value". The test enforces runtime; the PRD/tech document is the contract for readers including future maintainers, reviewers at validate, and the qa-analyst axis.
4. When the TPM cannot be sure a value is upstream, run: `grep -n "<old-value>" .specaffold/features/<slug>/0[1-5]*.md` before issuing the update-plan command. Any non-empty output is a blocker on the narrow update-plan.

## Example

Live symptom in this feature: the narrow update-plan successfully corrected T96 and unblocked W1 retry but created a 10-day latent documentation-drift time bomb that detonated at validate's analyst axis. Fix was not feasible at archive time (the drifted values had already been consumed by T96's taxonomy.rs / T100's taxonomy.ts structural test / 26 i18n keys in T112a+T112b), so the drift was accepted as advisory and filed for a post-archive `/scaff:update-prd` + `/scaff:update-tech` sweep.
