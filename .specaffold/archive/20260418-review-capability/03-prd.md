# PRD — review-capability (B2.b)

_2026-04-18 · PM_

## 1. Overview

Final of a six-item harness upgrade series (B1 shipped items 1–3 as prompt-rules-surgery; B2.a shipped items 5 + 7 as shareable-hooks; this feature delivers the deferred items 4 + 6). Adds **multi-dimensional reviewer capability** in two complementary shapes: (a) inline per-task review during the implement-wave merge step, and (b) a one-shot `/specflow:review <slug>` command that dispatches 3 reviewers (security / performance / style) in parallel against the whole-feature diff. Blocking is **severity-gated** — findings tagged `must` halt a wave merge; `should` / `advisory` findings log and flow to gap-check context.

## 2. Goals / Non-goals

### Goals
- **(4) Inline per-task review** — between each wave's task commits and wave merge, 3 reviewer subagents (security / performance / style) run in parallel against each task's diff; any `must` finding halts that wave's merge until remediated; runtime-class bugs (the SF-2 double-report class from symlink-operation) surface at wave-merge, not at gap-check.
- **(6) `/specflow:review <slug>`** — new slash command dispatches the same 3 reviewers concurrently against the full feature-branch diff; writes a timestamped report under the feature dir; runnable at any stage (in-flight or archived); never advances STATUS.
- **Meta outcome** — the next feature run against this harness shows fewer late-stage gap-check `should`-fixes (inline review catches them at wave merge), and gap-check verdicts now reflect multi-axis coverage rather than one reviewer squinting at three concerns.

### Non-goals
- TDD enforcement (deferred; separate future feature).
- Strategic compaction hooks.
- `/specflow:extract` knowledge-extraction command.
- Cross-harness adapters (Cursor / Codex / OpenCode).
- Further symlink or hook infrastructure (B2.a shipped the shallow globalization).
- Superpowers / ECC / wshobson wholesale port.
- Dashboard / GUI / TUI for specflow runs.
- AgentShield-grade threat-model security depth — reviewers here are craft-level, not security-specialist-depth.
- Additional reviewer axes (docs, correctness, architecture). v1 ships 3 (security / performance / style); more can follow after the pattern proves out.
- Reviewer-verdict disagreement resolution beyond "take the highest severity per finding".
- Automated linter that flags performative reviewer output (stub PASS with no rationale).

## 3. User stories

1. **Catch task-level runtime bugs at wave merge, not 10 tasks later.** As a developer finishing T5 in wave 3, I want a security reviewer to flag my hardcoded path and a performance reviewer to flag my shell-out-in-loop BEFORE the wave merges, not at gap-check after the whole feature lands.
2. **Multi-dimensional gap-check context.** As a PM kicking off gap-check, I want `/specflow:review` to have already run a 3-axis parallel review so gap-check's verdict reflects security + performance + style coverage, not just static diff-vs-PRD analysis.
3. **Supplemental audit of archived features.** As a contributor investigating a regression in an archived feature, I want to run `/specflow:review <archived-slug>` and get a per-axis review of that feature's delivered code without re-running the stage flow.
4. **Severity-gated, not all-or-nothing blocking.** As a developer merging a wave with a style-drift finding, I want the merge to proceed and log the finding — not block on cosmetic nits — while still halting on a real `must`-severity runtime bug.

## 4. Functional requirements

### Inline per-task review during implement (item 4)

**R1 — Inline review dispatches per-task × per-reviewer after wave completion, before merge.** After all developer subagents in a wave return, and BEFORE any `git merge --no-ff <slug>-T<n>` call in `/specflow:implement`'s per-wave loop step 6, the orchestrator spawns **3 reviewer subagents per completed task** (security / performance / style), all in parallel across tasks × reviewers (one message, multiple Agent tool calls). For a 5-wide wave this is 15 concurrent reviewer invocations; wall-clock is dominated by the slowest single reviewer.

**R2 — Reviewer context is task-local.** Each reviewer subagent receives only:
- the task's branch diff against the feature branch (`git diff <slug>...<slug>-T<n>`),
- its axis rubric (`.claude/rules/reviewer/<axis>.md`, loaded by the agent itself per R15),
- the PRD requirement IDs relevant to the task (read from `06-tasks.md`),
- its role team-memory per the standard invocation block.

Reviewers MUST NOT receive the whole repo or the whole feature diff during inline review. Keeping context task-local bounds token cost and sharpens the finding lens.

**R3 — Reviewer verdict contract.** Each reviewer returns a structured result containing:
- `verdict: PASS | NITS | BLOCK`
- `findings: []` — zero or more entries, each `{severity: must|should|advisory, file: <path>, line: <n>, rule: <rule-slug>, message: <one-line>}`

Verdict semantics: `PASS` = no findings; `NITS` = findings present, none at `must` severity; `BLOCK` = at least one `must` finding. Severity values are the same taxonomy used by `.claude/rules/` (consistency with B1).

**R4 — Orchestrator aggregation and merge gate.** After all per-task reviewers return for a wave:
- If ANY reviewer for ANY task returned `BLOCK` (at least one `must` finding), the wave merge halts. Orchestrator stops the implement loop, writes an aggregated per-task findings summary to the STATUS Notes, and surfaces the blocking tasks to the user with the recovery command (`/specflow:implement <slug> --task T<n>`). The developer retries the flagged task; already-completed task branches for that wave remain unmerged on feature branch until the retry resolves.
- If all reviewers returned `PASS` or `NITS` (no `must` findings anywhere in the wave), the wave merge proceeds as today.
- Where two reviewers disagree on the severity of the same file:line finding, orchestrator takes the higher severity.

**R5 — Retry re-runs all 3 reviewers.** When a developer retries a task that was blocked by a `must` finding, the orchestrator MUST re-invoke all 3 reviewers on the new commit, not just the reviewer that flagged the original `must`. Rationale: fixing a security issue can introduce a style regression (and vice versa); re-running all 3 is the simpler contract and catches the "fix one, break another" race. Max retries per task = 2; on exceed, the orchestrator STOPs the implement loop and surfaces the persistently-failing task to the user (same mechanism D6 documents in `04-tech.md`). [CHANGED 2026-04-18]

**R6 — NITS findings surface in the wave merge commit.** When a wave merges with `NITS` verdicts from any reviewer (i.e. `should` or `advisory` findings present, no `must`), the orchestrator's wave-merge commit message MUST contain a `## Reviewer notes` section listing the findings (one line per finding, grouped by task). NITS findings also append to the STATUS Notes line for the wave. This ensures non-blocking findings are not silently swallowed at merge time.

**R7 — Opt-out flag for explicit bypass.** `/specflow:implement <slug> --skip-inline-review` skips all reviewer dispatch for this run. Default behaviour: inline review is ON. The flag is for emergency / debugging / bootstrapping (the first wave that ships this feature itself cannot review its own landing — the dogfood paradox). Use of the flag MUST emit a diagnostic line to the STATUS Notes so its use is visible in archive.

### `/specflow:review <slug>` one-shot command (item 6)

**R8 — New slash command file.** Create `.claude/commands/specflow/review.md` following the shape of the other specflow slash commands (frontmatter `description`, ordered `## Steps`, `## Failures`, `## Rules` sections). The command is **orchestrator-run**, not agent-run — it dispatches the 3 reviewer subagents from R14 and consolidates.

**R9 — Dispatch shape.** `/specflow:review <slug>` invokes all 3 reviewer subagents in parallel (one message, 3 Agent tool calls). Each reviewer receives:
- the full feature-branch diff vs `main` (`git diff main...<slug>`), NOT chunked by task,
- its axis rubric,
- the feature's `03-prd.md` for requirement context,
- its role team-memory.

Reviewers chunk their own reading if the diff is large (this is a Sonnet-tier judgement call); orchestrator does not pre-chunk.

**R10 — Report artifact.** The command writes a report to `.spec-workflow/features/<slug>/review-<YYYY-MM-DD-HHMM>.md` (or, for archived features, the equivalent path under `.spec-workflow/archive/<slug>/`). Report contains a per-axis section (Security / Performance / Style) with that reviewer's verdict and findings, plus a top-level `## Consolidated verdict` block. Reports are additive — each invocation writes a new timestamped file; existing reports are never clobbered.

**R11 — Non-advancing, non-blocking.** The command does NOT check any box in STATUS's stage checklist. The command does NOT halt any other in-flight stage. It is a pure read-plus-report tool usable at any time (during implement, before gap-check, after archive). STATUS Notes gets one line per invocation (`YYYY-MM-DD review — <slug> axis=<all|...> verdict=<...>`).

**R12 — Single-axis mode.** `/specflow:review <slug> --axis <security|performance|style>` dispatches only the named reviewer, for targeted re-review after a fix. Single-axis mode writes to the same timestamped report path as full-axis mode; it simply omits the other axis sections.

**R13 — Exit code signals verdict.** The command's exit code is non-zero if any reviewer returns a `BLOCK` verdict (i.e. any `must`-severity finding present in the report). Because the command is one-shot and never auto-gates anything, the exit code is informational — it signals possible CI integration but does not halt any specflow stage.

### Reviewer subagent definitions

**R14 — Three reviewer agent files, flat layout.** Create three new agent files under `.claude/agents/specflow/`:
- `.claude/agents/specflow/reviewer-security.md`
- `.claude/agents/specflow/reviewer-performance.md`
- `.claude/agents/specflow/reviewer-style.md`

Each uses the B1 D10 six-block core template: YAML frontmatter → role identity → team-memory invocation block → when-invoked section(s) → output contract → rules. Structure matches `qa-analyst.md`'s post-B1 shape — this is the reference template.

**R15 — Each reviewer loads its own rubric.** In the "Before acting" block, each reviewer's core prompt MUST instruct it to read `.claude/rules/reviewer/<axis>.md` (the rubric for its axis) in addition to the standard team-memory invocation. The rubric is the source of truth for "what counts as `must` for this axis"; the agent prompt does not restate rubric content (R14 in B1 forbids duplication between rules and agent files).

**R16 — Model tier.** Each reviewer agent's frontmatter has `model: sonnet`. Reviewers are verification roles (same tier as QA-analyst and developer) — not decision roles (Opus).

**R17 — Stay-in-your-lane constraint.** Each reviewer's core prompt MUST contain the explicit instruction: "Comment only on findings against your axis rubric. Do not flag issues outside your axis even if you notice them — the other reviewers cover those axes." Verifiable by grep per reviewer file. Rationale: prevents the security reviewer from emitting style nits that dilute its `must`-severity signal; keeps the 3-reviewer signal orthogonal.

### Rubric content (PM seeds v1 here; Architect/TPM may refine)

**R18 — Create `.claude/rules/reviewer/security.md` with v1 content.** Uses the standard rule-file schema (5 frontmatter keys, `## Rule` / `## Why` / `## How to apply` / `## Example`) with `scope: reviewer`. The file MUST contain at least these 6 checks (expressed as an opinionated checklist in the `## How to apply` section):
1. **Hardcoded secrets or tokens** (`must`) — reject any commit that adds a literal secret / API key / token / bearer string; cross-reference env-var or keychain reads as the expected pattern.
2. **Path traversal** (`must`) — any path join on user-supplied or external input is resolved through an absolute-path resolver with a boundary check (the target must sit under an explicit allowed root); relative traversal (`..`) without boundary check is a finding.
3. **Input validation at boundaries** (`must`) — untrusted input (CLI args, env vars, file contents) is validated at the first point of entry, not deep inside the call tree; missing validation at a boundary is a `must`.
4. **Injection attacks** (`must`) — no string-concatenation into a shell command or SQL statement; parameterised queries and argv-form command invocation are required. String-built commands that include any variable are a `must` finding.
5. **Untrusted YAML / JSON parsing** (`should`) — parsing external YAML with a full loader (e.g. `yaml.load` rather than `yaml.safe_load`) is a finding; JSON parsers should be standard-library; no eval-based parsing.
6. **Secure defaults — cross-reference `no-force-on-user-paths`** (`must`) — any CLI that touches user-owned paths must default to non-destructive behaviour (no silent clobber, backup before mutate, atomic swap). This rubric entry cross-references the existing `.claude/rules/common/no-force-on-user-paths.md` rather than restating it.
7. **Atomic file writes and backups** (`should`) — writes to user-owned paths should use write-temp-then-rename with a prior `.bak` backup; non-atomic writes are a `should`.
8. **Sentinel-file race conditions** (`should`) — check-then-write patterns on sentinel files (lock files, state markers) should use atomic creation primitives (`O_EXCL`) or explicit mutex patterns; a plain `-e` check followed by write is a finding.

**R19 — Create `.claude/rules/reviewer/performance.md` with v1 content.** Same schema, `scope: reviewer`, at least these 6 checks:
1. **No shell-out in tight loops** (`must`) — any subprocess call inside a loop body iterating over more than a small constant count is a finding; recommend batch invocation or in-process equivalent.
2. **Avoid O(n²) where O(n) works** (`must`) — obvious quadratic patterns (nested membership check against a list, repeated sort inside a loop) are findings; hash-lookup or pre-sort is the expected pattern.
3. **Cache expensive operations** (`should`) — repeated invocation of `uname`, `git status`, `git rev-parse`, network fetches, or other out-of-process calls within a single script run should be cached to a variable on first call; repeated invocation is a finding.
4. **Prefer `awk`/`sed` over `python3` for simple transforms** (`should`) — spawning a Python interpreter for a one-shot string replace or column extraction is wasteful on hook and loop paths; simple transforms belong in `awk`/`sed`.
5. **No re-reading the same file** (`should`) — reading the same file multiple times in a single tool invocation is a finding; read once, reuse.
6. **Minimise fork/exec in hot paths** (`should`) — loops that spawn one or more processes per iteration should be refactored to batch invocation or in-process handling; flag when the loop body is expected to iterate more than a few times.
7. **Hook latency budget < 200ms** (`must`) — any code added to SessionStart / Stop / other hooks must keep total hook wall-clock under 200ms on a warm cache; a hook that exceeds this budget is a finding. Cross-references B1's R5 SLA.
8. **Avoid eager loads of unused data** (`should`) — loading a large file / dataset when only a few fields are read is a `should`; stream or selective-parse where practical.

**R20 — Create `.claude/rules/reviewer/style.md` with v1 content.** Same schema, `scope: reviewer`, at least these 6 checks:
1. **Match existing naming conventions in the file** (`should`) — new symbols / functions / vars in an edited file should follow the naming convention of the surrounding code (snake_case vs camelCase, prefix conventions); drift is a finding.
2. **No commented-out code** (`must`) — commit adds lines of commented-out code left as a future reference are a finding. Use git history if you need the old version.
3. **Comments explain WHY, not WHAT** (`should`) — a comment that merely restates what the next line does (`# increment counter`) is a finding; comments should explain rationale, constraints, or non-obvious decisions.
4. **Match neighbour indent and quoting** (`should`) — inconsistency with the immediate file's indent (tabs vs spaces, 2 vs 4) or string-quote style is a finding.
5. **Bash 3.2 portability — cross-reference `bash-32-portability`** (`must`) — do not restate the rule; when reviewing bash files, cross-reference `.claude/rules/bash/bash-32-portability.md` and flag violations there as `must`.
6. **Sandbox-HOME in test scripts — cross-reference `sandbox-home-in-tests`** (`must`) — do not restate; cross-reference `.claude/rules/bash/sandbox-home-in-tests.md` for test script reviews.
7. **`set -euo pipefail` convention** (`should`) — new bash scripts should match the strictness convention of neighbouring bash scripts in the same directory; do not introduce a looser mode in a directory where all existing scripts use `set -euo pipefail`. Avoid dogmatic re-opening of the debate when neighbours are consistent.
8. **Dead imports / unused symbols** (`should`) — unused imports or declared-but-unread variables in the diff are a finding.

**R21 — Rubric files use the existing rule schema, scope `reviewer`.** Each rubric file above has frontmatter with `name` (matching filename stem), `scope: reviewer`, `severity` (the *default* severity applied when the rubric flags a violation — authoring convention: the rubric file's `severity` should reflect the axis's general posture; individual rule entries in the `## How to apply` checklist may carry their own severity as above), `created`, `updated`. Body has `## Rule` / `## Why` / `## How to apply` / `## Example` in that order.

### Schema extension

**R22 — `.claude/rules/README.md` admits a new scope `reviewer`.** The scope enum in the rule-frontmatter schema section changes from `common | bash | markdown | git | <lang>` to `common | bash | markdown | git | reviewer | <lang>`. The directory-layout section grows a row for `reviewer/`. The authoring checklist's scope-check bullet covers the new value.

**R23 — SessionStart hook MUST NOT auto-load reviewer-scoped rules.** The B1 SessionStart hook (`.claude/hooks/session-start.sh`) walks rule subdirs to build its digest. Reviewer rubrics are agent-triggered content (loaded on reviewer invocation per R15), not session-wide guardrails; loading them into every Claude session's context would pollute non-reviewer sessions with rubric detail they do not need. The hook therefore MUST skip the `.claude/rules/reviewer/` subdirectory during its walk. Verifiable by inspecting the hook's digest for any reviewer/* mentions.

### Tests

**R24 — Unit tests per reviewer agent.** For each of the 3 reviewer agent files, a small test script under `test/` stubs an invocation (pre-made diff + pre-made rubric stub), runs the agent contract (or a close simulation), and asserts the returned shape contains `verdict: PASS|NITS|BLOCK` and zero-or-more `findings` entries with the expected structural keys. This is a contract-shape test, not a behaviour test against specific rubric content.

**R25 — Integration test for inline review flow.** A sandbox test (under `test/`, using the `sandbox-home-in-tests` rule for HOME isolation) constructs a fake feature with a fake task branch containing one intentional `must`-severity violation, runs the inline-review dispatch logic, and asserts:
- the orchestrator aggregates a `BLOCK` verdict,
- the wave merge does not occur,
- a follow-up retry with the violation fixed is allowed to proceed,
- all 3 reviewers are re-invoked on the retry (per R5).

**R26 — Test for `/specflow:review` one-shot.** A sandbox test invokes `/specflow:review <fake-slug>` against a fake feature dir containing a pre-made diff and asserts a timestamped report file is written under the feature dir with 3 per-axis sections and a consolidated verdict block. Additionally: a repeat invocation does not clobber the prior report (both timestamped files present on disk).

**R27 — Test that SessionStart hook skips reviewer-scoped rules.** A test invokes the SessionStart hook with a populated `.claude/rules/reviewer/` subdir (the rubric files from R18–R20) and asserts the hook's stdout digest contains no lines mentioning files under `reviewer/`. Maps to R23.

**R28 — Extend `test/smoke.sh` to cover the new tests.** The smoke-test harness grows from 33 assertions to `33 + <new>`, where `<new>` is the sum of AC-gated assertions this PRD adds (see §5). Concretely: each new AC that can be asserted by a shell check becomes one smoke-test line; the total assertion count is printed by the harness as today.

## 5. Acceptance criteria

- **AC-inline-review-fires** — A wave-merge run with at least one completed task dispatches 3 reviewers per task before merging any task branch. Verified by instrumenting the implement loop and counting reviewer subagent invocations in a sandbox integration test. Maps to R1, R2.
- **AC-verdict-shape** — Every reviewer invocation returns a result whose top-level keys are exactly `verdict` (value in `{PASS, NITS, BLOCK}`) and `findings` (array, possibly empty). Verified by the unit tests in R24. Maps to R3.
- **AC-block-on-must** — In the integration test (R25), a task diff containing one `must`-severity violation causes the wave merge to halt; no `git merge --no-ff <slug>-T<n>` call executes while the BLOCK is outstanding. Maps to R4.
- **AC-retry-reruns-all** — In the retry half of the integration test, after the developer fixes the flagged violation and re-runs the task, all 3 reviewers (not just the one that flagged) are invoked on the new commit. Verified by invocation count. Maps to R5.
- **AC-advisory-logs** — In a sandbox where a reviewer returns `NITS` (no `must`, one `should`), the wave merge proceeds and the merge commit message contains a `## Reviewer notes` section with the finding. Verified by inspecting the merge commit message in the sandbox. Maps to R6.
- **AC-skip-flag-works** — `/specflow:implement <slug> --skip-inline-review` completes a wave without dispatching any reviewer; STATUS Notes includes a diagnostic line flagging the skip. Maps to R7.
- **AC-review-command-exists** — `.claude/commands/specflow/review.md` exists and is parseable by the same conventions as other specflow commands (grep-checkable frontmatter + Steps/Failures/Rules sections). Maps to R8.
- **AC-review-command-parallel** — `/specflow:review <slug>` on a sandbox feature dispatches 3 reviewer subagents in parallel (one orchestrator message, 3 Agent tool calls). Verified by instrumenting the command. Maps to R9.
- **AC-review-report-written** — After `/specflow:review <slug>` completes, a file matching `review-YYYY-MM-DD-HHMM.md` exists under the feature dir with 3 per-axis sections and a `## Consolidated verdict`. Maps to R10.
- **AC-review-no-clobber** — Running `/specflow:review <slug>` twice in the same day produces two distinct timestamped report files; neither overwrites the other. Maps to R10.
- **AC-review-no-stage-advance** — After `/specflow:review <slug>`, STATUS's stage checklist has the same `[x]` / `[ ]` state as before. Verified by diffing STATUS.md. Maps to R11.
- **AC-review-axis-flag** — `/specflow:review <slug> --axis security` writes a report containing only the Security section (other axes omitted). Maps to R12.
- **AC-review-exit-code** — `/specflow:review` exits non-zero iff any reviewer returned `BLOCK` in the report. Maps to R13.
- **AC-reviewer-agents-exist** — All three files `.claude/agents/specflow/reviewer-{security,performance,style}.md` exist with valid frontmatter (`model: sonnet`), a team-memory block, a when-invoked section, an output contract, and a rules section. Maps to R14, R15, R16.
- **AC-stay-in-your-lane** — Each reviewer agent core file contains the literal stay-in-your-lane instruction. Verified by grep per file for a canonical phrase. Maps to R17.
- **AC-rubric-files-exist** — All three files `.claude/rules/reviewer/{security,performance,style}.md` exist with valid frontmatter (`scope: reviewer`, 5 keys), at least 6 distinct checklist entries in `## How to apply`, and the required body headings in order. Maps to R18, R19, R20, R21.
- **AC-scope-reviewer-added** — `.claude/rules/README.md` scope enum contains `reviewer`; directory-layout section documents `reviewer/`. Maps to R22.
- **AC-reviewer-not-in-digest** — Running the SessionStart hook with populated `.claude/rules/reviewer/` emits a digest that does not mention any file under `reviewer/`. Verified by grep on hook stdout. Maps to R23.
- **AC-unit-tests-pass** — Unit-test script per reviewer agent returns exit 0 and prints the contract-shape assertions passed. Maps to R24.
- **AC-integration-block-and-retry** — The R25 integration test passes end-to-end: block, retry, re-run-all, merge. Maps to R25.
- **AC-review-one-shot-test** — The R26 one-shot-command sandbox test passes. Maps to R26.
- **AC-hook-skip-reviewer-test** — The R27 hook-digest test passes. Maps to R27.
- **AC-smoke-green** — `bash test/smoke.sh` exits 0; its printed assertion count equals the pre-feature count + the number of new ACs added by this PRD that are shell-assertable. Maps to R28.
- **AC-no-regression** — All ACs from B1 (`prompt-rules-surgery`) and B2.a (`shareable-hooks`) still hold after this feature lands: rules layer intact, session-start hook still fires, stop hook still syncs STATUS, existing smoke tests still green. Verified by a re-run of both prior features' AC scripts.

## 6. Edge cases

- **All 3 reviewers timeout or fail to return.** Orchestrator's fallback for inline review: treat the wave as unreviewed, emit a loud diagnostic to STATUS Notes, and halt the wave. Do not silently proceed — a silent-proceed on reviewer failure is indistinguishable from no-reviewer, which defeats the feature. User must either retry (transient failure) or invoke `--skip-inline-review` (accepted cost). For `/specflow:review`, timeout causes a non-zero exit and a partial report (whichever reviewers did return are captured); user can re-run `--axis <missing>` after a transient failure.
- **Reviewer flags a `must` finding, developer fixes it, retry runs, the same reviewer now passes — but a *different* reviewer now flags something the first pass didn't cover.** This is the explicit justification for R5 (re-run all 3). The new finding is legitimate — it's on code the developer just touched during the retry — and the wave correctly halts again. Not a stale-feedback bug; it's the signal working as designed.
- **`/specflow:review` invoked on an archived feature.** R10 says report path follows the feature's current location (archive vs in-flight). Archived features live under `.spec-workflow/archive/<slug>/`, so the report file lands there. The diff basis is still `main`-vs-the-feature-commit (resolved via `git log` for archived features). No stage advancement. Works.
- **Concurrent wave merges from multiple features in flight.** Today's specflow does not run multiple features concurrently (single-feature-focus harness). If a user did run two `/specflow:implement` invocations in parallel, each would have its own orchestrator and its own reviewer dispatches; reviewer subagents are stateless, so there's no cross-contamination. Not a supported workflow; noted for completeness.
- **Reviewer disagreement on severity for the same file:line finding.** R4 says take the highest severity. Documented; not a blocker.
- **Dogfood paradox — the first wave landing THIS feature cannot have its own inline review.** Expected. `--skip-inline-review` (R7) is the escape hatch for the bootstrap wave. First real use of inline review is the next feature after this one. Same shape as B2.a's Stop hook bootstrap paradox.
- **Rubric file is malformed (missing frontmatter, missing sections).** The reviewer agent that depends on it should emit a diagnostic and return `verdict: PASS` (conservative — better to let the wave proceed with a loud diagnostic than block on our own broken rubric). User sees the diagnostic in STATUS Notes and fixes the rubric.
- **SessionStart hook walk edge case — a `reviewer/` subdir exists but also contains a `common/` subdir by author error.** The hook walks by top-level subdir name; `reviewer/` and its children are skipped entirely per R23. If a user puts `common/` rules under `reviewer/`, they do not load into session context. Documented as an authoring guideline (rubric files belong in `reviewer/` top level; no nested axes).
- **Report file name collision — user invokes `/specflow:review <slug>` twice within the same minute.** Timestamp granularity is minute-level; within-minute collisions would clobber. Mitigation: report filename includes second-granularity when a collision is detected (`review-YYYY-MM-DD-HHMM-<nn>.md`). Implementation detail for TPM.

## 7. Open questions / blockers

None. Candidate questions resolved:

- Q1 Shape — **ship together**, one feature (brainstorm §1, applies `pm/split-by-blast-radius`).
- Q2 Reviewer count — **3** (security / performance / style) per brainstorm §3-Q2.
- Q3 Blocking policy — **severity-gated** (`must` blocks, `should`/`advisory` log), per brainstorm §3-Q3; reused severity taxonomy from B1 rules layer.
- Q4 `/specflow:review` positioning — **one-shot command, never a stage** (brainstorm §3-Q4; preserves STATUS stability across feature versions).
- Q5 Model tier — **sonnet** for all 3 reviewers (brainstorm §3-Q5).
- Q6 Layout — **flat** `.claude/agents/specflow/reviewer-<axis>.md` (brainstorm §3-Q6).
- Q-BLOCK-1 Rubric content — PM seeds v1 content in R18–R20 above (6–8 entries per rubric, opinionated, cross-references existing rules rather than restating).
- Q-BLOCK-2 Retry reviewer set — **re-run all 3** on developer retry (R5).
- Scope extension — `reviewer` admitted as a new scope value in `.claude/rules/README.md` (R22).
- Hook filtering — reviewer rubrics are agent-triggered, not session-loaded (R23).

Nice-to-clarify (not blocking; Architect's call in `04-tech.md`):

- Exact wire format of the reviewer verdict-and-findings payload (JSON block in markdown? structured section in markdown return?). PRD specifies the contract's semantic keys; the literal encoding is an Architect D-decision.
- Timestamp format and collision handling for the report filename — `YYYY-MM-DD-HHMM` is the default; seconds-suffix on collision is an Architect call.
- Whether `/specflow:review` should accept a `--since <commit>` flag for partial-diff review. Not in v1 (full-feature diff is the default); if later demand appears, add as a future flag.
- Whether the sandbox integration test (R25) should live under `test/` or a new `test/review/` subdir — follows architect `script-location-convention` memory (test helpers under `test/`).

## 8. Out of scope

- TDD enforcement (deferred).
- Strategic compaction hooks.
- `/specflow:extract` knowledge-extraction command.
- Cross-harness adapters (Cursor / Codex / OpenCode).
- Further symlink or hook infrastructure (B2.a shipped the shallow globalization).
- Superpowers / ECC / wshobson wholesale port.
- AgentShield-grade threat-model security scanning — reviewers here are craft-level, not security-specialist-depth.
- Additional reviewer axes (docs, correctness, architecture) — v1 is 3; more can follow after the pattern proves out.
- Reviewer vote-based consensus — severity-gated aggregation (R4) is the only v1 mechanism.
- Automated linter that flags performative reviewer output (stub-PASS with no rationale).
- Versioning of the reviewer rubrics — rule edits apply to subsequent sessions, not retroactively to archived features.
- Dashboard / GUI / TUI for review results.
