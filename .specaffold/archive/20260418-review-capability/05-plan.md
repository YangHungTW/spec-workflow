# Plan — review-capability (B2.b)

_2026-04-18 · TPM_

## Team memory consulted

- `tpm/parallel-safe-requires-different-files.md` — load-bearing for §5. The three reviewer agent files (`reviewer-{security,performance,style}.md`) and the three rubric files (`reviewer/{security,performance,style}.md`) are six distinct files across two dirs → fully parallel-safe in the same wave. The two command edits (`implement.md` vs new `review.md`) are also different files → parallel-safe.
- `tpm/parallel-safe-append-sections.md` — applied to expected append-only collisions on `.claude/rules/README.md` (schema change + directory table row), `.claude/rules/index.md` (3 new rows for rubrics), `test/smoke.sh` (new test registrations), and STATUS Notes. All resolvable via keep-both; do NOT over-serialize the schema-extension wave on these grounds.
- `tpm/checkbox-lost-in-parallel-merge.md` (new, B2.a retro) — this feature will run wide waves (6-way in Wave 2). Orchestrator MUST audit `06-tasks.md` post-merge for silently-dropped checkbox flips and commit a `fix: check off T<n> (lost in merge)` per wave, matching the B1/B2.a precedent. Flagged in §6.
- `tpm/tasks-doc-format-migration.md` — not applicable (no downstream command-contract format change this round).
- `shared/` (both tiers) — empty; nothing to pull.

## 1. Scope summary

This plan delivers the B2.b review-capability feature against the PRD (R-count=28, AC-count=24) and tech doc (D-count=12):
- **(4) Inline per-task review** during `/specflow:implement`'s per-wave loop — 3 reviewer subagents per task run in parallel after developer commits, before `git merge --no-ff`; severity-gated (`must` blocks, `should`/`advisory` log-and-merge).
- **(6) `/specflow:review <slug>`** one-shot command — dispatches 3 reviewers (or 1 under `--axis`) against the full feature-branch diff; writes a timestamped report; never advances STATUS.

Supporting deliverables: 3 reviewer agent files (flat layout, D9), 3 rubric rule files under new `reviewer/` scope (D12), schema extension to `.claude/rules/README.md` (D12), SessionStart hook skip of reviewer subdir (D7), edit to `implement.md` for inline review injection (D2), new `review.md` command (D3), `test/smoke.sh` growth with ≥5 new test scripts (R28), and a dogfood paradox escape (R7 `--skip-inline-review` flag).

This is the final of the six-item harness-upgrade series — B1 shipped items 1–3, B2.a shipped items 5 + 7, B2.b closes items 4 + 6. No B2.c planned.

## 2. Milestones

### M1 — Schema extension + SessionStart hook skip

- **Output**:
  - `.claude/rules/README.md` — scope enum grows from `common | bash | markdown | git | <lang>` to `common | bash | markdown | git | reviewer | <lang>`; directory-layout table gains a `reviewer/` row; authoring-checklist scope-bullet covers the new value.
  - `.claude/hooks/session-start.sh` — D7 patch: `SKIP_SUBDIRS="reviewer"` variable + early-`continue` guard inside the existing walk loop. Pure string check; no change to the fail-safe envelope (`set +e`, trap, unconditional `exit 0`). Bash 3.2 portable (no `[[ =~ ]]`, no `readlink -f`).
  - New empty directory `.claude/rules/reviewer/` with a placeholder `.gitkeep` so later M2 commits can target it cleanly.
- **Requirements covered**: R22, R23.
- **Decisions honored**: D7 (early-continue skip-list), D12 (minimal-diff schema extension — one enum value, one table row, one checklist bullet).
- **Verification signal**: AC-scope-reviewer-added (grep on README.md); AC-reviewer-not-in-digest dry-fires (no rubric files exist yet, but populated-dir test lands in M6/t38); SessionStart hook still exits 0 on all B1 fixtures (no regression).

### M2 — Rubric files × 3 (`.claude/rules/reviewer/{security,performance,style}.md`)

- **Output**: three new rubric files, each with 5-key frontmatter (`scope: reviewer`, matching filename stem, severity per axis posture, created/updated), `## Rule` / `## Why` / `## How to apply` / `## Example` in that order. `## How to apply` contains ≥6 distinct checklist entries drawn verbatim from PRD R18–R20. Each file's individual entry severities track the PRD (mix of `must` / `should`).
  - `security.md` — 8 entries: hardcoded secrets (must), path traversal (must), input validation (must), injection attacks (must), untrusted YAML/JSON parsing (should), secure defaults cross-reference to `no-force-on-user-paths` (must), atomic file writes (should), sentinel-file race conditions (should).
  - `performance.md` — 8 entries: no shell-out in tight loops (must), avoid O(n²) (must), cache expensive operations (should), prefer awk/sed over python3 (should), no re-reading files (should), minimise fork/exec in hot paths (should), hook latency < 200ms (must), avoid eager loads (should).
  - `style.md` — 8 entries: match naming conventions (should), no commented-out code (must), comments explain WHY (should), match neighbour indent/quoting (should), bash 3.2 portability cross-reference (must), sandbox-HOME in tests cross-reference (must), `set -euo pipefail` convention (should), dead imports (should).
  - `.claude/rules/index.md` — append 3 new rows (scope=reviewer), sorted by scope then name per the index's existing convention.
- **Requirements covered**: R18, R19, R20, R21.
- **Decisions honored**: D12 (reviewer scope existence), PRD `## Rule` body-structure convention, no-duplication discipline (cross-reference to existing rules rather than restating — security rubric entry 6 points at `common/no-force-on-user-paths.md`; style rubric entries 5 and 6 point at `bash/bash-32-portability.md` and `bash/sandbox-home-in-tests.md`).
- **Verification signal**: AC-rubric-files-exist (grep + structural checks); R35/t35 rubric-schema test passes.

### M3 — Reviewer agent files × 3 (`.claude/agents/specflow/reviewer-{security,performance,style}.md`)

- **Output**: three new agent files in flat layout (D9), each using the B1 D10 six-block core template (`qa-analyst.md` is the reference shape):
  1. YAML frontmatter: `name: reviewer-<axis>`, `model: sonnet` (D8), `description`, `tools`.
  2. Role identity line.
  3. `## Team memory` invocation block — standard shape (`ls ~/.claude/team-memory/<role>/` + `none apply because <reason>` phrases) — plus an explicit extension per R15: agent MUST also read `.claude/rules/reviewer/<axis>.md` before acting.
  4. `## When invoked for /specflow:implement` (inline review) and `## When invoked for /specflow:review` (one-shot) sections, per R1–R2 / R8–R9.
  5. `## Output contract` — canonical verdict-footer shape per D1 (`## Reviewer verdict` header, `axis: …` / `verdict: PASS|NITS|BLOCK` / `findings: …` with `severity`/`file`/`line`/`rule`/`message` keys per finding).
  6. `## Rules` — the literal stay-in-lane sentence (R17 / AC-stay-in-your-lane): "Comment only on findings against your axis rubric. Do not flag issues outside your axis even if you notice them — the other reviewers cover those axes."
- **Requirements covered**: R14, R15, R16, R17.
- **Decisions honored**: D1 (markdown footer output contract, not JSON), D4 (stay-in-lane literal, grep-checkable), D5 (inline vs one-shot input contract spelled out in the two when-invoked sections), D8 (Sonnet), D9 (flat layout).
- **Verification signal**: AC-reviewer-agents-exist, AC-stay-in-your-lane, AC-verdict-shape (via M6 unit tests).

### M4 — `/specflow:implement` inline-review injection

- **Output**: single-file edit to `.claude/commands/specflow/implement.md`:
  1. New step between "collect wave commits" and "`git merge --no-ff` per task" implementing the D2 pure-bash aggregator. Reviewer dispatch is ONE orchestrator message with `3 × N_tasks` Agent tool calls (all parallel). Aggregator parses D1 verdict footers (D2 bash `while read | case`), classifies the wave into `BLOCK | NITS | PASS` (pure classifier per `classify-before-mutate` rule); dispatch arm routes to halt-merge / merge-with-notes / merge-silent.
  2. Retry semantics (R5 / D6): when developer re-runs a flagged task, orchestrator re-invokes ALL 3 reviewers on the new commit, not just the flagger.
  3. NITS notes surface in the wave merge commit body per R6 — `## Reviewer notes` section, one line per finding grouped by task.
  4. `--skip-inline-review` flag (R7 / D11): frontmatter usage line documents the flag; when set, skips reviewer dispatch entirely and emits a diagnostic line to STATUS Notes (`YYYY-MM-DD implement — skip-inline-review flag USED for wave <N>`).
  5. Error posture per tech-doc §4: missing/malformed verdict footer → treat as BLOCK (fail-loud); rubric file malformed → reviewer returns PASS with diagnostic (fail-safe per agent contract).
- **Requirements covered**: R1, R2, R3, R4, R5, R6, R7.
- **Decisions honored**: D1 (verdict wire format), D2 (pure-bash classifier), D6 (retry re-runs all 3), D11 (flag-only opt-out, no env var).
- **Verification signal**: AC-inline-review-fires, AC-block-on-must, AC-retry-reruns-all, AC-advisory-logs, AC-skip-flag-works (via M6 integration test t36).

### M5 — `/specflow:review` one-shot command (`.claude/commands/specflow/review.md`)

- **Output**: new slash command file following the shape of other specflow commands (frontmatter `description`, ordered `## Steps`, `## Failures`, `## Rules` sections). Per R8–R13:
  1. Frontmatter + `description: multi-axis review of a feature branch diff (security / performance / style); writes a timestamped report; never advances STATUS`.
  2. Steps: resolve feature dir (in-flight under `.spec-workflow/features/<slug>/` or archived under `.spec-workflow/archive/<slug>/`); resolve diff basis as `main...<slug>` (handles archived features via `git log` commit-range); dispatch 3 (or 1 under `--axis`) reviewer subagents in parallel; aggregate verdicts via D3 aggregator (inline duplicate of D2 shape — different dispatch: file-write + exit code instead of merge-gate).
  3. Report path: `<feature-dir>/review-YYYY-MM-DD-HHMM.md` with D10 seconds-collision fallback (`-HHMMSS.md`) and `-<pid>` final fallback on same-second collision. Report body has per-axis sections + `## Consolidated verdict` block.
  4. `--axis <security|performance|style>` flag (R12): single-axis mode writes same-shape report with only the named section.
  5. Exit code (R13): non-zero iff any reviewer returned BLOCK. Informational only — never auto-gates any stage.
  6. STATUS Notes (R11): one line per invocation (`YYYY-MM-DD review — <slug> axis=<all|…> verdict=<…>`); no checkbox mutation.
- **Requirements covered**: R8, R9, R10, R11, R12, R13.
- **Decisions honored**: D1 (wire format), D3 (inline-duplicate aggregator), D5 (feature-wide diff for one-shot), D10 (minute-granular filename + seconds/pid fallback).
- **Verification signal**: AC-review-command-exists, AC-review-command-parallel, AC-review-report-written, AC-review-no-clobber, AC-review-no-stage-advance, AC-review-axis-flag, AC-review-exit-code (via M6 one-shot test t37).

### M6 — Test harness (5 new scripts + smoke integration prep)

- **Output**: 5 new `test/t{34..38}_*.sh` scripts per tech-doc §4 testing table, each honoring the `sandbox-home-in-tests` rule (mktemp sandbox, `HOME=$SANDBOX/home`, preflight assert):
  - `t34_reviewer_agents.sh` — per-reviewer contract-shape unit test. Stubs an invocation with a pre-made diff and stub rubric; asserts verdict-footer shape (header present, `verdict:` line with canonical value, zero-or-more `- severity:` entries with required keys). Covers R24 / AC-verdict-shape.
  - `t35_reviewer_rubrics.sh` — rubric-file schema test. Asserts all 3 files have 5-key frontmatter with `scope: reviewer`, ≥6 checklist entries in `## How to apply`, required body headings in order. Covers R18–R21 / AC-rubric-files-exist.
  - `t36_inline_review_integration.sh` — inline-review sandbox integration test. Fake feature dir + fake task branch with one intentional `must`-severity violation; dispatches inline-review logic; asserts aggregate BLOCK, `git merge --no-ff` NOT called, retry with fix re-invokes all 3 reviewers, merge then proceeds. Covers R25 / AC-integration-block-and-retry + AC-block-on-must + AC-retry-reruns-all + AC-advisory-logs via sub-case with NITS. Also covers AC-skip-flag-works via a sub-case invoking the flag.
  - `t37_review_oneshot.sh` — one-shot command sandbox test. Fake feature dir with pre-made diff; invokes `/specflow:review`; asserts timestamped report present with 3 per-axis sections + consolidated verdict; second invocation produces distinct second file (no clobber); `--axis security` sub-case asserts single-section report; exit-code sub-case asserts non-zero on BLOCK. Covers R26 / AC-review-*.
  - `t38_hook_skips_reviewer.sh` — SessionStart hook skip verification. Invokes hook against sandbox with populated `.claude/rules/reviewer/` (using M2 rubric fixtures); greps hook stdout for any mention of `reviewer/`; asserts zero matches. Covers R27 / AC-reviewer-not-in-digest.
- **Requirements covered**: R24, R25, R26, R27.
- **Decisions honored**: D1/D2/D3 (verdict-format and aggregator contracts tested), D7 (hook skip tested), sandbox-HOME rule enforced.
- **Verification signal**: each `test/tNN_*.sh` exits 0 standalone; smoke registration happens in M7.

### M7 — Smoke.sh integration + README note + dogfood diagnostic

- **Output**:
  - `test/smoke.sh` grows from 33 to 33 + new-assertions registrations (t34 + t35 + t36 + t37 + t38 plus any inline grep-assertables like stay-in-lane-literal, scope-enum, model-sonnet frontmatter, skip-flag STATUS-Notes trace — target ≥38 total, exact count set by Developer when wiring).
  - Top-level `README.md` (or the in-repo doc that documents the harness) gains a short paragraph: multi-axis review is now an inline step of `/specflow:implement` and a one-shot `/specflow:review <slug>` command; rubrics live under `.claude/rules/reviewer/`; `--skip-inline-review` is the emergency escape.
  - STATUS Notes entry documenting the dogfood paradox: this feature's own `/specflow:implement` runs under `--skip-inline-review` (bootstrapping — inline review cannot review its own landing). First real use of inline review is the next feature after B2.b.
- **Requirements covered**: R28, AC-smoke-green, AC-no-regression, dogfood paradox documentation (PRD §6 edge case #5).
- **Decisions honored**: D6/D7 testing-strategy sign-off; B1/B2.a 33-test floor preserved.
- **Verification signal**: `bash test/smoke.sh` → PASS N/N (N ≥ 38); B1 and B2.a ACs still green; manual read of README confirms dogfood-paradox note.

**Milestone count: 7** (M1–M7).

## 3. Cross-cutting concerns

- **Sandbox-HOME discipline** — every M6 test (and any smoke-suite growth in M7) MUST begin with the `mktemp -d` sandbox + `HOME=$SANDBOX/home` + case-pattern preflight per `.claude/rules/bash/sandbox-home-in-tests.md`. Non-negotiable. Any test that invokes a CLI expanding `$HOME` without the sandbox preflight is a flake-and-damage risk on the contributor's real `~/.claude/`. See also B2.a retro — this held for 33-test smoke and must hold for the new additions.
- **Don't regress existing smoke (33/33 from B1 + B2.a)** — every milestone in this plan MUST preserve the existing smoke count. The M1 SessionStart hook patch is the most at-risk change; t38 (new) asserts the skip works, but the B1 hook-happy-path and hook-failsafe tests (t17, t18) must continue to pass unchanged. QA-analyst at gap-check explicitly audits the B1/B2.a AC set still holds (AC-no-regression / PRD R24 of this feature).
- **Dogfood paradox** — this feature's own `/specflow:implement` runs CANNOT use inline review (the reviewers and their rubrics are landing in this feature's waves). The escape hatch is R7's `--skip-inline-review` flag. **Every `/specflow:implement` invocation against THIS feature's task set MUST include `--skip-inline-review`** — documented in M7's STATUS Notes diagnostic and called out again in §6 risks. Same shape as B2.a's Stop-hook bootstrap paradox.
- **Checkbox audit post-merge (tpm/checkbox-lost-in-parallel-merge.md)** — this feature's Wave 2 is 6-way parallel (see §5). Based on the B1 (7-way lost T4/T15) and B2.a (7-way lost T1/T2) precedents, checkbox drops during the merge of Wave 2 are predictable. Orchestrator MUST run `grep -c '^- \[x\]' 06-tasks.md` after the Wave 2 merge and commit a `fix: check off T<n> (lost in merge)` if short. Apply uniformly to every multi-task wave.
- **Token cost ceiling** — inline review adds `3 × N_tasks × (diff + rubric + PRD-excerpt)` to every wave. Worst case 5-wide wave × 3 reviewers = 15 concurrent Sonnet calls, ~45k tokens per wave (tech-doc §4 performance target). Acceptable at Sonnet pricing; escape hatch is `--skip-inline-review` for emergencies. Reviewer context is task-local per D5/R2 — NEVER pass the whole repo or whole feature diff to the inline reviewer; only `git diff <slug>...<slug>-T<n>`.
- **LLM reviewer flakiness** — Sonnet can emit a non-canonical verdict footer. D2's tolerant-but-loud parser handles: malformed finding entry → drop with stderr diagnostic; missing/malformed footer → treat entire reviewer result as BLOCK (fail-loud posture per tech-doc §4). This is the explicit contract — silent-proceed on reviewer failure defeats the feature.
- **Stay-in-lane enforcement is soft** — D4 combines prompt-literal (grep-checkable) + rubric-level reiteration + (if needed later) orchestrator-side post-filter. v1 ships prompt + rubric; orchestrator filter deferred per tech-doc §6. Watch item at gap-check: if reviewers are frequently emitting out-of-axis findings, flag for a B3 follow-up.
- **Bash 3.2 portability** — the M1 hook patch (D7) is the only new bash in this feature; follow `.claude/rules/bash/bash-32-portability.md` (no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` in portability-critical logic). M4/M5 aggregators (D2/D3) live inside command markdown and execute via the Bash tool — same portability floor applies to the pseudocode.
- **No-force discipline on reports (D10 / PRD §6)** — `/specflow:review` MUST NEVER clobber a prior report file. D10 spec: minute-granular default, seconds fallback on collision, pid fallback on same-second collision. M5 acceptance includes AC-review-no-clobber verification.

## 4. Dependencies & sequencing

```
M1 (schema + hook skip)
  ├──→ M2 (rubric files × 3)  ──┐
  └──→ M3 (agent files × 3)  ───┤
                                ├──→ M4 (implement.md inline injection)  ──┐
                                └──→ M5 (review.md one-shot command)  ─────┤
                                                                           ├──→ M6 (tests t34–t38)  ──→ M7 (smoke + README + dogfood note)
```

**Key edges:**
- **M1 before M2** — the schema must admit `scope: reviewer` before any rubric file can reference it without a schema-check failure.
- **M1 before M3** — agent files reference rubric locations under `reviewer/`; M1's hook-skip must exist before M3 lands to prevent the short window where rubrics would session-load.
- **M2 and M3 parallel-safe** — six distinct files across two dirs. Different files, no textual conflict.
- **M2/M3 before M4/M5** — both commands reference the rubrics by path and dispatch the reviewer agents by name; the referenced files must exist before the command prompts are authored.
- **M4 and M5 parallel-safe** — different command files (`implement.md` vs new `review.md`).
- **M6 after M1–M5** — integration test t36 exercises inline review end-to-end (needs M4); one-shot test t37 exercises `/specflow:review` end-to-end (needs M5); unit test t34 needs M3 agents; schema test t35 needs M2 rubrics; hook-skip test t38 needs M1 + M2 (populated `reviewer/` subdir).
- **M7 last** — smoke registration, README note, and dogfood diagnostic are all gated on everything above being green.

## 5. Wave schedule hints for TPM task-breakdown stage

Advisory input for `/specflow:tasks`; actual wave schedule is set then. Target 12–18 tasks across 5 waves. Per-milestone task profiles:

- **M1** — 2 tasks: (a) schema extension edit to `.claude/rules/README.md` + `.gitkeep` in `reviewer/`; (b) SessionStart hook D7 patch to `.claude/hooks/session-start.sh`. Different files → parallel-safe with each other.
- **M2** — 3 tasks, one per rubric file (`security.md`, `performance.md`, `style.md`). Different files → parallel-safe across the set. The `.claude/rules/index.md` row-append is handled at the end of each task (expected append-only collision per `tpm/parallel-safe-append-sections.md` — keep-both resolution).
- **M3** — 3 tasks, one per reviewer agent file. Different files → parallel-safe across the set.
- **M4** — 1 task (single file edit, multi-site — do NOT split across sites per `tpm/parallel-safe-requires-different-files.md`: all sites are in the same file, splitting forces serialization for no gain).
- **M5** — 1 task (new file, self-contained).
- **M6** — 5 tasks, one per test file. Different files → fully parallel-safe across the set. Smoke registration is deferred to M7 to avoid 5-way smoke.sh append collision (per B2.a's M4 recommendation: single-editor for smoke.sh).
- **M7** — 1 task (smoke.sh registrations + README note + STATUS Notes dogfood diagnostic). Bundled per the B2.a precedent — small cross-file edits logically tied to release readiness; parallelism gain negligible.

**Recommended wave shape at `/specflow:tasks` time:**
- **Wave 1 (2 parallel)**: M1 schema-extension task + M1 hook-skip task. 2 different files.
- **Wave 2 (6 parallel)**: M2 × 3 rubrics + M3 × 3 agent files. All 6 files distinct across two dirs. Expected checkbox-audit fix-up after merge per §3.
- **Wave 3 (2 parallel)**: M4 implement.md edit + M5 review.md new file. 2 different files.
- **Wave 4 (5 parallel)**: M6 × 5 test files. All distinct.
- **Wave 5 (1 serial)**: M7 bundle (smoke.sh + README + STATUS notes).

**Total: 15 tasks across 5 waves**, within the 12–18 target.

**Expected append-only collisions (per `parallel-safe-append-sections.md`)** — do NOT over-serialize on these:
- `.claude/rules/index.md`: M2's 3 tasks each append one row → mechanical keep-both.
- `test/smoke.sh`: M6 tasks do NOT touch smoke.sh; M7 is the sole registrar. Zero collision.
- `STATUS.md` Notes: every task appends. Standard keep-both.
- `06-tasks.md` checkboxes: wave-2 6-way merge WILL lose checkbox flips per the `tpm/checkbox-lost-in-parallel-merge.md` precedent. Orchestrator MUST run post-merge audit and commit fix-up — predictable, automate-able.

## 6. Risks / watch-items

- **Dogfood paradox for THIS feature** — B2.b lands the inline-review capability; that capability cannot review its own landing. Every `/specflow:implement` run against this feature's tasks MUST include `--skip-inline-review` (R7). If an implementer forgets the flag, the implement loop will attempt to dispatch reviewer subagents that haven't been authored yet → the fail-loud posture of D2's parser (missing/malformed footer = BLOCK) correctly halts the wave; recovery is to add the flag. Document in M7 STATUS Notes diagnostic; first real use of inline review is the next feature after B2.b.
- **SessionStart hook skip (D7 / M1) risks regressing the existing 33/33 B1+B2.a smoke suite** — the hook patch is a one-line change but touches the canary hook that all B1 tests assert against. Mitigation: M1's hook-skip task MUST verify t17 (hook happy path) and t18 (hook fail-safe) still pass before declaring acceptance; t38 (new) positively asserts the skip behavior. Run the B1 hook tests against the patched hook BEFORE landing M1.
- **Token-cost inflation of inline review** — 5-wide wave × 3 reviewers × per-reviewer context ≈ 45k tokens per wave. Acceptable at Sonnet pricing, but visible in practice. Mitigation: `--skip-inline-review` is the documented escape; D5 keeps per-reviewer context task-local (no whole-repo handoff); Sonnet parallelism keeps wall-clock dominated by slowest single reviewer (~30s). Watch item post-ship if cost telemetry shows unexpected growth.
- **LLM reviewer emits non-canonical verdict footer** — D1 wire format is prescriptive (`## Reviewer verdict` + `key: value` lines), but Sonnet can deviate (JSON codeblock wrap, missing colon, etc.). Mitigation: D2's tolerant-but-loud parser treats malformed as BLOCK; t34 tests the contract shape on canonical input. Watch item: if reviewers regularly emit malformed footers in practice, tighten the agent prompt in a B3 follow-up.
- **Checkbox drops during Wave 2 (6-way merge)** — highly predictable per B1 (7-way lost T4 + T15) and B2.a (7-way lost T1 + T2) precedents captured in `tpm/checkbox-lost-in-parallel-merge.md`. Mitigation: orchestrator auto-runs checkbox-count audit after Wave 2 merge; commits `fix: check off T<n> (lost in merge)` as needed.
- **Rubric drift over time** — rubrics live under `.claude/rules/reviewer/` and are edited through normal PR review; no version pinning. Accepted per PRD non-goal; watch item if post-hoc compliance of an archived feature ever matters (tech-doc §6 deferred).
- **Stay-in-lane leakage** — D4 combines prompt literal + rubric reiteration; no orchestrator-side filter in v1. If the security reviewer routinely emits style nits that dilute signal, add post-filter (tech-doc §6 deferred). Watch item at gap-check; if leakage is common, flag for B3.
- **`/specflow:review` on a large archived feature** — D5 chose feature-wide diff (not chunked). Sonnet 1M context is well above any single-feature diff we have shipped (B1 ~1800 lines), but unknown for future long-running features. Mitigation: PRD §7 deferred `--since <commit>` for partial diff; if a large-feature overflow appears, add flag as a follow-up.
- **Report filename same-second collision** — two `/specflow:review` runs within the same second produce `review-YYYY-MM-DD-HHMMSS.md` for both. D10 fallback: append `-<pid>`. M5 must implement both tiers of fallback; AC-review-no-clobber requires the distinct-file property.

## 7. Out of plan

- **B2.c — does not exist**. This feature closes the six-item harness-upgrade series (B1 items 1–3, B2.a items 5 + 7, B2.b items 4 + 6). Nothing left in the series.
- **TDD enforcement** — deferred, separate future feature (PRD §2 non-goal).
- **Strategic compaction hooks** — not in scope.
- **`/specflow:extract`** — not in scope.
- **Cross-harness adapters (Cursor / Codex / OpenCode)** — not in scope.
- **Further symlink or hook infrastructure** — B2.a shipped the shallow globalization; no more this round.
- **Additional reviewer axes** (docs, correctness, architecture) — v1 is 3 (security / performance / style); more can follow via a new PRD after the 3-axis pattern proves.
- **Axis-weighting / voting consensus** — severity-gated aggregation (R4) is the only v1 mechanism; tech-doc §6 deferred.
- **Reviewer appendix files** (`reviewer-<axis>.appendix.md`) — tech-doc §6 deferred; trigger is a reviewer core file exceeding ~60 non-empty lines.
- **Python aggregator helper** — D2 bash-only; promote to `scripts/specflow-review-aggregate` only if the bash grows beyond ~30 lines or the verdict format moves to JSON.
- **Reviewer rubric versioning** — rule edits apply to subsequent sessions only, not retroactively to archived features. Tech-doc §6 deferred.
- **`--since <commit>` flag for `/specflow:review`** — not in v1; PRD §7 deferred.
- **AgentShield-grade threat-model security scanning** — reviewers here are craft-level, not security-specialist-depth. PRD non-goal.
- **Dashboard / GUI / TUI for review results** — PRD non-goal.
- **Automated linter flagging performative reviewer output (stub-PASS with no rationale)** — PRD non-goal.

---

## Summary

- **Milestone count**: 7 (M1 schema + hook skip, M2 rubric files × 3, M3 agent files × 3, M4 implement.md inline injection, M5 review.md one-shot command, M6 tests t34–t38, M7 smoke + README + dogfood note).
- **Key sequencing calls**:
  - M1 before M2 (scope enum must admit `reviewer` before rubrics reference it).
  - M1 before M3 (hook skip must exist before rubrics could session-load via any walk).
  - M2 ⟂ M3 (six different files across two dirs; Wave 2 = 6 parallel).
  - M4 ⟂ M5 (different command files; Wave 3 = 2 parallel).
  - M6 tests can NOT be red-first with M4/M5 because inline review's integration test (t36) exercises the implement.md aggregator — wait for M4 green.
  - M7 is always last (smoke registrar, README note, dogfood diagnostic).
- **Risk flags to escalate now**:
  - Dogfood paradox — this feature's own `/specflow:implement` runs MUST use `--skip-inline-review`; document in M7 and in every run's CLI invocation.
  - SessionStart hook patch (M1/D7) — must preserve B1+B2.a 33/33 smoke; run t17/t18 before declaring M1 acceptance.
  - Wave-2 checkbox audit — 6-way merge will drop checkboxes per established precedent; orchestrator must auto-audit and fix-up per `tpm/checkbox-lost-in-parallel-merge.md`.
  - D7 hook skip test coverage (t38) — the ONE test that catches a regression where `reviewer/` rubrics accidentally session-load; treat as non-skippable in smoke.
- **TPM memory-consultation summary**: 4 TPM memory entries consulted. `parallel-safe-requires-different-files` and `parallel-safe-append-sections` shaped §5 wave hints directly (6-way Wave 2 via six distinct files; smoke.sh registration funneled through single M7 editor). `checkbox-lost-in-parallel-merge` (new, B2.a retro) added a post-merge audit as a hard cross-cutting concern in §3 and a risk in §6. `tasks-doc-format-migration` not applicable this round.
