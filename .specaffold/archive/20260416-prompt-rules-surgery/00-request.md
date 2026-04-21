# Request

**Raw ask**: Upgrade the specflow agent harness with the six priority recommendations synthesized from Superpowers, wshobson/agents, and everything-claude-code. Scope: (1) progressive disclosure refactor — slim all 7 agent prompts into core-behavior + on-demand appendix layers to cut token load; (2) new .claude/rules/ layer (common/ + per-language subdirs) with a SessionStart hook that injects them — harden cross-role guardrails that are currently scattered inside individual agent prompts; (3) mandatory team-memory invocation — every role must list relevant memory entries before acting, or explicitly state 'none apply'; (4) subagent-driven inline code review per task during implement wave, before the wave merge; (5) Stop hook that auto-appends the current agent's STATUS note, to eliminate the linter/race issues we've been hitting; (6) new /specflow:review <slug> command that dispatches parallel reviewers (security, performance, style) concurrently as an optional stage or gap-check supplement.

**Context**: Specflow eats its own dogfood — this feature modifies the harness (`.claude/agents/specflow/`, `.claude/commands/specflow/`, hooks, rules) that runs specflow itself. The six items are drawn as inspiration, not wholesale ports, from three external references: `obra/superpowers` (methodology — mandatory memory reads, inline per-task review), `wshobson/agents` (marketplace patterns — progressive disclosure, parallel reviewer teams), and `affaan-m/everything-claude-code` (infra plugin — `.claude/rules/` layer, SessionStart and Stop hooks). The recent `symlink-operation` feature surfaced concrete pain that motivates each item: STATUS.md "file modified since read" linter races between orchestrator and agents (twice), task-level bugs (SF-2 double-report) caught only at static gap-check rather than during implement, team-memory entries written but with no enforcement that later runs read them, and Architect/TPM prompts ballooning past several hundred lines with inline rules and examples interleaved. Scope confirmed post-brainstorm: this feature (B1) ships items (1)(2)(3). Items (4)(5)(6) are deferred to follow-up feature B2, opened after B1 archives.

**Success looks like**:
- (1) Every specflow agent prompt has a slim core-behavior section plus on-demand appendices; steady-state token load per invocation drops noticeably versus today's monolithic prompts.
- (2) Cross-role guardrails previously duplicated across agent prompts live in `.claude/rules/` (common/ + per-language) and are injected via a SessionStart hook, so each rule has one source of truth.
- (3) Every role invocation either lists the memory entries it pulled in, or explicitly states "none apply" — team-memory drift is visible in STATUS/artifacts rather than silent.
- **Meta outcome**: the next feature run after this one is noticeably cheaper to execute (lower token spend, fewer retries), and gap-check surfaces fewer late-stage should-fixes because more issues are caught during implement.

**Deferred to B2** (separate feature, opened after B1 archives):
- (4) During implement waves, a reviewer subagent inspects each task's diff before the wave merges, catching task-level quality issues at authorship time rather than at gap-check.
- (5) STATUS.md notes are auto-appended by a Stop hook on agent exit; the "file has been modified since read" class of errors seen during symlink-operation stops recurring.
- (6) `/specflow:review <slug>` dispatches security, performance, and style reviewers in parallel as an optional stage or a gap-check supplement, producing a consolidated report.

**Out of scope**:
- NOT porting Superpowers skills, everything-claude-code's MCP configs, or wshobson's plugin marketplace wholesale.
- NOT migrating specflow to the Claude plugin-marketplace format.
- NOT building cross-harness adapters (Cursor / Codex / OpenCode).
- NOT AgentShield-grade security scanning — a simpler reviewer subagent is fine.
- NOT a dashboard or GUI for specflow runs.
- NOT TDD enforcement (third-tier; revisit after this lands).
- NOT strategic compaction hooks (third-tier).
- NOT `/specflow:extract` knowledge-extraction command (third-tier).
- Items (4) inline per-task code review, (5) Stop hook for STATUS sync, (6) `/specflow:review` parallel reviewer team — deferred to feature B2 (separate PRD, opened after this feature archives).

**UI involved?**: no

**Open questions**:
- ~~**[blocker] One PRD vs split?** This request bundles six distinct sub-deliverables (prompt refactor, rules layer + SessionStart hook, memory enforcement, inline per-task review, Stop hook, parallel `/specflow:review` command) with different risk profiles and blast radii. Brainstorm must explicitly weigh shipping as a single PRD versus splitting into smaller features (e.g., "hooks + rules" as one, "prompt slim + memory enforcement" as another, "review subagents" as a third). Do not resolve unilaterally at intake — flag and decide at brainstorm with the user.~~ _Resolved in brainstorm (2026-04-16): split as two features (B1 + B2). This feature is B1 (items 1, 2, 3); B2 (items 4, 5, 6) opens after B1 archives._
