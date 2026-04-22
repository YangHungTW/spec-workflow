# Validate: 20260421-rename-flow-monitor
Date: 2026-04-22
Axes: tester, analyst

## Consolidated verdict
Aggregate: **NITS**
Findings: 0 must, 6 should, 1 advisory

Runtime AC10 + AC11 deferred to manual desktop-app walkthrough (no non-interactive path available for Tauri GUI).

## Tester axis

### AC Walkthrough Summary

| AC | Verdict | Evidence |
|---|---|---|
| AC1 grep-zero repo-wide | PASS | `bash test/t_grep_allowlist.sh` exits 0 ("all carryover hits allow-listed") |
| AC2 `palette.group.specflow` absent in `flow-monitor/src/` | PASS | grep returns 0 hits |
| AC3 capability allow-list: 2 new `.specaffold` paths, 0 legacy | PASS | JSON parse + key inspection confirms swap |
| AC4 invoke.rs shell script uses `scaff`, not `specflow` | PASS | line 304: `scaff '{cmd_escaped}'`; 0 `specflow` hits |
| AC5 cargo test green + seam4 renamed | PASS | 153 tests pass; `seam4_no_write_call_references_specaffold_path` in listing |
| AC6 i18n JSONs: new keys/values match delta exactly | PASS | python3 parse + assertion against string-delta §1/§2 |
| AC7 vitest passes | **NITS** | 11 pre-existing Tauri test-env failures (identical to main baseline); 0 rename-caused regressions |
| AC8 SettingsRepositories.tsx:33 uses `.specaffold` | PASS | confirmed at line 33 |
| AC9 README brand tokens + upgrade-notes line | PASS | lines 3, 77, 99-100, 136 use scaff/specaffold; line 145 has R10 upgrade-notes line with legacy path |
| AC10 runtime walkthrough (sidebar, invoke, audit.log) | **DEFERRED** | Tauri desktop app requires GUI interaction — manual verification by user |
| AC11 runtime zh-TW locale check | **DEFERRED** | Requires app launch + locale switch — manual verification by user |
| AC12 architect sign-off on capability swap | PASS | `04-tech.md §4.4` contains full sign-off; diff confirms atomic swap |

### Verdict footer

```
## Validate verdict
axis: tester
verdict: NITS
findings:
  - severity: should
    ac: AC7
    evidence: "cd flow-monitor && npx vitest run → 11 failed | 375 passed; identical result on main baseline (pre-existing Tauri @tauri-apps/api mock failures; T15 NITS per STATUS.md)"
    message: 11 vitest failures are pre-existing Tauri test-env failures, not rename regressions; feature branch does not worsen baseline
  - severity: should
    ac: AC10
    evidence: no non-interactive path available; Tauri desktop app requires full tauri build + macOS GUI interaction
    message: runtime AC10 walkthrough requires manual desktop-app launch; structural evidence PASS; deferred to manual verification by user
  - severity: should
    ac: AC11
    evidence: no non-interactive path available; zh-TW locale requires app launch + settings locale switch
    message: runtime AC11 walkthrough requires manual desktop-app launch with locale switched to zh-TW; i18n bundle values verified structurally in AC6; deferred to manual verification by user
```

## Analyst axis

### Gap Analysis Summary

**Requirements map (R1–R11)**: all 11 requirements implemented and verified in the diff. Every R-id has at least one corresponding task commit with the expected file delta.

**Acceptance criteria map (AC1–AC12)**: 9 structural ACs verified (AC1, AC2, AC3, AC4, AC5 via STATUS testimony, AC6, AC8, AC9, AC12); AC7 NITS (pre-existing vitest env failures); AC10 / AC11 deferred to runtime manual walkthrough (by design per plan §3 risk 6).

**Decisions compliance**: all 13 decisions (PRD D1–D7 + tech-D1 through tech-D6) respected in the shipped diff. No dual-path fallback, no shared constant, no transition-window capability dual-grant, no one-time audit-log migration — all decisions held.

**Scope audit — plan-drift findings**:

1. **T16 added 3 extra allow-list entries inline without `/scaff:update-plan`**. The T14 plan scope says "exactly one narrow entry" with a verify check requiring count unchanged; the shipped allowlist grew from 11 → 14 entries. The 3 extra entries (`flow-monitor/dist/**`, `.specaffold/features/20260421-rename-flow-monitor/**`, `.claude/team-memory/**`) are individually justified, but the plan's T14 verify check is now falsified.

2. **Tech §6 said "zero new entries required"**. The architect did not anticipate 3 additional carve-outs needed at T16 time. Tech-doc was not updated.

3. **`.claude/team-memory/**` is over-broad**. Only 7 specific files contain legacy strings; the blanket `/**` exempts all 65 team-memory files, silently granting future memory entries a pass on the grep-zero invariant.

4. **`.specaffold/features/20260421-rename-flow-monitor/**` forward-allows RETROSPECTIVE.md** (a file that does not yet exist). Matches the `pre-allow-before-file-exists-is-a-silent-over-exemption` pattern from the predecessor feature.

No missing work, no dropped ACs, no `must`-severity regressions.

### Verdict footer

```
## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    area: carve-out
    message: ".claude/team-memory/** blanket exemption covers 65 files; only 7 files actually contain legacy strings; blanket pattern silently exempts any future memory entry from the grep-zero invariant"
  - severity: should
    area: plan-gap
    message: "T16 remediation added 3 extra allow-list entries in bookkeeping commit 4c8a149 without /scaff:update-plan; 05-plan.md T14 scope still says 'exactly flow-monitor/README.md' and its Verify check (count unchanged) is falsified by the shipped state (11 entries → 14)"
  - severity: should
    area: drift
    message: "tech §6 declared 'zero new entries required' but 3 additional entries were required at T16 time; tech-doc was not updated to reflect actual allow-list delta"
  - severity: advisory
    area: carve-out
    message: ".specaffold/features/20260421-rename-flow-monitor/** forward-allows RETROSPECTIVE.md before it exists; archive-time author will not see a grep failure prompting review of any legacy strings it introduces"
```

## Validate verdict
axis: aggregate
verdict: NITS
