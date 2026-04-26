# Validate: 20260426-chore-status-template-skip-stages
Date: 2026-04-26
Axes: tester, analyst

## Consolidated verdict
Aggregate: NITS
Findings: 0 must, 2 should

## Tester axis

### C1 — `[~]` in matrix-skip pseudocode block of `next.md`

```
$ grep -n -F '[~]' .claude/commands/scaff/next.md
59:         # rewrite the leading `[ ]` to `[~]` and append ` (skipped — chore × tiny matrix)` suffix to that stage line.
63:         #   After:  - [~] design        (02-design/)                 — Designer (skip if has-ui: false) (skipped — chore × tiny matrix)
74:   - If `has-ui: false` and next stage is `design` → rewrite the `design` checklist line to `[~] design ... (skipped — has-ui: false)` in STATUS, append a STATUS Notes line, then re-read and advance again.
```

Line 59 is inside the `case "$status" in skipped)` arm. Line 63 is the "After:" example. PASS.

### C2 — `skipped — has-ui: false` in `has-ui` design-skip path

```
$ grep -n -F 'skipped — has-ui: false' .claude/commands/scaff/next.md
74:   - If `has-ui: false` and next stage is `design` → rewrite the `design` checklist line to `[~] design ... (skipped — has-ui: false)` in STATUS, append a STATUS Notes line, then re-read and advance again.
```

PASS.

### C3 — Forward-only verification

C3 requires a freshly-initialised chore × tiny feature to be advanced past `prd` after this chore lands. No such feature exists yet. Documented in PRD §Checklist as forward-only and in plan §1.3. Static proxy check: pseudocode at next.md lines 57–66 instructs the orchestrator to write the new `[~]` shape going forward. DEFERRED — not a finding.

### C4 — qa-analyst memory updated

```
$ grep -n -F '[~]' .claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md
26: 3. **New convention (post-`20260426-chore-status-template-skip-stages`)**: ...
```

§How to apply step 3 names `[~]` as the new convention going forward; legacy `[x]` precedents preserved in step 1. PASS.

### §Verify rolled-up commands

| Command | Exit | Result |
|---|---|---|
| `grep -F '[~]' .claude/commands/scaff/next.md` | 0 | 3 matches |
| `grep -F 'skipped — has-ui: false' .claude/commands/scaff/next.md` | 0 | 1 match |
| `grep -F '[~]' .claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md \|\| [ ! -f ... ]` | 0 | grep matched (line 26) |

### Markdown sanity check

`.claude/commands/scaff/next.md`: YAML front-matter, headings, code-fences, table, and bash pseudocode block all properly closed. The edit lines 59/63 are inside a bash comment inside a markdown code block — syntactically inert. PASS.

### Adjacent regression

`bash test/t114_seed_settings_json.sh` → exit 0; all assertions PASS. No regression.

### Diff scope

Exactly 4 files changed: `.claude/commands/scaff/next.md`, `.claude/team-memory/qa-analyst/chore-tiny-status-checkbox-vs-notes-asymmetry.md`, plus 2 bookkeeping (`05-plan.md`, `STATUS.md`). No unintended files touched. `bin/scaff-stage-matrix` and `_template/STATUS.md` confirmed unchanged.

## Validate verdict
axis: tester
verdict: PASS
findings: []

## Analyst axis

### Diff scope

15 insertions / 6 deletions across 4 files. Substantive: next.md (+8/-2) and the qa-analyst memory (+1/-1). Bookkeeping: 05-plan.md (T1 checkbox flip) and STATUS.md (Notes lines).

### Missing

None. All four PRD §Checklist items covered (C3 deferred forward-only by design; not a missing).

### Extra

None. Out-of-scope discipline clean: `bin/scaff-stage-matrix`, `.specaffold/features/_template/STATUS.md`, and the three already-archived chore-tiny STATUS files all unchanged.

### Drifted

**Finding 1 — should — memory-index-consistency**

`.claude/team-memory/qa-analyst/index.md` line 15 hook line still reads `Retire when STATUS template plumbing-fix lands` — directly contradicts the updated memory body (§How-to-apply step 3 now states the file is no longer a retirement candidate). Plan §3 Risks second bullet anticipated this and recommended updating the index hook line; Developer did not. Stale index hook will mislead a future analyst who reads only the index line.

File: `.claude/team-memory/qa-analyst/index.md` line 15.

**Finding 2 — should — advisory-threshold-suggest (informational)**

STATUS line 33 records `auto-upgrade SUGGESTED tiny→standard (diff: 9 lines, 4 files; threshold 200/3 — files-count exceeded, lines well under)`. This is a files-count-floor trigger where bookkeeping (05-plan.md + STATUS.md) is the majority of the 4-file count. The STATUS Note correctly identifies this as a false-positive variant of `tpm/threshold-suggest-test-vs-prod-line-asymmetry`. The existing memory's decline criteria target test-line dominance, not bookkeeping floor — the archive retro should consider extending the memory to cover this second variant so the SUGGEST decline rationale is documented for both causes.

File: `.specaffold/features/20260426-chore-status-template-skip-stages/STATUS.md` line 33 (informational; the STATUS already documents the rationale, but the upstream memory does not yet cover this case).

### Render-shape correctness

PRD §Decisions (b): orchestrator rewrites only the leading checkbox + appends suffix; does not replace the line text. The next.md comment block lines 60-63 explicitly describes "do NOT replace the original right-hand annotation" with a verbatim before/after example preserving role attribution. CORRECT.

### Memory dual-posture

Step 1 (legacy `[x]` acceptance criteria) untouched; Step 3 (new `[~]` convention) added. Both shapes correctly described — legacy applies to archived chore-tiny features, new applies to future. CORRECT.

### STATUS hygiene

Stage field `validate` correct. All Notes lines present and consistent (request tier, PM, chore intake, design/tech/plan skip with pre-fix `[x]` rationale, stage advance, Developer T1 done, skip-inline-review, wave 1 done, threshold SUGGEST with explanation, implement done). No gaps.

### Threshold-SUGGEST observation (informational)

Files-count-floor trigger; lines (9) far below the 200 line threshold. Worth surfacing at archive retro as a memory-extension candidate (Finding 2 above).

## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    file: .claude/team-memory/qa-analyst/index.md
    line: 15
    rule: memory-index-consistency
    message: Index hook line still reads "Retire when STATUS template plumbing-fix lands" — contradicts the updated memory body (§How-to-apply step 3 now says the file is no longer a retirement candidate); plan §3 Risks second bullet flagged this as a mitigation item; Developer did not update it.
  - severity: should
    file: .specaffold/features/20260426-chore-status-template-skip-stages/STATUS.md
    line: 33
    rule: advisory-threshold-suggest
    message: Threshold SUGGEST tiny→standard fired on 4-file bookkeeping floor (lines well under 200); archive retro should consider extending tpm/threshold-suggest-test-vs-prod-line-asymmetry memory to cover the bookkeeping-floor cause variant.

## Validate verdict
axis: aggregate
verdict: NITS
