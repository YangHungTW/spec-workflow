# Gap Check — prompt-rules-surgery (B1)

_2026-04-17 · QA-analyst_

Scope: Items 1, 2, 3 only (B1). Items 4/5/6 are deferred to B2 and are NOT flagged.

---

## 1. Missing

### M1 — T4 STATUS note absent from 06-tasks.md `## STATUS Notes` section

**Severity**: note  
**R-id**: n/a (process)  
**Evidence**: `06-tasks.md` STATUS Notes section has entries for T1, T2, T3, T5, T6, T7, T10–T22. T4 (`no-force-on-user-paths` rule) has no individual note. The wave-2 STATUS.md entry `"implement wave 2 done — T2, T3, T4, T5, T6, T7"` confirms T4 was done, and the file exists (`/Users/yanghungtw/Tools/spec-workflow/.claude/rules/common/no-force-on-user-paths.md`), but the per-task note in 06-tasks.md was dropped during the wave-2 merge.  
**Recommended action**: Add a retroactive T4 STATUS note to `06-tasks.md`. No code change needed — the rule file is correct and fully verified.

### M2 — `settings.json.bak` committed to the feature branch (no `.gitignore` entry)

**Severity**: should-fix  
**R-id**: D12  
**Evidence**: `git ls-files settings.json.bak` returns the file. D12 states: "safety net, not version history; git is version history." `settings.json.bak` is identical to `settings.json` (both 205 bytes, same content), meaning it adds no safety value as a committed artifact and will be stale whenever `settings.json` changes. Neither `.gitignore` nor the tasks plan adds a `.gitignore` entry for `settings.json.bak`.  
**Recommended action**: Add `settings.json.bak` to `.gitignore` and remove it from the index (`git rm --cached settings.json.bak`). The D12 invariant is "runtime backup"; it should not be a tracked repo file.

---

## 2. Extra

### E1 — `test/t7_specflow_install_hook.sh` not in tasks plan and not wired into `test/smoke.sh`

**Severity**: note  
**Task-id**: None (no task plans this file)  
**Evidence**: `ls test/` shows `t7_specflow_install_hook.sh` (164 lines). No task in `06-tasks.md` lists this file as a deliverable. `grep 't7_specflow_install_hook' test/smoke.sh` returns zero matches — it is silently unexecuted. The D12 invariants it covers (idempotence, key preservation) are already covered by `test/t27_settings_json_preserves_keys.sh` and `test/t28_settings_json_idempotent.sh`, which ARE wired into smoke.sh.  
**Recommended action**: Either wire it into smoke.sh with a note explaining the overlap, or remove it. Leaving an unwired test file in `test/` creates false confidence and future confusion about coverage. The preferred action is removal (coverage already exists in t27/t28).

---

## 3. Drift

### DR1 — `settings.json` missing `$schema` key from D2's canonical shape

**Severity**: note  
**R-id**: D2  
**Evidence**: D2's "Concrete `settings.json`" block shows:
```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": { ... }
}
```
The actual committed `settings.json` at repo root contains only the `"hooks"` key — no `"$schema"`. AC-hook-wired only requires the SessionStart entry to be present, which it is. The `$schema` key is not required by any AC, but it is shown as part of the D2 canonical shape.  
**Recommended action**: Add `"$schema": "https://json.schemastore.org/claude-code-settings.json"` to `settings.json` via `bin/specflow-install-hook` or a one-time `python3` merge. Low-priority cosmetic alignment with D2.

### DR2 — `06-tasks.md` STATUS Notes section contains no entries for T8, T9, T17, T23, T24, T25

**Severity**: note  
**R-id**: n/a (process)  
**Evidence**: The `## STATUS Notes` section in `06-tasks.md` ends after T22. Entries for T8 (user checkpoint), T9 (settings.json wire), T17 (dedup audit), T23 (smoke.sh integration), T24 (docs README), T25 (top-level README) exist in `STATUS.md` but were not backfilled into `06-tasks.md`. The D10 template specifies that every task completion appends a line in `06-tasks.md`; the STATUS Notes section is the authoritative per-task record.  
**Recommended action**: Backfill the missing notes from `STATUS.md` into the `06-tasks.md` STATUS Notes section. No code change — documentation consistency only.

---

## Coverage Summary (all PRD requirements and ACs verified)

| Requirement | AC | File/Evidence | Status |
|---|---|---|---|
| R1 (rules dir structure) | AC-rules-dir | 4 subdirs present; `test -d` verifiable | PASS |
| R2 (rule file format) | AC-rules-schema | All 5 rule files: 5 frontmatter keys + 3 required body sections | PASS |
| R3 (initial 5 rules) | AC-rules-count | 5 slugs present; `common/` has 3 files | PASS |
| R4 (hook script + settings.json) | AC-hook-exists, AC-hook-wired | `.claude/hooks/session-start.sh` exec bit set; `settings.json` references hook | PASS |
| R5 (hook behavior) | AC-hook-failsafe, AC-hook-bad-frontmatter, AC-hook-lang-lazy | t18, t19, t20 tests exist | PASS |
| R6 (common always-load) | AC-hook-lang-lazy | Hook walks `common/` unconditionally | PASS |
| R7 (two-layer per agent) | AC-slim-line-count | All 7 core files within R9b ceilings | PASS |
| R8 (core header order) | AC-core-header-grep | All 7 files: frontmatter → identity → Team memory → When invoked | PASS |
| R9 (appendix pointer phrase) | AC-appendix-pointers-resolve | 4 appendix files; section pointers verified against headings | PASS |
| R9b (>=30% slim) | AC-slim-line-count | pm:22/22, designer:22/22, developer:24/24, qa-analyst:21/21, qa-tester:21/23, architect:32/37, tpm:39/44 — all at or below ceiling | PASS |
| R10 (memory invocation block) | AC-memory-required | All 7 roles: `ls ~/.claude/team-memory/<role>/` token present | PASS |
| R11 (Team memory section) | AC-memory-section-visible | All 7 roles: `## Team memory` heading + required phrases present | PASS |
| R12 (missing dir message) | AC-missing-memory-dir | All 7 roles: `dir not present:` token present | PASS |
| R13 (no auto-linter) | n/a | No linter implemented; per PRD non-goal | PASS |
| R14 (no duplication) | AC-no-duplication | `grep -lE 'readlink -f\|--force\|sandbox-HOME' agents/*.md` returns zero | PASS |
| R15 (no new command) | AC-no-new-command | `ls .claude/commands/specflow/ | wc -l` = 18, matches baseline | PASS |
| R16 (no regression) | AC-no-regression | 28 tests registered in smoke.sh; T8 confirmed hook fires in real session | PASS |
| D12 (read-merge-write) | t27, t28 | `bin/specflow-install-hook` preserves keys + idempotent; .bak created (see DR1 on committed .bak) | PASS (drift noted) |

---

## Verdict: PASS

Zero blockers. Two should-fixes and three notes.

**Blocker count**: 0  
**Should-fix count**: 1 (M2 — `settings.json.bak` committed without `.gitignore` entry)  
**Note count**: 4 (M1 missing T4 STATUS note; E1 unwired test file; DR1 missing `$schema`; DR2 missing STATUS notes for T8/T9/T17/T23/T24/T25)
