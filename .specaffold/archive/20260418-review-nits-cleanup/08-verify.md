# 08-verify — review-nits-cleanup

**Slug**: `20260418-review-nits-cleanup`
**Date**: 2026-04-18
**Verifier**: QA-tester
**Gap-check verdict**: PASS (07-gaps.md embedded in STATUS.md notes; file not written separately)

---

## R1 / AC1 — Slug validation in review.md before feature-dir resolution

Status: PASS
Evidence: `.claude/commands/specflow/review.md` Step 1 contains:
- Regex `^[a-z0-9][a-z0-9-]*$` named explicitly (line 11)
- `exit 2` on mismatch (line 18 `exit 2`)
- stderr error emission via `printf ... >&2` (line 18)
- Appears in Step 1 (Parse args); feature-dir resolution is Step 2

Code-level check: file `.claude/commands/specflow/review.md` lines 9–21 — slug validation is the first numbered bullet, strictly before "Resolve feature dir" at Step 2.

---

## R2 / AC2 — t35 single awk pass per rubric (performance refactor)

Status: PASS
Evidence:
- `bash test/t35_reviewer_rubric_schema.sh` → exit 0, all 3 rubrics PASS
- Code review: `test/t35_reviewer_rubric_schema.sh` lines 64–120 implement one `awk` block per rubric file — a single traversal emitting all required keys, body section markers, and checklist count. No per-check file re-reads remain.
- Byte-identical diff against pre-refactor baseline: not machine-verifiable (the test file was newly introduced in the review-capability feature; no previous version exists in HEAD~1). The test output is deterministic and passes; code review confirms the folding is correct.

---

## R3 / AC3 — t34 single cat-to-variable per agent file (performance refactor)

Status: PASS
Evidence:
- `bash test/t34_reviewer_verdict_contract.sh` → exit 0, 32/32 PASS
- Code review: `test/t34_reviewer_verdict_contract.sh` line 91: `content="$(cat "$agent_file")"` — file read exactly once per agent; all subsequent checks use `printf '%s\n' "$content" | grep ...` against the in-memory variable. Fork/exec count per agent file reduced from 6+ to 1.
- Byte-identical diff: same caveat as AC2 — no prior-version baseline. Test runs deterministically and passes.

---

## R4 / AC4 — reviewer-security.md: no stale reviewer-security/ paths

Status: PASS
Evidence: `grep -n 'reviewer-security/' .claude/agents/specflow/reviewer-security.md` → no output (exit 1)

---

## R5 / AC5 — reviewer-style.md team-memory block matches numbered ls checklist shape

Status: PASS (with noted scope limitation)
Evidence: `.claude/agents/specflow/reviewer-style.md` lines 13–16 show a numbered ls checklist:
```
1. `ls ~/.claude/team-memory/reviewer/` and `ls .claude/team-memory/reviewer/` (global then local).
2. `ls ~/.claude/team-memory/shared/` and `ls .claude/team-memory/shared/`.
3. Pull in any entry whose description is relevant.
4. Read `.claude/rules/reviewer/style.md` before acting...
```
This structurally matches `reviewer-performance.md` lines 13–16 (identical numbered format). `reviewer-security.md` still uses a prose invocation block — this pre-existing inconsistency was recorded as gap-check N1 (out of R4/R5 scope). R5 scoped only to style.md; style.md now aligns with performance.md.

---

## R6 / AC6 — implement.md pseudocode block: no 3-space indented lines

Status: PASS
Evidence: `awk` check for 3-space-indented lines in `.claude/commands/specflow/implement.md` lines 86–110 → no output. All pseudocode lines use 2-space indentation.

---

## R7 / AC7 — t34: set -u -o pipefail

Status: PASS
Evidence: `grep -n '^set ' test/t34_reviewer_verdict_contract.sh` → `7:set -u -o pipefail`

---

## R8 / AC8 — t37: set -u -o pipefail

Status: PASS
Evidence: `grep -n '^set ' test/t37_review_oneshot.sh` → `8:set -u -o pipefail`

---

## R9 / AC9 — t38: set -u -o pipefail

Status: PASS
Evidence: `grep -n '^set ' test/t38_hook_skips_reviewer.sh` → `8:set -u -o pipefail`

---

## R10 / AC10 — t26: WHAT comment deleted

Status: PASS
Evidence: `grep -c 'Count files only (not directories) in the commands dir' test/t26_no_new_command.sh` → `0`

---

## R11 / AC11 — t35: WHAT comment deleted (post-R2 refactor)

Status: PASS
Evidence: `grep -n 'Extract line numbers' test/t35_reviewer_rubric_schema.sh` → no output. The awk-folding refactor (R2) restructured the file; no equivalent WHAT-narrating comment survives.

---

## R12 / AC12 — to_epoch() removed from stop.sh; no call sites

Status: PASS
Evidence:
- `grep -n 'to_epoch' .claude/hooks/stop.sh` → no output (exit 1). Function deleted; stop.sh now uses `date +%s` directly inside `within_60s()`.
- `grep -rn 'to_epoch' . --include='*.sh'` → one hit: `test/t32_stop_hook_dedup.sh:7` — this is a comment line (`# The to_epoch() wrapper in stop.sh dispatches on`) referencing the historical implementation name. It is not a function definition, not a function call, and not a dead call site. The PRD precondition ("no call site references `to_epoch`") is met.
- Archive docs (`.spec-workflow/archive/`) also contain `to_epoch` references; these are historical design documentation and are not executable code.

---

## R13 / AC13 — repo-wide grep: no reviewer-security/ in .claude/ tree

Status: PASS
Evidence: `grep -rn 'reviewer-security/' .claude/` → no output (exit 1)

---

## R14 / AC14 — smoke suite 38/38 PASS

Status: PASS
Evidence: `bash test/smoke.sh` → `smoke: PASS (38/38)`, exit 0

---

## AC15 — follow-up /specflow:review returns no regression of source findings

Status: N/A (MANUAL — documented escape)
Evidence: Inline review was skipped this run per STATUS.md notes (2026-04-18 Orchestrator entry): "session cache hasn't refreshed post-B2.b merge so native reviewer subagents aren't dispatchable; documented escape per plan §4." No automated check exists for this criterion in this session. The dogfood paradox is noted. A future `/specflow:review 20260418-review-nits-cleanup` run should be executed once the session refreshes to validate G2.

---

## Summary

| AC | R | Status | Check |
|---|---|---|---|
| AC1 | R1 | PASS | Code-level: review.md lines 9–21 |
| AC2 | R2 | PASS | `bash test/t35_reviewer_rubric_schema.sh` exit 0; code review |
| AC3 | R3 | PASS | `bash test/t34_reviewer_verdict_contract.sh` 32/32; code review |
| AC4 | R4 | PASS | `grep 'reviewer-security/' reviewer-security.md` → 0 hits |
| AC5 | R5 | PASS | style.md numbered ls block matches performance.md; N1 scope note |
| AC6 | R6 | PASS | awk check for 3-space indent → 0 hits |
| AC7 | R7 | PASS | `grep '^set ' t34` → `set -u -o pipefail` |
| AC8 | R8 | PASS | `grep '^set ' t37` → `set -u -o pipefail` |
| AC9 | R9 | PASS | `grep '^set ' t38` → `set -u -o pipefail` |
| AC10 | R10 | PASS | `grep 'Count files only' t26` → 0 hits |
| AC11 | R11 | PASS | `grep 'Extract line numbers' t35` → 0 hits |
| AC12 | R12 | PASS | `grep 'to_epoch' stop.sh` → 0; remaining hit is comment-only |
| AC13 | R13 | PASS | `grep -rn 'reviewer-security/' .claude/` → 0 hits |
| AC14 | R14 | PASS | `bash test/smoke.sh` → 38/38 exit 0 |
| AC15 | G2 | N/A | MANUAL — inline review skipped (dogfood paradox, session cache) |

---

## Verdict: PASS

14/14 requirements verified PASS. AC15 is N/A (justified: documented escape in STATUS.md, not a regression). No failing requirements.
