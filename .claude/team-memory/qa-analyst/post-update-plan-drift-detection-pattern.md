---
name: Post-/specflow:update-plan drift detection pattern
description: At validate, always cross-grep PRD concrete values (command lists, paths, named constants) against shipped code + 04-tech.md; update-plan may have narrowed to the plan file without mirroring upstream.
type: pattern
created: 2026-04-21
updated: 2026-04-21
---

## Rule

At QA-analyst axis time, ALWAYS run a cross-artefact grep for any PRD or 04-tech.md concrete value that appears as an AC literal (command name lists, file paths, taxonomy constants, configuration keys). If an `/specflow:update-plan` commit exists in the feature branch, this grep is especially load-bearing: update-plan may have narrowed a rename to the plan file alone without mirroring to PRD/tech. File findings as `should`-severity drift with the specific update-plan commit hash as evidence.

## Why

`20260420-flow-monitor-control-plane` had `update-plan 9a7a45a` that retired pre-tier-model stub command names from T96's scope. The edit was correct for the plan file but PRD AC5.b, PRD AC8.b, and 04-tech.md D3 still carried the pre-edit taxonomy. The analyst axis caught this by running grep against the actual shipped artefacts (`command_taxonomy.rs` live DESTROY = `archive, update-req, update-tech, update-plan, update-task`) vs the PRD text, finding the mismatch at 03-prd.md:325 and 03-prd.md:403 / 04-tech.md D3.

Two findings (M1, M2) were filed as `should` drift; one further finding (DR2) located the same drift in 05-plan.md:711 T120 scope text itself (the update-plan edit didn't even fully sweep its own file's prose). A fourth finding (E1 purge_stale_temp_files orphan) was detected by grepping the code for callers of a tech-decision-promised function — same class (tech commitment vs shipped reality).

The pattern is: the PRD and tech documents are written early and rarely re-grepped; the plan is edited frequently; the code is the only ground truth. Analyst axis is the first role in the flow that cross-references all three. If the analyst doesn't catch it, the archive inherits the drift silently.

## How to apply

1. For each concrete-value AC in PRD (e.g. "lists `request, brainstorm, …`", "writes to `/tmp/foo`", "has exactly 4 entries"), grep the actual shipped source for the same values. Any mismatch is a `should` finding.
2. For each D-id in 04-tech.md that commits to a concrete call site (e.g. "called from the app setup hook on launch"), grep the code for that call. Absence is a `should` finding of class "tech commitment unmet".
3. Check `git log --oneline <feature-branch>` for any `update-plan` commit. For each found: diff the plan-file change, identify values changed, grep PRD + tech for the OLD values. If any hit, file a `should` drift.
4. The analyst axis's job is not to fix — the fixes go in archive retrospective follow-ups (update-prd / update-tech passes). Filing as `should` (advisory, not blocking) lets the archive proceed while preserving the follow-up list.

## Example

The four `should` findings in this feature's analyst axis (M1, M2, E1, DR2) are the template:
- M1 + M2: update-plan 9a7a45a commit trail + PRD/tech cross-grep.
- E1: 04-tech.md D1 commitment ("setup hook on launch") vs `grep -rn 'purge_stale_temp_files' src-tauri/src/lib.rs` (no matches).
- DR2: update-plan commit touched only task-scope bodies; internal prose of T120 scope went unchecked.

Two minutes of grep per AC catches all four classes. Promote to routine step.
