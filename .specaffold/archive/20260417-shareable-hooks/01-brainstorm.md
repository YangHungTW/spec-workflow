# Brainstorm — b2-harness-upgrade

_PM, 2026-04-17. Applying `pm/split-by-blast-radius-not-item-count` (written during B1) to a 4-item ask that splits naturally into two clusters._

Team memory consulted:
- `pm/split-by-blast-radius-not-item-count.md` — the explicit heuristic for this brainstorm; dogfooding it on its second application.
- `shared/` — empty, no cross-role conventions apply.

---

## Decision (2026-04-17, user-confirmed)
- Split: shape B (two features).
- B2.a (this feature, slug `20260417-shareable-hooks`): items (5) + (7).
- B2.b (follow-up, slug TBD, opens after B2.a archives): items (4) + (6).
- Q1 globalization = b (shallow): only hook scripts symlink via bin/claude-symlink to ~/.claude/hooks/. Rules stay per-project. Per-project opt-in via specflow-install-hook.
- Dogfood paradox accepted: item (5) Stop hook can't validate during its own implement; B2.b will be the first feature to actually use it.

---

## 1. Split recommendation — **B (two features)**

**Recommendation: shape B — split into two features by cluster.**

- **B2.a — "globalize rules + status-sync hook"**: items **(7)** (extend `bin/claude-symlink` + hook-wiring helper) and **(5)** (Stop hook for STATUS sync). Failure surface: **session startup / STATUS writes across every installed project** (global blast radius).
- **B2.b — "inline + parallel review capability"**: items **(4)** (per-task inline reviewer) and **(6)** (`/specflow:review <slug>` parallel reviewers). Failure surface: **implement-stage orchestration + one opt-in command** (local blast radius, opt-in).

**One-line reason**: items (5)/(7) both ship hook scripts + `settings.json` wiring that runs on every session of every project — a different failure surface from (4)/(6), which only affect the implement/review stages of a single feature at a time.

**Why not A (one PRD)**: four items × two very different blast radii = a monolithic gap-check that cannot meaningfully verify "does this break all my sessions?" alongside "does the reviewer over-flag cosmetic nits?". Same mistake B1 would have made.

**Why not C (three+)**: within each cluster the items share real plumbing — (5) and (7) both touch `.claude/hooks/` conventions and `bin/specflow-install-hook` wiring; (4) and (6) both introduce reviewer subagents with a shared rubric. Splitting finer forces redo work.

**Precedent**: B1 itself made the same call (mixed session-wide + stage-local, split at the seam). This is the second application of the heuristic, not a novel judgement — which is also why there are no new PM memory proposals from this brainstorm.

---

## 2. Per-item approach sketches

### (7) Globalize rules/hooks via `bin/claude-symlink` (extension)

- **What changes**: extend `plan_links()` in `bin/claude-symlink` to emit two new dir-level pairs — `.claude/rules/` and `.claude/hooks/` — alongside the existing `agents/specflow`, `commands/specflow`, and walked `team-memory/**`. New subcommand or option to wire the SessionStart hook into a target project's `settings.json` transparently (reuse `bin/specflow-install-hook add SessionStart …`). The existing classify-before-mutate contract (8-state enum, ownership gate, managed-set ownership) holds as-is; we just grow the managed set.
- **Trickiest thing — scope of globalization (BLOCKER, §5)**: `.claude/rules/` symlinked into `~/.claude/rules/` means *every* Claude Code session on this machine loads the repo's rules, regardless of which project the session is in. That is probably the intent (rules like bash-32-portability are universal), but it is also a large, invisible behaviour change. The alternative is per-project opt-in — each project's own `.claude/rules/` continues to be the source of truth, and `bin/claude-symlink` is extended only to install the hook script + wire `settings.json` per project, not to symlink the rules themselves. See §5 for the open question that blocks PRD.
- **Second-trickiest — directory-level vs file-level walk**: B1's hook script (`.claude/hooks/session-start.sh`) is one file today, but `.claude/rules/` already has `common/`, `bash/`, etc. Dir-level pairs (like `agents/specflow`) are simpler but make the source repo the single ground truth for rule content — a consumer project can't add local rules without editing the symlinked dir. File-level pairs (like `team-memory/**`) let consumers layer local additions but explode the managed-set size. PRD should call this.
- **Third-trickiest — hook wiring per project**: each consumer project needs its own `settings.json` entry pointing at the symlinked `hooks/session-start.sh`. The `settings.json` path must be absolute (SessionStart resolves from the session's cwd, and the hook script itself lives at `~/.claude/hooks/session-start.sh` once symlinked). This is a one-shot per project, not a per-session op; the install step should run `specflow-install-hook add` automatically when the user opts in, with a `--no-hook` escape hatch.
- **Depends on**: none upstream. Lands first in B2.a.

### (5) Stop hook for STATUS sync

- **What changes**: new `.claude/hooks/stop.sh` (shares conventions with B1's `session-start.sh` — fail-safe `exit 0` on error, JSON stdout contract, no `jq` / `readlink -f` / `mapfile`). Hook reads a well-known scratch location where the stopping agent deposited its STATUS-note fragment, appends atomically to the feature's `STATUS.md`. Wire entry goes into `settings.json` via the existing `specflow-install-hook add Stop "…"` helper.
- **Trickiest thing — scoping**: Stop fires on *every* agent stop event, not only implement-wave developer stops. The hook must no-op unless a scratch fragment exists (absence = this stop has nothing to sync). Fragment filename convention should carry the feature slug + role so the hook knows which `STATUS.md` to touch; this becomes the only contract between agents and the hook.
- **Second-trickiest — concurrency**: two parallel developer agents in a wave can Stop in the same second. Append-with-lock via `mkdir` lockfile (bash-3.2-portable; no `flock`). Agents write uniquely-named fragments; the hook serializes the append per feature.
- **Depends on**: shares hook-script conventions with (7). If (7) lands first in the same feature, (5) reuses the layout (`.claude/hooks/stop.sh`) without contention.

### (4) Inline per-task code review

- **What changes**: new `specflow-reviewer` subagent (likely sonnet). `/specflow:implement` wave-loop grows a step between task-commit and wave-merge: reviewer reads the task diff against PRD requirements + tech decisions, returns PASS / FIX / ESCALATE. FIX = developer gets one remediation shot; ESCALATE = stop the wave. Rubric lives in `.claude/rules/reviewer/` so tuning is a rule edit, not a prompt edit (leveraging B1's rules layer directly).
- **Trickiest thing — strictness tuning**: too strict blocks every wave on cosmetic nits; too lax = wall-of-approvals noise. Default to **advisory-only for first N waves** (logs findings, doesn't gate); promote to gating only after pass-rate settles. Risk §4 revisits this.
- **Depends on**: leverages B1's `.claude/rules/` layer for the rubric, but doesn't depend on B2.a. Can land in parallel if B2.a and B2.b are developed concurrently.

### (6) `/specflow:review <slug>` parallel reviewer team

- **What changes**: new slash command `.claude/commands/specflow/review.md`; 2–3 new reviewer agents (security, performance, style) invoked concurrently via the multi-Agent-call pattern already used in `/specflow:implement`. Consolidated report written to `07-review.md` or folded into `07-gaps.md`. Optional stage — user opts in; not a gap-check replacement.
- **Trickiest thing — dedup + latency**: three reviewers produce overlapping findings; the consolidator must dedupe without losing the distinct per-axis lens. Parallel invocation means total wall-clock = slowest reviewer (usually acceptable; §4).
- **Depends on**: (4) should land first so reviewer-agent conventions (prompt shape, rubric source, PASS/FIX/ESCALATE verb set) are established. (6)'s three agents inherit the shape.

---

## 3. Dogfooding check

This feature changes the implement flow (item 4) and the Stop hook (item 5). Both affect **this feature's own implement waves** — chicken-and-egg territory.

**Recommended order**:

1. **Ship B2.a first** — items (7) then (5). Item (7) is zero-dogfood-paradox (symlink tool extension; tested in sandbox). Item (5) is the one that *itself* would benefit from already being in place; accept the paradox, land it with tests that don't rely on it (sandboxed hook invocation per `bash/sandbox-home-in-tests.md`), and the *next* feature (B2.b) gets the Stop hook working during its own implement waves.
2. **Then B2.b** — items (4) then (6). (4) lands first so its reviewer subagent defines the conventions (6) inherits. (4) runs in advisory-only mode during its own implement (won't gate merges on its own PRs); (6) is opt-in, so its implementation doesn't trigger itself.

**Cannot be tested in situ during its own feature**:
- **Item (5) Stop hook** — shipping the hook doesn't mean it fires for the agents shipping it, because the `settings.json` wire happens at install time, after merge. The feature's own implement waves will still show the "file modified since read" race. This is acceptable; the *next* feature's waves validate it. Flag for a **follow-up validation session** after B2.a archives: open a tiny throwaway feature, run one implement wave, confirm no STATUS race.
- **Item (4) inline reviewer** — similarly won't guard its own merge. Validation comes during B2.b's implementation of (6) — by then (4) is live.

---

## 4. Risk callouts

- **(4) over-reviewing → blocks wave merges on cosmetic nits**
  - *Mitigation*: ship in **advisory-only mode** (logs findings, does not gate) for the first N waves of use. Promote to gating only after pass-rate settles above a threshold. Rubric in `.claude/rules/reviewer/` so tuning is a rule edit.

- **(5) Stop hook mis-fires → appends STATUS notes on every stop event**
  - *Mitigation*: hook no-ops unless a well-known scratch fragment file exists. Fragment naming convention (`$feature-slug.$role.$timestamp.fragment` or similar) is the contract — no fragment, no append. This also means unrelated agent stops (non-implement, non-specflow) are silently ignored.

- **(6) reviewer latency → parallel 3-way review takes as long as the slowest**
  - *Mitigation*: accept for v1. Reviewers are opt-in, not gating. If sonnet-tier reviewers finish in ~30s each and run concurrently, wall-clock ≈ 30s — acceptable vs gap-check's own runtime. Flag for post-ship measurement.

- **(7) globalization creates `~/.claude/rules/` loaded by every session — surprise factor**
  - *Mitigation*: install step must be **explicit opt-in** with a clear dry-run diff showing exactly which paths get symlinked and which settings.json files get edited. `--no-rules` flag for users who want hooks but not global rules. Document the "to unwind: `bin/claude-symlink uninstall` + `specflow-install-hook remove …`" path in the install output.
  - *Cross-reference*: `common/no-force-on-user-paths.md` already governs the mutation pattern; globalization inherits it automatically via the existing `classify-before-mutate` dispatch.

---

## 5. Open questions for PRD

**Blockers (must resolve before PRD)**:

- **Q1 — Globalization scope for item (7)**: does `.claude/rules/` symlink into `~/.claude/rules/` (every Claude Code session on this machine picks up spec-workflow's rules), OR do consumer projects keep their own `.claude/rules/` and only the SessionStart *hook script* globalizes? This decides whether B2.a's value is "share rules across my projects" vs "make B1's hook mechanism reusable". Both are defensible; the ask is ambiguous ("globalize rules + hooks" vs "globalize the hook that reads rules"). **Needs user decision.**

- **Q2 — Shape confirmation**: shape B as recommended? If user wants A (one PRD) or C (split (7) off alone because it's the highest-dogfood-payoff item), say so before PRD.

**Nice-to-clarify (resolve inline in PRD)**:

- **Q3 — Reviewer model tier**: sonnet for (4)/(6) to keep cost down? PRD assumes yes unless stated otherwise.
- **Q4 — (6) `/specflow:review` gating vs advisory**: PRD will default to **advisory, user-invoked**; user overrides if they want it to gate gap-check.
- **Q5 — Fragment location for (5) Stop hook**: `.spec-workflow/features/<slug>/.status-fragments/` (feature-local) vs `/tmp/specflow-status-fragments/` (session-local)? PRD will pick feature-local for auditability unless the architect flags a reason to move it.

Not open — out of scope per request: TDD enforcement, strategic compaction hooks, `/specflow:extract`, cross-harness adapters, rewriting the existing managed set.

---

## Summary line (for STATUS)

Recommend **shape B** (two features, split by cluster): B2.a = items (7)+(5) (global infra), B2.b = items (4)+(6) (review capability). One PRD-blocker: Q1 on globalization scope for item (7).
