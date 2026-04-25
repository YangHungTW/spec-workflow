# Validate: 20260426-scaff-init-preflight
Date: 2026-04-26 02:26
Axes: tester, analyst

## Consolidated verdict
Aggregate: NITS
Findings: 0 must, 2 should, 5 advisory

## Tester axis

# QA-Tester validate report — 20260426-scaff-init-preflight

## Team memory

Applied entries:
- `qa-tester/prd-ac-wording-superseded-by-tech-decision.md` — applied when handling the 17-vs-18 count drift in PRD R3; the tech doc (D1/Note A) explicitly reconciles to 18 as authoritative, so the implementation's 18-file coverage is correct.
- `qa-tester/probe-anchor-spot-checks-should-span-spelling-variants.md` — reviewed; no anchor-phrase tests at risk here (marker is a fixed HTML comment, not a conceptual phrase with spelling variants).
- `qa-tester/sandbox-home-preflight-pattern.md` — confirmed all runtime tests (t107, t110) implement `mktemp -d` sandbox, `export HOME="$SANDBOX/home"`, `trap 'rm -rf "$SANDBOX"' EXIT`, and the case-preflight assertion per `.claude/rules/bash/sandbox-home-in-tests.md`.
- `shared/dogfood-paradox-third-occurrence.md` — confirms structural ACs are the primary surface; runtime ACs exercised via sandboxed shell harness, not assistant invocation.
- `shared/status-notes-rule-requires-enforcement-not-just-documentation.md` — confirmed: gate is enforced by lint + pre-commit, not by per-author memory.

---

## AC walkthrough

### AC1 (structural — single source of truth exists)

**Test coverage**: t107 A1, A2 + direct inspection of `.specaffold/preflight.md`.

**Evidence**:
```
$ bash test/t107_preflight_lint_and_body.sh
PASS: A1: .specaffold/preflight.md exists
PASS: A1: open sentinel present
PASS: A1: close sentinel present
PASS: A1: block contains token REFUSED:PREFLIGHT
PASS: A1: block contains token .specaffold/config.yml
PASS: A1: block contains token /scaff-init
...
PASS: t107
EXIT=0
```
`.specaffold/preflight.md` exists at line 1-14. The fenced block is bounded by exact sentinel comments `# === SCAFF PREFLIGHT — DO NOT INLINE OR DUPLICATE ===` and `# === END SCAFF PREFLIGHT ===`. A grep across `.claude/commands/scaff/*.md` for the gate logic body (`[ ! -f ".specaffold/config.yml" ]`) finds zero matches — the logic is in `preflight.md` only.

**PASS**

---

### AC2 (structural — all 17/18 gated commands reference the shared mechanism)

**Test coverage**: t109 A1, A2, A3 + direct `bin/scaff-lint preflight-coverage`.

**Evidence**:
```
$ bin/scaff-lint preflight-coverage; echo "exit=$?"
ok:.claude/commands/scaff/archive.md
ok:.claude/commands/scaff/bug.md
ok:.claude/commands/scaff/chore.md
ok:.claude/commands/scaff/design.md
ok:.claude/commands/scaff/implement.md
ok:.claude/commands/scaff/next.md
ok:.claude/commands/scaff/plan.md
ok:.claude/commands/scaff/prd.md
ok:.claude/commands/scaff/promote.md
ok:.claude/commands/scaff/remember.md
ok:.claude/commands/scaff/request.md
ok:.claude/commands/scaff/review.md
ok:.claude/commands/scaff/tech.md
ok:.claude/commands/scaff/update-plan.md
ok:.claude/commands/scaff/update-req.md
ok:.claude/commands/scaff/update-task.md
ok:.claude/commands/scaff/update-tech.md
ok:.claude/commands/scaff/validate.md
exit=0
```
18 `ok:` lines, exit 0.

**Note on PRD R3 "exactly 17" vs implementation "18"**: PRD §5.3 R3 prose says "exactly 17 commands" but enumerates 18. The tech doc (§5 Note A) and plan (§1.1) explicitly reconcile to 18 as authoritative, and the directory contains 18 files. The implementation gates all 18 correctly. This is a documentation drift in the PRD prose only, not an implementation gap. Flagged as advisory below per `qa-tester/prd-ac-wording-superseded-by-tech-decision.md`.

**PASS** (implementation matches tech-reconciled count of 18)

---

### AC3 (structural — scaff-init.md does not reference the shared mechanism)

**Test coverage**: t109 A4, A5; t110 A5.

**Evidence**:
```
$ ls .claude/commands/scaff/scaff-init.md
No such file or directory

$ bash test/t109_marker_coverage.sh
PASS: A4 — scaff-init.md is absent from the gated directory (vacuous AC3)
PASS: A5 — no preflight marker found in .claude/skills/ (correct: skills are outside scan scope)
EXIT=0
```
As noted in tech D8 and plan §1.2, `scaff-init` is a skill at `.claude/skills/scaff-init/SKILL.md`, not a slash command. The file `.claude/commands/scaff/scaff-init.md` does not exist. AC3 is satisfied vacuously: there is nothing to grep for the marker in. The lint does not carry an exclusion for scaff-init (correct — no dead code, as the file simply does not exist).

**PASS (vacuous)**

---

### AC4 (structural — by-construction inheritance)

**Test coverage**: t108 A1, A2, A3, A4.

**Evidence**:
```
$ bash test/t108_precommit_preflight_wiring.sh
PASS: t108
EXIT=0
```
t108 asserts: (A1) `bin/scaff-seed` shim template contains `preflight-coverage`; (A2) a sandboxed `scaff-seed init` produces a pre-commit hook with both `scan-staged` and `preflight-coverage` invocations; (A3) second `scaff-seed init` is idempotent; (A4) foreign pre-commit hook is untouched.

Local `.git/hooks/pre-commit` confirmed:
```
#!/usr/bin/env bash
# scaff-lint: pre-commit shim — installed by bin/scaff-seed init/migrate
set -euo pipefail
bin/scaff-lint scan-staged "$@"
bin/scaff-lint preflight-coverage
```
A future author adding `newcmd.md` under `.claude/commands/scaff/` will fail the pre-commit hook until they add the marker — by-construction enforcement confirmed.

**PASS**

---

### AC5 (structural — refusal message format)

**Test coverage**: t107 A2 + direct inspection of `.specaffold/preflight.md`.

**Evidence** (from `/Users/yanghungtw/Tools/specaffold/.specaffold/preflight.md` line 8):
```
  printf 'REFUSED:PREFLIGHT — .specaffold/config.yml not found in %s; run /scaff-init first\n' "$(pwd)" >&2
```
Single line; contains all three required tokens: `.specaffold/config.yml` (literal), `$(pwd)` (runtime CWD substitution), `/scaff-init` (literal). No banner, no multi-paragraph output. t107 A2 asserts the extracted block passes `bash -n` syntax check and smoke-run exits 70.

**PASS**

---

### AC6 (structural — README mention)

**Test coverage**: direct grep per AC6 spec.

**Evidence**:
```
$ grep -E '(config\.yml.*scaff-init|scaff-init.*config\.yml)' README.md
Every `/scaff:*` command (except `/scaff-init`) refuses to run when `.specaffold/config.yml` is missing — run `/scaff-init` first.
exit=0
```
One line, both co-occurring tokens present, sentence conveys gate purpose and recovery command.

**PASS**

---

### AC7 (runtime — refusal happy path)

**Test coverage**: t110 A1.

**Evidence**:
```
$ bash test/t110_runtime_sandbox_acs.sh
PASS: A1: exit code is 70
PASS: A1: output contains REFUSED:PREFLIGHT
PASS: A1: output contains .specaffold/config.yml
PASS: A1: output contains /scaff-init
PASS: A1: output contains runtime CWD (/var/folders/st/6v8_06mn0t78h4yklvx0l1_c0000gn/T/tmp.cuxv4fQ0kK/proj-noinit)
PASS: A1: output is exactly one non-empty line
EXIT=0
```
Also confirmed via live sandbox run:
```
$ # Fresh sandbox without .specaffold/config.yml
REFUSED:PREFLIGHT — .specaffold/config.yml not found in /var/folders/.../proj; run /scaff-init first
exit=70
```
All four conditions met: contains `.specaffold/config.yml`, contains `/scaff-init`, contains sandbox CWD, exactly one line.

**PASS**

---

### AC8 (runtime — zero side effects)

**Test coverage**: t110 A2.

**Evidence**:
```
PASS: A2: filesystem hash identical before/after (no side effects)
PASS: A2: .specaffold/ not created
PASS: A2: STATUS.md not created
PASS: A2: .git/ not created
```
The preflight shell block contains only `[ -f ]`, `printf`, and `exit` — no filesystem mutations are possible by construction.

**PASS**

---

### AC9 (runtime — exempt path)

**Test coverage**: t110 A5 (structural assertion).

**Evidence**:
```
PASS: A5: .claude/commands/scaff/scaff-init.md does not exist — gate cannot fire on exempt path
```
The gate cannot fire on the scaff-init path because there is no `.claude/commands/scaff/scaff-init.md` file for the wiring directive to live in. t110 explicitly asserts this structural cross-check of D8. Per tech D7's test strategy: "the test is structural — assert the scaff-init skill is not in `.claude/commands/scaff/`".

**PASS (structural)**

---

### AC10 (runtime — passthrough)

**Test coverage**: t110 A3.

**Evidence**:
```
PASS: A3: exit code is 0 (passthrough)
PASS: A3: output is empty (silent passthrough per R7)
```
When `.specaffold/config.yml` exists (even empty via `touch`), the block exits 0 and emits nothing.

**PASS**

---

### AC11 (runtime — malformed-config passthrough)

**Test coverage**: t110 A4.

**Evidence**:
```
PASS: A4a: zero-byte config — exit 0
PASS: A4a: zero-byte config — output is empty
PASS: A4b: non-YAML config — exit 0
PASS: A4b: non-YAML config — output is empty
```
Both zero-byte and non-YAML (arbitrary bytes) configs pass the gate silently. NG5 (no content validation) is locked in.

**PASS**

---

### AC12 (structural — baseline diff shape)

**Test coverage**: t111 A1, A2.

**Evidence**:
```
$ bash test/t111_baseline_diff_shape.sh
PASS: A1 — all 18 files have pure-addition wiring block, no deletions
shortstat:  18 files changed, 108 insertions(+)
PASS: A2 — bulk diff stat: +108 insertions, -0 deletions
EXIT=0
```

**Note on +90 vs +108 plan prose**: Plan §T6 Verify says "exactly `90 insertions(+), 0 deletions(-)`" (5 lines × 18) and plan T10 Scope says "+90 -0". The actual implementation adds 6 lines per file (5 wiring lines + 1 blank separator), totalling +108. The developer's STATUS Notes entry at 2026-04-26 explicitly records "+6 each (5 markers + 1 separator)". t111 correctly asserts +108 (not +90). The plan prose is stale documentation only; the implementation and its tests are consistent. Per `qa-tester/prd-ac-wording-superseded-by-tech-decision.md`, this plan-prose drift (not a PRD AC drift) is advisory only — no blocking impact.

**PASS** (implementation is self-consistent; plan prose has a stale count)

---

### AC13 (structural — passthrough byte-identical)

**Test coverage**: t111 A3.

**Evidence**:
```
PASS: A3 — all 18 files are byte-identical to baseline after stripping wiring block
EXIT=0
```
Each of the 18 files: after stripping the 5-line wiring block, the remainder is byte-identical to the pre-T6 baseline. The gate addition is purely additive; no command body content was modified.

**PASS**

---

## Summary table

| AC | Verdict | Test | Notes |
|----|---------|------|-------|
| AC1 | PASS | t107 A1,A2 | preflight.md exists; sentinels + tokens present |
| AC2 | PASS | t109 A1,A2,A3 + lint direct | 18 files, all `ok:`, lint exit 0 |
| AC3 | PASS (vacuous) | t109 A4; t110 A5 | scaff-init.md absent from gated directory |
| AC4 | PASS | t108 A1,A2,A3,A4 | shim template wires both subcommands; pre-commit enforces |
| AC5 | PASS | t107 A2 + inspection | single line, all 3 tokens present |
| AC6 | PASS | direct grep | README one-liner matches co-occurrence pattern |
| AC7 | PASS | t110 A1 + sandbox | exit 70, REFUSED:PREFLIGHT, CWD, 1 line |
| AC8 | PASS | t110 A2 | hash-identical FS before/after refusal |
| AC9 | PASS (structural) | t110 A5 | no slash-command file for scaff-init to carry a gate |
| AC10 | PASS | t110 A3 | present config → exit 0, silent |
| AC11 | PASS | t110 A4 | malformed/zero-byte config → exit 0, silent |
| AC12 | PASS | t111 A1,A2 | +108/-0 across 18 files; pure additive |
| AC13 | PASS | t111 A3 | bodies byte-identical to baseline after wiring strip |

---

## Notable design choices verified against PRD intent

1. **17 vs 18 count**: PRD R3 prose says "17"; tech Note A and plan §1.1 reconcile to 18 as authoritative; directory has 18 files; all 18 are gated. Flagged as advisory documentation drift only.

2. **AC3 vacuous**: Confirmed. `.claude/commands/scaff/scaff-init.md` does not exist. The skill lives at `.claude/skills/scaff-init/`. AC3 cannot fail by construction; t109 A4 and t110 A5 both assert the file's absence.

3. **+6 lines per file (+108 total), not +5 (+90) as plan prose states**: The blank separator line after the wiring block counts as a sixth added line per file. t111 asserts +108 correctly; plan prose is stale but the implementation is self-consistent. Developer STATUS Notes explicitly record the "+6 each" count.

---

## Validate verdict
axis: tester
verdict: NITS
findings:
  - severity: advisory
    ac: AC2
    message: PRD R3 prose says "exactly 17 commands" but implementation gates 18; tech Note A reconciles to 18 as authoritative; no implementation gap, but PRD prose should be corrected at archive retrospective.
  - severity: advisory
    ac: AC12
    message: Plan T6 Verify and T10 Scope both say "+90 -0" (5 lines × 18) but actual diff is +108 -0 (6 lines × 18, including blank separator); t111 correctly asserts +108; developer STATUS Notes record the actual count; plan prose is stale documentation only.


## Analyst axis

# QA-analyst validate report — 20260426-scaff-init-preflight
axis: analyst
date: 2026-04-26

---

## Team memory

Applied entries:
- `shared/dogfood-paradox-third-occurrence.md` — relevant: feature invokes the paradox (§9, plan §1.4); used to evaluate the missing RUNTIME HANDOFF sentinel and the --no-verify usage discipline.
- `qa-analyst/agent-name-dispatch-mismatch.md` — not applicable: no agent dispatch table involved.
- `qa-analyst/dead-code-orphan-after-simplification.md` — checked: no dead code orphans found.
- `qa-analyst/post-update-plan-drift-detection-pattern.md` — applied to the plan-T6-Verify +90 vs actual +108 drift detection.
- `qa-analyst/task-acceptance-stricter-than-prd-allowance.md` — applied to verify no over-acceptance occurred.
- `qa-analyst/partial-wiring-trace-every-entry-point.md` — dir not present: /Users/yanghungtw/Tools/specaffold/.claude/team-memory/qa-analyst/partial-wiring-trace-every-entry-point.md (file absent at read time).

---

## 1. Coverage matrix

| R-id / AC | Task | Files |
|---|---|---|
| R1, R2, R5, R6, R7, R8, R9, R10 | T1 | `.specaffold/preflight.md` |
| R4, R8 | T2 | `bin/scaff-lint` (new function + case arm) |
| R1, R2, R5, R6, R7, R10 (structural + smoke) | T3 | `test/t107_preflight_lint_and_body.sh` |
| R4, R8 | T4 | `bin/scaff-seed` (lines 730-545 + 1311-1315) |
| R4 | T5 | `test/t108_precommit_preflight_wiring.sh` |
| R3, R4, R8, R9 | T6 | all 18 `.claude/commands/scaff/*.md` |
| R3, R4, R8 | T7 | `test/t109_marker_coverage.sh` |
| R13 | T8 | `README.md` |
| R1, R2, R5, R6, R7, R10 (runtime) | T9 | `test/t110_runtime_sandbox_acs.sh` |
| R3, R7 (baseline-diff) | T10 | `test/t111_baseline_diff_shape.sh` |

All 13 R-ids (R1–R13) and all 13 ACs (AC1–AC13) have at least one test or diff artefact mapping to them.

---

## 2. Gap analysis

### 2.1 Missing coverage

**FINDING 1 (should): cmd_migrate path at line 1314 not covered by new tests.**

The W2 fixup correctly mirrored the shim update from line 733 to line 1314 (`cmd_migrate` emitter in `bin/scaff-seed`). This fix is traceable to R4/AC4 (by-construction inheritance requires both init AND migrate paths to install the full pre-commit hook). However, no test in the 5 new test files exercises the migrate path. `test/t108_precommit_preflight_wiring.sh` A2 tests only `scaff-seed init`; it does not run `scaff-seed migrate` and verify the resulting hook contains `preflight-coverage`. The existing migrate tests (t45/t46/t47) predate this feature and do not assert the new hook content. The fix is a real plan-scope gap that was caught and corrected; the gap in test coverage is a residual risk.

Files: `bin/scaff-seed` line 1314, `test/t108_precommit_preflight_wiring.sh`

### 2.2 Extra work (scope creep analysis)

Two unplanned fixups landed:

**W1 fixup (acceptable):** `test/t107_preflight_lint_and_body.sh` had a hard-fail bug (`grep -lF` exit-1 under `set -o pipefail` silently aborted A3). Fixed by capturing matched files with `|| true` then `grep -c`. Also folded T3-perf NITS resolution (reuse `$BLOCK` instead of re-awk'ing preflight.md). Both fixes are clearly within T3's intent; no extra scope. STATUS Notes log the fix. Acceptable.

**W2 fixup (plan-scope gap, but correctly bounded to R4):** Line 1314 in `bin/scaff-seed` (`cmd_migrate` shim emitter) was not enumerated in plan T4's scope. Without the fix, `scaff-seed migrate` would have installed the OLD single-invocation shim, violating R4/AC4. STATUS Notes log this as "out-of-scope security observation; plan-scope gap". The fix is the right call; the plan was incomplete. Acceptable as a bug-fix-class correction, not scope creep.

No other extra-work candidates found. Deferred items from plan §1.5 (config schema validation, bypass flag, help-exempt path, gating `bin/scaff-*` scripts, PRD R3 prose fix, README.zh-TW.md localisation) are confirmed not shipped.

### 2.3 Drift findings

**Known drift 1 (acknowledged in task brief):** PRD §5.3 R3 prose says "17 commands"; plan §1.1 and tech §1.1 reconcile to 18. Plan is authoritative. Not a blocker.

**Known drift 2 (acknowledged in task brief):** AC3 is satisfied vacuously — `scaff-init.md` does not exist in `.claude/commands/scaff/`; `scaff-init` is a skill. t109 A4 and t110 A5 both assert vacuous satisfaction correctly. Not a blocker.

**Known drift 3 (acknowledged in task brief):** Tech-D3 says "+5 lines (1 comment + 4 directive lines)" and plan T6 Verify step says `+90 insertions(+)` (5×18). Actual is +6 per file (5 content lines + 1 blank separator) = +108 total. STATUS line confirms `+6 each (5 markers + 1 separator)`. The `t111` test (T10) correctly hard-codes `+108`. However, plan T6 Verify step at line 276 still says "exactly `90 insertions(+), 0 deletions(-)`" and plan T10 A2 at line 348 still says "exactly `+90 -0`". These plan lines are stale. The implementation and t111 test are internally consistent at 108; the stale plan text is the only artefact still saying 90. Verdict: should-level drift (plan text inconsistency; no runtime impact since t111 is correct).

**FINDING 2 (should): Plan T6 Verify and plan T10 A2 still assert +90; implementation and t111 assert +108.**

Files: `05-plan.md` line 276 (T6 Verify step) and line 348 (T10 A2 description).

**FINDING 3 (advisory): STATUS Notes do not log the zh-TW deferral that T8 plan required.**

Plan T8 scope explicitly states: "Document this [README.zh-TW.md out of scope] in STATUS Notes at T8 close." The STATUS Notes do not contain this entry. Low severity (the decision itself is sound and documented in the plan; the STATUS omission only affects auditability). Advisory.

Files: `.specaffold/features/20260426-scaff-init-preflight/STATUS.md`, `05-plan.md` line 312.

**FINDING 4 (advisory): W3 dev commit (T7) may have used --no-verify without a STATUS Notes log.**

The task brief states "W2 bookkeeping commit and W3 dev T7 commit needed --no-verify." STATUS line 36 logs the W2 usage but does not explicitly log W3. The T7 commit (`1fff22f`) was authored before T6's markers landed (per plan's parallel-safety analysis for W3), so the pre-commit hook would have failed at T7 commit time without `--no-verify`. Per `shared/dogfood-paradox-third-occurrence.md` discipline, every `--no-verify` use must appear in STATUS Notes. The W2 log is present; the W3 log is missing or implicit. Advisory.

Files: `.specaffold/features/20260426-scaff-init-preflight/STATUS.md` line 36.

**FINDING 5 (advisory): Deferred NITS with no in-code annotation markers.**

Several NITS from waves 2–4 are logged in STATUS Notes but not annotated inline in the affected files: T5-style (2 WHAT-only comments in t108), T10-perf (A1 loop ~145 forks in t111), T10-style (ALLCAPS loop-locals in t111). Without inline annotations these deferred NITS may not be visible when a future contributor reads those files. Advisory (STATUS Notes is the correct tracking mechanism; inline annotation is a convention question).

Files: `test/t108_precommit_preflight_wiring.sh`, `test/t111_baseline_diff_shape.sh`.

---

## 3. Summary

Coverage: complete. All 13 R-ids and 13 ACs are covered by at least one artefact.
Extra work: 2 unplanned fixups; both are correctly bounded to in-scope requirements and logged in STATUS.
Blockers: none.
Should-level gaps: 2 (migrate path test coverage, stale plan line count).
Advisory notes: 3 (STATUS zh-TW omission, W3 --no-verify log, deferred NITS without inline annotation).

---

## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    file: test/t108_precommit_preflight_wiring.sh
    line: 1
    rule: partial-wiring-trace-every-entry-point
    message: cmd_migrate shim path (bin/scaff-seed line 1314) updated in W2 fixup but not exercised by any new test; t108 A2 tests init only; migrate path coverage gap for R4/AC4.
  - severity: should
    file: .specaffold/features/20260426-scaff-init-preflight/05-plan.md
    line: 276
    rule: post-update-plan-drift-detection-pattern
    message: Plan T6 Verify says '+90 insertions(+)' (5 lines x 18); actual is +108 (6 lines x 18 including blank separator); t111 correctly asserts 108 but plan text is stale at line 276 and line 348.
  - severity: advisory
    file: .specaffold/features/20260426-scaff-init-preflight/STATUS.md
    line: 44
    rule: status-notes-rule-requires-enforcement-not-just-documentation
    message: T8 plan scope explicitly required a STATUS Notes entry for README.zh-TW.md deferral at T8 close; entry is absent from STATUS Notes.
  - severity: advisory
    file: .specaffold/features/20260426-scaff-init-preflight/STATUS.md
    line: 36
    rule: dogfood-paradox-third-occurrence
    message: W3 dev T7 commit reportedly used --no-verify (per task brief) but STATUS Notes only logs W2 --no-verify usage; W3 usage is undocumented per the dogfood-paradox discipline.
  - severity: advisory
    file: test/t111_baseline_diff_shape.sh
    line: 1
    rule: post-update-plan-drift-detection-pattern
    message: Deferred NITS (T10-perf A1 loop ~145 forks; T10-style ALLCAPS loop-locals) and t108 T5-style WHAT-only comments have no inline annotation; visible only in STATUS Notes.


## Validate verdict
axis: aggregate
verdict: NITS
