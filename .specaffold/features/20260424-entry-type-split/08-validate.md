# Validate: 20260424-entry-type-split
Date: 2026-04-24
Axes: tester, analyst

## Consolidated verdict
Aggregate: **NITS**
Findings: 0 must, 2 should, 2 advisory
Structural tests: 139/139 PASS (t102 + t103 + t104 + t105 + t106)
Runtime ACs: DEFERRED per PRD D8 / AC-runtime-deferred (dogfood paradox — 10th occurrence)

## Tester axis

### AC walk summary

| AC | Verdict | Evidence |
|---|---|---|
| AC1 | PASS | `bug.md` description + 3 classification branches; t104 |
| AC2 | PASS | `chore.md` description + template ref + slug; t104 |
| AC3 | **NITS** | 1-line diff is a comment reference (template-seeding via `_template/STATUS.md`), not a standalone setter line. Spirit met; literal wording partially met. Advisory only |
| AC4 | PASS | `## When invoked for /scaff:bug` and `/scaff:chore` each count=1 in pm.md; t106 |
| AC5 | PASS | `race condition`, `typo`, `bump dep`, `cleanup` anchors in pm.md keyword table; t106 |
| AC6 | PASS | All 3 templates under `.specaffold/prd-templates/` with required headings; t103 |
| AC7 | PASS | `-fix-` in bug.md, `-chore-` in chore.md, `exit 2` in slug-prefix-rejection; t104 |
| AC8 | PASS | `bin/scaff-stage-matrix` — 72 cells encoded; t102 |
| AC9 | PASS | Feature-tier cells preserve prior tier_skips_stage semantics; t102 |
| AC10 | PASS | 3 verbatim retrospective prompts in tpm.md, count=1 each; t106 |
| AC11 | PASS | `_template/STATUS.md` has `- **work-type**: feature`, count=1 |
| AC12 | PASS | `_template/` has no subdirs; t103, t106 |
| AC13 | PASS | README.md + README.zh-TW.md document `/scaff:bug` + `/scaff:chore` |
| AC14 | PASS | No archive slugs renamed (grep over `.specaffold/archive/` → empty diff) |
| AC15 | **NITS** | Structural proxy via t105 passes 16/16. Live `/scaff:request` fixture invocation not executable from bash subprocess; tech-D8 option (b) chose shape-assertion over byte-diff |
| AC-runtime-deferred | DEFERRED | HANDOFF sentinel present; runtime exercise deferred to successor bug/chore ticket per PRD D8 |

**Structural test suite**: t102 (78) + t103 (18) + t104 (15) + t105 (16) + t106 (12) = **139/139 PASS**.

### Verdict footer

```
## Validate verdict
axis: tester
verdict: NITS
findings:
  - severity: should
    ac: AC3
    evidence: "git diff main -- .claude/commands/scaff/request.md — 1 line changed; parenthetical comment referencing work-type; no standalone setter line"
    message: "AC3 literal wording says 'single work-type line addition'; implementation uses template-seeding via _template/STATUS.md (correct per tech-D6 dispatch signal design). Spirit met; literal partially met. Advisory only."
  - severity: should
    ac: AC15
    evidence: "t105 16/16 PASS; live fixture invocation of /scaff:request not executable from bash test environment"
    message: "Structural regression proxy passes. Live invocation portion of AC15 requires Claude Code slash command; cannot exercise from bash. No regression evidence found. Advisory only."
```

## Analyst axis

### Requirements map (R1–R15)

All 15 requirements have traceable task + diff evidence. No orphans.

### Acceptance criteria (AC1–AC15 + AC-runtime-deferred)

All 15 structural ACs verified. AC-runtime-deferred handled per PRD D8 (sentinel present, t106 asserts, runtime exercise deferred to successor).

### Decisions compliance

D1–D8 (PRD) + tech-D1..tech-D10 (Tech): **all 18 decisions respected in shipped diff**.

- D1 auto-classify: 3 branches in bug.md
- D2 chore checklist: skeleton marker present
- D3 3×3 matrix: 72 cells in bin/scaff-stage-matrix
- D4 slug prefixes: `-fix-` / `-chore-` / (feature = unchanged); no retroactive rename
- D5 per-type retro prompts: 3 verbatim in tpm.md
- D6 STATUS work-type dispatch signal
- D7 templates in `.specaffold/prd-templates/` (W1 remediation)
- D8 structural-only validate + pre-committed HANDOFF
- tech-D1..tech-D10: all verified (see full analyst reply)

### Scope audit

**Extra work (justified)**:
- README.zh-TW.md updated (T15 plan premise "zh-TW doesn't exist" was wrong; developer correctly updated anyway; AC13 satisfied)
- W1 remediation commit `8f60a55`: templates moved from `.claude/commands/scaff/prd-templates/` to `.specaffold/prd-templates/` (plan-gap surfaced + remediated with full trail in 04-tech.md tech-D7 addendum)

**Missing**: none

**Retry flow**: W2 BLOCK→retry→NITS handled within-wave per `05-plan.md §3 risk 7`. No `/scaff:update-task` needed. Test fixes (t105 `why[- ]now` regex; t106 TEMPLATE_STATUS path) are implementation-error corrections, not scope drift.

### Dogfood paradox (10th occurrence) — CLEAN

1. T17 pre-committed sentinel line — matches tight regex
2. t106 asserts sentinel presence structurally
3. Runtime ACs explicitly deferred; no silent skip; handoff prose in STATUS names the successor obligation

### Retrospective signals (for archive)

1. `.claude/commands/scaff/` recursive md-harvest catches template files → architect memory candidate
2. BLOCK→retry→NITS is healthy pattern for security-fix class; in-wave retry is correct without /scaff:update-task
3. tech-D7 addendum pattern for mid-wave path moves
4. Exact-text anchor brittleness in probe-content grep checks (why[- ]now)
5. T15 find-verification false-negative at plan authoring time

### Verdict footer

```
## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: advisory
    file: .specaffold/features/20260424-entry-type-split/05-plan.md
    rule: scope-consistency
    message: T15 plan text claimed "No README.zh-TW.md exists at the repo root" but the file has existed since commit 26009d0; developer correctly updated zh-TW anyway. AC13 satisfied. Advisory only.
  - severity: advisory
    file: .specaffold/features/20260424-entry-type-split/03-prd.md
    rule: consistency
    message: AC15 literal wording says "fixture invocation of /scaff:request run in sandboxed HOME" but t105 performs static grep assertions (tech-D8 option b); tech-doc controls over PRD wording. Not a regression.
```

## Validate verdict
axis: aggregate
verdict: NITS
