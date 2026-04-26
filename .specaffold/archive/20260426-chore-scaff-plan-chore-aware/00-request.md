# Request — chore: relax /scaff:plan + add TPM chore-tiny short-circuit (Option A)

- **Slug**: `20260426-chore-scaff-plan-chore-aware`
- **Work-type**: chore
- **Tier**: standard (user-supplied via `--tier standard`)
- **Author**: PM
- **Date**: 2026-04-26

## Raw ask (verbatim)

> resolve the chore-tiny-plan-short-circuit plumbing gap so the orchestrator no longer hand-writes a minimal 05-plan.md stub on chore × tiny features. Per tpm/chore-tiny-plan-short-circuit-plumbing-gap.md, two options exist: Option A — relax /scaff:plan step 1 to require 03-prd.md AND only require 04-tech.md if work-type ≠ chore; TPM short-circuits to a minimal 05-plan.md when no 04-tech.md present (TPM-side automation of what orchestrator currently hand-writes). Option B — relax /scaff:implement step 1 to accept 03-prd.md as the checklist source on chore-tiny when no 05-plan.md exists; eliminates the stub file entirely. Recommend Option A as more conservative: preserves /scaff:implement's input contract (always 05-plan.md), localises the chore-aware logic to /scaff:plan, and keeps the 5-section plan shape consistent across work-types. Four chore-tiny precedents have shipped under the workaround (t108, seed-copies-settings, t114, status-template-skip-stages); plumbing fix is overdue per memory's empirical-stability note.

## Context note

This chore is the deferred plumbing fix surfaced from the chore cluster shipped 2026-04-26. Memory `.claude/team-memory/tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` was bumped at the seed-copies-settings archive retro to "three chore-tiny shipped, plumbing fix overdue" and is now confirmed at four (t108, seed-copies-settings, t114, status-template-skip-stages). Sibling chore `20260426-chore-status-template-skip-stages` §Decisions(e) explicitly filed this follow-up brief.

Option A chosen by user; Option B explicitly rejected (preserves /scaff:implement's input contract).

## UI involved?

No (chore — no `has-ui` probe per chore branch convention; STATUS already has `has-ui: false`).
