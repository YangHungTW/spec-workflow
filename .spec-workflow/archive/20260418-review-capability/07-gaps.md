# Gap-check — review-capability (B2.b)

_2026-04-18 · QA-analyst_

**Branch**: `20260418-review-capability` vs `main`
**Artifacts**: 03-prd.md (R1–R28, 24 AC), 04-tech.md (D1–D12), 06-tasks.md (T1–T16, all `[x]`)
**Smoke baseline**: 38/38 PASS (pre-gap-check run)
**Known-expected items** (not flagged): checkbox losses in waves 2/4 (fixed per tpm memory); rubric name briefing bug caught + fixed mid-flight by T12; t26 baseline 18→19 (legitimate new command); dogfood paradox (--skip-inline-review on this feature's own waves).

---

## 1. Missing

No missing PRD requirements. All R1–R28 map to delivered code:

| Requirement group | Deliverable | Verdict |
|---|---|---|
| R1–R7 (inline review) | `implement.md` step 7 + `--skip-inline-review` flag | present |
| R8–R13 (`/specflow:review`) | `commands/specflow/review.md` | present |
| R14–R17 (reviewer agents × 3) | `.claude/agents/specflow/reviewer-{security,performance,style}.md` | present |
| R18–R21 (rubric files × 3) | `.claude/rules/reviewer/{security,performance,style}.md` | present |
| R22 (schema extension) | `rules/README.md` scope enum + dir layout + authoring checklist | present |
| R23 (hook skip) | `hooks/session-start.sh` SKIP_SUBDIRS guard at line 215–225 | present |
| R24–R27 (tests t34–t38) | all 5 test files present, exec bit set, passing | present |
| R28 (smoke 33→38) | `test/smoke.sh` t34–t38 registered, 38/38 green | present |

No tasks without corresponding code changes. No PRD requirements without a task.

---

## 2. Extra

### E1 — `implement.md` adds max-retry=2 cap and TPM escalation not in PRD or tech doc

**Severity**: note
**File**: `.claude/commands/specflow/implement.md:157,165`

Lines 157 and 165 read:
> "Max retries = 2 per task. If a task is still blocked after 2 retries, escalate to TPM via `/specflow:update-task`."
> "All reviewers blocked after 2 retries → escalate to TPM."

PRD R4 and R5 describe the retry loop with no count cap. PRD edge case §6 says the recovery is "retry (transient failure) or invoke `--skip-inline-review`". Tech doc D6 says "all 3 re-run every retry" with no bound. The `/specflow:update-task` escalation path does not exist in the command set. Neither document names a maximum of 2 retries.

**Recommended action**: Either back-fill as "R29 — retry cap at N=2 with TPM escalation" in 03-prd.md and note the decision in 04-tech.md, or remove the cap from `implement.md` and leave the decision to the user (`--skip-inline-review`). No functional harm either way. The cap is a reasonable guardrail; it just needs traceability.

---

## 3. Drift

### D1 — Agent `name:` fields for `reviewer-performance` and `reviewer-style` do not match dispatch names (SHOULD-FIX)

**Severity**: should-fix
**Files**: `.claude/agents/specflow/reviewer-performance.md:2`, `.claude/agents/specflow/reviewer-style.md:2`

Both `implement.md` (step 7, lines 42–44) and `review.md` (lines 24–27) dispatch reviewers by the identifiers `reviewer-security`, `reviewer-performance`, `reviewer-style`. Claude Code matches subagents by the `name:` frontmatter field. The three files have:

| File | `name:` value | Dispatch name in commands | Match |
|---|---|---|---|
| `reviewer-security.md` | `reviewer-security` | `reviewer-security` | ✓ |
| `reviewer-performance.md` | `specflow-reviewer-performance` | `reviewer-performance` | **FAIL** |
| `reviewer-style.md` | `specflow-reviewer-style` | `reviewer-style` | **FAIL** |

The existing 7 agents all use `name: specflow-<role>` (e.g. `specflow-qa-analyst`). T6 task spec wrote `name: reviewer-security` (no prefix) intentionally; T7 and T8 task specs also specified no prefix (`name: reviewer-performance`, `name: reviewer-style`) but the implementations added the `specflow-` prefix, creating a mismatch with both the task spec and the dispatch names in the command files.

**Runtime consequence**: an orchestrator following `implement.md` step 7 or `review.md` step 3 will invoke `reviewer-performance` and `reviewer-style`; Claude Code will search for agents with those exact `name:` values and will not find them (the files declare `specflow-reviewer-performance` and `specflow-reviewer-style`). The fail-loud posture (malformed/missing reviewer output → treat as BLOCK) would cause every wave merge to be blocked on the first real use of inline review.

**Recommended action**: Change `reviewer-performance.md` line 2 to `name: reviewer-performance` and `reviewer-style.md` line 2 to `name: reviewer-style`. This aligns with the dispatch names in both command files and with the T7/T8 task specifications. Fix before archive.

---

### D2 — `review.md` line 75 documents `YYYYMMDD` but code generates `YYYY-MM-DD` (note)

**Severity**: note
**File**: `.claude/commands/specflow/review.md:75`

Pseudocode at line 64 uses `date +%Y-%m-%d-%H%M`, producing `review-2026-04-18-1430.md` — correct per PRD R10 (`review-YYYY-MM-DD-HHMM.md`). The human-readable documentation on line 75 reads:
> "The three tiers are: `review-YYYYMMDD-HHMM.md` → `review-YYYYMMDD-HHMMSS.md` → ..."

The `YYYYMMDD` form omits the dashes within the date portion. The t37 test uses a loose grep pattern (`review-.*-.*-.*\.md`) that matches both forms, so the inconsistency is not caught by the test suite.

**Recommended action**: Fix line 75 to read `review-YYYY-MM-DD-HHMM.md` to match the code and the PRD. One-line documentation fix.

---

### D3 — `reviewer-security` agent lacks `specflow-` prefix common to all other agents (note)

**Severity**: note
**File**: `.claude/agents/specflow/reviewer-security.md:2`

All 7 pre-existing agents use `name: specflow-<role>`. T6 task spec explicitly wrote `name: reviewer-security` (no prefix), and the implementation matches the spec. Combined with D1's recommended fix (drop `specflow-` from performance and style), the three reviewer agents would all share no-prefix naming — a deliberate departure from the `specflow-<role>` convention. This departure should be documented explicitly, either in the README or in a comment in the agent files, so future authors know which convention applies to reviewer agents.

**Recommended action**: After D1 is resolved, add a note in `.claude/agents/specflow/README.md` (or the relevant memory file) that reviewer agents use `name: reviewer-<axis>` (no `specflow-` prefix) so the dispatch names in command files stay short. No code change needed; documentation only.

---

### D4 — `index.md` "sorted by scope then name" header violated by the whole table (note)

**Severity**: note
**File**: `.claude/rules/index.md`

The header says "Keep rows sorted by scope then name." The three new `reviewer/` rows were inserted alphabetically-by-name (between `no-force-on-user-paths` and `sandbox-home-in-tests`), consistent with the de-facto pattern of all existing rows but violating the stated policy. Correct scope-then-name order: `common/*` → `bash/*` → `reviewer/*`. This is a pre-existing disorder from B1 that this feature continued.

**Recommended action**: Fix the entire table to scope-then-name sort in a follow-up cleanup commit. No tool behaviour is affected; this is a human-readability issue.

---

## Memory-pattern checks

### dry-run-double-report-pattern
No `--dry-run` mode ships in this feature. Both aggregators (implement.md step 7, review.md step 5) are pure classifiers per D2/D3, with no adjacent report+mutation helper calls. Pattern does not apply.

### dead-code-orphan-after-simplification
All helper functions in the five new test scripts have callers: `t34` (`classify_footer` 8 refs, `check_agent` 2 refs), `t36` (`parse_verdict_dir` 8 refs), `t35/t37/t38` (only `pass`/`fail` helpers, fully used). No orphaned helpers found.

---

## Summary

| ID | Type | Severity | Description |
|---|---|---|---|
| E1 | Extra | note | `implement.md:157,165` adds undocumented max-retry=2 cap + TPM escalation |
| D1 | Drift | **should-fix** | `reviewer-performance.md:2` and `reviewer-style.md:2` `name:` fields don't match command dispatch identifiers; would block all inline review on first real use |
| D2 | Drift | note | `review.md:75` doc string uses `YYYYMMDD` instead of `YYYY-MM-DD` |
| D3 | Drift | note | `reviewer-security.md:2` lacks `specflow-` prefix; needs convention doc after D1 fix |
| D4 | Drift | note | `rules/index.md` rows sorted by name not scope-then-name; pre-existing, continued |

**Blocking gaps**: 0
**Should-fix gaps**: 1 (D1)
**Notes**: 4 (E1, D2, D3, D4)

---

## Verdict: PASS

Zero blockers. D1 is a real runtime defect that would manifest on the first real inline-review run (next feature after B2.b), but the `--skip-inline-review` escape hatch provides recovery and the dogfood paradox means the current feature itself was not subject to inline review. Fix D1 before archiving to prevent silent reviewer dispatch failure. All other findings are documentation/traceability nits.
