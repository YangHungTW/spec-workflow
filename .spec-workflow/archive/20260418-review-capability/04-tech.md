# Tech — review-capability (B2.b)

_2026-04-18 · Architect_

## Team memory consulted

- `architect/classification-before-mutation.md` — **applies** to the orchestrator's
  per-wave reviewer aggregation: reviewer verdicts land in a closed severity
  enum (`PASS | NITS | BLOCK`, per-finding `must | should | advisory`), are
  classified into "block-the-wave" / "log-and-merge" buckets by a pure function,
  and only then does the mutation (wave merge, STATUS update, report write)
  dispatch. No mutation inside the classifier. See D2, D3.
- `architect/hook-fail-safe-pattern.md` — **applies** to R23's SessionStart
  walk edit. The existing hook is already fail-safe (`set +e`, trap, exit 0,
  stderr diagnostics). Adding a skip-list entry for `reviewer/` must not
  regress any of that. See D7.
- `architect/settings-json-safe-mutation.md` — **does not apply**. No config
  file is mutated by this feature. `/specflow:implement`'s `--skip-inline-review`
  is a runtime flag, not a persisted setting; `/specflow:review` writes
  timestamped markdown reports into feature dirs, never into user-owned
  config. Called out here so downstream roles can stop looking for it.
- `architect/shell-portability-readlink.md` — **applies** to every new bash
  touched by this feature (the SessionStart skip patch is the only one).
  See D7.
- `architect/script-location-convention.md` — **applies** indirectly. This
  feature ships no new `bin/` executables; all artifacts are prompts
  (`.claude/agents/specflow/`), commands (`.claude/commands/specflow/`),
  rules (`.claude/rules/reviewer/`), and tests (`test/`). See D1.
- `architect/no-force-by-default.md` — **applies as report-and-skip
  analogy** to R10's report-file handling: never clobber a prior report,
  always write a new timestamped file. See D3 + edge-case §6 of PRD.
- `shared/` (both tiers) — empty. Nothing to pull.

---

## 1. Context & Constraints

### Existing stack (what B1 + B2.a already shipped)
- **`.claude/rules/` layer** loaded per-session by the SessionStart hook
  (`.claude/hooks/session-start.sh`). Five-key frontmatter schema; `common/`
  always loads; `bash/`, `markdown/`, `git/` load on lang-heuristic match.
  This feature **adds a sixth scope** (`reviewer/`) that must NOT load
  session-wide (R23).
- **Seven agent files** at `.claude/agents/specflow/*.md` (flat layout, no
  subdirs), using the B1 D10 six-block core template. `qa-analyst.md` is the
  closest-fit reference (verification role, sonnet, short core + appendix).
  This feature **adds three sibling files** (`reviewer-security.md`,
  `reviewer-performance.md`, `reviewer-style.md`).
- **`/specflow:implement`** is a wave-based parallel orchestrator; today's
  per-wave loop is: spawn developers → collect commits → `git merge --no-ff`
  per task → STATUS update. This feature **injects an inline review step
  between "collect commits" and "merge"** (R1, R4).
- **`test/smoke.sh`** harness with ~33 assertions; each new AC that shell-checks
  becomes one line there (R28).

### Hard constraints
- **macOS bash 3.2 + BSD userland floor.** The only new shell code is the
  SessionStart skip patch (D7); follow `shell-portability-readlink` and
  `.claude/rules/bash/bash-32-portability.md`.
- **No new runtime dependency.** No Python, Node, jq, or homebrew add.
  Python 3 is already allowed for JSON nits (B1 D12), but we do not need
  it for this feature — pure markdown parsing suffices (see D1).
- **Token-cost ceiling.** 5-wide wave × 3 reviewers = 15 concurrent
  subagent calls per wave. Per-reviewer context = task diff + rubric + PRD
  requirement lines only. No whole-repo handoff.
- **Wave-merge critical-path latency.** Reviewers run in parallel; wall-clock
  is dominated by the slowest Sonnet reviewer (~30s). Acceptable: a wave
  that previously merged "instantly" now gates on one Sonnet call.
- **`/specflow:review` never advances STATUS.** Report-only; exit code
  signals verdict, no checkbox mutation (R11, R13).

### Soft preferences
- **Pure markdown verdict wire format** (D1). JSON-in-codefence was
  considered and rejected; markdown with `key: value` lines parses with
  awk/grep and is human-readable in the saved report.
- **Single aggregator in bash** (D2/D3) — no Python helper. The aggregation
  logic is "max severity across N findings", trivially expressible in a
  `while read | case` loop.
- **Flat reviewer layout** matches existing agent convention; appendix files
  deferred unless a rubric cross-reference needs more than a line or two
  (none expected at v1 — rubrics live in `.claude/rules/reviewer/`, not in
  appendix pages).

### Forward constraints
- **Schema extension must stay narrow.** R22 adds `reviewer` as a scope
  enum value; the README's layout table grows one row; the authoring
  checklist bullet covers the new value. No other schema change.
- **Reviewer rubric = content, not prompt.** Agent prompts cite the rubric
  file location; they do not restate rubric entries (B1 R14 — no duplication
  between rules and agent files).
- **One-shot command shape must match other specflow commands.**
  `.claude/commands/specflow/review.md` uses the same frontmatter +
  Steps/Failures/Rules sections as the rest of `commands/specflow/`.

---

## 2. System Architecture

### Components

```
/specflow:implement <slug>                              /specflow:review <slug> [--axis X]
          |                                                    |
          v (per-wave loop)                                    v
+----------------------------+                     +-----------------------------+
| orchestrator               |                     | orchestrator                |
|  - spawn developers        |                     |  - resolve diff basis:      |
|  - collect commits         |                     |     main...<slug>           |
|  - INLINE REVIEW step      |                     |  - spawn 1 or 3 reviewers   |
|    (NEW — R1..R7)          |                     |  - aggregate verdicts       |
|  - merge / STATUS          |                     |  - write review-TS.md       |
+--------------+-------------+                     +--------------+--------------+
               |                                                  |
               | spawn 3 × N tasks subagents                      | spawn 3 (or 1)
               v (one message, N*3 Agent calls)                   v
   +----------------------------------+              +---------------------------+
   | reviewer-security                |              | reviewer-security         |
   | reviewer-performance             |              | reviewer-performance      |
   | reviewer-style                   |              | reviewer-style            |
   | (sonnet; load own rubric)        |              | (same, whole-feature diff)|
   +------------------+---------------+              +-------------+-------------+
                      |                                            |
                      | read                                       | read
                      v                                            v
      +-------------------------------+              +------------------------------+
      | .claude/rules/reviewer/       |              | same rubric files             |
      |   security.md                 |              +------------------------------+
      |   performance.md              |
      |   style.md                    |
      +------------------+------------+
                         |
                         | NOT loaded by SessionStart
                         | (R23 skip-list entry)
                         v
                 .claude/hooks/session-start.sh
                   lang_heuristic walks common/ + matched lang subdirs
                   SKIP_SUBDIRS="reviewer"  ← D7
```

### Data flow — key PRD scenarios

**Scenario A: wave-merge inline review (R1–R7, AC-inline-review-fires,
AC-block-on-must, AC-retry-reruns-all, AC-advisory-logs).**
1. `/specflow:implement` completes a wave; developers return task commits
   on `<slug>-T<n>` branches (merge has NOT yet occurred).
2. Orchestrator invokes, in a single message, `3 × N` reviewer subagents
   (3 axes × N tasks) with Agent tool calls — all parallel.
3. Each reviewer receives: `git diff <slug>...<slug>-T<n>` text, its axis
   slug, the PRD R-ids linked to the task (read from `06-tasks.md`), and
   its role team-memory block.
4. Each reviewer reads its own rubric (`.claude/rules/reviewer/<axis>.md`)
   per R15 and returns a **verdict block** (D1) at the end of its markdown
   reply.
5. Orchestrator collects all `3 × N` verdict blocks, parses them (D2), and
   classifies:
   - If any finding has `severity: must` → wave is BLOCKED; do NOT run the
     `git merge --no-ff` loop. Surface per-task findings, halt.
   - Else if any `NITS` → merge proceeds; merge commit body appends
     `## Reviewer notes` section per R6.
   - Else all `PASS` → merge proceeds silently.
6. Retry path: developer re-runs the flagged task; orchestrator re-spawns
   **all 3 reviewers** on the new commit (R5). Loop to step 5.

**Scenario B: `/specflow:review <slug>` one-shot (R8–R13, AC-review-*).**
1. User invokes `/specflow:review <slug>` or `/specflow:review <slug> --axis security`.
2. Orchestrator resolves the feature dir (in-flight under
   `.spec-workflow/features/<slug>/` or archived under
   `.spec-workflow/archive/<slug>/`), resolves diff basis as `main...<slug>`
   (or feature's archived commit range for archived features).
3. Orchestrator spawns 3 (or 1) reviewer subagents in parallel; each
   receives the whole-feature diff, its rubric, and the feature's `03-prd.md`.
4. On return, orchestrator writes
   `<feature-dir>/review-YYYY-MM-DD-HHMM.md` (or `-HHMMSS.md` on
   within-minute collision per PRD §6 edge case) containing per-axis
   sections + a `## Consolidated verdict` block (D3).
5. Orchestrator exits non-zero iff any reviewer returned `BLOCK` (R13).
6. STATUS Notes appends one diagnostic line; no checkbox advances.

**Scenario C: SessionStart hook skip (R23, AC-reviewer-not-in-digest).**
1. Claude Code opens a session; SessionStart hook runs.
2. Hook walks `common/` always; if lang-heuristic fires, walks `bash/`,
   `markdown/`, `git/`.
3. With D7 patch: hook maintains `SKIP_SUBDIRS="reviewer"` and treats
   `reviewer/` as never-walked regardless of heuristic. Digest output
   contains zero references to files under `.claude/rules/reviewer/`.
4. Reviewer agents, when invoked later, read their rubric files directly
   per R15 — that content only enters context inside reviewer subagent
   scope, never session-wide.

### Module boundaries

- **New agent files** (prompt data, read by Claude Code when agent invoked):
  - `.claude/agents/specflow/reviewer-security.md`
  - `.claude/agents/specflow/reviewer-performance.md`
  - `.claude/agents/specflow/reviewer-style.md`
- **New rubric files** (data, read by reviewer agents themselves):
  - `.claude/rules/reviewer/security.md`
  - `.claude/rules/reviewer/performance.md`
  - `.claude/rules/reviewer/style.md`
- **Edited orchestration prompt**: `.claude/commands/specflow/implement.md`
  grows an inline-review step (R1–R7) between steps 5 and 6 in the current
  per-wave loop. `--skip-inline-review` flag added to frontmatter usage.
- **New command prompt**: `.claude/commands/specflow/review.md` (R8–R13).
- **Edited hook**: `.claude/hooks/session-start.sh` — one diff hunk adding
  a skip-list check inside the walk (D7).
- **Edited schema doc**: `.claude/rules/README.md` scope enum gains
  `reviewer` (R22).
- **Tests**: `test/t34_reviewer_agents.sh`, `test/t35_reviewer_rubrics.sh`,
  `test/t36_inline_review_integration.sh`, `test/t37_review_oneshot.sh`,
  `test/t38_hook_skips_reviewer.sh`, wired into `smoke.sh` per R28.

---

## 3. Technology Decisions

### D1. Reviewer verdict wire format — markdown with `key: value` footer
- **Options considered**: (A) JSON fenced codeblock in markdown reply,
  (B) pure-markdown `key: value` footer section, (C) XML-ish structured
  tags, (D) external JSON file written by each reviewer.
- **Chosen**: **B. pure-markdown footer**. Each reviewer ends its reply
  with a canonical fenced section:
  ```
  ## Reviewer verdict
  axis: security
  verdict: BLOCK
  findings:
    - severity: must
      file: bin/claude-symlink
      line: 42
      rule: path-traversal
      message: hardcoded /tmp path bypasses boundary check
    - severity: should
      file: test/t6_classify_target.sh
      line: 17
      rule: sandbox-home
      message: HOME preflight assertion missing
  ```
- **Why**: parseable by `awk` / `grep` without a JSON engine; readable
  verbatim in the saved `review-TS.md` report so humans see the same
  text the orchestrator parses; avoids the "JSON codeblock got wrapped
  in backticks by the model" class of failure that bit other tools.
  `key: value` is already the shape of rule/memory frontmatter — one
  less convention to learn.
- **Tradeoffs accepted**: freer-form than JSON; one missing colon can
  confuse the parser. Mitigated by D2's tolerant parser (skip malformed
  finding entries with a stderr diagnostic; the orchestrator's aggregate
  classifier treats "unparseable reviewer output" as BLOCK per §4
  reviewer-timeout posture — fail loud, not silent).
- **Reversibility**: **high** — swap-in a JSON format later requires
  only the parser and the agent prompt (`Output contract` block) to
  change; call sites are unaffected.
- **Requirement link**: R3, R9.

### D2. Inline-review aggregator — pure-bash classifier, dispatched table
- **Options considered**: (A) pure-bash parser + case dispatch, (B) Python
  helper in `bin/specflow-review-aggregate`, (C) inline one-shot invocation
  of `python3 -c`.
- **Chosen**: **A. pure-bash**, living inside `.claude/commands/specflow/implement.md`
  as prompt pseudocode (orchestrator executes via Bash tool).
- **Why**: the aggregate is "max severity across N findings per task;
  max across tasks per wave" — two nested `while read | case` loops, no
  JSON required (D1 gives us `key: value` lines). Applies
  `classification-before-mutation`: the aggregator is a pure classifier
  that emits one of `wave:BLOCK | wave:NITS | wave:PASS` on stdout;
  mutation (merge or halt) lives in the dispatch arm below it, never
  inside the classifier.
- **Tradeoffs accepted**: bash parsing is brittle if reviewer output
  drifts. Mitigated by the contract test (R24) asserting exact
  footer shape, and by the tolerant-but-loud fallback (malformed
  output → treat as BLOCK, stderr diagnostic).
- **Reversibility**: **medium** — moving to Python later means
  rewriting one block inside `implement.md`; call sites unchanged.
  Not a structural lock-in.
- **Requirement link**: R4, R5.

### D3. `/specflow:review` aggregator — same shape as D2, different dispatch
- **Options considered**: (A) share D2's aggregator code via a `scripts/`
  helper, (B) inline duplicate in `review.md`.
- **Chosen**: **B. inline duplicate** in `.claude/commands/specflow/review.md`.
  The two aggregators share a classifier shape but differ in their
  mutation dispatch: D2 gates a `git merge`, D3 writes a report file and
  sets exit code.
- **Why**: duplicating ~20 lines of shell is cheaper than creating a
  `scripts/` helper whose lifecycle must be documented and versioned.
  `script-location-convention` memory reminds us `scripts/` is for
  dev-time helpers, not prompt-internal subroutines. Both aggregators
  live inside command markdown; if they ever diverge more than cosmetically,
  promote one to `scripts/specflow-review-aggregate` with a shared
  contract.
- **Tradeoffs accepted**: two edit sites if the verdict format ever
  changes. Acceptable — D1 is designed to be stable.
- **Reversibility**: **high** — promote-to-helper is a local refactor.
- **Requirement link**: R9, R10, R13.

### D4. Reviewer stay-in-lane enforcement — prompt literal + rubric boundary
- **Options considered**: (A) prompt-level literal instruction in each
  reviewer core file, (B) rubric-level scoping preamble, (C) orchestrator-
  side post-filter that drops out-of-axis findings, (D) trust the model.
- **Chosen**: **A + B combined**. Each reviewer core file contains the
  canonical stay-in-lane sentence (grep-checkable per R17 / AC-stay-in-your-lane):
  *"Comment only on findings against your axis rubric. Do not flag issues
  outside your axis even if you notice them — the other reviewers cover
  those axes."* Each rubric file's `## How to apply` reiterates the axis
  boundary.
- **Why**: prompt-level literal is the checkable surface (grep-testable);
  rubric-level reiteration is the craft surface (the reviewer reads the
  rubric at invocation time per R15, so the reminder is adjacent to the
  rule list). Orchestrator-side filter (C) was rejected — it would need
  axis taxonomy for every rule, which duplicates the rubric.
- **Tradeoffs accepted**: the model may still occasionally leak an
  out-of-axis finding; this is a soft constraint, not a hard gate. v1
  is the first real datapoint; if leakage becomes a pattern, we add
  orchestrator-side post-filter as a follow-up decision.
- **Reversibility**: **high**.
- **Requirement link**: R17.

### D5. Reviewer subagent inputs — task-local for inline, feature-wide for one-shot
- **Options considered**: (A) reviewer receives whole repo always,
  (B) task-local for inline, feature-wide for one-shot, (C) always
  feature-wide, (D) always task-local.
- **Chosen**: **B**.
  - Inline (R2): `git diff <slug>...<slug>-T<n>` — only the task's
    commit range, nothing else from the repo beyond what the reviewer
    chooses to `Read` for context.
  - One-shot (R9): `git diff main...<slug>` — the whole feature diff,
    not chunked. Reviewer may chunk its own reading if the diff is
    large.
- **Why**: task-local keeps inline-review token cost bounded for the
  5-wide × 3-reviewer worst case; feature-wide for one-shot matches the
  "supplemental audit before gap-check" use case where cross-task drift
  is a legitimate finding.
- **Tradeoffs accepted**: one-shot reviewer on a large feature may hit
  context limits. Sonnet 1M is well above any single-feature diff we
  ship (B1 was ~1800 lines); no chunking logic in v1.
- **Reversibility**: **high** — diff basis is a one-line change in each
  command prompt.
- **Requirement link**: R2, R9.

### D6. Retry re-runs all 3 reviewers — not just the one that flagged
- **Options considered**: (A) only the flagging reviewer re-runs,
  (B) all 3 re-run every retry, (C) orchestrator decides based on what
  files the retry touched.
- **Chosen**: **B. all 3 re-run**, per PRD R5.
- **Why**: simpler contract (user doesn't memorize which reviewer was
  the flagger), catches the "fix security, break style" race PRD §6
  edge-case #2 calls out. The token cost of re-running 3 vs 1 on retry
  is trivial compared to the first-pass wave cost. Applies
  `classification-before-mutation` at the retry boundary: classify the
  new state with the same full classifier, don't take shortcuts based
  on prior state.
- **Tradeoffs accepted**: ~3× retry token cost vs option A. Acceptable.
- **Reversibility**: **high**.
- **Requirement link**: R5.

### D7. SessionStart hook skip — `SKIP_SUBDIRS="reviewer"` guard inside walk
- **Options considered**: (A) filter `lang_heuristic` output to exclude
  reviewer, (B) pre-filter the `WALK_DIRS` list before the loop, (C)
  early-`continue` inside the walk loop on reviewer match, (D) move
  rubrics outside `.claude/rules/` entirely.
- **Chosen**: **C. early-`continue` inside the walk loop**, implemented
  as a `SKIP_SUBDIRS` variable checked against each subdir name at the
  top of the loop body.
- **Why**: minimal-diff — the existing hook has a single `while IFS= read
  -r subdir; do … done` loop; we prepend a check. The filter-at-source
  option (A) would need to live inside `lang_heuristic` but that function
  today emits only `bash/markdown/git` (none of which is `reviewer`);
  putting the skip there hides intent from future readers who add new
  languages. Option D (move rubrics out of `.claude/rules/`) fights the
  scope-extension grain — PRD R22 explicitly adds `reviewer` as a scope
  value; we honor that and filter at load.
- **Tradeoffs accepted**: one extra `case` statement per loop iteration.
  Negligible.
- **Reversibility**: **high** — remove the guard, reviewer subdir loads
  normally.
- **Why hook stays fail-safe**: the guard is a pure string check; it
  cannot fail in a way that breaks the existing `set +e` / `trap 'exit 0'`
  posture. See `hook-fail-safe-pattern` memory.
- **Requirement link**: R23.

### D8. Model tier — Sonnet for all 3 reviewers
- **Options considered**: (A) Sonnet all, (B) Opus for security (highest-
  stakes axis) + Sonnet for performance/style, (C) Opus all.
- **Chosen**: **A. Sonnet all**, per PRD R16 and brainstorm Q5.
- **Why**: reviewers are verification roles (same tier as QA-analyst and
  developer). Cost of 15 parallel Opus calls per wave is prohibitive;
  Sonnet handles rubric-driven diff review competently. Latency: Sonnet
  ~30s beats Opus ~90s on the wave-merge critical path.
- **Tradeoffs accepted**: if a security finding needs architectural
  judgment (rare for rubric-driven axes), Sonnet may underfire. Revisit
  only if real-world use shows this.
- **Reversibility**: **high** — single frontmatter edit per agent.
- **Requirement link**: R16.

### D9. Reviewer agent layout — flat, matches existing convention
- **Options considered**: (A) flat `reviewer-<axis>.md` files in
  `.claude/agents/specflow/`, (B) nested `.claude/agents/specflow/reviewer/<axis>.md`,
  (C) reviewer as a role subdir alongside `specflow/` at `.claude/agents/reviewer/`.
- **Chosen**: **A. flat**, per PRD R14 and brainstorm Q6.
- **Why**: consistency with the 7 existing agent files; subagent
  resolution reads the flat file list; filename prefix `reviewer-`
  provides alphabetical grouping without a subdir. If reviewer count
  ever exceeds 6–8, reconsider.
- **Tradeoffs accepted**: none — pure convention alignment.
- **Reversibility**: **high**.
- **Requirement link**: R14.

### D10. Report filename timestamp — minute-level default, seconds fallback on collision
- **Options considered**: (A) `review-YYYY-MM-DD.md` day-granular (clobber
  risk on same-day runs), (B) `review-YYYY-MM-DD-HHMM.md` minute-granular,
  (C) `review-YYYY-MM-DD-HHMMSS.md` seconds always, (D) sequence suffix
  `review-N.md`.
- **Chosen**: **B with C as collision fallback**, per PRD R10 and §6
  edge-case. Orchestrator checks if `review-YYYY-MM-DD-HHMM.md` already
  exists; if so, emits `review-YYYY-MM-DD-HHMMSS.md`. If that also
  collides (same-second, extremely unlikely), append `-<pid>` as a
  final fallback.
- **Why**: minute-granular is human-readable and sorts; seconds fallback
  is the minimal change on the rare collision; `--no-force` discipline
  (never clobber a prior report) applies verbatim.
- **Tradeoffs accepted**: filename format isn't uniform across all runs.
  Acceptable — the rare long filename is a signal that two runs happened
  within the same minute, which is informative.
- **Reversibility**: **high**.
- **Requirement link**: R10.

### D11. Opt-out flag wiring — `--skip-inline-review` parsed in implement.md
- **Options considered**: (A) flag parsed in `implement.md` prompt,
  (B) env var `SPECFLOW_SKIP_INLINE_REVIEW=1`, (C) both.
- **Chosen**: **A. flag only**.
- **Why**: flag is visible in the command invocation and in STATUS Notes
  (R7 requires diagnostic line). An env var hides the skip from casual
  readers of the STATUS file. Keep one mechanism.
- **Tradeoffs accepted**: no way to default-skip across a whole shell
  session. Acceptable — inline review is opt-IN-by-default for a reason.
- **Reversibility**: **high** — add env var later if demand surfaces.
- **Requirement link**: R7.

### D12. Schema extension minimal-diff — one enum value, one table row, one checklist bullet
- **Options considered**: (A) add `reviewer` as a peer of `common|bash|
  markdown|git|<lang>`, (B) introduce a two-level scope taxonomy
  (`session-wide | agent-triggered`) with `reviewer` under the latter.
- **Chosen**: **A. peer value**, per PRD R22.
- **Why**: (B) would be a much larger schema refactor; the SessionStart
  hook's skip-list (D7) is a cheaper way to express "agent-triggered,
  not session-wide" without a taxonomy bifurcation. One-scope-enum
  stays simple.
- **Tradeoffs accepted**: the enum grows by one value every time we
  add an agent-triggered rules sibling (unlikely, but possible).
  Revisit if a second such scope appears.
- **Reversibility**: **medium** — backing out the enum requires editing
  every `reviewer/*.md` frontmatter.
- **Requirement link**: R22.

---

## 4. Cross-cutting Concerns

### Error handling
- **Reviewer fails or times out (PRD §6 edge-case #1)**: orchestrator
  treats a missing or malformed verdict footer as BLOCK. This is the
  fail-loud posture — silent-proceed on reviewer failure is
  indistinguishable from no-reviewer, defeating the feature. User
  either retries (transient) or invokes `--skip-inline-review` (accepted
  cost).
- **Rubric file malformed (PRD §6 edge-case #7)**: reviewer agent
  emits a diagnostic and returns `verdict: PASS`. Conservative: better
  to let the wave proceed with a loud warning than block on our own
  broken rubric. User sees the diagnostic in STATUS Notes.
- **Parser drift on verdict format**: D2's bash parser treats any
  finding entry missing a required key as malformed; emits stderr
  diagnostic; the finding is dropped from aggregation. If the verdict
  line itself is missing, entire reviewer result is treated as BLOCK
  (see above).

### Logging / tracing / metrics
- **Reviewer invocations**: orchestrator logs `YYYY-MM-DD review
  dispatched — slug=<slug> wave=<N> tasks=<T1,T2> axes=<security,performance,style>`
  to STATUS Notes at dispatch time.
- **Per-wave result**: orchestrator logs `YYYY-MM-DD review result
  — wave <N> verdict=<BLOCK|NITS|PASS> blocking-tasks=<…>` after
  aggregation.
- **Per-review report file**: `.spec-workflow/features/<slug>/review-TS.md`
  is the trace artifact for `/specflow:review` runs; archived alongside
  the feature.
- **No metrics system introduced** — STATUS Notes is the audit log
  for this feature, matching the rest of specflow.

### Security / authn / authz
- **No new secrets, no new network calls.** Reviewers read files the
  agent already has Read access to; they do not write outside the
  feature dir. No credentials handled.
- **Rubric files are trusted content**, same trust level as existing
  `.claude/rules/` — they are committed to the repo and reviewed
  through the normal PR path.
- **`--skip-inline-review` is a trust boundary**: the flag allows a
  developer to merge a wave without multi-axis review. STATUS Notes
  makes every use visible in archive; if audit later matters, the log
  is the audit trail.

### Testing strategy
- **Contract-shape tests (R24)**: one test per reviewer agent asserting
  the verdict-footer shape is emitted on a trivial stub invocation
  (D1). Shell-level assertions: footer-header present, `verdict:` line
  with canonical value, zero-or-more `- severity:` list entries with
  required keys. Target files: `test/t34_reviewer_agents.sh`.
- **Rubric file schema tests**: assert `.claude/rules/reviewer/*.md`
  have 5-key frontmatter with `scope: reviewer`, ≥6 checklist entries
  in `## How to apply`, and required body headings in order. Target:
  `test/t35_reviewer_rubrics.sh`.
- **Integration test for inline review (R25)**: sandboxed per
  `sandbox-home-in-tests` rule; fake feature dir, fake task branch
  with one `must` violation, dispatch inline review (via prompt
  simulation or harness), assert aggregate BLOCK, assert no merge,
  assert retry re-runs all 3. Target: `test/t36_inline_review_integration.sh`.
- **One-shot test (R26)**: sandboxed; fake feature, invoke `/specflow:review`,
  assert timestamped report file present with 3 per-axis sections +
  consolidated verdict; second invocation produces second file without
  clobber. Target: `test/t37_review_oneshot.sh`.
- **Hook skip test (R27)**: invoke hook with populated
  `.claude/rules/reviewer/`, grep hook stdout for any mention of
  `reviewer/` — must be zero. Target: `test/t38_hook_skips_reviewer.sh`.
- **Smoke**: wire all new tests into `smoke.sh` (R28). Expected new
  count = 33 + N where N is the number of shell-assertable ACs this
  PRD adds (10 tests: t34..t38 plus stay-in-lane grep, scope-enum grep,
  agent-frontmatter model-sonnet grep, verdict-format contract, and
  skip-flag STATUS-Notes assertion).

### Performance / scale targets
- **Wave-merge wall-clock regression ceiling**: inline review must add
  ≤ slowest-Sonnet-reviewer to the critical path (~30s). Reviewer
  parallelism keeps this from scaling with N tasks in a wave.
- **Token cost per wave**: bounded by `N_tasks × 3 × (diff_size +
  rubric_size + PRD_excerpt_size)`. 5-wide × 3 × ~3k tokens ≈ 45k
  tokens per wave. Acceptable at Sonnet pricing.
- **Hook latency unchanged**: D7 adds one string compare per subdir
  walk iteration; no measurable impact on the < 200ms hook budget
  (B1 R5; cross-referenced in `reviewer/performance.md` rubric entry 7).

---

## 5. Open Questions

**None blocking.** All PRD blockers were resolved in §7 of `03-prd.md`;
all architect-call nice-to-clarify items are answered in D1 / D10 / D5
above.

No deferred blockers. TPM can proceed to `/specflow:plan`.

---

## 6. Non-decisions (deferred)

- **Orchestrator-side out-of-axis finding filter (D4 option C)**.
  Deferred. Trigger: if v1 shipping shows repeated leakage where
  (e.g.) the security reviewer emits style nits, add a post-filter
  that drops findings whose rule slug isn't in the reviewer's rubric.
- **Python aggregator helper (D2 option B)**. Deferred. Trigger: if
  the bash aggregator grows beyond ~30 lines or if the verdict format
  ever moves to JSON, promote to `scripts/specflow-review-aggregate`.
- **Reviewer rubric versioning**. Deferred. Trigger: when a rubric
  edit retroactively changes a past feature's verdict in a way that
  matters (e.g., post-hoc compliance audit). Today rule edits apply
  to subsequent runs only; no version pinning.
- **`--since <commit>` flag for `/specflow:review`**. Deferred per
  PRD §7. Trigger: demand for partial-diff review on long-running
  features.
- **Additional reviewer axes (docs, correctness, architecture)**.
  Deferred per PRD §2 non-goals. Trigger: v1 ships 3; if the 3-axis
  pattern proves durable, add a 4th via a new PRD.
- **Axis-weighting or voting consensus**. Deferred. Trigger: severity-
  gated aggregation proves insufficient in practice (e.g., two reviewers
  split on a single finding's severity more than cosmetically).
- **Reviewer appendix files** (`reviewer-<axis>.appendix.md`). Deferred.
  Trigger: any reviewer core file exceeds ~60 non-empty lines and needs
  overflow per the B1 D10 core+appendix convention.

---

## 7. Acceptance checks architect stands behind

Developer (and TPM when scoping tasks) must demonstrate, at task-completion
or gap-check:

1. **Verdict footer is machine-parseable (D1)**: a synthetic reviewer
   invocation with a one-finding verdict round-trips through the D2
   bash parser and lands in the correct severity bucket. Shell-asserted
   in `test/t34_reviewer_agents.sh`.
2. **Inline review injected in the right place (D2)**: `implement.md`'s
   per-wave loop has the review step strictly between "collect commits"
   and "git merge --no-ff" — confirmed by grep on the command file and
   by the integration test (R25).
3. **BLOCK halts merge, not just logs (R4)**: integration test asserts
   the `git merge --no-ff` call was NOT made while a `must` finding
   was outstanding.
4. **Retry re-runs 3, not 1 (D6)**: integration test asserts 3 reviewer
   invocations on retry, matching `--task T<n>` retry semantics.
5. **Stay-in-lane literal present (D4 / R17)**: grep per reviewer file
   for the canonical sentence returns exactly one match.
6. **Scope enum + SessionStart skip (D7, D12)**: `.claude/rules/README.md`
   contains `reviewer` in the scope enum; hook digest contains zero
   references to files under `reviewer/` when the rubric dir is
   populated.
7. **Report no-clobber (D10)**: two `/specflow:review` invocations in
   the same minute produce two distinct files on disk.
8. **Hook stays fail-safe (D7 / hook-fail-safe memory)**: the patched
   `session-start.sh` still exits 0 on any fault; `trap 'exit 0'`,
   `set +e`, and stderr-only diagnostics are all preserved.
9. **Bash 3.2 portability (shell-portability memory)**: the D7 patch
   uses no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no
   `[[ =~ ]]` in portability-critical logic.

---

## 8. Memory candidates flagged for archive retro

Not yet writing — these are candidates the retro should examine after
landing:

- **"Reviewer verdict wire format — pure-markdown `key: value` footer
  beats JSON codefence for agent output"** — new pattern from D1. If
  a second agent-emits-structured-data feature lands and adopts this
  shape, promote to architect memory.
- **"Aggregator-as-classifier — severity max-reduce over multi-axis
  findings"** — specialization of `classification-before-mutation` for
  the verdict-aggregation case. Worth a memory only if a second
  multi-axis feature (e.g., a future docs reviewer addition) reuses
  the shape.
- **"Scope extension minimal-diff — add enum value before taxonomy
  refactor"** — D12's call to resist a two-level scope taxonomy.
  Candidate if a third scope-extension request arrives.
- **"Opt-out flag visibility — require STATUS Notes trace on any
  override that skips a safety step"** — D11 generalizes nicely to
  any future safety-gate bypass flag (R7). Candidate after second
  application.

Retro will decide scope (global vs local) per the
`.claude/team-memory/README.md` protocol.
