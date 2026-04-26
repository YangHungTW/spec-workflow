---
description: Advance a feature to its next stage automatically. Usage: /scaff:next <slug>
---

<!-- preflight: required -->
# Resolve $SCAFF_SRC: env var, then user-global symlink, then fail.
if [ -z "${SCAFF_SRC:-}" ] || [ ! -d "${SCAFF_SRC}" ]; then
  _scaff_src_link=$(readlink "$HOME/.claude/agents/scaff" 2>/dev/null || true)
  SCAFF_SRC="${_scaff_src_link%/.claude/agents/scaff}"
  unset _scaff_src_link
fi
[ -d "${SCAFF_SRC:-}" ] || { printf '%s\n' 'ERROR: cannot resolve SCAFF_SRC; set the SCAFF_SRC env var, or run `bin/claude-symlink install` from the scaff source repo' >&2; exit 65; }
Run the preflight from `$SCAFF_SRC/.specaffold/preflight.md` first.
If preflight refuses (output starts with `REFUSED:PREFLIGHT`), abort
this command immediately with no side effects (no agent dispatch,
no file writes, no git ops); print the refusal line verbatim.

Orchestrator. Reads STATUS and advances one stage. Stops at any point that needs your input (blocker questions, design approval, one task at a time during implement).

```bash
# Source tier and stage-matrix helpers — double-source safe; REPO_ROOT must be set by caller.
source "$SCAFF_SRC/bin/scaff-tier"
source "$SCAFF_SRC/bin/scaff-stage-matrix"
```

## Steps

1. **Resolve slug**:
   - If `$ARGUMENTS` has a slug → use it.
   - Else scan `.specaffold/features/*/STATUS.md`, keep features whose `archive` box is unchecked (i.e. still in progress). Sort by slug descending (newest date prefix first).
     - **0 active** → tell user "No active features. Start one with `/scaff:request \"<ask>\"`." Exit.
     - **1 active** → use it silently. Report which and continue.
     - **≥2 active** → show a numbered picker:
       ```
       Which feature to advance?
         1. 20260416-unify-auth        → stage: plan
         2. 20260415-dark-mode-toggle  → stage: implement (T3/T8)
         3. 20260410-retry-upload      → stage: validate
       ```
       For `implement` stage, also count checked vs total tasks in `05-plan.md`. Ask user to pick by number or by typing a slug. Default (pressing Enter) = option 1.
2. Read `.specaffold/features/<slug>/STATUS.md`.
3. Determine the **next unchecked stage** in the Stage checklist.
4. Apply these rules:
   - **Read tier and work-type** (before every stage dispatch):
     ```bash
     tier=$(get_tier "$feature_dir")
     # get_work_type: reads "- **work-type**: <value>" from STATUS.md;
     # defaults to "feature" when the field is absent (legacy feature default per tech-D3).
     work_type=$(grep -m1 '^\- \*\*work-type\*\*:' "$feature_dir/STATUS.md" 2>/dev/null | sed 's/.*\*\*work-type\*\*: *//' | sed 's/[[:space:]]*$//' || true)
     if [ -z "$work_type" ]; then work_type="feature"; fi
     ```
     - If `tier = missing`: treat as `standard` for skip decisions (legacy feature, no `tier:` field yet).
     - If `tier = malformed`: stop immediately — print error to user, exit 2. Do not advance.
   - **Matrix-driven skip check** — before dispatching to any stage, consult `stage_status` with all three dimensions:
     ```bash
     status=$(stage_status "$work_type" "$tier" "$next_stage")
     case "$status" in
       skipped)
         # check the box inline: append `[x]` to that stage line with note `skipped (work-type: <wt>, tier: <t>)`
         # append STATUS Notes line: `<date> next — stage_status $work_type/$tier/$next_stage = skipped`
         # re-read STATUS and advance again (loop — same as has-ui skip below)
         ;;
       required|optional)
         # proceed to dispatch; optional stages are still dispatched — downstream command decides
         ;;
     esac
     ```
     STATUS Notes line format: `YYYY-MM-DD next — stage_status <work-type>/<tier>/<stage> = skipped`
     R10.1 byte-identity: for `work_type=feature`, `stage_status` produces identical skip verdicts to the former `tier_skips_stage` table — no behavioural change for legacy feature workflows.
   - If `has-ui: false` and next stage is `design` → auto-check the `design` box with note `skipped (has-ui: false)` in STATUS Notes, then re-read and advance again.
   - Otherwise, follow the matching command file's instructions:

| Next stage | Follow |
|---|---|
| request    | Tell user to run `/scaff:request <slug> "<ask>"` (can't infer the ask) |
| brainstorm | `.claude/commands/scaff/brainstorm.md` |
| design     | `.claude/commands/scaff/design.md` |
| prd        | `.claude/commands/scaff/prd.md` |
| tech       | `.claude/commands/scaff/tech.md` |
| plan       | `.claude/commands/scaff/plan.md` |
| tasks      | `.claude/commands/scaff/tasks.md` |
| implement  | `.claude/commands/scaff/implement.md` (runs ALL remaining waves in parallel via worktrees until done or blocked) |
| gap-check  | `.claude/commands/scaff/gap-check.md` |
| verify     | `.claude/commands/scaff/verify.md` |
| archive    | `.claude/commands/scaff/archive.md` |

5. Execute that command's flow with the same `<slug>`. Do NOT chain into the stage after — one `/scaff:next` advances one stage.
6. On finish, report: what just ran, current STATUS, and what a follow-up `/scaff:next <slug>` will do.

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
- Never re-run a checked stage without an explicit `/scaff:update-*` invocation.
- If STATUS is missing or malformed, stop and surface to user.
