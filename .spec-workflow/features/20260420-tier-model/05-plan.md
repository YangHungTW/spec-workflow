# Plan — tier-model

**Feature**: `20260420-tier-model`
**Stage**: plan
**Author**: TPM
**Date**: 2026-04-20
**Shape**: **new merged form** (narrative + task checklist in one file per PRD R19). No `06-tasks.md` will be authored for this feature.

Inputs consumed: `03-prd.md` (R1–R20, AC1–AC12), `04-tech.md` (D1–D10 + §4 cross-cutting + §7 file list), `01-brainstorm.md` (hybrid self-bootstrap rationale), draft `.spec-workflow/drafts/tier-model.md` (§11 condensed rollout sketch — absorbed; draft deleted at end of plan stage per user instruction).

---

## 1. Wave plan (narrative)

### 1.1 Sequencing rationale

The feature is a single-repo bash + markdown restructure. Wave boundaries are driven by **call-graph dependencies** (what must exist before what can be built) and the **parallelism rules** from `tpm/parallel-safe-requires-different-files.md` and `tpm/parallel-safe-append-sections.md` (shared files force serialisation unless the edits are append-only).

Five implement waves plus a trailing docs wave:

- **W0 — Schema & helpers.** Lays down the `tier:` field in `_template/STATUS.md`, the `bin/specflow-tier` sourceable library (D1, D2), its tests, the one-shot migration script (D3), its dry-run test, and the actual migration of B2's STATUS (R2, AC5). Nothing downstream can source the helper or assume a `tier:` field until this wave lands.
- **W1 — Aggregator extraction.** Lifts the copy-pasted aggregator out of `implement.md` step 7b and `review.md` step 5 into `bin/specflow-aggregate-verdicts` parameterised by axis-set (D5). The refactor is a precondition for the new `/specflow:validate` command in W2 — without a single extracted aggregator, we'd be adding a third copy-paste. Both existing call-sites are rewritten in the same wave as the extraction so no stale inline aggregator lingers past the wave boundary.
- **W2 — New command + retired stubs + agent footer rename.** The `/specflow:validate` command file, the four deprecation stubs (D8 — all parallel-safe because every stub is its own file), and the qa-tester/qa-analyst header rename (`## Reviewer verdict` → `## Validate verdict`, R18) all land together. Each edit touches a distinct file.
- **W3 — Tier-aware dispatch.** The command files that need to read the tier helper — `request.md`, `next.md`, `implement.md`, `archive.md`, `plan.md` — plus the two agent prompts that need tier-proposal heuristic and merged-plan guidance (`pm.md`, `tpm.md`). Each edit is to a distinct file; parallel-safe within the wave. `implement.md` is the one file also touched in W1 (T9 refactors step 7b; T21 adds dispatch + threshold) — sequencing across waves is the only safe shape.
- **W4 — Structural validation tests.** All AC-structural tests land in parallel — each test is its own `test/tN_*.sh` file. The `test/smoke.sh` registration is a shared append-only file handled per `tpm/parallel-safe-append-sections.md` (keep-both mechanical resolution expected).
- **W5 — Docs + template stage-checklist update.** README / team-memory / template stage-checklist. Small wave; isolated files.

### 1.2 Dogfood paradox handling (R20, §9.1 PRD, shared/dogfood-paradox-third-occurrence.md)

This feature's own verify covers every AC **structurally only**. Runtime exercise is deferred to B2 (`20260420-flow-monitor-control-plane`). No task in this plan depends on the self-shipped mechanism being active during its own implement. In particular:

- The new commands (`/specflow:validate`, updated `/specflow:next`, `/specflow:plan`, `/specflow:archive --allow-unmerged`, `/specflow:request --tier`) are **not invoked** by any task in this plan; they are only **authored** and **unit-tested**.
- The `--skip-inline-review` precedent from B2.b carries over: reviewers / inline review can still fire during this feature's own implement because the reviewer contract was shipped in B2.b and has been stable since.
- Structural tests cover AC1, AC3, AC4, AC5, AC6, AC7, AC8, AC9, AC10, AC11, AC12. AC2 is structurally covered by the dispatch-matrix unit test (T26) driven off `get_tier`.

### 1.3 What is NOT in this plan (out-of-scope carries)

Per PRD §10, excluded from this feature and therefore absent from the wave list:

- Agent role consolidation (pm+tpm, qa-analyst+qa-tester).
- New reviewer axes.
- Back-filling `tier:` into archived STATUS files.
- Cross-feature orchestration (bulk tier-bump).
- Auto-downgrade path.
- Calibrating diff thresholds from archived-feature histogram (starting values in R14 are committed; retrospective-driven tuning is NOT planned here).
- Inventing a `/specflow:validate`-specific aggregator (R17 reuses the review aggregator).
- Re-seeding stage artefacts on tier upgrade (R15 says NOT to do this; no tooling is built).
- Renumbering `08-validate.md` → `07-validate.md` (tech §6 non-decision).
- Deleting the four deprecation stubs after a grace period (tech §6 non-decision).

### 1.4 Risks (flagged to Developer, not TPM-resolvable)

- **RA — Validate aggregator signal for security-must auto-upgrade.** Tech §4.3 commits the aggregator emitting a `suggest-audited-upgrade` side-effect signal when it sees `severity: must` on `axis: security`. This side-effect is a new wire-format element on top of the existing PASS/NITS/BLOCK verdict. T7 must commit the signal shape (stdout marker, env file, STATUS mutation) in its scope; reviewers should check it doesn't break existing `/specflow:review` aggregator callers.
- **RB — Threshold check fires after wave merge inside `/specflow:implement`.** T21 implements D7. The logic runs inside the orchestrator's implement flow, not inside a developer subagent's worktree. Reviewers need to verify the git-diff commands use the correct base reference (`<base>...HEAD` against the feature branch's merge-base with main, not the subagent's branch).
- **RC — B2's STATUS is a user-owned file edited by T6.** The migration script must back up to `STATUS.md.bak` before write (per `.claude/rules/common/no-force-on-user-paths.md`). T6 verifies the backup exists post-run and the diff is exactly one new line.
- **RD — `implement.md` is modified in two waves.** T9 (W1 aggregator refactor) and T21 (W3 dispatch + threshold). Sequential across waves prevents conflict, but the Developer on T21 must **re-read `implement.md`** fresh at task start (not rely on memory of pre-W1 shape) because the aggregator extraction reshaped step 7b's surrounding prose.

### 1.5 Escalations (none)

No open questions. All four PRD carry-forward Qs are resolved at tech (Q-CARRY-1 → D7; Q-CARRY-2 → D6; Q-CARRY-3 → D4 parallel; Q-CARRY-4 → D9+D10). No PRD requirement found ambiguous during plan. If a gap surfaces at implement, escalate per `/specflow:update-plan`.

---

## 2. Wave schedule

- **W0** — T1, T2, T3, T4, T5, T6 (6 tasks; mixed parallel / sequential — see per-wave analysis)
- **W1** — T7, T8, T9, T10 (4 tasks; T7+T8 parallel, T9+T10 parallel after T7)
- **W2** — T11, T12, T13, T14, T15, T16, T17 (7 tasks; all parallel — each touches distinct file)
- **W3** — T18, T19, T20, T21, T22, T23, T24, T25 (8 tasks; all parallel — distinct files)
- **W4** — T26, T27, T28, T29, T30, T31, T32, T33 (8 tasks; test files disjoint; T33 appends to `test/smoke.sh` — append-only collision expected)
- **W5** — T34, T35 (2 tasks; distinct files, parallel)

**Total tasks**: 35. **Total waves**: 6 (W0–W5). **Widest wave**: 8 (W3, W4).

### 2.1 Parallel-safety per wave

**W0 — Schema & helpers.** Mixed.
- T1 (`_template/STATUS.md`) stands alone.
- T2 (`bin/specflow-tier`) + T3 (`test/tN_specflow_tier.sh`): different files, parallel-safe. T3 depends on T2 existing for the tests to be meaningful, but can be authored in parallel from the D2 five-state spec.
- T4 (`scripts/tier-rollout-migrate.sh`) + T5 (`test/tN_tier_rollout_migrate.sh`): different files, parallel-safe. T5 depends on T4's dry-run interface being specified (already fixed in tech §4.1); can be authored in parallel.
- T6 (apply migration to B2's STATUS): runs AFTER T4/T5 merge because it invokes the migration script; sequential.

Grouping: **W0a = {T1, T2, T3, T4, T5}** (5 parallel), **W0b = {T6}** (serial after W0a). Written as one wave with an internal ordering note: T6 runs last in this wave, after the other five land.

**W1 — Aggregator extraction.** Internal sequence.
- T7 (`bin/specflow-aggregate-verdicts`) must exist before T8 tests can run, and before T9/T10 can call it.
- T8 (`test/tN_aggregate_verdicts.sh`) + T7: different files; can parallelise authoring but T8's assertion is meaningful only against T7's committed shape. Safe to pair.
- T9 (`implement.md` step 7b refactor) + T10 (`review.md` step 5 refactor): different files, parallel-safe. Both depend on T7.

Grouping: **W1a = {T7, T8}** (parallel), **W1b = {T9, T10}** (parallel after W1a). Written as one wave with internal ordering.

**W2 — New + retired + agent rename.** 7 parallel, all distinct files.
- T11 `validate.md`, T12 `brainstorm.md` stub, T13 `tasks.md` stub, T14 `verify.md` stub, T15 `gap-check.md` stub, T16 dual-edit of `qa-tester.md` + `qa-analyst.md`, T17 `test/tN_deprecation_stubs.sh`.
- File-set check: no overlap. `qa-tester.md` and `qa-analyst.md` are both edited in T16 (single task), so no cross-task collision on those.
- Dispatcher check: none; no shared case/switch.
- Append-only check: none; no shared append target in this wave.
- Wave-safe: yes, fully parallel.

**W3 — Tier-aware dispatch.** 8 parallel, all distinct files.
- T18 `request.md`, T19 `pm.md` agent, T20 `next.md`, T21 `implement.md`, T22 `tpm.md` agent, T23 `archive.md`, T24 `plan.md`, T25 `test/tN_heuristic_determinism.sh`.
- Critical: `implement.md` in T21 is also touched in W1 by T9 — sequential across waves satisfies this. Within W3, `implement.md` is a single task's file (T21).
- File-set check: no overlap within the wave.
- Dispatcher check: `next.md`'s tier-skip dispatch lives in T20 only. No other task edits it.
- Wave-safe: yes, fully parallel.

**W4 — Structural tests.** 8 parallel, test files all distinct.
- T26–T32: seven new `test/tN_*.sh` files, each its own file.
- T33 appends registrations for all seven new tests to `test/smoke.sh`. This is an **append-only collision** per `tpm/parallel-safe-append-sections.md` — if implement dispatches T33 in parallel with T26–T32 and each test task is tempted to self-register, we'd lose the parallelism benefit. To keep it simple: T33 is the ONLY task that writes to `test/smoke.sh`; T26–T32 do NOT self-register. T33 depends on all of T26–T32 being committed (it needs the test-filenames, which are stable in the plan — so technically T33 can author its diff in parallel, but to avoid the tester-has-to-exist contract, sequence T33 after T26–T32).

Grouping: **W4a = {T26, T27, T28, T29, T30, T31, T32}** (7 parallel), **W4b = {T33}** (serial after W4a). Written as one wave with internal ordering.

**W5 — Docs + template checklist.** 2 parallel, distinct files.
- T34 `README.md` (if present; else a doc under `.spec-workflow/` or similar — exact location decided by T34).
- T35 `_template/STATUS.md` stage-checklist finalisation (retire `tasks`/`gap-check`/`verify` boxes; add `validate` box).

NOTE: T1 in W0 already adds the `tier:` field to `_template/STATUS.md`. T35 is a follow-up edit to the **stage checklist section** of the same file. To avoid dispatcher-style collision in the same file across waves, T35 is scheduled in W5 (explicitly sequential after T1). If the two edits are textually far apart (header vs checklist), this is still safe; if they're adjacent, T35 may need to be folded into T1 instead — Developer on T1 flags if so.

### 2.2 Merge gate per wave (inline reviewers)

Default per-wave gate is **inline review on** (the repo's normal posture). This feature does not invoke `--skip-inline-review` anywhere.

- **W0**: security (T4 migration writes to user-owned file; security review required) + style (bash portability per `.claude/rules/bash/bash-32-portability.md`) + performance (low risk).
- **W1**: security (aggregator parses external agent output) + style + performance (aggregator is called per-wave; not a hot path).
- **W2**: style (mostly; deprecation stubs are trivial). Security gate is low-risk but runs per default.
- **W3**: security (propose-and-confirm prompt at request; merge-check at archive) + style + performance (threshold check uses git diff — tech §4.5 already cached; reviewer confirms).
- **W4**: style (test-script shape consistency per `test/smoke.sh` conventions).
- **W5**: style (docs).

Per `.claude/rules/bash/sandbox-home-in-tests.md`, every test task that exercises a CLI reading `$HOME` must sandbox-home. Flagged to developers on T3, T5, T17, T27–T32.

### 2.3 Structural-vs-runtime verification matrix

Per PRD §9.1 and shared/dogfood-paradox-third-occurrence.md.

| AC | Coverage at this feature's validate | Deferred to |
|---|---|---|
| AC1 (STATUS schema) | Structural (T1 + T6) | — |
| AC2 (tier-aware dispatch) | Structural (T20, T26 unit table) | B2 runtime |
| AC3 (archive merge-check) | Structural (T23 + T27 mock git) | B2 runtime |
| AC4 (upgrade audit log) | Structural (T2 set_tier + T28) | Any future upgrade event |
| AC5 (B2 migration zero-touch) | Structural (T4 dry-run + T6 actual run) | B2's first `/specflow:next` |
| AC6 (retired commands) | Structural (T12–T15 + T17) | B2 (user invokes retired command) |
| AC7 (self-bootstrap hybrid) | **Structural only** (artefact shape in this feature's dir) | B2 (first feature authored by the commands) |
| AC8 (validate aggregator) | Structural (T7 + T8) | B2 first `/specflow:validate` |
| AC9 (auto-upgrade triggers) | Structural (T29 three triggers) | B2 runtime |
| AC10 (mid-flight upgrade non-destructive) | Structural (T30 byte-diff) | — |
| AC11 (tiny inline review default) | Structural (T21 + T31 dry-run) | B2 follow-up if any |
| AC12 (tier-proposal prompt) | Structural (T19 + T25 + T32) | First post-rollout feature |

---

## 3. Task checklist

Conventions in this section (new merged shape):

- Tasks numbered T1..T35 contiguously. The feature's tier is `standard` (PRD AC7) so the `05-plan.md` format follows the TPM appendix `06-tasks.md` task-block shape, compiled into this single file.
- `Files:` lists the exact paths each task creates or modifies. Overlap within a wave is a planning bug.
- `Requirement:` cites ≥1 PRD R-id. `Decisions:` cites the tech D-id(s) the task realises.
- `Verify:` is a runnable command. For tasks whose verification lives in a sibling test task (e.g. T2 verified by T3), `Verify:` points to the sibling test file and includes `bash test/tN_<name>.sh`.
- `Depends on:` lists in-plan task IDs only. Waves are the coarse grouping; `Depends on:` is the fine-grained edge.
- `Parallel-safe-with:` lists same-wave tasks this task is explicitly safe to run alongside. Tasks missing from a peer's `Parallel-safe-with:` list must run in different waves even if `Depends on:` is empty.
- Orchestrator checks off `[x]` in a post-wave bookkeeping commit per `tpm/wave-bookkeeping-commit-per-wave.md`. Developers do NOT flip their own checkbox and do NOT append their own STATUS Notes line (orchestrator does both in one post-wave commit).

### Wave 0 — Schema & helpers (6 tasks)

## T1 — [x] Extend `_template/STATUS.md` with `tier:` field
- **Milestone**: M0
- **Requirements**: R1
- **Decisions**: —
- **Scope**: Add a `**tier**: standard` line to the header block between `**has-ui**:` and `**stage**:`. Default placeholder value is `standard`; the real value is written by `/specflow:request` in W3. Do NOT modify the `## Stage checklist` section in this task — T35 finalises that in W5.
- **Deliverables**: `.spec-workflow/features/_template/STATUS.md`
- **Verify**: `grep -q '^- \*\*tier\*\*:' .spec-workflow/features/_template/STATUS.md` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T2, T3, T4, T5
- [ ]

## T2 — [x] `bin/specflow-tier` sourceable library
- **Milestone**: M0
- **Requirements**: R1, R2, R11, R12, R13
- **Decisions**: D1, D2
- **Scope**: Author a new sourceable bash library at `bin/specflow-tier` (per `architect/script-location-convention.md`). Functions (PRD R11 — single parse site):
  - `get_tier(feature_dir)` — stdout one of `tiny|standard|audited|missing|malformed`. Pure classifier per `.claude/rules/common/classify-before-mutate.md` — no side effects, no file mutation.
  - `set_tier(feature_dir, new, role, reason)` — validates transition via `validate_tier_transition`; on OK, updates `STATUS.md` `tier:` line via temp-file + `mv` atomic swap (per `.claude/rules/common/no-force-on-user-paths.md`); appends STATUS Notes line in the R13 format `YYYY-MM-DD <role> — tier upgrade <old>→<new>: <reason>`. Exit 2 on disallowed transitions.
  - `validate_tier_transition(old, new)` — returns 0 (valid) / 1 (invalid). Monotonic enum: `tiny → standard → audited`.
  - `tier_skips_stage(tier, stage)` — returns 0 (skip) / 1 (run) per PRD R10 matrix. Pure function.
  - Double-source guard at top: `[ "${SPECFLOW_TIER_LOADED:-0}" = "1" ] && return 0; SPECFLOW_TIER_LOADED=1`.
  - Bash 3.2 / BSD userland compliance per `.claude/rules/bash/bash-32-portability.md` (no `readlink -f`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical paths, no GNU-only `sed` flags).
  - Exact STATUS Notes line format quoted verbatim from PRD R13: `YYYY-MM-DD <role> — tier upgrade <old>→<new>: <reason>`.
- **Deliverables**: `bin/specflow-tier` (exec bit per `architect/script-location-convention.md`)
- **Verify**: `bash test/tN_specflow_tier.sh` (T3) exits 0. Structural check: `[ -x bin/specflow-tier ]`.
- **Depends on**: —
- **Parallel-safe-with**: T1, T3, T4, T5
- [ ]

## T3 — [x] Unit tests for `bin/specflow-tier`
- **Milestone**: M0
- **Requirements**: R1, R2, R11, R12, R13
- **Decisions**: D1, D2
- **Scope**: Author `test/tN_specflow_tier.sh` covering per tech §4.4:
  - `get_tier` fixtures: valid tier (all three), missing field (→ `missing`), malformed field (→ `malformed`), file-not-found (→ `missing` per D2 five-state spec — confirm with Developer; tech §4.1 says get_tier never exits non-zero, so file-absence must map to one of the five states).
  - `set_tier` transition matrix: every old→new pair. Valid: `tiny→standard`, `tiny→audited`, `standard→audited`. Invalid (exit 2): `standard→tiny`, `audited→standard`, `audited→tiny`, any `missing→anything-except-standard`, any `malformed→anything`. Self-transition (e.g. `standard→standard`): confirm disposition with Developer (likely no-op or exit non-zero; tech doesn't specify — Developer decides and T3 asserts).
  - `tier_skips_stage`: enumerate every (tier, stage) pair against PRD R10. Matrix verbatim from R10.
  - Sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md` (mktemp-d sandbox, `HOME=$SANDBOX/home`, preflight assert, trap cleanup).
  - STATUS Notes format assertion: after `set_tier`, grep the STATUS.md for the exact R13-format line.
- **Deliverables**: `test/tN_specflow_tier.sh` (N = next free number; allocate at task-start time by `ls test/ | awk` over existing `tNN_*.sh` names)
- **Verify**: `bash test/tN_specflow_tier.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T4, T5
- [ ]

## T4 — [x] `scripts/tier-rollout-migrate.sh` one-shot migration
- **Milestone**: M0
- **Requirements**: R2
- **Decisions**: D3
- **Scope**: Create `scripts/` directory if absent; author `scripts/tier-rollout-migrate.sh` (per `architect/script-location-convention.md` — one-off migrations go in `scripts/`, not `bin/`). Behaviour:
  - Iterate over `.spec-workflow/features/*/STATUS.md`.
  - Skip archived features: `.spec-workflow/archive/` is NOT walked (PRD R2: "Archived features MUST NOT be touched").
  - For each in-flight feature whose STATUS lacks a `tier:` field: back up to `STATUS.md.bak` first (per `.claude/rules/common/no-force-on-user-paths.md`), then insert `- **tier**: standard` between `- **has-ui**:` and `- **stage**:` using atomic write-temp-then-rename (per `classify-before-mutate.md` + `no-force-on-user-paths.md`).
  - Idempotent: re-run on already-migrated STATUS is a no-op (log "skipped: already migrated"). Matches tech §4.1.
  - `--dry-run` flag: prints the would-be diff without mutating files. Exits 0 on success.
  - Fail-loud: exits 2 if a mutation produces an unexpected diff (more than one new line or any other field changed). Matches tech §4.1.
  - Bash 3.2 portability.
- **Deliverables**: `scripts/tier-rollout-migrate.sh` (exec bit)
- **Verify**: `bash test/tN_tier_rollout_migrate.sh` (T5) exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T5
- [ ]

## T5 — [x] Dry-run test for migration script
- **Milestone**: M0
- **Requirements**: R2, AC5
- **Decisions**: D3
- **Scope**: Author `test/tN_tier_rollout_migrate.sh` covering:
  - Dry-run against a fixture feature dir (no `tier:` field) asserts the expected one-line insert diff printed to stdout, no file mutation.
  - Real run against the same fixture asserts the backup exists at `STATUS.md.bak`, the `tier: standard` line is present at the correct header position, and no other field changed (byte-compare every other line).
  - Idempotent re-run: second invocation is a no-op, backup unchanged.
  - Archived feature dir (fake `.spec-workflow/archive/` subpath) is NOT touched.
  - Sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md` — sandbox includes fixture feature dirs under `$HOME/`.
- **Deliverables**: `test/tN_tier_rollout_migrate.sh`
- **Verify**: `bash test/tN_tier_rollout_migrate.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4
- [ ]

## T6 — [x] Apply migration to B2's STATUS
- **Milestone**: M0
- **Requirements**: R2, AC5
- **Decisions**: D3
- **Scope**: Invoke `bash scripts/tier-rollout-migrate.sh` (without `--dry-run`) against the current working tree. Expected effect: `.spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md` gains exactly one new line `- **tier**: standard` between `- **has-ui**:` and `- **stage**:`; no other content changes. A `STATUS.md.bak` file is created in that feature's directory. Commit message: `migrate: add tier: standard to B2 (flow-monitor-control-plane) STATUS`. Do NOT commit the `STATUS.md.bak` file — it's a local safety artefact, add it to `.gitignore` if not already covered; confirm at task start.
- **Deliverables**: modified `.spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md`
- **Verify**: `grep -q '^- \*\*tier\*\*: standard$' .spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md` exits 0. `git diff --stat` shows exactly one insertion in that STATUS file.
- **Depends on**: T4, T5 (script must be tested before running against the real file)
- **Parallel-safe-with**: — (runs last in W0, sequential after T4+T5 merge)
- [ ]

### Wave 1 — Aggregator extraction (4 tasks)

## T7 — `bin/specflow-aggregate-verdicts` extracted aggregator CLI
- **Milestone**: M1
- **Requirements**: R17, R18
- **Decisions**: D5
- **Scope**: New bash CLI at `bin/specflow-aggregate-verdicts`. Input: positional axis-set (space-separated axis names) + `--dir <path>` for the directory of per-axis verdict files. Output to stdout: single aggregated verdict `PASS` / `NITS` / `BLOCK` per the classifier semantic (any BLOCK → BLOCK; all PASS → PASS; else NITS). Additional side-effect signal: if any verdict file contains a `severity: must` finding on `axis: security`, print a second line `suggest-audited-upgrade: <task-id-or-axis-name>` to stdout (tech §4.3 — drives R14 auto-upgrade trigger). Malformed footer (missing `## Reviewer verdict` header, missing `verdict:` key, verdict outside `{PASS,NITS,BLOCK}`) MUST parse as BLOCK per tech §4.1 and PRD R18. Exit 0 on any classifier outcome; exit 2 on argument errors (no axis-set, missing `--dir`, missing dir). Bash 3.2 portability.
- **Deliverables**: `bin/specflow-aggregate-verdicts` (exec bit)
- **Verify**: `bash test/tN_aggregate_verdicts.sh` (T8) exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T8
- [ ]

## T8 — Unit tests for aggregator
- **Milestone**: M1
- **Requirements**: R17, R18
- **Decisions**: D5
- **Scope**: Author `test/tN_aggregate_verdicts.sh` covering per tech §4.4:
  - Three-axis review case: `{PASS, PASS, PASS}` → `PASS`; `{PASS, NITS, PASS}` → `NITS`; `{PASS, BLOCK, PASS}` → `BLOCK`.
  - Two-axis validate case: `{tester:PASS, analyst:PASS}` → `PASS`; `{tester:PASS, analyst:BLOCK}` → `BLOCK`; `{tester:NITS, analyst:PASS}` → `NITS`.
  - Malformed-footer cases: missing header, missing `verdict:` key, verdict `OOPS` (not in the closed set). Each → `BLOCK`.
  - Security-must signal: a verdict file with `axis: security` + `severity: must` finding → aggregator stdout contains `suggest-audited-upgrade:` line in addition to the aggregated verdict line.
  - No security-must signal when finding is `should`/`avoid` or on a non-security axis.
  - Sandbox-HOME discipline.
- **Deliverables**: `test/tN_aggregate_verdicts.sh`
- **Verify**: `bash test/tN_aggregate_verdicts.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T7
- [ ]

## T9 — Refactor `implement.md` step 7b to call extracted aggregator
- **Milestone**: M1
- **Requirements**: R17
- **Decisions**: D5
- **Scope**: Rewrite the inline aggregator block in `.claude/commands/specflow/implement.md` step 7b (per-task × axis aggregation during inline review) to invoke `bin/specflow-aggregate-verdicts`. Preserve the existing per-task × axis semantics: the step already loops over tasks and axes; the per-iteration aggregator call now delegates to the extracted CLI. Keep existing integration points: the step still writes its per-task verdict to the location existing callers read. Preserve the `suggest-audited-upgrade` signal plumbing — tech §4.3 step 7c explicitly consumes this and invokes `set_tier` on security-must; T9 keeps the signal reachable to step 7c.
- **Deliverables**: modified `.claude/commands/specflow/implement.md` (step 7b region)
- **Verify**: `grep -q 'bin/specflow-aggregate-verdicts' .claude/commands/specflow/implement.md` exits 0. Manual review: the inline aggregator hunk is removed; the CLI invocation is in its place.
- **Depends on**: T7
- **Parallel-safe-with**: T10
- [ ]

## T10 — Refactor `review.md` step 5 to call extracted aggregator
- **Milestone**: M1
- **Requirements**: R17
- **Decisions**: D5
- **Scope**: Rewrite the inline aggregator block in `.claude/commands/specflow/review.md` step 5 (whole-feature review aggregation) to invoke `bin/specflow-aggregate-verdicts`. Axis set passed: `security performance style`. Preserve the existing output shape: the aggregated verdict feeds `review.md`'s downstream STATUS / header write.
- **Deliverables**: modified `.claude/commands/specflow/review.md` (step 5 region)
- **Verify**: `grep -q 'bin/specflow-aggregate-verdicts' .claude/commands/specflow/review.md` exits 0. Manual review: inline aggregator hunk removed.
- **Depends on**: T7
- **Parallel-safe-with**: T9
- [ ]

### Wave 2 — New command + retired stubs + agent footer rename (7 tasks)

## T11 — `.claude/commands/specflow/validate.md` new command
- **Milestone**: M2
- **Requirements**: R3, R17, R18
- **Decisions**: D4 (parallel axes), D5 (uses extracted aggregator)
- **Scope**: Author the new command file following the shape of existing `verify.md` + `gap-check.md` combined. Contract (tech §2.2 Flow C):
  - Resolve feature dir; require all implement tasks checked (grep `- \[ \]` returns nothing under `## Wave schedule` or equivalent).
  - Dispatch qa-tester and qa-analyst **in parallel** (D4 — one orchestrator message with two Agent calls). Tech §2.2 Flow C is the canonical reference.
  - Each agent writes a `## Validate verdict` footer (pure markdown, same wire format as reviewer verdicts per `architect/reviewer-verdict-wire-format.md`). Header changed from `## Reviewer verdict` to `## Validate verdict` to avoid ambiguity at parse time; PRD R18 mandates this shape.
  - Aggregate via `bin/specflow-aggregate-verdicts tester analyst --dir <validate-verdict-dir>` → stdout verdict.
  - Compose `08-validate.md`: header + per-axis findings + aggregated `## Validate verdict` footer.
  - Update STATUS: check `[x] validate` ONLY if aggregated verdict is PASS or NITS. BLOCK leaves box unchecked; prints diagnostic.
- **Deliverables**: `.claude/commands/specflow/validate.md`
- **Verify**: `[ -f .claude/commands/specflow/validate.md ]` and `grep -q '^description:' .claude/commands/specflow/validate.md` (frontmatter present). T17 covers aggregate behaviour.
- **Depends on**: T7 (aggregator must exist)
- **Parallel-safe-with**: T12, T13, T14, T15, T16, T17
- [ ]

## T12 — `brainstorm.md` deprecation stub
- **Milestone**: M2
- **Requirements**: R4
- **Decisions**: D8
- **Scope**: Replace contents of `.claude/commands/specflow/brainstorm.md` with the deprecation stub shape from tech §D8 quoted verbatim. The stub:
  - Frontmatter `description:` reads `RETIRED — see /specflow:prd. Usage: /specflow:brainstorm <slug>`.
  - Body directs user to fold exploration into PRD `## Exploration` section, suggests `/specflow:prd <slug>` next.
  - Prints notice and exits non-zero when invoked. No STATUS mutation.
- **Deliverables**: modified `.claude/commands/specflow/brainstorm.md`
- **Verify**: `grep -q '^description: RETIRED' .claude/commands/specflow/brainstorm.md` exits 0. T17 covers invocation behaviour.
- **Depends on**: —
- **Parallel-safe-with**: T11, T13, T14, T15, T16, T17
- [ ]

## T13 — `tasks.md` deprecation stub
- **Milestone**: M2
- **Requirements**: R4
- **Decisions**: D8
- **Scope**: Mirror of T12 for `.claude/commands/specflow/tasks.md`. Successor: `/specflow:plan`. Frontmatter: `RETIRED — see /specflow:plan. Usage: /specflow:tasks <slug>`.
- **Deliverables**: modified `.claude/commands/specflow/tasks.md`
- **Verify**: `grep -q '^description: RETIRED' .claude/commands/specflow/tasks.md` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T11, T12, T14, T15, T16, T17
- [ ]

## T14 — `verify.md` deprecation stub
- **Milestone**: M2
- **Requirements**: R4
- **Decisions**: D8
- **Scope**: Mirror of T12 for `.claude/commands/specflow/verify.md`. Successor: `/specflow:validate`. Frontmatter: `RETIRED — see /specflow:validate. Usage: /specflow:verify <slug>`.
- **Deliverables**: modified `.claude/commands/specflow/verify.md`
- **Verify**: `grep -q '^description: RETIRED' .claude/commands/specflow/verify.md` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T11, T12, T13, T15, T16, T17
- [ ]

## T15 — `gap-check.md` deprecation stub
- **Milestone**: M2
- **Requirements**: R4
- **Decisions**: D8
- **Scope**: Mirror of T12 for `.claude/commands/specflow/gap-check.md`. Successor: `/specflow:validate`. Frontmatter: `RETIRED — see /specflow:validate. Usage: /specflow:gap-check <slug>`.
- **Deliverables**: modified `.claude/commands/specflow/gap-check.md`
- **Verify**: `grep -q '^description: RETIRED' .claude/commands/specflow/gap-check.md` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T11, T12, T13, T14, T16, T17
- [ ]

## T16 — qa-tester + qa-analyst verdict footer header rename
- **Milestone**: M2
- **Requirements**: R18
- **Decisions**: —
- **Scope**: Change the verdict footer header from `## Reviewer verdict` to `## Validate verdict` in both `.claude/agents/specflow/qa-tester.md` and `.claude/agents/specflow/qa-analyst.md`. Preserve the `axis:` / `verdict:` / `findings:` shape verbatim per `architect/reviewer-verdict-wire-format.md`. The `axis:` values become `tester` and `analyst` respectively (tech §2.2 Flow C).
  - Constraint quoted verbatim from PRD R18: "The `08-validate.md` artefact MUST include a `## Validate verdict` footer with `axis: <name>` and `verdict: PASS|NITS|BLOCK` for each axis, plus an aggregated top-level verdict."
  - Review-axis reviewers (security/performance/style) keep the existing `## Reviewer verdict` header — this task touches ONLY qa-tester and qa-analyst.
- **Deliverables**: modified `.claude/agents/specflow/qa-tester.md`, modified `.claude/agents/specflow/qa-analyst.md`
- **Verify**: `grep -c '^## Validate verdict' .claude/agents/specflow/qa-tester.md .claude/agents/specflow/qa-analyst.md` reports 1 each. No `## Reviewer verdict` remains in either file: `! grep -q '^## Reviewer verdict' .claude/agents/specflow/qa-tester.md .claude/agents/specflow/qa-analyst.md`.
- **Depends on**: —
- **Parallel-safe-with**: T11, T12, T13, T14, T15, T17
- [ ]

## T17 — Deprecation-stub invocation tests
- **Milestone**: M2
- **Requirements**: R4, AC6
- **Decisions**: D8
- **Scope**: Author `test/tN_deprecation_stubs.sh` covering per tech §4.4:
  - For each of the four retired commands (`brainstorm`, `tasks`, `verify`, `gap-check`), assert the command file exists, the frontmatter `description:` line matches the `RETIRED — see /specflow:<successor>` shape, and invoking the stub (or a structural proxy — orchestrator invocation is non-trivial from bash, so a grep-based structural assertion is acceptable per tech §4.4 "one per retired command; invoke the stub, assert exit non-zero + expected message text" — Developer picks a practical structural proxy if full invocation is infeasible).
  - Successor mapping matches PRD R4 verbatim.
  - Sandbox-HOME per `.claude/rules/bash/sandbox-home-in-tests.md`.
- **Deliverables**: `test/tN_deprecation_stubs.sh`
- **Verify**: `bash test/tN_deprecation_stubs.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T11, T12, T13, T14, T15, T16
- [ ]

### Wave 3 — Tier-aware dispatch (8 tasks)

## T18 — `request.md` accepts `--tier` flag + propose-and-confirm
- **Milestone**: M3
- **Requirements**: R5, AC12
- **Decisions**: D6
- **Scope**: Extend `.claude/commands/specflow/request.md` to accept optional `--tier <tiny|standard|audited>`. Parse the flag in the command's bash preamble. Pass-through to pm subagent (T19) with context indicating whether the user provided an explicit tier (skip prompt) or not (prompt per D6). Prompt contract shape verbatim from tech §D6:
  ```
  Based on the ask, I propose tier: <proposed>.
    tiny     — <one-line definition>
    standard — <one-line definition>
    audited  — <one-line definition>
  Press Enter to accept <proposed>, or type tiny|standard|audited to override.
  ```
  Insertion point: AFTER the existing `has-ui` probe, BEFORE the slug is finalised (tech §D6).
  - PM MUST NOT silently default; MUST propose. PM MUST NOT block indefinitely on user input (PRD R5). Re-prompt once on unrecognised input, then default to proposed.
  - Silent acceptance adopts proposed; explicit tier name overrides.
- **Deliverables**: modified `.claude/commands/specflow/request.md`
- **Verify**: `grep -q -- '--tier' .claude/commands/specflow/request.md` exits 0. Prompt shape and insertion point confirmed by manual review. T32 covers determinism.
- **Depends on**: T2 (helper must exist to validate tier enum)
- **Parallel-safe-with**: T19, T20, T21, T22, T23, T24, T25
- [ ]

## T19 — `pm.md` extended with tier-proposal heuristic
- **Milestone**: M3
- **Requirements**: R5, AC12
- **Decisions**: D6
- **Scope**: Extend `.claude/agents/specflow/pm.md` with the tier-proposal heuristic per tech §D6 — keyword scan + PM judgment. Literal keyword sets (quoted verbatim from D6 for briefing correctness per `tpm/briefing-contradicts-schema.md`):
  - **Tiny keywords** (case-insensitive substring match): `typo`, `fix typo`, `rename`, `copy change`, `wording`, `comment`, `docstring`, `one-line`, `one line`, `single line`, `readme`.
  - **Audited keywords** (any one match → propose audited): `auth`, `oauth`, `secret`, `secrets`, `token`, `bearer`, `password`, `credential`, `payment`, `billing`, `migration`, `migrate db`, `breaking change`, `breaking api`, `settings.json`.
  - **Default**: `standard`.
  - PM scans keywords first; has discretion to upgrade (never downgrade) based on probe answers; logs override reasoning to STATUS Notes per tech §D6.
- **Deliverables**: modified `.claude/agents/specflow/pm.md`
- **Verify**: all three keyword set tokens from a spot-check (`typo`, `oauth`, `settings.json`) present in `pm.md`. T25 covers determinism.
- **Depends on**: —
- **Parallel-safe-with**: T18, T20, T21, T22, T23, T24, T25
- [ ]

## T20 — `next.md` tier-aware stage skip
- **Milestone**: M3
- **Requirements**: R8, R10
- **Decisions**: D1, D2
- **Scope**: Extend `.claude/commands/specflow/next.md` per tech §2.2 Flow B:
  - Source `bin/specflow-tier` near top.
  - Before dispatching to the matching stage command, call `tier=$(get_tier "$feature_dir")` then `if tier_skips_stage "$tier" "$next_stage"; then <check box inline; append STATUS Notes; advance>; else <existing dispatch>; fi`.
  - Handle `missing` state by treating as `standard` for read purposes (tech §1.4 forward constraint).
  - Handle `malformed` state by failing loud (exit 2, surface to user).
  - STATUS Notes line format: `<date> next — tier <t> skips <stage>` per tech §4.2.
- **Deliverables**: modified `.claude/commands/specflow/next.md`
- **Verify**: `grep -q 'tier_skips_stage' .claude/commands/specflow/next.md` exits 0. T26 covers matrix correctness.
- **Depends on**: T2 (helper must exist)
- **Parallel-safe-with**: T18, T19, T21, T22, T23, T24, T25
- [ ]

## T21 — `implement.md` task-file dispatch + threshold check
- **Milestone**: M3
- **Requirements**: R6, R7, R14, AC9
- **Decisions**: D7, D9
- **Scope**: Two changes to `.claude/commands/specflow/implement.md` (re-read the file at task start — T9 in W1 already modified step 7b; the shape may differ from memory per risk RD):
  1. **Presence-based task-file dispatch (D9, R7)** — replace step 1's "Read `06-tasks.md`" with the dispatch block quoted verbatim from tech §D9:
     ```bash
     if [ -f "$feature_dir/06-tasks.md" ]; then
       TASK_FILE="$feature_dir/06-tasks.md"           # legacy / archived feature
     elif [ -f "$feature_dir/05-plan.md" ] && \
          grep -q '^- \[ \]' "$feature_dir/05-plan.md" 2>/dev/null; then
       TASK_FILE="$feature_dir/05-plan.md"             # new merged shape
     else
       echo "ERROR: neither 06-tasks.md nor task-bearing 05-plan.md found" >&2
       exit 2
     fi
     ```
  2. **Threshold check (D7, R14)** — after each wave merge, before reading next wave:
     - Source `bin/specflow-tier`; `tier=$(get_tier "$feature_dir")`.
     - Cache git-diff once (tech §4.5):
       ```bash
       diff_files_list=$(git diff --name-only "$BASE...HEAD")
       diff_files=$(printf '%s\n' "$diff_files_list" | wc -l)
       diff_lines=$(git diff --shortstat "$BASE...HEAD" | awk '{s+=$4+$6} END {print s+0}')
       ```
     - If `tier = tiny` AND ( `diff_lines > ${SPECFLOW_TIER_DIFF_LINES:-200}` OR `diff_files > ${SPECFLOW_TIER_DIFF_FILES:-3}` ) → emit stderr WARNING + append STATUS Notes pending line per tech §D7. Continue running waves.
     - TPM acts via `set_tier` — NOT auto-promoted here.
  3. **Security-must auto-upgrade (R14 bullet 2, tech §4.3)** — step 7c consumes the `suggest-audited-upgrade:` signal from the extracted aggregator (T7) and invokes `set_tier <slug> audited "security-must finding in <task>"`. Immediate, no confirmation. Preserve this behaviour if it already exists in a prior form; add it if not.
  4. **Tiny default `--skip-inline-review` (R16, AC11)** — before the inline-review gate, check `get_tier`; if `tier = tiny` and no explicit `--inline-review` flag, default to skip and log the skip to STATUS Notes.
- **Deliverables**: modified `.claude/commands/specflow/implement.md`
- **Verify**: `grep -q 'SPECFLOW_TIER_DIFF_LINES' .claude/commands/specflow/implement.md` exits 0. `grep -q 'suggest-audited-upgrade' .claude/commands/specflow/implement.md` exits 0. T29 covers trigger correctness.
- **Depends on**: T2 (helper), T7 (aggregator signal), T9 (W1 refactor must land first to avoid conflict)
- **Parallel-safe-with**: T18, T19, T20, T22, T23, T24, T25
- [ ]

## T22 — `tpm.md` extended with merged-plan authoring guidance
- **Milestone**: M3
- **Requirements**: R6
- **Decisions**: D9
- **Scope**: Extend `.claude/agents/specflow/tpm.md` with guidance for authoring `05-plan.md` as the merged narrative + task checklist form (for new-shape features). Reference the TPM appendix task-block shape. Note that `06-tasks.md` is not authored for new-shape features. Instruction on how to detect tier-aware authoring (presence of `tier:` field in STATUS means new shape).
- **Deliverables**: modified `.claude/agents/specflow/tpm.md`
- **Verify**: `grep -q '05-plan.md' .claude/agents/specflow/tpm.md` exits 0 and the surrounding prose mentions "merged" or equivalent. Manual review.
- **Depends on**: —
- **Parallel-safe-with**: T18, T19, T20, T21, T23, T24, T25
- [ ]

## T23 — `archive.md` merge-check + `--allow-unmerged REASON`
- **Milestone**: M3
- **Requirements**: R9, AC3
- **Decisions**: —
- **Scope**: Extend `.claude/commands/specflow/archive.md`:
  - Source `bin/specflow-tier`; resolve tier.
  - If `tier ∈ {standard, audited}` AND `git merge-base --is-ancestor <branch> main` returns non-zero → refuse: print branch + main ref + diagnostic, exit non-zero, leave feature unmodified.
  - Exception: `--allow-unmerged REASON` flag — REASON is a **required positional argument** (PRD R9). Invoking `--allow-unmerged` without a reason exits non-zero with usage error.
  - On `--allow-unmerged REASON` use: append STATUS Notes line `<date> archive — --allow-unmerged USED: <REASON>` (tech §4.2).
  - `tier = tiny`: merge-check skipped entirely.
  - `tier = missing` (legacy): treat as tiny-equivalent (tech §1.4 forward constraint) — archives cleanly.
  - `tier = malformed`: fail loud.
- **Deliverables**: modified `.claude/commands/specflow/archive.md`
- **Verify**: `grep -q -- '--allow-unmerged' .claude/commands/specflow/archive.md` exits 0 and `grep -q 'merge-base --is-ancestor' .claude/commands/specflow/archive.md` exits 0. T27 covers behaviour.
- **Depends on**: T2 (helper must exist)
- **Parallel-safe-with**: T18, T19, T20, T21, T22, T24, T25
- [ ]

## T24 — `plan.md` guidance edit (new merged form)
- **Milestone**: M3
- **Requirements**: R6
- **Decisions**: D9
- **Scope**: Edit `.claude/commands/specflow/plan.md` to reflect the new merged `05-plan.md` authoring contract: TPM produces ONE file containing both narrative and task checklist; no separate `06-tasks.md` for new-shape features. Reference TPM agent guidance in T22. Keep the command lightweight — the heavy-lift guidance lives in `tpm.md`.
- **Deliverables**: modified `.claude/commands/specflow/plan.md`
- **Verify**: `grep -q '05-plan.md' .claude/commands/specflow/plan.md` exits 0; manual review confirms merged-form framing.
- **Depends on**: —
- **Parallel-safe-with**: T18, T19, T20, T21, T22, T23, T25
- [ ]

## T25 — Heuristic determinism test for tier proposal
- **Milestone**: M3
- **Requirements**: R5, AC12
- **Decisions**: D6
- **Scope**: Author `test/tN_tier_proposal_heuristic.sh`. Given a fixture set of raw asks, assert that the keyword-scan heuristic produces the expected proposed tier deterministically:
  - `"fix typo in README"` → `tiny`
  - `"rotate oauth secrets"` → `audited`
  - `"rename internal helper"` → `tiny` (keyword `rename`)
  - `"add dashboard page"` → `standard` (no keyword hit)
  - `"migrate db schema for payment"` → `audited`
  - Empty string / whitespace-only → `standard` (default)
  - Because the keyword scan lives inside the pm subagent prompt, the test asserts against a Developer-supplied standalone helper that encapsulates the scan logic (e.g. `bin/specflow-tier` gets a `propose_tier(raw_ask)` function, OR the scan is factored into a separate testable bash function under `.claude/agents/`). Developer decides the exact factoring at task start; the test must run without invoking the full pm agent. Tech §6 non-decision explicitly notes "Whether `bin/specflow-tier` should grow a `propose_tier(raw_ask)` function — only if a non-PM caller needs to compute a proposed tier" — T25 IS that second caller (the test), so this task triggers the decision. Developer may add `propose_tier` to `bin/specflow-tier` or introduce a sibling sourceable helper.
- **Deliverables**: `test/tN_tier_proposal_heuristic.sh`; may also modify `bin/specflow-tier` if Developer chooses to add `propose_tier` there (decision noted in commit message).
- **Verify**: `bash test/tN_tier_proposal_heuristic.sh` exits 0.
- **Depends on**: T2 (helper exists), T19 (heuristic authored)
- **Parallel-safe-with**: T18, T20, T21, T22, T23, T24 (T19 is a dependency not a peer)
- [ ]

### Wave 4 — Structural validation tests (8 tasks)

## T26 — Tier-aware dispatch matrix unit test
- **Milestone**: M4
- **Requirements**: R8, R10, AC2
- **Decisions**: D2
- **Scope**: Author `test/tN_tier_dispatch_matrix.sh`. Table-driven test: for each tier ∈ {tiny, standard, audited} and each stage from PRD R10, assert `tier_skips_stage` returns the expected 0/1. Data derived verbatim from the R10 matrix. Must cover:
  - `tiny` skips `brainstorm|tech|design|review` (all 4).
  - `standard` skips `brainstorm` only (folded into PRD); `design` is conditional on `has-ui: true` — test both `has-ui: false` and `has-ui: true` fixtures.
  - `audited` skips nothing.
  - `validate` stage: tiny runs tester-only default (how this surfaces in `tier_skips_stage` vs command-level behaviour — Developer decides at task start; test asserts the observed contract).
- **Deliverables**: `test/tN_tier_dispatch_matrix.sh`
- **Verify**: `bash test/tN_tier_dispatch_matrix.sh` exits 0.
- **Depends on**: T2 (helper), T20 (dispatch consumer; optional — unit test against helper only is sufficient)
- **Parallel-safe-with**: T27, T28, T29, T30, T31, T32
- [ ]

## T27 — Archive merge-check test
- **Milestone**: M4
- **Requirements**: R9, AC3
- **Decisions**: —
- **Scope**: Author `test/tN_archive_merge_check.sh`. Mock git repo fixture via `git init` in sandbox; create a fake feature dir with `tier: standard`; create an unmerged branch; invoke `/specflow:archive` logic (via sourced helper or direct git-based check). Expected:
  - Unmerged branch + `tier: standard` → archive refuses, exit non-zero, diagnostic mentions branch + main.
  - Unmerged branch + `tier: standard` + `--allow-unmerged "test reason"` → archive accepts, STATUS Notes gains the reason line.
  - `--allow-unmerged` without reason → exit non-zero (usage error).
  - Unmerged branch + `tier: tiny` → archive accepts (no merge-check).
  - Unmerged branch + `tier: missing` (legacy) → archive accepts (tiny-equivalent per tech §1.4).
  - Sandbox-HOME per `sandbox-home-in-tests.md`.
- **Deliverables**: `test/tN_archive_merge_check.sh`
- **Verify**: `bash test/tN_archive_merge_check.sh` exits 0.
- **Depends on**: T23
- **Parallel-safe-with**: T26, T28, T29, T30, T31, T32
- [ ]

## T28 — Upgrade audit log test
- **Milestone**: M4
- **Requirements**: R12, R13, AC4
- **Decisions**: —
- **Scope**: Author `test/tN_upgrade_audit.sh`. Invoke `set_tier` with:
  - Valid transition `standard → audited` with role `TPM` and reason `"test upgrade"` → assert STATUS Notes gains a line matching the R13 format `YYYY-MM-DD TPM — tier upgrade standard→audited: test upgrade`.
  - Invalid transition `standard → tiny` → exit non-zero, STATUS unchanged byte-identical.
  - Same-tier "upgrade" (e.g. `standard → standard`) → Developer-chosen disposition, consistent with T3.
  - Sandbox-HOME.
- **Deliverables**: `test/tN_upgrade_audit.sh`
- **Verify**: `bash test/tN_upgrade_audit.sh` exits 0.
- **Depends on**: T2
- **Parallel-safe-with**: T26, T27, T29, T30, T31, T32
- [ ]

## T29 — Auto-upgrade trigger tests
- **Milestone**: M4
- **Requirements**: R14, AC9
- **Decisions**: D7
- **Scope**: Author `test/tN_auto_upgrade_triggers.sh`. Three independent fixtures per PRD AC9:
  - **Diff trigger (sub-a, lines)**: fake git repo with 250-line single-file diff; assert the threshold check in `implement.md` flow emits the WARNING + STATUS Notes pending line.
  - **Diff trigger (sub-b, files)**: fake 100-line diff across 5 files; same expectation.
  - **Security-must finding**: mock aggregator verdict dir containing `axis: security` + `severity: must` finding; assert `bin/specflow-aggregate-verdicts` emits `suggest-audited-upgrade:` line AND (via step 7c consumer logic) `set_tier` was invoked with reason `security-must finding in <task>`.
  - **Sensitive-path trigger**: fake PRD containing reference to `settings.json` / `auth` path; assert PM-side suggestion surfaces.
  - Each trigger is independent; test does NOT require full `/specflow:implement` invocation — targeted helper/function invocations are acceptable per tech §4.4.
  - Sandbox-HOME.
- **Deliverables**: `test/tN_auto_upgrade_triggers.sh`
- **Verify**: `bash test/tN_auto_upgrade_triggers.sh` exits 0.
- **Depends on**: T2, T7, T21
- **Parallel-safe-with**: T26, T27, T28, T30, T31, T32
- [ ]

## T30 — Mid-flight upgrade non-destructive test
- **Milestone**: M4
- **Requirements**: R15, AC10
- **Decisions**: —
- **Scope**: Author `test/tN_mid_flight_upgrade_nondestructive.sh`. Fixture: feature dir with `tier: tiny` and a one-line `03-prd.md`. Invoke `set_tier` to upgrade to `standard`. Assertions per PRD AC10:
  - `03-prd.md` is byte-identical pre vs post upgrade.
  - `STATUS.md` has exactly one line added (the R13 audit note).
  - `STATUS.md` has exactly one field mutated (`tier: tiny` → `tier: standard`).
  - No new files created.
  - Sandbox-HOME.
- **Deliverables**: `test/tN_mid_flight_upgrade_nondestructive.sh`
- **Verify**: `bash test/tN_mid_flight_upgrade_nondestructive.sh` exits 0.
- **Depends on**: T2
- **Parallel-safe-with**: T26, T27, T28, T29, T31, T32
- [ ]

## T31 — Tiny inline review default test
- **Milestone**: M4
- **Requirements**: R16, AC11
- **Decisions**: —
- **Scope**: Author `test/tN_inline_review_default.sh`. Two cases:
  - `/specflow:implement` dry-run on `tiny` feature without explicit `--inline-review` flag → stdout/stderr announces inline review is SKIPPED.
  - `/specflow:implement` dry-run on `standard` feature → stdout/stderr announces inline review WILL RUN.
  - "Dry-run" is a structural inspection of the command's gate logic; if `implement.md` doesn't already have a dry-run mode, the test targets the specific gate code via a sourced helper or structural grep. Developer picks approach at task start.
  - Sandbox-HOME.
- **Deliverables**: `test/tN_inline_review_default.sh`
- **Verify**: `bash test/tN_inline_review_default.sh` exits 0.
- **Depends on**: T21
- **Parallel-safe-with**: T26, T27, T28, T29, T30, T32
- [ ]

## T32 — Tier-proposal prompt text test
- **Milestone**: M4
- **Requirements**: R5, AC12
- **Decisions**: D6
- **Scope**: Author `test/tN_tier_proposal_prompt.sh`. Assert that `/specflow:request` invoked (structurally; via helper or grep) with a raw ask and without `--tier` produces a PM prompt containing:
  - A proposed tier value (one of `tiny|standard|audited`).
  - One-line definitions for each of the three tiers.
  - An invitation for confirmation or override.
  - Determinism: same raw ask → same proposed tier across runs. Complements T25 (which tests the heuristic in isolation; T32 tests the prompt shape).
- **Deliverables**: `test/tN_tier_proposal_prompt.sh`
- **Verify**: `bash test/tN_tier_proposal_prompt.sh` exits 0.
- **Depends on**: T18, T19
- **Parallel-safe-with**: T26, T27, T28, T29, T30, T31
- [ ]

## T33 — Register W4 tests in `test/smoke.sh`
- **Milestone**: M4
- **Requirements**: all ACs above
- **Decisions**: —
- **Scope**: Append registration lines to `test/smoke.sh` for T3, T5, T8, T17, T25, T26, T27, T28, T29, T30, T31, T32 test files. Each registration follows the existing pattern in `test/smoke.sh` (read the file at task start for the exact shape). Note: T26–T32's test files must already exist (this is why T33 sequences AFTER T26–T32 within W4). Earlier wave tests (T3, T5, T8, T17, T25) may already have been registered by their own wave if the convention is test-author-registers; Developer confirms by reading `test/smoke.sh` at task start and only appends missing registrations.
  - Per `tpm/parallel-safe-append-sections.md`, append-only collisions on `test/smoke.sh` are expected if multiple waves try to self-register; to keep things clean, T33 is the single task that owns the W4 registrations. W0/W1/W2 test-authors may self-register if convention requires, OR T33 covers them. Developer reads the existing smoke.sh pattern and picks the consistent approach.
- **Deliverables**: modified `test/smoke.sh`
- **Verify**: `bash test/smoke.sh` exits 0 (runs all registered tests). Each of the 12 new tests appears at least once in `test/smoke.sh`.
- **Depends on**: T3, T5, T8, T17, T25, T26, T27, T28, T29, T30, T31, T32
- **Parallel-safe-with**: — (runs last in W4, sequential after W4a)
- [ ]

### Wave 5 — Docs + template stage-checklist (2 tasks)

## T34 — README / docs update
- **Milestone**: M5
- **Requirements**: (documentation for R1–R20)
- **Decisions**: —
- **Scope**: Update top-level `README.md` (if present) with a new section documenting:
  - Three tiers (`tiny`/`standard`/`audited`) and their stage matrix (copy from PRD R10).
  - Tier declaration at `/specflow:request` time via `--tier` or propose-and-confirm prompt.
  - Monotonic upgrade rule (R12) and audit-log format (R13).
  - New `/specflow:validate` command and retired `brainstorm`/`tasks`/`verify`/`gap-check` (with their successors).
  - Archive merge-check behaviour and `--allow-unmerged REASON` escape hatch (R9).
  - Reference to `bin/specflow-tier` as the single tier-reading helper (R11).
  - If no `README.md` exists, author a specflow-facing doc at `.spec-workflow/README.md` or equivalent (Developer picks at task start based on existing repo doc convention).
  - Developer reads `.claude/README.md` for any existing conventions that may override.
  - Non-destructive: any existing README content is preserved; new content is additive.
- **Deliverables**: modified `README.md` (or new doc file)
- **Verify**: `grep -qi 'tier' README.md 2>/dev/null || grep -qi 'tier' .spec-workflow/README.md 2>/dev/null`. Manual review for clarity.
- **Depends on**: —
- **Parallel-safe-with**: T35
- [ ]

## T35 — Finalise `_template/STATUS.md` stage checklist (new shape)
- **Milestone**: M5
- **Requirements**: R19
- **Decisions**: D9, D10
- **Scope**: Update the `## Stage checklist` section of `.spec-workflow/features/_template/STATUS.md` to the new shape (retire `tasks`, `gap-check`, `verify` boxes; add `validate` box). Target shape verbatim:
  ```markdown
  ## Stage checklist
  - [ ] request       (00-request.md)              — PM
  - [ ] design        (02-design/)                 — Designer (skip if has-ui: false)
  - [ ] prd           (03-prd.md)                  — PM
  - [ ] tech          (04-tech.md)                 — Architect
  - [ ] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
  - [ ] implement     (05-plan.md tasks checked off) — Developer
  - [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
  - [ ] archive       (moved to .spec-workflow/archive/)     — TPM
  ```
  `brainstorm` is absorbed into PRD `## Exploration` per PRD R4 — its standalone box is removed. This is the shape for `standard` tier; tier-aware skipping per R10 happens at dispatch time, not in the template. Note: T1 (W0) already added the `tier:` field to the header of this file; T35 edits only the `## Stage checklist` section. Coordination: if T1 and T35 edits would be textually adjacent (unlikely — header vs checklist are separate sections), the Developer folds T35's content into T1 instead. Flag at task start.
- **Deliverables**: modified `.spec-workflow/features/_template/STATUS.md`
- **Verify**: `grep -q '\[ \] validate' .spec-workflow/features/_template/STATUS.md` exits 0 AND `! grep -qE '\[ \] (tasks|verify|gap-check|brainstorm)' .spec-workflow/features/_template/STATUS.md`.
- **Depends on**: T1
- **Parallel-safe-with**: T34
- [ ]

---

## 4. STATUS Notes convention for this feature

Per `tpm/wave-bookkeeping-commit-per-wave.md`: task agents do NOT toggle their own checkboxes and do NOT append their own STATUS Notes lines. The orchestrator creates one bookkeeping commit per wave covering:

1. Toggle `- [ ]` → `- [x]` for all completed tasks in `05-plan.md` (this file; new merged shape per PRD R19).
2. Append the wave's STATUS note to `STATUS.md`.

Task commits touch only their deliverable files. This prevents the checkbox-loss pattern documented in `tpm/checkbox-lost-in-parallel-merge.md` (seen at 4 prior waves).

---

## 5. Team memory

Applied entries (relevance notes):

- `tpm/parallel-safe-requires-different-files.md` (global) — drives wave splits across W1 (T9 vs T10) and W3 (all 8 tasks on distinct files); drives T6 serialisation after T4+T5 and T33 serialisation after T26–T32.
- `tpm/parallel-safe-append-sections.md` (global) — flags expected append-only collision on `test/smoke.sh` (T33) and on this feature's own STATUS Notes per-wave commit; keep-both mechanical resolution acceptable.
- `tpm/wave-bookkeeping-commit-per-wave.md` (global) — §4 convention above; task agents do NOT self-toggle checkboxes or append STATUS notes; orchestrator lands one post-wave bookkeeping commit.
- `tpm/briefing-contradicts-schema.md` (local) — T16 quotes PRD R18 verbatim for the `## Validate verdict` header contract; T19 quotes the D6 keyword sets verbatim rather than paraphrasing.
- `shared/dogfood-paradox-third-occurrence.md` (local) — drives §1.2 and §2.3 structural-vs-runtime matrix; no task in this plan depends on the self-shipped mechanism being active during own implement.
