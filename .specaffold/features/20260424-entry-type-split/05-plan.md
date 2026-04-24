# Plan — entry-type-split

- **Feature**: `20260424-entry-type-split`
- **Stage**: plan
- **Author**: TPM
- **Date**: 2026-04-24
- **Tier**: audited (every wave merge runs reviewer-security + reviewer-performance + reviewer-style per `.claude/rules/reviewer/*.md`)
- **Shape**: **new merged form** (narrative + task checklist in one file per PRD R19). No `06-tasks.md` will be authored for this feature.

PRD: `03-prd.md` (R1–R15, AC1–AC15 + AC-runtime-deferred, D1–D8).
Tech: `04-tech.md` (tech-D1..tech-D10; §4.3 architect-gate APPROVED for tier=audited).

---

## 1. Approach

This feature splits the single `/scaff:request` intake into three work-typed entry commands (`/scaff:request` feature, `/scaff:bug` bug, `/scaff:chore` chore) while preserving `/scaff:request` backward-compat byte-for-byte (except the single `work-type: feature` STATUS line per R13 / AC3). The downstream stage machine is unchanged; only intake, PRD template, slug convention, tier-keyword consultation, and per-type retrospective prompt branch.

The plan sequences the work as **three strict serial waves**, with strong parallel-safety within each wave. The serialisation is not busywork: each wave's contents are consumers of the previous wave's producers, and strict wave boundaries make the consumer-safety invariant a merge-gate property rather than a per-task `Depends on:` chain (see `tpm/two-wave-serial-resolves-cross-layer-merge-order-constraint.md` — pattern applied, widened to three waves because the producer-consumer chain has three layers here, not two).

- **W1 — foundation / producers** — the new `bin/scaff-stage-matrix` helper (tech-D1), its unit tests, the three PRD template files (D7/tech-D7), the `_template/STATUS.md` `work-type:` field (R13/tech-D2), pm.md's three probe branches + single master keyword table (tech-D5, tech-D6), and tpm.md's per-type retrospective prompts (R11/D5). Every artefact W2 consumes is authored in W1.
- **W2 — dispatch / consumers** — the three entry commands (`request.md` minimal-diff work-type=feature addition for AC3; `bug.md` new; `chore.md` new), the two consumers that wire `bin/scaff-stage-matrix` into `/scaff:next` and `/scaff:implement` skip decisions, and structural AC tests for the new commands + backward-compat shape assertion (tech-D8) for `/scaff:request`.
- **W3 — documentation, final structural gate, RUNTIME HANDOFF** — README.md + structural grep gate across pm.md/tpm.md/_template/STATUS.md for AC4/AC5/AC10/AC11/AC12, plus the RUNTIME HANDOFF STATUS Notes line pre-committed per tech-D10 / D8 / `shared/dogfood-paradox-third-occurrence.md` ninth-occurrence discipline.

The feature itself **cannot** runtime-exercise `/scaff:bug` or `/scaff:chore` during its own validate — the commands do not exist until after W2 merges. All §6.1 ACs are structural; §6.2 `AC-runtime-deferred` defers runtime verification to the next real bug/chore ticket after archive (explicit handoff in W3 T17; see §3 risk #1 and §4).

---

## 2. Wave schedule

| Wave | Purpose                                                                 | Task IDs       | Parallelisation notes                                                                 |
|------|-------------------------------------------------------------------------|----------------|---------------------------------------------------------------------------------------|
| W1   | Foundation — stage-matrix helper + PRD templates + STATUS field + agent-prompt probe/retro branches + matrix unit tests + template shape tests | T1–T7          | All 7 tasks write to disjoint files / directories. Fully parallel-safe.              |
| W2   | Dispatch — 3 entry commands + 2 consumers of `bin/scaff-stage-matrix` + new-command shape tests + backward-compat shape assertion on `/scaff:request` | T8–T14         | All 7 tasks write to disjoint files. Fully parallel-safe.                             |
| W3   | Documentation + final structural gate + RUNTIME HANDOFF pre-commit     | T15–T17        | T15 edits `README.md`; T16 writes a new test file; T17 writes `STATUS.md`. Disjoint. |

**Wave count**: 3. **Task count**: 17. **Per-wave counts**: W1 = 7 · W2 = 7 · W3 = 3.

### Parallel-safety analysis per wave

**W1** — Seven tasks across seven disjoint file namespaces. T1 writes `bin/scaff-stage-matrix` (new file); T2 writes `test/t102_stage_matrix.sh` (new); T3 writes three new files under `.claude/commands/scaff/prd-templates/` (new directory — no pre-existing collision); T4 edits `.specaffold/features/_template/STATUS.md` (one added line, no other edits); T5 edits `.claude/agents/scaff/pm.md` (consolidates both probe-branch and keyword-table work — they both live in pm.md, so a single task owns the whole file edit); T6 edits `.claude/agents/scaff/tpm.md`; T7 writes `test/t103_prd_templates_shape.sh` (new). No two tasks write to the same file; no shared config / fixture collision.

Why T5 bundles probe branches + keyword table: both deliverables edit `pm.md`. Splitting would create a same-file hazard (`tpm/parallel-safe-requires-different-files.md`: tasks are parallel-safe only if they edit different files). Combined into one task; still well under the ~1-hour target because the content is additive (two new `## When invoked for /scaff:<cmd>` sections + one 3-row master table replacing the current feature-only keyword list).

**W2** — Seven tasks across seven disjoint file namespaces. T8 edits `.claude/commands/scaff/next.md`; T9 edits `.claude/commands/scaff/implement.md`; T10 writes new `.claude/commands/scaff/bug.md`; T11 writes new `.claude/commands/scaff/chore.md`; T12 edits `.claude/commands/scaff/request.md` (one added line — work-type=feature STATUS setter per AC3 minimal-diff); T13 writes new `test/t104_entry_commands_shape.sh`; T14 writes new `test/t105_request_backward_compat.sh`. No file overlap.

All five command-file tasks (T8–T12) live under `.claude/commands/scaff/` but each touches a different file — parallel-safe. All seven tasks depend on W1 artefacts (matrix helper, PRD templates, keyword table, STATUS template field); none depends on any W2 peer (cross-task dependencies inside W2 are nil by design).

**W3** — Three tasks. T15 edits `README.md`. T16 writes new `test/t106_pm_tpm_status_shape.sh`. T17 edits this feature's own `STATUS.md` (RUNTIME HANDOFF pre-commit). All disjoint; parallel-safe.

### Test filename pre-declaration (per `tpm/pre-declare-test-filenames-in-06-tasks.md`)

Next available counter as of 2026-04-24: `t102` (last used: `t101` in `20260420-flow-monitor-control-plane`). Wave assignments:

- T2 → `test/t102_stage_matrix.sh`
- T7 → `test/t103_prd_templates_shape.sh`
- T13 → `test/t104_entry_commands_shape.sh`
- T14 → `test/t105_request_backward_compat.sh`
- T16 → `test/t106_pm_tpm_status_shape.sh`

No same-wave test-filename collisions (`grep 'test/' 05-plan.md | sort | uniq -d` returns empty).

---

## 3. Risks

1. **Dogfood paradox (tenth occurrence)** — This feature ships the `/scaff:bug` and `/scaff:chore` commands. They cannot be exercised against themselves during implement or validate; the commands do not exist until W2 merges. All §6.1 ACs are structural; §6.2 `AC-runtime-deferred` is the explicit handoff. **Mitigation**: T17 pre-commits the RUNTIME HANDOFF STATUS Notes line in W3 (tech-D10; ninth-occurrence-promoted discipline from `shared/dogfood-paradox-third-occurrence.md`). The sentinel regex `^- [0-9]{4}-[0-9]{2}-[0-9]{2} .* RUNTIME HANDOFF \(for successor bug/chore\):` is asserted structurally by T16.

2. **`/scaff:request` backward compat (R15 / AC3 / AC15)** — Any change to `pm.md` or `request.md` that alters how feature intake produces `00-request.md` / `03-prd.md` shape is a regression. **Mitigation**: (a) T12 (request.md edit) is scoped to a single-line addition — the `work-type: feature` STATUS setter — and nothing else. (b) T14 runs a grep-based shape assertion per tech-D8: required section headings still present in the feature PRD template (`## Problem`, `## Goals`, `## Non-goals`, `## Requirements`, `## Acceptance criteria`, `## Decisions`, `## Open questions`); STATUS diff limited to the single permitted R13 addition. The test runs sandbox-HOME per `.claude/rules/bash/sandbox-home-in-tests.md`. (c) T5 (pm.md additive edits only — new parallel `## When invoked for /scaff:bug` / `/scaff:chore` sections + a 3-row master keyword table replacing the feature-only list; no content removed from the feature probe).

3. **Stage-matrix consumer fanout (tech-D9 ABI lock)** — `/scaff:next` (T8) and `/scaff:implement` (T9) both consume `stage_status <work-type> <tier> <stage>` (ternary: `required | optional | skipped`). If the ABI drifts mid-flight, both consumers break together. **Mitigation**: T1 ships the ternary ABI as the single public function per tech-D9; T2 unit-tests every one of the 27 combinations (3 types × 3 tiers × 3 stage-categories) against the D3 matrix. The ABI is frozen at W1 close and must not change during W2 — any consumer need (e.g. a fourth enum value) is escalated as `/scaff:update-tech`, not patched inside W2.

4. **Pre-checked checkboxes anti-pattern** — Per `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md`, every `- [ ]` below stays unchecked. TPM never writes `- [x]` at plan time; the orchestrator's per-wave bookkeeping commit is the sole `[x]` writer. Also per `tpm/checkbox-lost-in-parallel-merge.md`, post-wave audit flips any `[ ]` → `[x]` for tasks the wave actually merged.

5. **Placeholder-token hazard** — Per `tpm/task-scope-fence-literal-placeholder-hazard.md`, no `tN_` / `<fill>` / `<new file>` placeholders appear in any task's `Deliverables:` or `Verify:` field. All test filenames are pre-filled (§2 above).

6. **Legacy `work-type` field handling (tech-D3)** — `get_work_type` defaults to `feature` when the STATUS field is absent (legacy archives). **Tested** by T2's matrix unit test which exercises the default path; also implicitly validated by T14's backward-compat assertion (a pre-feature fixture invocation of `/scaff:request` predates the `work-type:` field's existence and must still resolve to `feature`).

7. **Wave-merge reviewer axis budget (tier=audited)** — Every wave merge runs reviewer-security + reviewer-performance + reviewer-style per `.claude/rules/reviewer/*.md`. Anticipated axis hits:
   - **security** — T1's `bin/scaff-stage-matrix` takes `work-type` + `tier` + `stage` as positional args; strict allowlist match (no shell interpolation); `REPO_ROOT` boundary check not required here because the helper does not touch files. T10/T11's bug-arg auto-classify is a pure POSIX-string cascade (no shell interpolation); arg stored verbatim. Per PRD D1 and tech §4.3 architect-gate sign-off: security surface is light.
   - **performance** — All new code paths run at most once per `/scaff:*` invocation; none are on a tight loop or in a hook. No `shell-out-in-loop` risk. Expected green.
   - **style** — T1's new bash helper must be bash 3.2 / BSD portable per `.claude/rules/bash/bash-32-portability.md` (no `readlink -f`, no `jq`, no `[[ =~ ]]` for portability-critical logic, no `mapfile`). Test scripts sandbox HOME per `.claude/rules/bash/sandbox-home-in-tests.md`.

---

## 4. Dogfood paradox handling

Per PRD §9 and tech-D10, this feature invokes the dogfood paradox (tenth occurrence; `shared/dogfood-paradox-third-occurrence.md` filename is legacy, records 9 prior).

Discipline applied at plan time:

1. **Every §6.1 AC is structural** — file-existence grep, heading-grep, STATUS-line grep, classify-function-fixture assertion. No §6.1 AC requires `/scaff:bug` or `/scaff:chore` to fire end-to-end.
2. **§6.2 AC-runtime-deferred is honoured in W3 T17** — TPM authors the RUNTIME HANDOFF STATUS Notes line **in a pre-committed task in the final wave** per the ninth-occurrence-promoted discipline, not at archive-time as an afterthought. Exact task title: **T17 — Pre-commit RUNTIME HANDOFF STATUS Notes line for next bug/chore successor**.
3. **T16 structurally asserts** the handoff line is present via the tight regex `^- [0-9]{4}-[0-9]{2}-[0-9]{2} .* RUNTIME HANDOFF \(for successor bug/chore\):` (tech-D10). This is the runtime-deferred equivalent of a compile check: it doesn't verify the command fires, but it verifies the handoff contract is in place for the next feature to honour.
4. **QA-tester guidance (not authored here but stated for clarity at plan time)** — structural PASS vs runtime PASS per AC. Every §6.1 AC gets structural PASS; §6.2 `AC-runtime-deferred` is marked deferred with a pointer to T17's handoff line; validate must not mark runtime ACs as PASS from "build succeeds".

---

## 5. Open questions

None. Every tech gap surfaced during `/scaff:plan` was closed by the architect's 10 tech-Ds; every PRD decision (D1–D8) is bound; every risk in §3 has a concrete mitigation; every task in §6 has a runnable `Verify:` command or an explicit documentation justification.

---

## 6. Task checklist

Each task below uses the new-merged-form task block shape per `tpm.appendix.md` §"Task format and wave schedule rules".

---

### W1 — Foundation (producers)

## T1 — Author `bin/scaff-stage-matrix` ternary classifier helper

- **Milestone**: M1
- **Requirements**: R10, R10.1
- **Decisions**: D3, tech-D1, tech-D9
- **Scope**: Create a new sourced bash library at `bin/scaff-stage-matrix` mirroring `bin/scaff-tier`'s conventions (shebang, double-source guard via `SCAFF_STAGE_MATRIX_LOADED`, header comment enumerating public functions). Public function per tech-D9: `stage_status <work-type> <tier> <stage>` which emits one of `required` | `optional` | `skipped` on stdout for every valid `(work-type, tier, stage)` triple, matching the 9-cell × 8-stage matrix in PRD §8 D3 byte-for-byte. Two thin wrappers permitted: `is_stage_required` (returns 0 iff stage_status == required) and `is_stage_skipped` (returns 0 iff stage_status == skipped). Usage errors (unknown work-type, unknown tier, unknown stage) emit a single-line usage message to stderr and exit 2. Bash 3.2 / BSD portable per `.claude/rules/bash/bash-32-portability.md` — no `[[ =~ ]]` for enum matching (use `case`), no `jq`, no `mapfile`. No dependencies on `REPO_ROOT` (the function is pure: no file I/O).
- **Deliverables**: `bin/scaff-stage-matrix` (new file, executable).
- **Verify**: `bash test/t102_stage_matrix.sh` (T2 authors this test; T1 delivers the helper the test exercises). Also `bash -n bin/scaff-stage-matrix` for syntax-check. Also `grep -qE '^stage_status\(\)' bin/scaff-stage-matrix` to confirm public-function presence.
- **Depends on**: —
- **Parallel-safe-with**: T2, T3, T4, T5, T6, T7
- [ ]

## T2 — Unit-test `stage_status` against all 72 `(work-type × tier × stage)` cells

- **Milestone**: M1
- **Requirements**: R10, R10.1
- **Decisions**: D3, tech-D1, tech-D9
- **Scope**: Author `test/t102_stage_matrix.sh` asserting `stage_status <work-type> <tier> <stage>` returns the expected ternary enum for every one of the 72 cells (3 work-types × 3 tiers × 8 stages from the D3 matrix). Include explicit fixtures for the key asymmetries flagged in D3 rationale: `stage_status bug tiny validate` → `required` (bug regression); `stage_status chore tiny design` → `skipped` (chore has-ui=false by construction); `stage_status feature tiny tech` → `skipped` (preserves `tier_skips_stage` byte-identity per R10.1). Also assert `stage_status bogus tiny validate` exits 2 with usage-error on stderr (malformed input path). No shell-out in loops (performance axis compliance). Test script uses sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md` (the helper does not read HOME, but the discipline is template-uniform per the rule).
- **Deliverables**: `test/t102_stage_matrix.sh` (new file, executable).
- **Verify**: `bash test/t102_stage_matrix.sh` prints `PASS` and exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T1, T3, T4, T5, T6, T7
- [ ]

## T3 — Author the three PRD template files under `.claude/commands/scaff/prd-templates/`

- **Milestone**: M1
- **Requirements**: R8, R8.1
- **Decisions**: D2, D7, tech-D7
- **Scope**: Create a new directory `.claude/commands/scaff/prd-templates/` (D7 location) and three new files:
  1. `feature.md` — byte-identical feature PRD shape (Problem / Goals / Non-goals / Users / Requirements / ACs / Decisions / Open questions headings) with `<!-- placeholder: <description> -->` HTML-comment fill-in markers at each section body per tech-D7. Canonical source: today's PRD shape as seen in prior archives (e.g. `.specaffold/archive/20260421-rename-to-specaffold/03-prd.md`).
  2. `bug.md` — sections per R8: Problem, Source (with `type: url | ticket-id | description` subkey per D1), Repro, Expected, Actual, Environment, Root cause, Fix requirements (R1..Rn), Regression test requirements, Acceptance criteria (AC1..ACn), Decisions, Open questions. Use HTML-comment placeholders.
  3. `chore.md` — checklist-shaped per D2: Summary, Scope, Reason, Checklist items (literal skeleton entry `- [ ] <item> — verify: <assertion>` per AC6), Verify assertions (rolled up), Out-of-scope. Use HTML-comment placeholders.
  All three templates are English-content per `.claude/rules/common/language-preferences.md` carve-out (b). No frontmatter required (these are templates, not rules / agents).
- **Deliverables**: `.claude/commands/scaff/prd-templates/feature.md`, `.claude/commands/scaff/prd-templates/bug.md`, `.claude/commands/scaff/prd-templates/chore.md` (all new).
- **Verify**: `bash test/t103_prd_templates_shape.sh` (T7 authors this test). Also `ls .claude/commands/scaff/prd-templates/ | sort | tr '\n' ' '` outputs `bug.md chore.md feature.md `.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T4, T5, T6, T7
- [ ]

## T4 — Add `work-type:` field to `.specaffold/features/_template/STATUS.md`

- **Milestone**: M1
- **Requirements**: R12, R13
- **Decisions**: D6, tech-D2, tech-D3
- **Scope**: Edit `.specaffold/features/_template/STATUS.md` to insert one new line `- **work-type**: feature` between the existing `- **has-ui**:` line and the `- **tier**:` line. Default value is `feature` per tech-D3 (every legacy archive is a feature by construction; the default is semantically correct, not a fallback stub). No other edits; the `_template/` directory remains a single template per R12 / AC12 (no per-type subdirectories created). Per `.claude/rules/common/no-force-on-user-paths.md`, the file is committed in git; no `.bak` needed for a template edit.
- **Deliverables**: `.specaffold/features/_template/STATUS.md` (edited — one line added).
- **Verify**: `grep -c '^- \*\*work-type\*\*: feature$' .specaffold/features/_template/STATUS.md` returns `1`. Also `diff -u` of the template before/after shows exactly one added line between `has-ui` and `tier`.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T5, T6, T7
- [ ]

## T5 — Add three parallel `## When invoked for /scaff:<cmd>` probe sections + single master 3-row keyword table to `pm.md`

- **Milestone**: M1
- **Requirements**: R4, R5, R6, R7, R7.1, R8.1
- **Decisions**: D1, D6, D7, tech-D5, tech-D6
- **Scope**: Edit `.claude/agents/scaff/pm.md` additively (no deletion of existing content; current `## When invoked for /scaff:request` section remains byte-identical per AC3 discipline). Additions:
  1. **`## When invoked for /scaff:bug`** — new parallel section per tech-D5. Probe elicits (a) repro steps (ordered list), (b) expected behaviour, (c) actual behaviour, (d) environment (OS / version / relevant config), (e) the verbatim source value + detected type per R4 / D1. No has-ui probe. When producing `03-prd.md`, reads STATUS `work-type=bug` and selects `.claude/commands/scaff/prd-templates/bug.md` (R8.1).
  2. **`## When invoked for /scaff:chore`** — new parallel section per tech-D5. Probe elicits (a) scope, (b) reason, (c) verify-assertion per R5. No has-ui probe (default has-ui=false by construction). When producing `03-prd.md`, reads STATUS `work-type=chore` and selects `.claude/commands/scaff/prd-templates/chore.md` (D2 / R8.1).
  3. **Single 3-row master keyword table** per tech-D6 / R7.1, replacing the current feature-only keyword list. Columns: `type`, `tiny-keywords`, `audited-keywords`. Rows: feature (current keywords preserved verbatim), bug (R6 keyword set: tiny = `typo, wording, copy change, off-by-one, wrong label`; audited = `crash, data loss, data corruption, regression, security, xss, csrf, sql injection, auth bypass, privilege escalation, memory leak, race condition`), chore (R7 keyword set: tiny = `comment, docstring, readme, rename, cleanup, dead code, formatting, lint`; audited = `bump dep, dependency update, security patch, ci migration, settings.json, migration`). Default = standard is a footnote.

  All content English per `.claude/rules/common/language-preferences.md`. Changes to pm.md are additive; the feature-branch probe is unchanged so AC3's `/scaff:request` byte-identity survives.
- **Deliverables**: `.claude/agents/scaff/pm.md` (edited — two new `## When invoked for /scaff:<cmd>` sections + one keyword-table edit).
- **Verify**: structural grep assertions run by T16 (`bash test/t106_pm_tpm_status_shape.sh`). Inline quick-check: `grep -c '^## When invoked for /scaff:bug' .claude/agents/scaff/pm.md` returns `1`; `grep -c '^## When invoked for /scaff:chore' .claude/agents/scaff/pm.md` returns `1`; `grep -F 'race condition' .claude/agents/scaff/pm.md` returns one line (R6 audited bug keyword anchor); `grep -F 'bump dep' .claude/agents/scaff/pm.md` returns one line (R7 audited chore keyword anchor).
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T6, T7
- [ ]

## T6 — Add per-type retrospective prompts + `work-type` read to `tpm.md`

- **Milestone**: M1
- **Requirements**: R11
- **Decisions**: D5, D6
- **Scope**: Edit `.claude/agents/scaff/tpm.md` to add the three per-type retrospective prompts (R11 / D5) in the `## Retrospective protocol` section (or a new subsection `### Per-type retrospective prompts`). Prompts quoted verbatim per `tpm/briefing-contradicts-schema.md` discipline:
  - feature: `"What technical decisions surprised you? Architecture patterns worth extracting into memory?"`
  - bug: `"What guardrail (test, review axis, rule) would have caught this bug before release? Where in the pipeline did it slip through?"`
  - chore: `"Could this cleanup have been automated? Does it indicate a broader tech-debt pattern worth naming?"`

  Add one sentence stating TPM reads STATUS `work-type` at archive-retrospective time (via the pattern sourced from `bin/scaff-tier`'s `get_tier` convention; legacy default = feature per tech-D3) and dispatches to the matching prompt. No other content changes; tpm.md additions are purely additive.
- **Deliverables**: `.claude/agents/scaff/tpm.md` (edited — three prompt strings added + one dispatch-explanation sentence).
- **Verify**: structural grep run by T16. Inline quick-check: `grep -F 'What technical decisions surprised you? Architecture patterns worth extracting into memory?' .claude/agents/scaff/tpm.md` returns one line; `grep -F 'What guardrail (test, review axis, rule) would have caught this bug before release?' .claude/agents/scaff/tpm.md` returns one line; `grep -F 'Could this cleanup have been automated? Does it indicate a broader tech-debt pattern worth naming?' .claude/agents/scaff/tpm.md` returns one line.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T5, T7
- [ ]

## T7 — Test: PRD-template shape assertions (AC6, AC12 support)

- **Milestone**: M1
- **Requirements**: R8 (AC6), R12 (AC12)
- **Decisions**: D2, D7, tech-D7
- **Scope**: Author `test/t103_prd_templates_shape.sh`. Assertions:
  - `feature.md` contains all required headings (`## Problem`, `## Goals`, `## Non-goals`, `## Users`, `## Requirements`, `## Acceptance criteria`, `## Decisions`, `## Open questions`) verified via `grep -c '^## <heading>$'` returning ≥ 1 per heading. Per AC6.
  - `bug.md` contains `## Source`, and the Source section lists all three `type:` values (`url`, `ticket-id`, `description`) per R14 / D1. Also contains `## Repro`, `## Expected`, `## Actual`, `## Environment`. Per AC6.
  - `chore.md` contains the checklist skeleton marker `- [ ] <item> — verify:` (literal string, one exact occurrence or the template skeleton form). Per D2 / AC6.
  - `.specaffold/features/_template/` contains no subdirectories — `find .specaffold/features/_template/ -mindepth 1 -type d | wc -l` returns `0`. Per R12 / AC12.

  Test script uses sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md` (HOME isolation required by the rule template even for read-only checks). Bash 3.2 portable.
- **Deliverables**: `test/t103_prd_templates_shape.sh` (new, executable).
- **Verify**: `bash test/t103_prd_templates_shape.sh` prints `PASS` and exits 0 after T3 + T4 land.
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T5, T6
- [ ]

---

### W2 — Dispatch (consumers)

## T8 — Wire `bin/scaff-stage-matrix` into `/scaff:next` stage-skip logic

- **Milestone**: M2
- **Requirements**: R10, R15
- **Decisions**: D3, tech-D1, tech-D9
- **Scope**: Edit `.claude/commands/scaff/next.md` to replace (or augment) the current `tier_skips_stage`-only call with `stage_status <work-type> <tier> <stage>` from `bin/scaff-stage-matrix`. Read `work-type` from STATUS via a `get_work_type` helper (or inline `grep '^- \*\*work-type\*\*:'` per tech-D2; default to `feature` per tech-D3 when absent). Decision table for the next-stage skip predicate: if `stage_status` returns `skipped` → skip the stage (same behaviour as today's `tier_skips_stage`); if `required` → run; if `optional` → run (defer orchestrator judgement; same as today's behaviour for `standard` + design stage). Preserve R10.1 byte-identity for feature-tier cells.
- **Deliverables**: `.claude/commands/scaff/next.md` (edited).
- **Verify**: `bash -n .claude/commands/scaff/next.md 2>/dev/null || true` — markdown; no syntax check applicable. Structural grep: `grep -F 'stage_status' .claude/commands/scaff/next.md` returns ≥ 1 line. Functional: T2's matrix test (already passing from W1) exercises the helper path; the runtime skip decision is deferred to the next actual `/scaff:next` invocation which is itself a runtime-deferred structural check per dogfood paradox (structural assertion is the grep of the helper invocation).
- **Depends on**: T1 (needs `bin/scaff-stage-matrix` helper)
- **Parallel-safe-with**: T9, T10, T11, T12, T13, T14
- [ ]

## T9 — Wire `bin/scaff-stage-matrix` into `/scaff:implement` design-skip logic

- **Milestone**: M2
- **Requirements**: R10
- **Decisions**: D3, tech-D1, tech-D9
- **Scope**: Edit `.claude/commands/scaff/implement.md` to consult `stage_status <work-type> <tier> design` from `bin/scaff-stage-matrix` when deciding whether to require the design artefact; replace the existing has-ui-only heuristic with the matrix-driven decision. For `work-type=chore`, the matrix returns `skipped` for design at every tier per D3 (chores are mechanical by construction). For `work-type=feature | bug`, the current has-ui semantics are preserved: at tier=tiny the matrix returns `skipped`; at tier=standard / audited it returns `optional` (has-ui=false short-circuits as today). Do not break the current implement entry path.
- **Deliverables**: `.claude/commands/scaff/implement.md` (edited).
- **Verify**: structural grep: `grep -F 'stage_status' .claude/commands/scaff/implement.md` returns ≥ 1 line. Functional assertion carried by T2.
- **Depends on**: T1
- **Parallel-safe-with**: T8, T10, T11, T12, T13, T14
- [ ]

## T10 — Author `.claude/commands/scaff/bug.md` (new entry command)

- **Milestone**: M2
- **Requirements**: R1, R9, R14
- **Decisions**: D1, D4, D6, tech-D4
- **Scope**: Create a new markdown instruction file `.claude/commands/scaff/bug.md` parallel in structure to `request.md` (tech-D4 full-duplication; no shared helper). Contract:
  - Arg shape: `/scaff:bug "<arg>" [--tier tiny|standard|audited] [slug]`.
  - Classify `<arg>` per R14 / D1 using a POSIX cascade (no shell interpolation — security axis; no `[[ =~ ]]` for regex — portability axis): `case "$arg" in http://*|https://*) type=url ;; *) ... esac`; for ticket-id, a `case` over `[A-Z][A-Z]*-[0-9][0-9]*` glob-ish approximation plus an explicit POSIX regex via `expr "$arg" : '^[A-Z][A-Z]*-[0-9][0-9]*$'` so the match is bash-3.2 safe; fallback `description`. The full three-branch classifier is visible in the command body for AC1 grep-findability.
  - Generate slug `YYYYMMDD-fix-<body>` per R9 / D4. Reject user-supplied slug that violates the `-fix-` prefix: usage error to stderr, exit 2 (`.claude/rules/common/no-force-on-user-paths.md` — no silent correction).
  - Seed from `.specaffold/features/_template/` (R12). Write `00-request.md` with `Source: { type: <type>, value: <verbatim-arg> }`. Set STATUS `work-type: bug` (per tech-D2 via the pattern established by T4's template edit; use the same temp-file + atomic-mv discipline as `scaff-tier:set_tier` per tech-D4 §3).
  - Invoke the scaff-pm agent with the work-type=bug signal (STATUS is the dispatch signal per D6; pm.md reads STATUS and enters the bug probe branch authored in T5).

  Full-duplication rationale per tech-D4 §3: shared bash primitives (classify-bug-arg, slug-gen, set-work-type) live in inline code blocks in this file; they are not extracted to a sidecar. All file content English per `.claude/rules/common/language-preferences.md`.
- **Deliverables**: `.claude/commands/scaff/bug.md` (new file).
- **Verify**: `bash test/t104_entry_commands_shape.sh` (T13 authors). Inline quick-check: `test -f .claude/commands/scaff/bug.md`; `grep -E '^description:.*scaff:bug' .claude/commands/scaff/bug.md` returns one line; `grep -F 'type=url' .claude/commands/scaff/bug.md` + `grep -F 'ticket-id' .claude/commands/scaff/bug.md` + `grep -F 'description' .claude/commands/scaff/bug.md` all return ≥ 1 line (AC1 three-branch evidence).
- **Depends on**: T3 (consumes `prd-templates/bug.md`), T4 (consumes work-type template field), T5 (consumes pm.md bug probe branch)
- **Parallel-safe-with**: T8, T9, T11, T12, T13, T14
- [ ]

## T11 — Author `.claude/commands/scaff/chore.md` (new entry command)

- **Milestone**: M2
- **Requirements**: R2, R9
- **Decisions**: D2, D4, D6, tech-D4
- **Scope**: Create a new markdown instruction file `.claude/commands/scaff/chore.md` parallel in structure to `request.md` (tech-D4 full-duplication). Contract:
  - Arg shape: `/scaff:chore "<ask>" [--tier tiny|standard|audited] [slug]`.
  - Generate slug `YYYYMMDD-chore-<body>` per R9 / D4. Reject user-supplied slug that violates the `-chore-` prefix: usage error to stderr, exit 2.
  - Seed from `.specaffold/features/_template/` (R12). Set STATUS `work-type: chore`.
  - Invoke scaff-pm agent with work-type=chore signal (pm.md reads STATUS and enters the chore probe branch authored in T5; produces an `03-prd.md` using the checklist-shaped `prd-templates/chore.md` per D2 / R8.1).

  All file content English per `.claude/rules/common/language-preferences.md`.
- **Deliverables**: `.claude/commands/scaff/chore.md` (new file).
- **Verify**: `bash test/t104_entry_commands_shape.sh` (T13). Inline quick-check: `test -f .claude/commands/scaff/chore.md`; `grep -E '^description:.*scaff:chore' .claude/commands/scaff/chore.md` returns one line; `grep -F 'prd-templates/chore.md' .claude/commands/scaff/chore.md` returns ≥ 1 line; `grep -F 'YYYYMMDD-chore-' .claude/commands/scaff/chore.md` OR equivalent slug-prefix evidence present.
- **Depends on**: T3 (consumes `prd-templates/chore.md`), T4 (consumes work-type template field), T5 (consumes pm.md chore probe branch)
- **Parallel-safe-with**: T8, T9, T10, T12, T13, T14
- [ ]

## T12 — Minimal-diff edit to `.claude/commands/scaff/request.md` (add `work-type: feature` STATUS setter)

- **Milestone**: M2
- **Requirements**: R3, R13, R15
- **Decisions**: D6, tech-D2, tech-D3
- **Scope**: Edit `.claude/commands/scaff/request.md` to add exactly one logical change: at the point the command seeds STATUS from `_template/STATUS.md`, ensure the `work-type: feature` line is set (if the template already carries the line from T4, this may be a no-op in text terms but must be explicitly stated in the command flow so `grep -F 'work-type: feature' .claude/commands/scaff/request.md` finds the reference). This is the **sole permitted addition** per AC3; no other content changes to `request.md`. If the existing command flow already copies the template verbatim, add one instructional line ("set STATUS work-type to feature per R13"); the edit is additive and narrow.
- **Deliverables**: `.claude/commands/scaff/request.md` (edited — one added instructional line or equivalent minimal addition).
- **Verify**: `grep -F 'work-type' .claude/commands/scaff/request.md` returns ≥ 1 line. Backward-compat shape assertion in T14 confirms no other semantic drift.
- **Depends on**: T4 (consumes template field)
- **Parallel-safe-with**: T8, T9, T10, T11, T13, T14
- [ ]

## T13 — Test: structural shape assertions for `bug.md` + `chore.md` + slug prefixes (AC1, AC2, AC7)

- **Milestone**: M2
- **Requirements**: R1, R2, R9, R14
- **Decisions**: D1, D4
- **Scope**: Author `test/t104_entry_commands_shape.sh`. Assertions:
  - `.claude/commands/scaff/bug.md` exists; `grep -E '^description:.*scaff:bug'` returns one line (AC1); command body references all three classification branches (`url`, `ticket-id`, `description`) via the evidence regexes listed in T10's Verify (AC1 three-branch grep).
  - `.claude/commands/scaff/chore.md` exists; command body references `prd-templates/chore.md` and the chore slug convention `YYYYMMDD-chore-` (AC2).
  - Slug-prefix evidence per AC7: `bug.md` body contains the literal string `-fix-` in the slug-generation codefence; `chore.md` body contains the literal string `-chore-`.
  - Usage-error branches: both files contain a string matching `exit 2` or `usage` adjacent to the slug-prefix-rejection flow.

  Test script uses sandbox-HOME discipline per `.claude/rules/bash/sandbox-home-in-tests.md` (template compliance even for read-only checks). Bash 3.2 portable.
- **Deliverables**: `test/t104_entry_commands_shape.sh` (new, executable).
- **Verify**: `bash test/t104_entry_commands_shape.sh` prints `PASS` and exits 0 after T10 + T11 land.
- **Depends on**: —
- **Parallel-safe-with**: T8, T9, T10, T11, T12, T14
- [ ]

## T14 — Test: backward-compat shape assertion for `/scaff:request` (AC3, AC15)

- **Milestone**: M2
- **Requirements**: R3, R15
- **Decisions**: tech-D8
- **Scope**: Author `test/t105_request_backward_compat.sh` implementing the tech-D8 grep-based shape assertion (not byte-diff — tech-D8 rejected byte-diff as brittle). Assertions, all run in a sandbox-HOME per `.claude/rules/bash/sandbox-home-in-tests.md`:
  - `.claude/commands/scaff/request.md` diff vs its pre-change state is exactly the single added reference to `work-type` per AC3. (Approximation since the test cannot reach pre-change state at run time: assert the request.md `diff`-able shape has not regressed beyond the one added `work-type` mention — `grep -c 'work-type' .claude/commands/scaff/request.md` returns exactly `1` or `2`, and the file still contains its pre-existing anchor strings for the feature probe — `grep -qF 'why now' .claude/commands/scaff/request.md`, `grep -qF 'success criteria' .claude/commands/scaff/request.md`, `grep -qF 'out-of-scope' .claude/commands/scaff/request.md`, `grep -qF 'has-ui' .claude/commands/scaff/request.md`.)
  - Feature PRD template (`prd-templates/feature.md`) preserves the canonical feature PRD headings per AC6 feature: `grep -c '^## Problem$' prd-templates/feature.md` ≥ 1, similarly for `## Goals`, `## Non-goals`, `## Requirements`, `## Acceptance criteria`, `## Decisions`, `## Open questions`.
  - pm.md `/scaff:request` section still contains the existing probe anchor strings (`why now`, `success criteria`, `out-of-scope`, `has-ui`) — verified by `grep -qF` per anchor after the section header `## When invoked for /scaff:request`. (AC15 byte-identity shape-assertion equivalent per tech-D8 §3 "include at least one probe-content spot-check grep".)

  The test is English-content per `.claude/rules/common/language-preferences.md`. Bash 3.2 / BSD portable.
- **Deliverables**: `test/t105_request_backward_compat.sh` (new, executable).
- **Verify**: `bash test/t105_request_backward_compat.sh` prints `PASS` and exits 0 after T3 + T5 + T12 land.
- **Depends on**: —
- **Parallel-safe-with**: T8, T9, T10, T11, T12, T13
- [ ]

---

### W3 — Documentation + final gate + RUNTIME HANDOFF

## T15 — Update `README.md` to document `/scaff:bug`, `/scaff:chore`, per-type slug conventions

- **Milestone**: M3
- **Requirements**: R15
- **Decisions**: D4, D5
- **Scope**: Edit `README.md` additively: add the two new entry commands to the command reference (mention `/scaff:bug` and `/scaff:chore` alongside the existing `/scaff:request`). Document the per-type slug convention: `YYYYMMDD-<body>` for feature (unchanged), `YYYYMMDD-fix-<body>` for bug, `YYYYMMDD-chore-<body>` for chore. Briefly note the per-type PM probe shapes (feature: why-now/success/has-ui/out-of-scope; bug: repro/expected/actual/environment; chore: scope/reason/verify-assertion). English-content per `.claude/rules/common/language-preferences.md` carve-out (b). No `README.zh-TW.md` exists at the repo root (verified via `find . -maxdepth 2 -name 'README.zh-TW.md'` → empty); scope is English README only.
- **Deliverables**: `README.md` (edited — additive command-reference entries).
- **Verify**: `grep -F '/scaff:bug' README.md` returns ≥ 1 line; `grep -F '/scaff:chore' README.md` returns ≥ 1 line; `grep -F '-fix-' README.md` returns ≥ 1 line (slug convention evidence); `grep -F '-chore-' README.md` returns ≥ 1 line.
- **Depends on**: —
- **Parallel-safe-with**: T16, T17
- [ ]

## T16 — Test: structural grep gates for pm.md / tpm.md / _template/STATUS.md + RUNTIME HANDOFF sentinel (AC4, AC5, AC10, AC11, AC12, §6.2 assertion hook)

- **Milestone**: M3
- **Requirements**: R4, R5, R6, R7, R11, R12, R13
- **Decisions**: D5, D6, tech-D10
- **Scope**: Author `test/t106_pm_tpm_status_shape.sh` consolidating the structural grep gates that are not covered by T2 (matrix cells), T7 (PRD templates), T13 (new command shapes), or T14 (`/scaff:request` backward compat). Assertions:
  - **AC4** — `grep -c '^## When invoked for /scaff:bug' .claude/agents/scaff/pm.md` returns `1`; likewise for `/scaff:chore`.
  - **AC5** — pm.md contains at least one keyword from each of R6's tiny / audited bug lists and R7's tiny / audited chore lists (fixed anchors: `race condition`, `typo`, `bump dep`, `cleanup`). `grep -F` each anchor; each returns ≥ 1 line.
  - **AC10** — tpm.md contains all three verbatim retrospective prompts (R11). `grep -F` each full prompt string; each returns exactly one line.
  - **AC11** — `grep -c '^- \*\*work-type\*\*:' .specaffold/features/_template/STATUS.md` returns `1`.
  - **AC12** — `.specaffold/features/_template/` has no subdirectories (repeat of T7 assertion; included here for completeness in the final gate).
  - **§6.2 hook (tech-D10 sentinel regex)** — this feature's STATUS.md contains a line matching `^- [0-9]{4}-[0-9]{2}-[0-9]{2} .* RUNTIME HANDOFF \(for successor bug/chore\):` (T17 pre-commits the line; T16 structurally asserts its presence).

  Sandbox-HOME per `.claude/rules/bash/sandbox-home-in-tests.md`. Bash 3.2 / BSD portable.
- **Deliverables**: `test/t106_pm_tpm_status_shape.sh` (new, executable).
- **Verify**: `bash test/t106_pm_tpm_status_shape.sh` prints `PASS` and exits 0 after T17 lands.
- **Depends on**: T17 (the RUNTIME HANDOFF sentinel must be present before the assertion fires)
- **Parallel-safe-with**: T15 (different files)
- [ ]

## T17 — Pre-commit RUNTIME HANDOFF STATUS Notes line for next bug/chore successor

- **Milestone**: M3
- **Requirements**: AC-runtime-deferred (§6.2)
- **Decisions**: D8, tech-D10
- **Scope**: Append one line to this feature's `.specaffold/features/20260424-entry-type-split/STATUS.md` under `## Notes`, matching the tight regex `^- [0-9]{4}-[0-9]{2}-[0-9]{2} .* RUNTIME HANDOFF \(for successor bug/chore\):` per tech-D10. Exact form:

  ```
  - 2026-04-24 TPM — RUNTIME HANDOFF (for successor bug/chore): first real /scaff:bug or /scaff:chore invocation must open its STATUS Notes with "exercised entry-type-split commands on this feature's first live session". Structural ACs verified in this feature's validate; runtime ACs deferred per PRD §6.2 AC-runtime-deferred.
  ```

  This is the ninth-occurrence-promoted discipline from `shared/dogfood-paradox-third-occurrence.md`: pre-commit the handoff line in the final wave as a TPM-owned task, not as an archive-time afterthought. The line is structurally asserted by T16. No other STATUS edits in this task (the per-wave bookkeeping and stage-checkbox flips remain orchestrator concerns).
- **Deliverables**: `.specaffold/features/20260424-entry-type-split/STATUS.md` (one line appended under `## Notes`).
- **Verify**: `grep -cE '^- [0-9]{4}-[0-9]{2}-[0-9]{2} .* RUNTIME HANDOFF \(for successor bug/chore\):' .specaffold/features/20260424-entry-type-split/STATUS.md` returns `1`. Full structural verification runs as part of T16.
- **Depends on**: —
- **Parallel-safe-with**: T15 (different files)
- [ ]

---

## Team memory

- `tpm/two-wave-serial-resolves-cross-layer-merge-order-constraint.md` (local) — applied: widened to three waves because the producer→consumer chain has three layers (foundation → dispatch → docs/handoff). Wave boundaries carry the merge-order constraint so no cross-wave `Depends on:` edges are needed.
- `tpm/pre-declare-test-filenames-in-06-tasks.md` (local) — applied: T2/T7/T13/T14/T16 pre-declare exact `test/t102_...sh` through `test/t106_...sh` filenames; next counter = t102 (last used t101); no collisions within waves.
- `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md` (local) — applied: every `- [ ]` below is unchecked at plan-authoring time; TPM is never the `[x]`-writer.
- `shared/dogfood-paradox-third-occurrence.md` (local, ninth occurrence) — applied: T17 pre-commits the RUNTIME HANDOFF STATUS line in the final wave per the promoted sub-pattern; T16 structurally asserts the tech-D10 sentinel regex.
- `tpm/parallel-safe-requires-different-files.md` (local) — applied to consolidate pm.md's probe-branch + keyword-table work into a single T5 task, because both deliverables edit the same file and splitting would create a parallel-merge hazard.

## STATUS note

- 2026-04-24 TPM — 05-plan.md authored (new merged form; no 06-tasks.md per R19): 3 waves (W1 foundation 7 tasks · W2 dispatch 7 tasks · W3 docs+handoff 3 tasks), 17 tasks total; risks §3 lists dogfood paradox (tenth occurrence), /scaff:request backward compat, stage-matrix ABI freeze; §5 open questions empty; T17 pre-commits RUNTIME HANDOFF STATUS line per tech-D10 / ninth-occurrence discipline.
