# Request

**Raw ask**: B2.b of the harness upgrade series — delivers the deferred review-capability items from the original 6-item harness upgrade: (4) subagent-driven inline code review per task during implement wave, run between each task's completion and its wave's merge, so task-level quality issues (double-report bugs, missed edge cases, style drift) surface before integration instead of at gap-check after all tasks land; and (6) new /specflow:review <slug> command that dispatches parallel reviewers (security / performance / style) concurrently as an optional stage between implement and gap-check, or as a supplemental pass. Both items share reviewer subagent definitions — brainstorm should decide whether (4) seeds conventions that (6) then scales, or whether they ship together with shared reviewer agents from day one. Out of scope: TDD enforcement, strategic compaction hooks, /specflow:extract knowledge extraction, cross-harness adapters, and any further symlink/hook infrastructure (B2.a already shipped).

**Context**: Final piece of the original 6-item harness upgrade ask. Follows B1 `20260416-prompt-rules-surgery` (session-wide prompt slim + rules layer + SessionStart hook — archived) and B2.a `20260417-shareable-hooks` (Stop hook + shallow hooks-globalization via `bin/claude-symlink` — archived). The existing harness has two concrete review-quality pains: (a) gap-check is static-only — the QA-analyst reads the diff but doesn't run code, so runtime bugs like symlink-operation's **SF-2 dry-run double-report** surfaced only after all tasks landed, when inline review at T8's merge point would have caught it; (b) gap-check is single-viewpoint — one reviewer can't realistically cover security, performance, and style drift in one pass. Items (4) and (6) both introduce reviewer subagents and may share definitions, so the scope-shape decision (ship together vs sequenced) is the brainstorm's first call.

**Success looks like**:
- Item (4) — inline review: each implement-wave task passes a reviewer subagent check between task completion and wave merge; task-level quality issues (runtime bugs, missed edge cases, style drift) are flagged at the merge point rather than at gap-check.
- Item (6) — `/specflow:review <slug>`: a new command dispatches parallel reviewers (security / performance / style) concurrently, runnable as an optional stage between implement and gap-check or as a supplemental pass on any archived feature.
- Meta: the next feature run after this one has **fewer late-stage gap-check should-fixes** (inline review catches them earlier), and gap-check becomes **multi-dimensional** (parallel reviewers produce per-axis verdicts that roll up, rather than one reviewer squinting at three concerns).

**Out of scope**:
- TDD enforcement (deferred; separate future feature).
- Strategic compaction hooks.
- `/specflow:extract` knowledge extraction command.
- Cross-harness adapters (Cursor / Codex / OpenCode).
- Further symlink or hook infrastructure (B2.a shipped the shallow globalization — no deeper rework here).
- Superpowers / ECC / wshobson wholesale port.
- Dashboard GUI.
- AgentShield-grade security depth (reviewers here are craft-level, not threat-model-depth).

**UI involved?**: no

**Open questions**:
- **Shape**: do (4) and (6) ship together in one feature (shared reviewer-agent definitions from day one) or sequenced (4 seeds conventions, 6 scales them)? Likely **together** since the reviewer-agent definitions are shared surface — blast-radius heuristic (pm/split-by-blast-radius-not-item-count) says same-surface items belong in one feature. Brainstorm confirms.
- **Reviewer-agent count**: three axes (security / performance / style) as named in the raw ask, or more granular (e.g., add a11y / docs / error-handling), or fewer (one generalist "code review" agent)? Defer to PRD.
- **Inline review blocking policy**: does item (4)'s reviewer **block the wave merge** on findings, or emit **advisory** output only? Previously-flagged risk: "over-reviewing blocks merges on cosmetic nits." Tie-in: does severity (must / should / avoid, matching rules layer) gate blocking?
- **`/specflow:review` positioning**: optional stage wedged between implement and gap-check in the normal flow, or a one-shot command invocable anywhere (including on archived features for supplemental review)? Or both? Defer to brainstorm.
