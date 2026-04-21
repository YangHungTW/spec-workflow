# PRD — review-nits-cleanup

**Slug**: `20260418-review-nits-cleanup`
**Date**: 2026-04-18
**Author**: PM
**Stage**: prd
**Source**: `00-request.md`, `01-brainstorm.md`, `.spec-workflow/archive/20260418-review-capability/review-2026-04-18-1450.md`

---

## 1. Problem

The first `/specflow:review` meta-exercise on feature `20260418-review-capability` surfaced 13 quality nits (1 security, 2 performance, 8 style, 2 comment hygiene) — all `should` / `advisory`, none blocking. In parallel, the preceding B2.a gap-check left one orphaned helper (`to_epoch()` in `.claude/hooks/stop.sh`) as a carryover. These 14 items are real quality drift against the repo's own conventions (team-memory path alignment, `set -o pipefail` usage, WHAT-vs-WHY comments, per-file-read performance) and against one cross-file security boundary (un-validated slug argument). Left in place, they erode trust in the reviewer capability that was just shipped ("the reviewer flagged it, nothing happened") and allow the same drift patterns to propagate into the next feature.

The user-visible outcome the sweep restores: the reviewer's own output is credible — findings get addressed, and the sibling-file conventions the reviewers enforce match the sibling files the reviewers themselves ship as.

## 2. Goals (measurable)

- G1. All 14 in-scope items are resolved by file edit or deletion, each with a direct line-level diff attributable to the source finding ID (S1, P1, P2, St1–St8, X1 for `to_epoch()`).
- G2. A follow-up `/specflow:review` run against this feature returns **PASS** or a **strictly smaller / different** NITS set than the source review — no regression of the 13 addressed findings.
- G3. Smoke suite (`bash test/smoke.sh`) remains **38/38 PASS** after every change lands. No behavioral regression.
- G4. The two performance refactors (R2, R3) produce **byte-identical** test output before and after — verified by `diff`.

## 3. Non-goals

- No behavioral change to `/specflow:review` beyond the R1 slug-validation boundary (no rubric edits, no verdict-contract edits, no agent-frontmatter edits).
- No schema changes (rubric frontmatter, verdict contract, agent frontmatter — all untouched).
- No new features, commands, or agents.
- No findings outside the 14 in scope. Discovered nits during the sweep get logged for a future feature, not absorbed.
- No rewrite of WHAT-comments into WHY-comments (locked decision: drop, don't rewrite).

## 4. Users / scenarios

**Primary user**: the next developer or agent opening this repo after the cleanup ships.

- **Scenario A** — Developer runs `bash test/smoke.sh` and sees 38/38 green. Test behavior is unchanged; nothing in their workflow is disrupted by the refactors.
- **Scenario B** — Agent loads a reviewer subagent and follows the team-memory invocation block. All three reviewer agents point at the same `~/.claude/team-memory/reviewer/` path; no stale `reviewer-security/` reference remains anywhere in the repo.
- **Scenario C** — User invokes `/specflow:review <slug>` with a malformed slug (leading `-`, containing `..`, containing whitespace). The command exits 2 with a clear stderr message before any filesystem or git operation runs.
- **Scenario D** — Maintainer re-runs `/specflow:review 20260418-review-nits-cleanup` after this feature ships. Verdict is PASS or a different / smaller NITS set; none of the 13 source findings recur.

## 5. Requirements

Each requirement is a single file/line-level change. Requirement IDs are PRD-local (R1..R14); each cites the source finding ID for traceability.

### Group D — Security (source: S1)

- **R1** (source: S1) — `/specflow:review` command gains a slug-validation step. In `.claude/commands/specflow/review.md`, insert a new Step 1 bullet **before** feature-directory resolution: validate `<slug>` against the regex `^[a-z0-9][a-z0-9-]*$` (kebab-case per repo README frontmatter schema). On mismatch, emit a clear error to stderr and exit with status 2. No other command steps are modified.

### Group E — Performance (source: P1, P2)

- **R2** (source: P1) — `test/t35_reviewer_rubric_schema.sh` folds the 6+ per-file reads into **one `awk` pass per rubric** that emits the frontmatter keys, body section markers, and checklist count in a single traversal. The rubric loop iterates over 3 rubric files; after the refactor each iteration opens each file at most once for the folded pass (plus whatever minimal reads remain for framing, if any). Test output must be byte-identical to the pre-refactor output.
- **R3** (source: P2) — `test/t34_reviewer_verdict_contract.sh` reads each agent file **once** into a shell variable (e.g. `content=$(cat "$agent_file")`) and runs greps against the variable via `printf '%s\n' "$content" | grep ...`, **or** batches the schema-key checks into a single `awk` pass. Either approach is acceptable; the acceptance bar is that per-agent-file fork/exec count drops materially and test output remains byte-identical.

### Group A — Cross-file convention alignment (source: St1, St2, St8)

- **R4** (source: St1) — `.claude/agents/specflow/reviewer-security.md` replaces every `~/.claude/team-memory/reviewer-security/` reference with `~/.claude/team-memory/reviewer/`. This covers line 12 and any additional occurrences (prose, comments, team-memory invocation block, checklist lines). After R4, no `reviewer-security/` path string remains in this file.
- **R5** (source: St2) — `.claude/agents/specflow/reviewer-style.md` team-memory invocation block is extended to match the numbered `ls` checklist shape used by `reviewer-security.md` and `reviewer-performance.md`. Pure prose alignment; no semantic behavior change.
- **R6** (source: St8) — `.claude/commands/specflow/implement.md` around line 96: normalize indentation inside the heredoc-style pseudocode block so any 3-space indent becomes 2-space, consistent with the surrounding 2-space pseudocode block.

### Group B — `set -o pipefail` alignment (source: St3, St4, St5)

- **R7** (source: St3) — `test/t34_reviewer_verdict_contract.sh` line 7: change `set -u` to `set -u -o pipefail`.
- **R8** (source: St4) — `test/t37_review_oneshot.sh` line 8: change `set -u` to `set -u -o pipefail`.
- **R9** (source: St5) — `test/t38_hook_skips_reviewer.sh` line 8: change `set -u` to `set -u -o pipefail`.

### Group C — Comment drops (source: St6, St7)

- **R10** (source: St6) — `test/t26_no_new_command.sh` line 57: delete the WHAT-narrating comment line entirely. No replacement text.
- **R11** (source: St7) — `test/t35_reviewer_rubric_schema.sh` line 106 (pre-refactor): delete the WHAT-narrating comment line entirely. Coordinates with R2 — if R2's `awk`-folding refactor restructures this region, R11 is satisfied when no equivalent WHAT comment survives in the refactored code.

### Group F — Dead code (source: B2.a carryover X1)

- **R12** (source: X1 / B2.a gap-check N3) — `.claude/hooks/stop.sh` lines 108–117: remove the orphaned `to_epoch()` function. Precondition: verify (via repo-wide grep) that no call site references `to_epoch` anywhere. The rest of `stop.sh` remains byte-identical.

### Cross-cutting verification

- **R13** (cross-cutting for R4) — After R4 lands, a repo-wide grep for the old path token must return zero hits in the `.claude/` tree: `grep -r 'reviewer-security/' .claude/` returns empty. This catches any stale reference missed by R4's in-file edit.
- **R14** (cross-cutting, all tasks) — After all 12 deliverable changes (R1–R12) land, `bash test/smoke.sh` must report 38/38 PASS. No test is added, removed, or regressed.

## 6. Acceptance criteria

Each requirement maps to a concrete, automatable check.

- [ ] **AC1** (R1) — `.claude/commands/specflow/review.md` contains a Step 1 bullet that (a) names the regex `^[a-z0-9][a-z0-9-]*$`, (b) specifies exit code 2 on mismatch, (c) specifies stderr error emission, and (d) appears strictly before the feature-directory resolution step. Verified by inspection + a manual run with a malformed slug (e.g. `-bad`, `has space`, `has..dots`) confirming exit 2 and a stderr message.
- [ ] **AC2** (R2) — `diff <(bash test/t35_reviewer_rubric_schema.sh 2>&1) <(git show HEAD~1:test/t35_reviewer_rubric_schema.sh | bash 2>&1)` (or equivalent before/after comparison) produces empty output. Per-rubric file-open count measured at most once for the folded `awk` pass (verified by `strace`/inspection or by code review of the refactor).
- [ ] **AC3** (R3) — `diff` between pre- and post-refactor output of `bash test/t34_reviewer_verdict_contract.sh` is empty. Per-agent-file grep subprocess count materially reduced (verified by code review: single `cat`-to-variable OR single batched `awk` pass).
- [ ] **AC4** (R4) — `grep -n 'reviewer-security/' .claude/agents/specflow/reviewer-security.md` returns zero hits. The file now uses `~/.claude/team-memory/reviewer/` consistently.
- [ ] **AC5** (R5) — `.claude/agents/specflow/reviewer-style.md` team-memory invocation block contains a numbered `ls` checklist structurally matching `reviewer-security.md` and `reviewer-performance.md` (verified by side-by-side inspection).
- [ ] **AC6** (R6) — `.claude/commands/specflow/implement.md` around line 96: all lines inside the pseudocode block use 2-space indentation; no 3-space indented line remains in the block (verified by inspection or an `awk` check for 3-space prefixes inside the block fences).
- [ ] **AC7** (R7) — `grep -n '^set ' test/t34_reviewer_verdict_contract.sh` shows `set -u -o pipefail`.
- [ ] **AC8** (R8) — `grep -n '^set ' test/t37_review_oneshot.sh` shows `set -u -o pipefail`.
- [ ] **AC9** (R9) — `grep -n '^set ' test/t38_hook_skips_reviewer.sh` shows `set -u -o pipefail`.
- [ ] **AC10** (R10) — `test/t26_no_new_command.sh` no longer contains the `Count files only (not directories) in the commands dir` comment text anywhere.
- [ ] **AC11** (R11) — `test/t35_reviewer_rubric_schema.sh` no longer contains the `Extract line numbers of each required heading` comment text anywhere (post-R2 refactor).
- [ ] **AC12** (R12) — `grep -n 'to_epoch' .claude/hooks/stop.sh` returns zero hits. Repo-wide `grep -rn 'to_epoch' .` returns zero hits (confirming no dead call remained elsewhere). `diff` of `stop.sh` minus the deleted range shows no other edits.
- [ ] **AC13** (R13) — `grep -rn 'reviewer-security/' .claude/` returns zero hits across the entire `.claude/` tree.
- [ ] **AC14** (R14) — `bash test/smoke.sh` reports `38/38 PASS`, exit 0.
- [ ] **AC15** (G2, cross-cutting) — A follow-up `/specflow:review 20260418-review-nits-cleanup` run returns verdict **PASS** or a NITS set that does not regress any of S1, P1, P2, St1–St8, or the X1 carryover. Findings on genuinely new surfaces are acceptable; recurrence of any of the 13 listed source findings is not.

## 7. Open questions

None. All decisions locked at request stage (team-memory path = shared `reviewer/`; scope = 14 items including `to_epoch()` carryover; WHAT-comments drop, don't rewrite). No blockers.

## 8. Edge cases & risks

- **Performance-refactor output drift (R2, R3)** — `awk` folding or read-into-variable can change whitespace, ordering, or shell-expansion timing. Mitigation: the byte-identical-output acceptance criterion (AC2, AC3) is a hard gate; `diff` on before/after output must be empty.
- **Stale `reviewer-security/` references elsewhere (R4, R13)** — the in-file edit might miss a reference in prose, a comment, or a team-memory invocation line. R13's repo-wide grep catches this; scope is `.claude/` tree.
- **R11 vs R2 ordering** — R2 restructures the region around line 106. If R11 is scheduled before R2, R2 must not re-introduce an equivalent WHAT comment. If scheduled after R2, R11 verifies no such comment survives the refactor. Either ordering is acceptable; TPM chooses.
- **`to_epoch()` call-site check (R12)** — R12 requires a pre-deletion grep. If any surviving caller is found, the item escalates to a behavior question and should be flagged back to PM rather than deleted silently.
- **R1 regex dialect** — the slug-validation regex is POSIX-ERE (`^[a-z0-9][a-z0-9-]*$`). The command spec is prose, so no shell-regex-dialect ambiguity surfaces at PRD stage; Architect/TPM will decide the implementation language (bash `=~` vs `case` glob vs `grep -E`) per the bash 3.2 portability rule.

## 9. Traceability

| R | Source finding | File touched | Acceptance |
|---|---|---|---|
| R1 | S1 | `.claude/commands/specflow/review.md` | AC1 |
| R2 | P1 | `test/t35_reviewer_rubric_schema.sh` | AC2 |
| R3 | P2 | `test/t34_reviewer_verdict_contract.sh` | AC3 |
| R4 | St1 | `.claude/agents/specflow/reviewer-security.md` | AC4, AC13 |
| R5 | St2 | `.claude/agents/specflow/reviewer-style.md` | AC5 |
| R6 | St8 | `.claude/commands/specflow/implement.md` | AC6 |
| R7 | St3 | `test/t34_reviewer_verdict_contract.sh` | AC7 |
| R8 | St4 | `test/t37_review_oneshot.sh` | AC8 |
| R9 | St5 | `test/t38_hook_skips_reviewer.sh` | AC9 |
| R10 | St6 | `test/t26_no_new_command.sh` | AC10 |
| R11 | St7 | `test/t35_reviewer_rubric_schema.sh` | AC11 |
| R12 | X1 (B2.a N3) | `.claude/hooks/stop.sh` | AC12 |
| R13 | cross-cutting (R4) | `.claude/` tree | AC13 |
| R14 | cross-cutting (all) | `test/smoke.sh` | AC14 |
| — | G2 | follow-up review run | AC15 |
