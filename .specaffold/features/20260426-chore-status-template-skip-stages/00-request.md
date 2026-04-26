# Request

## Raw ask

> update .specaffold/features/_template/STATUS.md so chore × tiny initialisation leaves [ ] design / [ ] tech / [ ] plan unchecked (current template starts every stage as [ ], orchestrator's chore-tiny short-circuit flips them to [x] with skip Notes; the issue is that the orchestrator's auto-flip pre-checks the boxes before any STATUS audit can distinguish 'genuinely done' from 'matrix-skipped'). Goal: leave matrix-skipped stages as [ ] with a `(skipped)` annotation rendered into the line, OR rename the lines to a different shape that does not visually claim done-ness. Resolves analyst Finding 2 from archived feature 20260426-chore-t114-migrate-coverage (chore-tiny-status-checkbox-vs-notes-asymmetry — three consecutive precedents flagged inconsistently). Also align with the plumbing fix Options A/B in tpm/chore-tiny-plan-short-circuit-plumbing-gap.md so the chore-tiny short-circuit's 05-plan.md hand-write becomes unnecessary.

## Context

This chore is the remediation of analyst Finding 2 from archived feature `20260426-chore-t114-migrate-coverage` (`08-validate.md` lines 98–102, 134–137). Three consecutive chore × tiny features (`t108-migrate-coverage`, `seed-copies-settings`, `t114-migrate-coverage`) shipped with `[x] tech` rendered for matrix-skipped stages; analyst flagging was inconsistent (one-out-of-three flagged), and the archive retro for t114 filed this plumbing follow-up.

The fix is rendering-only: the orchestrator's chore-tiny short-circuit at `/scaff:next` should emit a non-`[x]` shape (e.g. `[~] tech (skipped — chore × tiny matrix)`) so the checklist line itself, read in isolation, no longer visually claims done-ness for stages the matrix never executed.

## Success looks like

After the chore lands, a freshly-initialised chore × tiny feature advanced via `/scaff:next` past `prd` renders matrix-skipped stages as `[~] <stage> (skipped — chore × tiny matrix)` (or chosen shape) instead of `[x] <stage>`; analysts can distinguish "genuinely done" from "matrix-skipped" at the checklist level alone.

## Out of scope

The Options A/B plumbing fix in `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` (eliminating the hand-written `05-plan.md` stub) — see `03-prd.md` §Out-of-scope. Backfilling already-archived chore-tiny features is also out-of-scope (archive immutability).

## UI involved?

No (chore — by construction `has-ui: false`).
