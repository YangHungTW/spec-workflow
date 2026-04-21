# Request

**Raw ask**: B2 of the harness upgrade series, scope TBD (brainstorm must decide whether to ship as one feature or split into B2 + B2.5). Candidate items: (4) subagent-driven inline code review per task during implement wave, run before each wave's merge, to catch task-level quality issues earlier than gap-check; (5) Stop hook that auto-appends the current agent's STATUS note on task completion, to eliminate the 'File has been modified since read' linter races we've been hitting; (6) new /specflow:review <slug> command that dispatches parallel reviewers (security, performance, style) concurrently, as an optional pre-gap-check stage or supplemental review pass; (7) NEW — extend bin/claude-symlink to manage .claude/rules/ and .claude/hooks/ subtrees so B1's SessionStart hook + rules digest globalize across projects, plus a helper (or extension of bin/specflow-install-hook) for per-project settings.json wiring so other projects can opt into the rules injection. Item (5) Stop hook and item (7) hooks-infrastructure overlap, so brainstorm should decide if they pair naturally. Item (4) and item (6) both add review capability — brainstorm should decide whether to sequence them or ship together.

**Context**: B2 of the harness upgrade series, directly following B1 (`20260416-prompt-rules-surgery`, archived). B1 landed the session-wide rules layer (`.claude/rules/`), the SessionStart hook that injects the rules digest, slimmed agent prompts with a mandatory memory block, and a `settings.json` wiring helper — but only inside this repo. B2 carries three items from the original request (items 4, 5, 6: inline review, Stop hook, parallel reviewers) plus a new item 7 surfaced after B1 archived: extend `bin/claude-symlink` and `bin/specflow-install-hook` so B1's rules layer and SessionStart hook globalize across projects. The four items cluster along two seams — review capability (4, 6) and hook/symlink infrastructure (5, 7) — with different blast radii. The PM memory `pm/split-by-blast-radius-not-item-count.md` (written during B1's split) applies here: brainstorm should group by failure surface ("what breaks if this ships wrong") and decide whether to ship as one feature, two features split by cluster, or three+ split by item.

Scope confirmed post-brainstorm: this feature (B2.a) ships items (5) and (7). Items (4) and (6) deferred to follow-up B2.b. Globalization mode = shallow (Q1=b): only hook scripts globalize via symlink; rules stay per-project; each project opts into the SessionStart hook via specflow-install-hook.

**Success looks like**:
- Item 5: STATUS.md updates no longer race with agent writes — the "File has been modified since read" linter error disappears from the implement stage.
- Item 7: `bin/claude-symlink` manages `.claude/hooks/` alongside its existing set; other projects can opt into the SessionStart hook via a one-command install that wires their `settings.json` to the globally symlinked hook script.
- Meta: the hook scripts ship from this repo via symlink and any project can opt into the rules-injection hook with one command.

**Deferred to B2.b**:
- Item 4: task-level quality regressions (e.g. SF-2 double-report pattern from symlink-operation) are caught inline during the implement wave, before the merge, not at gap-check.
- Item 6: `/specflow:review <slug>` dispatches security / performance / style reviewers in parallel, producing multi-dimensional findings that a single gap-check reviewer misses.

**Out of scope**:
- NOT a rewrite of `bin/claude-symlink`'s existing managed set — `agents/specflow`, `commands/specflow`, and `team-memory/**` stay as-is.
- NOT porting Superpowers skills, ECC MCP configs, or wshobson plugin marketplace.
- NOT cross-harness adapters (Cursor / Codex / OpenCode).
- NOT TDD enforcement (deferred from the original 9-item harness-upgrade list).
- NOT strategic compaction hooks (deferred).
- NOT `/specflow:extract` knowledge extraction (deferred).
- NOT a dashboard GUI.
- Items (4) inline per-task code review, (6) /specflow:review parallel reviewer team — deferred to feature B2.b.
- Deep globalization of `.claude/rules/` (Q1=a/c) — explicitly rejected: rules stay per-project, only hooks globalize.

**UI involved?**: no

**Open questions**:
- _Resolved post-brainstorm: shape B (split B2.a + B2.b); globalization Q1=b (shallow, hook-only). This feature is B2.a._
