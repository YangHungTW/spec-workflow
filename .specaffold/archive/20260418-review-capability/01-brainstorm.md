# Brainstorm — review-capability (B2.b)

_PM, 2026-04-18. Items (4) inline per-task reviewer + (6) `/specflow:review <slug>` parallel reviewer team. Third consecutive application of `pm/split-by-blast-radius-not-item-count.md`._

Team memory consulted:
- `pm/split-by-blast-radius-not-item-count.md` — anchors Q1 (ship together vs sequenced). Third application. Items (4) and (6) share the same failure surface (reviewer subagents running against implement-stage diffs), so they belong in the same feature.
- `shared/` — empty. No cross-role conventions to apply.

No new PM memory proposed from this brainstorm — the decisions are either applications of existing memory (Q1) or first-application judgements that need one more datapoint before generalising (Q3, Q5).

---

## 1. Shape decision — **ship (4) and (6) together** (one feature)

**Recommendation: one feature, items (4) and (6) delivered together with shared reviewer subagent definitions from day one.**

One-line reason: `pm/split-by-blast-radius-not-item-count` says items with the **same failure surface** belong in one feature. Items (4) and (6) both ship reviewer subagents that read a task/feature diff and emit a verdict against a rubric — identical prompt shape, identical rubric source, identical tool allow-list. A bad landing of the reviewer rubric degrades *both* (4) and (6) identically. That is one blast radius, not two.

Why not sequence (4) → (6):
- If (4) ships first with one generic reviewer and (6) arrives later with three specialised reviewers, the rubric convention gets retro-fitted twice: once to extract a shared shape, once to re-wire (4) onto the new shape. Merge churn on the reviewer prompt.
- Sequenced landing is defensible when the second step has unknown scope. Here (6) is well-specified (security / performance / style, parallel invocation, report aggregation). No unknowns that the (4) landing would resolve.
- The PM heuristic from B1 and B2.a both point the same way: ship-together when items share plumbing; split when they share a feature brief but touch different surfaces.

Why not split further (e.g., each reviewer its own feature):
- Three reviewer subagents with shared prompt shape is a taxonomy exercise, not three features. Taxonomy belongs in one PRD where the shape can be specified once.

Precedent: same call B2.a made — (5) + (7) shared hook-script plumbing, one feature. This is the third application of the heuristic; no new memory needed yet.

---

## 2. Per-item approach sketches

### (4) Inline per-task code review

- **What changes**: the `/specflow:implement` wave-loop grows a step between task-commit and wave-merge. For each completed task, orchestrator invokes three reviewer subagents in parallel (security / performance / style) on the task's diff; each returns a verdict against a shared rubric. Verdicts roll up per severity-gated policy (see Q3 below); a task that surfaces any `must` finding blocks its own wave-merge until the developer remediates (one retry slot). `should`/`advisory` findings log to a per-wave review log and flow into `07-gaps.md` as pre-flagged context.
- **Trickiest thing — strictness calibration**: too strict = every wave blocks on nits; too lax = wall-of-approvals. Severity-gated blocking (Q3c) is the mechanism; the rubric itself — what counts as `must` vs `should` — is the content. Rubric lives in `.claude/rules/reviewer/` (leverages B1's rules layer) so tuning is a rule edit, not a prompt edit.
- **Second-trickiest — reviewer context size**: each reviewer sees **only the task's diff** (not the whole repo). PRD should specify `git diff <slug>-T<n>..<slug>` as the review input, plus PRD §Requirements and TECH §Decisions for reference. Keeps token cost bounded and the review lens task-local.
- **Depends on**: B1's rules layer (shipped) for the rubric location; `/specflow:implement` wave-loop (shipped) for the insertion point.

### (6) `/specflow:review <slug>` parallel reviewer team

- **What changes**: new slash command `.claude/commands/specflow/review.md`. Same three reviewer subagents from (4) (`specflow-reviewer-security`, `-performance`, `-style`) invoked concurrently on the **whole-feature diff** (not per-task). Each writes its own scoped report; orchestrator consolidates into `07-review.md` with per-axis verdicts and a combined `## Verdict`. Runnable on an in-flight feature (supplemental pass before gap-check) or on an archived feature (opt-in audit).
- **Trickiest thing — feature-wide context**: at whole-feature scope the diff can be large (B1 was ~1800 lines). Reviewers still stay task-local by default (diff chunked by task from `06-tasks.md`) but each one emits feature-level roll-up findings. Prevents the "reviewer reads 1800 lines and emits vague findings" failure mode.
- **Second-trickiest — dedup at consolidation**: three reviewers produce overlapping findings (security might flag something style also catches). Consolidator groups by file:line + finding-hash, preserves the distinct per-axis lens in the report, and de-dupes only the "same issue, three voices" case.
- **Depends on**: (4) defines the reviewer subagent shape; (6) reuses it. Same reviewers, same rubric, different invocation context (whole-feature vs per-task).

---

## 3. Answers to the six brainstorm questions

### Q1 — Shape: ship together or sequenced? → **Ship together**

Defended above §1. Summary: same blast radius, same plumbing, no sequencing benefit, split costs a retro-fit of the rubric convention. Three reviewer subagents defined once up front; (4) invokes them per-task, (6) invokes them whole-feature. Shared rubric lives in `.claude/rules/reviewer/`.

### Q2 — Reviewer count → **3 reviewers (security / performance / style)** as PRD-suggested

Recommendation: **3 reviewers**, aligned with the raw ask. Defend the count against 1, 2, and 4:

- **Why not 1 (generalist)**: the whole point of multi-reviewer is the multi-dimensional gap-check — one reviewer squinting at three concerns is already what gap-check does. Reverting to one reviewer defeats the feature.
- **Why not 2 (security + quality)**: "quality" collapses performance + style into one lens; we lose the distinction that performance is diff-local ("this loop is O(n²)") whereas style is surface ("this file violates bash-32-portability"). Different rubric slices.
- **Why not 4 (+correctness or +docs)**: correctness is what gap-check does (PRD ↔ diff); adding it here duplicates. Docs is valuable but lower-ROI at v1; defer to a future "docs-reviewer" if the three-reviewer pattern proves out.
- **Why 3**: matches the rubric-layer structure (`common/`, `bash/`, etc.) — three reviewers map cleanly to three axes without overlap. Parallel invocation wall-clock ≈ slowest reviewer (≈30s sonnet), acceptable.

Feature size band (5–25 tasks): 3 reviewers × up to 5-wide wave = 15 reviewer invocations per wave (token-cost risk — see §4 Risks; mitigation: reviewers see **only the task diff**, not the whole repo).

### Q3 — Inline review blocking policy → **(c) Severity-gated blocking**

Recommendation: **severity-gated** — findings with severity `must` block the wave merge; `should` and `advisory` log but do not block.

Defence:
- **(a) Fully blocking** fails the "no cosmetic nits block merges" test from B1 risk callouts. Every wave becomes a negotiation.
- **(b) Fully advisory** fails the originating pain ("runtime bugs like SF-2 surfaced at gap-check instead of merge-time"). If the reviewer flags a runtime bug and the wave merges anyway, we didn't improve over gap-check.
- **(c) Severity-gated** gives us both: the rubric author decides per-rule which severity applies; runtime bugs are `must`, style drift is `should`. Reuses the **same severity taxonomy** as B1's rules layer (`must` / `should` / `avoid`) — one less concept for agents to learn.

Operationally:
- Reviewer verdict format: `verdict: PASS | FIX | ESCALATE`, with each finding tagged `severity: must|should|advisory`.
- `FIX` with any `must` finding → one remediation shot for the developer; if second attempt still has `must`, escalate (stop the wave).
- `FIX` with only `should`/`advisory` → log, merge anyway, findings flow to `07-gaps.md` context.
- `ESCALATE` → reviewer can't make a call (e.g., diff is incoherent); stop the wave, surface to user.

PRD-level: the rubric in `.claude/rules/reviewer/` is the place where "what is `must` for security" gets specified. Not the reviewer prompt.

### Q4 — `/specflow:review` positioning → **(c) One-shot command, never part of the stage checklist**

Recommendation: **(c) one-shot**. Not a stage. Invocable at any time by the user: `/specflow:review <slug>` during an in-flight feature, or against an archived feature for supplemental audit.

Defence:
- **(a) Inserted stage** breaks STATUS compatibility for in-flight features created before this ships. The stage-count changes; existing archived features have a shorter checklist than new ones. Untidy.
- **(b) Optional stage** carries the same compatibility drag as (a); the `optional: true` marker in STATUS adds a concept agents and users must learn, just to avoid breaking archived features' shape.
- **(c) One-shot** keeps the stage checklist stable across versions. The command reads `06-tasks.md` to scope the diff, writes `07-review.md` (a new artifact alongside `07-gaps.md`, not instead of it), and never advances the STATUS stage cursor. If users want it routinely before gap-check, documentation recommends the sequence — no machinery needed.

Bonus: (c) makes the command trivially usable on archived features, which is a named success criterion ("or as a supplemental pass on any archived feature"). (a) and (b) only work on in-flight features.

### Q5 — Reviewer agent model tier → **Sonnet**

Recommendation: **sonnet** for all three reviewers.

Defence (aligned with existing specflow tiering: Opus for decision roles — PM/Architect/TPM; Sonnet for execution/verification — Developer/QA-analyst/QA-tester):
- Reviewers are **verification** roles, not decision roles. They read a diff, apply a rubric, emit findings. Same shape as QA-analyst.
- Cost: 3 reviewers × per-wave invocation × up to dozens of waves per feature run. Opus would be 5–10× the token spend for verification work Sonnet handles competently at Anthropic's own published guidance for coding-assistant tiers.
- Latency: parallel invocation wall-clock ≈ slowest reviewer. Sonnet at ~30s/call beats Opus at ~90s/call on the wave-merge critical path.

When would Opus be justified: if a reviewer had to make **architectural judgement calls** (e.g., "does this decision align with the architect's constraints?"). That's what a future `reviewer-architecture` reviewer would need, but v1 doesn't include that axis — and if we add it later, it would be the one reviewer on Opus among the Sonnet trio.

### Q6 — Where reviewer subagents live → **Flat layout: `.claude/agents/specflow/reviewer-<axis>.md`**

Recommendation: **flat**, matching the existing convention (`qa-analyst.md`, `qa-tester.md`, `pm.md`, `architect.md` — no subdirs).

Defence:
- Consistency with the 7 existing agent files. The agent loader (Claude Code's subagent resolution) looks at the flat file list; a subdir (`reviewers/security.md`) would be a special-case in the only role-dir that has one.
- Role prefix (`reviewer-security`, `reviewer-performance`, `reviewer-style`) groups them alphabetically when the list is read by a human, without requiring a subdir.
- If a future feature adds more reviewers (docs, correctness, architecture), the flat layout scales to 6–8 files before directory discipline would matter. Not a v1 concern.

Appendix files follow the same pattern: `reviewer-security.appendix.md` etc. Rubric content (the detailed "what is `must` for security") lives in `.claude/rules/reviewer/` — rubric is content, not agent prompt; rules layer is where content goes.

---

## 4. Risks

- **Over-reviewing — 5-wide wave × 3 reviewers = 15 reviewer invocations per wave**
  - _Mitigation_: reviewers see **only the per-task diff** (not whole repo). Token cost per invocation is small (~5–50 lines of diff + rubric + PRD §Requirements ref). Parallel invocation so wall-clock ≈ one reviewer, not 15×.
  - _Residual_: the cost is real but bounded; PRD acceptance criterion should include a cap ("reviewer context ≤ N tokens per invocation") so regressions are caught.

- **Reviewer disagreement — security says block, style says ship**
  - _Mitigation_: severity-gated blocking (Q3c) sidesteps this by collapsing the decision to "any `must` = block". Reviewers don't vote; the severity tag on their findings does.
  - _Residual_: if two reviewers disagree on the *severity* of the same finding, orchestrator takes the higher severity. Documented in PRD acceptance criteria.

- **Stale reviewer reports — findings on T3 might be moot after T4 refactors the same code**
  - _Mitigation_: per-task review runs at task-commit time, before wave-merge. Findings address the task-as-committed, not a future refactor. If T4 in a later wave changes T3's code, T4 gets its own review; T3's report becomes historical context in the review log, not an active blocker.
  - _Residual_: the review log grows per wave; `07-review.md` (from item 6) only captures the latest run. Acceptable.

- **Reviewer context size — whole-feature diff for /specflow:review**
  - _Mitigation_: command chunks by task (reads `06-tasks.md`), dispatches one chunk per task per reviewer. Reviewers see task-scoped diffs, same as (4). Feature-level roll-up is a one-pass aggregation of per-task findings, not a single giant review.

- **Dogfood paradox — item (4) not wired until after its own T-tasks land**
  - _Mitigation_: accept. First actual inline-review use is the **next feature** after this one. Same paradox B2.a resolved for the Stop hook. Not a risk, just a limitation to document.

---

## 5. Open questions for PRD

**Blockers (must resolve in PRD, not here)**:

- **Q-BLOCK-1 — Reviewer rubric content**: the rubric lives in `.claude/rules/reviewer/security.md`, `.../performance.md`, `.../style.md`. What are the initial rule entries? PRD §Requirements needs to specify the *shape* (severity-gated findings) but not enumerate every rule. A seed rubric with 3–5 entries per axis is a T-task for the developer, sourced from the architect's tech decisions + existing rules index. Flagged for architect/TPM to scope.

- **Q-BLOCK-2 — Developer remediation slot interaction**: after a `must` finding blocks a wave, the developer gets one retry. Does the retry re-invoke all three reviewers, or only the one that flagged? PRD should pick; recommend **all three re-invoke** (simpler contract, avoids "fix security, break style" race).

**Nice-to-clarify (resolve inline in PRD)**:

- **Q-NICE-1 — Output artifact for (4)**: per-wave reviewer findings log location. Recommend `.spec-workflow/features/<slug>/.review-log/<wave>.md` (feature-local, gitignored like `.worktrees/`, surfaces in archive only if user wants).
- **Q-NICE-2 — Output artifact for (6)**: `07-review.md` alongside `07-gaps.md`. Not merged into gap-check output.
- **Q-NICE-3 — Reviewer prompt template**: single shared core + per-axis appendix (like existing developer/architect split)? Recommend yes — three files with identical core header, rubric-pull differs.

Not open — out of scope per request: TDD enforcement, strategic compaction hooks, `/specflow:extract`, cross-harness adapters, further hook infrastructure (B2.a shipped).

---

## Summary line (for STATUS)

Recommend **one feature, both items together**: 3 Sonnet reviewers (security/performance/style) in flat `.claude/agents/specflow/reviewer-*.md` layout, severity-gated blocking (`must` blocks wave merge, `should`/`advisory` log only), `/specflow:review` as a one-shot command (not a stage). Two PRD blockers: initial rubric content (Q-BLOCK-1) and retry-slot reviewer set (Q-BLOCK-2).
