# Brainstorm — harness-upgrade

_PM, 2026-04-16. Probing: one PRD or split? Plus per-item sketches, dogfooding order, risks._

Team memory: `pm/` and `shared/` indexes both empty — no prior PM patterns to apply.

---

## Decision (2026-04-16, user-confirmed)
- Split: shape **B** (two features).
- B1 (this feature, slug `20260416-prompt-rules-surgery`): items (1)(2)(3).
- B2 (follow-up, slug TBD, opens after B1 archives): items (4)(5)(6).
- Item (5) Stop hook stays in B2 per user; dogfood paradox accepted.

_Sections 1–5 below are preserved as-is for historical context and B2 planning reference; per-item sketches for (4)(5)(6), dogfooding order, risks, and open questions that touch B2 will be revisited when B2's own brainstorm opens._

---

## 1. Split recommendation — **B (two features), with a twist**

**Recommendation: Split into two features, sequenced.**

- **Feature B1 — "prompt & rules surgery"**: items (1) progressive disclosure, (2) rules layer + SessionStart hook, (3) mandatory memory invocation.
- **Feature B2 — "implement/review orchestration"**: items (4) inline per-task reviewer, (5) Stop hook for STATUS sync, (6) `/specflow:review <slug>` parallel reviewers.

**Why B over A (one big PRD)**:
- The two clusters have **different blast radii and failure modes**. B1 touches every agent prompt and adds a SessionStart hook — a bad landing degrades *every future session*. B2 touches the implement command wave-loop + a Stop hook + a new review command — a bad landing degrades the *next feature's implement phase*, but is scoped and reversible per hook. Mixing them means one risky gap-check covers two very different surfaces.
- A single PRD here would carry 18–25 tasks. Our recent symlink-operation feature at 13 tasks already stressed STATUS and wave merging. The TPM memory `tasks-doc-format-migration` and the two STATUS linter races cited in the request are warning signs that bigger batches cost us more than they save.
- B1 → B2 gives B2 a **cleaner substrate**: slim prompts, enforced memory reads, rules-layer in place. The new reviewer subagents in B2 get written against the post-refactor agent conventions, not a moving target.
- Retrospective quality: archive-time memory capture is sharper when the feature has one thematic spine. Two features = two focused retros.

**Why not A (one PRD)**: coherence is real but overrated here; a short "meta README" or shared tech-doc reference can link B1 and B2 without forcing a monolithic gap-check.

**Why not C (3+ smaller)**: items within each cluster are tightly coupled (see §2). Item (2) pulls content *out of* the same prompts item (1) is slimming and item (3) is editing the opener of — running these as separate features invites merge pain and redo work. Sequencing overhead also dominates for small shops (us).

**Twist**: within B1, land item (2) **before or paired with** item (1). If we slim prompts first and then extract rules into `.claude/rules/` later, the slim-prompt refactor has to be redone. Structurally: rules extraction first, then progressive disclosure, then memory-invocation opener. Expressed as PRD requirements, not separate features.

---

## 2. Per-item approach sketches

### (1) Progressive disclosure — refactor all 7 agent prompts
- **What changes**: each `.claude/agents/specflow/<role>.md` split into (a) slim core-behavior header (what the agent *does*, in imperative voice) and (b) on-demand appendix blocks the agent can pull in when a specific phase demands it. Probably an `appendices/` folder or inline `<details>`-style sections with explicit "read if X" gating.
- **Trickiest thing**: deciding what counts as "core" vs "appendix" without losing subtle directives (the "never touch ../" line in developer.md is short but load-bearing). Need a shared taxonomy across all 7 roles.
- **Depends on**: (2) landing first — otherwise rules content still lives inline and gets "slimmed" into an appendix, then re-extracted later.

### (2) Rules layer + SessionStart hook
- **What changes**: new `.claude/rules/common/*.md` and `.claude/rules/<lang>/*.md` tree. New hook entry in a project-level `settings.json` (doesn't exist yet at repo root — this creates it) that reads matching rule files at session start and injects them into context. Rules currently duplicated across agent prompts (e.g., TDD red-line, no-force default, bash-3.2 portability) move here as single source of truth.
- **Trickiest thing**: scoping rules to only the relevant agent/phase so we don't balloon context the other direction. Also: hook failure must degrade gracefully — a missing `jq` or malformed JSON shouldn't nuke every session.
- **Depends on**: nothing upstream. Should land first within B1 to make (1) a single-pass refactor.

### (3) Mandatory memory invocation
- **What changes**: every agent prompt opener grows one short mandatory step: "list the memory entries you pulled in, or say 'none apply'." Surfaces in STATUS/artifact output, not silent. Touches all 7 agents (already have memory-read step; this adds the *visibility* requirement).
- **Trickiest thing**: making the statement machine-checkable without being performative. If every agent blindly writes "none apply" we've gained nothing. Possibly paired with a lint in gap-check that flags suspicious "none apply" against non-trivial tasks.
- **Depends on**: lands cleanly alongside (1) since both edit the prompt openers.

### (4) Inline per-task code review
- **What changes**: new `specflow-reviewer` subagent (or repurpose — sonnet). `/specflow:implement` wave-loop grows a step between task-commit and wave-merge: reviewer reads the task's diff against PRD requirement + tech decision references, returns PASS / FIX / ESCALATE. FIX = developer gets one shot to remediate before the wave-merge; ESCALATE = stop the wave.
- **Trickiest thing**: tuning strictness. Too strict blocks every wave; too lax = wall-of-approvals noise. Needs a clear rubric (rubric probably lives in `.claude/rules/` once B1 lands).
- **Depends on**: ideally B1's rules layer exists so the reviewer reads from a single rubric source.

### (5) Stop hook for STATUS sync
- **What changes**: new hook script (probably `bin/` or `.claude/hooks/`) invoked on agent Stop; reads a well-known scratch location the agent wrote its STATUS-note-fragment to, then appends atomically to the feature's `STATUS.md`. Hook entry in `settings.json`. Eliminates the "file modified since read" race where orchestrator re-reads STATUS while an agent is mid-write.
- **Trickiest thing**: atomicity + concurrency. Two parallel developers in waves could both Stop in the same second. Need file-locking or append-with-lock (flock on macOS requires util-linux; `shlock`/`mkdir` pattern is the bash-3.2-safe fallback — see architect memory `shell-portability-readlink` for why we don't assume GNU).
- **Depends on**: nothing. Fully standalone.

### (6) `/specflow:review <slug>` parallel reviewer team
- **What changes**: new slash command in `.claude/commands/specflow/review.md`; 2–3 new reviewer agents (security, performance, style) invoked concurrently via multi-Agent-call pattern already used in `/specflow:implement`. Consolidated report written to `07-review.md` (or inline into existing gap-check output). Optional stage — user opts in, or gap-check offers it as a supplement.
- **Trickiest thing**: deduping the three reviewers' overlapping findings, and deciding whether this *gates* gap-check or runs alongside. Default should be alongside (advisory), not gating.
- **Depends on**: ideally (4) exists first so reviewer-agent conventions (prompt shape, rubric source) are established and (6)'s agents inherit them.

---

## 3. Dogfooding check — ordering to benefit subsequent waves

The harness upgrades itself. Order matters so each landed item reduces friction for the next.

**Recommended order across both features**:

1. **(5) Stop hook for STATUS sync** — lands first. Zero dependency on anything. Pays off *during B1's own implement waves* by killing the STATUS race that bit us on symlink-operation. Small surface (one hook + one script).
2. **(2) Rules layer + SessionStart hook** — lands second. Prerequisite for clean (1). New session after landing benefits immediately.
3. **(1) Progressive disclosure** — lands with (2) in same feature (B1). Once rules are out, the slim-prompt refactor is single-pass.
4. **(3) Mandatory memory invocation** — lands alongside (1) in same feature (edits same prompt openers). Memory visibility starts helping future features immediately.
5. **(4) Inline per-task reviewer** — first item in B2. Catches task-level bugs during *B2's own implement waves* (items 5/6 themselves). Paradox contained: item (5) is already in place by this point, and the reviewer running on item (4)/(6) code is a genuine dogfood test.
6. **(6) `/specflow:review <slug>` parallel reviewers** — last. Benefits the *next* feature after this one. By this point B2's own gap-check has already used the harness B1+partial-B2 delivered.

**Chicken-and-egg resolution**:
- (5) can't benefit the implementation of (5) itself — accept this, land it first so (2)/(1)/(3) all benefit.
- (4) can't benefit its own implementation — accept, land early in B2 so (6) benefits.
- (2)'s SessionStart hook is active for the session that implements (1) and (3) — good dogfood, but §4 below explains why this is also the highest-risk moment.

---

## 4. Risk callouts

- **Slim prompts (1) drop a load-bearing directive**. Subtle regressions surface two features later when the lost line would have caught a bug.
  - *Mitigation*: before merging B1, run a dry-feature — take a closed recent feature (symlink-operation) and re-run its gap-check using the new slim prompts; diff the output against the archived `07-gaps.md`. Any regression = put the missing directive back (either in core or in an appendix with explicit pull-trigger).

- **SessionStart hook (2) breaks → every session degraded silently**.
  - *Mitigation*: hook must `exit 0` on any internal error and log to a diagnostic file rather than fail the session. Add a self-test `bin/specflow-hook-check` that exercises the hook end-to-end; wire into CI (or a pre-merge manual gate if no CI).

- **Inline reviewer (4) too strict → every task blocks**.
  - *Mitigation*: ship with reviewer in **advisory-only** mode for first N waves (logs findings, doesn't gate). Promote to gating only after we see PASS-rate settle above a threshold (e.g., >80% first-try pass). Rubric lives in `.claude/rules/reviewer/` so tuning is a rule edit, not a prompt edit.

- **Stop hook (5) race on concurrent developer exits in a wave**.
  - *Mitigation*: append-with-lock using `mkdir` lockfile (bash-3.2-portable, no `flock` dep); each agent writes a uniquely-named fragment file and the hook appends fragments in timestamp order.

- **Memory-invocation (3) becomes performative — "none apply" everywhere**.
  - *Mitigation*: gap-check lints for any role-invocation that says "none apply" when memory index has >=1 entry whose description contains keywords from the task. Cheap heuristic; catches the obvious no-ops.

---

## 5. Open questions for PRD

- **Split confirmed as B?** User leaned B or A-with-discipline; this brainstorm recommends B with internal sequencing. Needs explicit go.
- **Where do hook scripts live?** `bin/` (follows `script-location-convention` architect memory — executables) vs `.claude/hooks/` (Claude convention). Architect will have a view; PRD should flag, not resolve.
- **Is `/specflow:review` gating or advisory at v1?** Out-of-scope says "optional stage or gap-check supplement" — PRD must pick one for the acceptance criterion.
- **Do we version `.claude/rules/`?** If rules are edited mid-feature, does the feature re-run? Probably not at v1, but PRD should note the non-goal.
- **Reviewer model tier** — sonnet for (4)/(6)? The recent cost-consciousness angle ("noticeably cheaper to execute") argues for sonnet, not opus, for reviewers. PRD-level call.

Not open — out of scope per request: TDD enforcement, strategic compaction hooks, `/specflow:extract`, plugin-marketplace format.
