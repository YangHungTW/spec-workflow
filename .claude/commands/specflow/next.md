---
description: Advance a feature to its next stage automatically. Usage: /specflow:next <slug>
---

Orchestrator. Reads STATUS and advances one stage. Stops at any point that needs your input (blocker questions, design approval, one task at a time during implement).

## Steps

1. **Resolve slug**:
   - If `$ARGUMENTS` has a slug → use it.
   - Else scan `.spec-workflow/features/*/STATUS.md`, keep features whose `archive` box is unchecked (i.e. still in progress). Sort by slug descending (newest date prefix first).
     - **0 active** → tell user "No active features. Start one with `/specflow:request \"<ask>\"`." Exit.
     - **1 active** → use it silently. Report which and continue.
     - **≥2 active** → show a numbered picker:
       ```
       Which feature to advance?
         1. 20260416-unify-auth        → stage: plan
         2. 20260415-dark-mode-toggle  → stage: implement (T3/T8)
         3. 20260410-retry-upload      → stage: verify
       ```
       For `implement` stage, also count checked vs total tasks in `06-tasks.md`. Ask user to pick by number or by typing a slug. Default (pressing Enter) = option 1.
2. Read `.spec-workflow/features/<slug>/STATUS.md`.
3. Determine the **next unchecked stage** in the Stage checklist.
4. Apply these rules:
   - If `has-ui: false` and next stage is `design` → auto-check the `design` box with note `skipped (has-ui: false)` in STATUS Notes, then re-read and advance again.
   - Otherwise, follow the matching command file's instructions:

| Next stage | Follow |
|---|---|
| request    | Tell user to run `/specflow:request <slug> "<ask>"` (can't infer the ask) |
| brainstorm | `.claude/commands/specflow/brainstorm.md` |
| design     | `.claude/commands/specflow/design.md` |
| prd        | `.claude/commands/specflow/prd.md` |
| tech       | `.claude/commands/specflow/tech.md` |
| plan       | `.claude/commands/specflow/plan.md` |
| tasks      | `.claude/commands/specflow/tasks.md` |
| implement  | `.claude/commands/specflow/implement.md` (runs ALL remaining waves in parallel via worktrees until done or blocked) |
| gap-check  | `.claude/commands/specflow/gap-check.md` |
| verify     | `.claude/commands/specflow/verify.md` |
| archive    | `.claude/commands/specflow/archive.md` |

5. Execute that command's flow with the same `<slug>`. Do NOT chain into the stage after — one `/specflow:next` advances one stage.
6. On finish, report: what just ran, current STATUS, and what a follow-up `/specflow:next <slug>` will do.

## Checkpoints (MUST pause for user)

Never auto-advance past any of these — they need human judgment:
- PRD has unresolved blocker questions (§7)
- Tech doc has blocker questions (§5)
- Design stage — user must approve the mockup before advancing
- Implement stage — runs to completion across all waves; only pauses on task failure or merge conflict
- Gap-check verdict = BLOCKED
- Verify verdict = FAIL
- Archive retrospective — each memory proposal needs user approval

## Rules
- Never skip stages (STATUS state machine already enforces; respect it).
- Never re-run a checked stage without an explicit `/specflow:update-*` invocation.
- If STATUS is missing or malformed, stop and surface to user.
