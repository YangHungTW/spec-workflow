---
description: Advance a feature to its next stage automatically. Usage: /YHTW:next <slug>
---

Orchestrator. Reads STATUS and advances one stage. Stops at any point that needs your input (blocker questions, design approval, one task at a time during implement).

## Steps

1. **Resolve slug**:
   - If `$ARGUMENTS` has a slug → use it.
   - Else scan `.spec-workflow/features/*/STATUS.md`, keep features whose `archive` box is unchecked (i.e. still in progress). Sort by slug descending (newest date prefix first).
     - **0 active** → tell user "No active features. Start one with `/YHTW:request \"<ask>\"`." Exit.
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
| request    | Tell user to run `/YHTW:request <slug> "<ask>"` (can't infer the ask) |
| brainstorm | `.claude/commands/YHTW/brainstorm.md` |
| design     | `.claude/commands/YHTW/design.md` |
| prd        | `.claude/commands/YHTW/prd.md` |
| tech       | `.claude/commands/YHTW/tech.md` |
| plan       | `.claude/commands/YHTW/plan.md` |
| tasks      | `.claude/commands/YHTW/tasks.md` |
| implement  | `.claude/commands/YHTW/implement.md` (runs one wave per call, tasks in parallel via worktrees) |
| gap-check  | `.claude/commands/YHTW/gap-check.md` |
| verify     | `.claude/commands/YHTW/verify.md` |
| archive    | `.claude/commands/YHTW/archive.md` |

5. Execute that command's flow with the same `<slug>`. Do NOT chain into the stage after — one `/YHTW:next` advances one stage.
6. On finish, report: what just ran, current STATUS, and what a follow-up `/YHTW:next <slug>` will do.

## Checkpoints (MUST pause for user)

Never auto-advance past any of these — they need human judgment:
- PRD has unresolved blocker questions (§7)
- Tech doc has blocker questions (§5)
- Design stage — user must approve the mockup before advancing
- Implement stage — one wave per call (wave = all tasks whose deps are satisfied, run in parallel)
- Gap-check verdict = BLOCKED
- Verify verdict = FAIL
- Archive retrospective — each memory proposal needs user approval

## Rules
- Never skip stages (STATUS state machine already enforces; respect it).
- Never re-run a checked stage without an explicit `/YHTW:update-*` invocation.
- If STATUS is missing or malformed, stop and surface to user.
