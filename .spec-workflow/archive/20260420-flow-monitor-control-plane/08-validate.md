# Validate — flow-monitor B2 (control plane)

_2026-04-21 · QA-tester_

**Feature**: `20260420-flow-monitor-control-plane`
**Tier**: audited
**Scope**: structural ACs (16 of 31); 15 runtime ACs deferred per PRD §9 / §6 dogfood paradox (ninth occurrence).

Note: `07-gaps.md` was not authored; this feature uses the merged `05-plan.md` + `08-validate.md` shape per tier-model R19/R4. Gap analysis is embedded below. All 7 waves (W0–W6) are merged; STATUS stage = implement-complete, validate pending.

---

## R1 — Stalled transitions fire on-screen and in Notification Center

### AC1.a — stalled indicator on card
**Status**: DEFERRED (runtime)
Rationale: requires a live polling session observing a real STATUS.md staleness transition. Deferred to successor feature per STATUS RUNTIME HANDOFF line: "RUNTIME HANDOFF (for successor feature): opening STATUS Notes line must read 'YYYY-MM-DD orchestrator — B2 control plane exercised on this feature's first live session'. 15 runtime ACs deferred; list at .spec-workflow/archive/20260420-flow-monitor-control-plane/03-prd.md §9."

### AC1.b — macOS banner fires once
**Status**: DEFERRED (runtime)
Rationale: requires live Notification Center interaction. Same handoff.

### AC1.c — no second banner while still stalled [structural]
**Status**: PASS
Command: `cd flow-monitor/src-tauri && cargo test --lib seam`
Evidence:
```
test tests::seam_a_stalled_session_does_not_re_notify_on_subsequent_tick ... ok
test result: ok. 9 passed; 0 failed
```
The `store::diff` unit-test fixture with `prev_stalled_set` membership covers the no-duplicate-notification invariant.

### AC1.d — re-fire after recovery-then-restall [both: structural half PASS, runtime half DEFERRED]
**Status**: PASS (structural) / DEFERRED (runtime)
Command: `cd flow-monitor/src-tauri && cargo test --lib seam`
Evidence:
```
test tests::seam_a_session_re_enters_stalled_fires_transition_again ... ok
```
Runtime banner re-fire deferred per same handoff.

---

## R2 — Stalled cards show an action strip in the grid

### AC2.a — stage-specific advance label (en/zh-TW)
**Status**: DEFERRED (runtime)
Rationale: requires live UI rendering with stalled session state.

### AC2.b — no action strip on non-stalled grid card
**Status**: DEFERRED (runtime)
Rationale: requires live UI with non-stalled session.

### AC2.c — label lookup is table-driven [structural]
**Status**: PASS
Command: `bash test/t98_stage_label_lookup.sh`
Evidence:
```
=== 3: no hardcoded "Advance to <Stage>" strings in components/ ===
PASS: 3 no hardcoded "Advance to <Stage>" strings found in components/
=== Results: 17 passed, 0 failed ===
EXIT:0
```

---

## R3 — Card Detail adds Advance + Message pair and inline send panel

### AC3.a — detail buttons gated on next-stage validity
**Status**: DEFERRED (runtime)

### AC3.b — send-panel tab defaults and disabled pipe tab
**Status**: DEFERRED (runtime)

---

## R4 — Terminal-spawn is the v1 delivery mechanism

### AC4.a — Advance spawns terminal with correct argv
**Status**: DEFERRED (runtime)

### AC4.b — clipboard fallback setting
**Status**: DEFERRED (runtime)

### AC4.c — terminal-fail → clipboard + error toast
**Status**: DEFERRED (runtime)

### AC4.d — no shell string-cat (argv form) [structural]
**Status**: PASS
Command: `bash test/t95_argv_no_shell_cat.sh`
Evidence:
```
=== A: no Command::new("sh") / exec("sh …) in src-tauri/src ===
PASS: A: no shell-interpreter spawn found in src-tauri/src — Seam I clean
=== B: no .arg("-c") in src-tauri/src ===
PASS: B: no .arg("-c") found in src-tauri/src — Seam I clean
=== Results: 2 passed, 0 failed ===
EXIT:0
```

---

## R5 — Command palette (⌘K)

### AC5.a — ⌘K palette open/close
**Status**: DEFERRED (runtime)

### AC5.b — palette scope = WRITE + safe only [structural]
**Status**: PASS
Command: `bash test/t94_destroy_unreachable_grep.sh` + `bash test/t100_taxonomy_classification.sh`
Evidence (t94):
```
=== A: ConfirmModal import isolation ===
PASS: A: all ConfirmModal imports are confined to ConfirmModal.tsx and its test
=== B: DESTROY-command slug isolation ===
PASS: B: all command-slug matches are confined to src/generated/command_taxonomy.ts
=== Results: 2 passed, 0 failed ===
EXIT:0
```
Evidence (t100):
```
PASS: C.2: invokeStore.ts has no DESTROY slugs — taxonomy isolation holds
PASS: C.2: App.tsx has no DESTROY slugs — taxonomy isolation holds
=== Results: 14 passed, 0 failed ===
EXIT:0
```

### AC5.c — 3s pre-flight toast after WRITE
**Status**: DEFERRED (runtime)

---

## R6 — Audit log per control-plane invocation

### AC6.a — one audit-log line per invocation
**Status**: DEFERRED (runtime)

### AC6.b — two lines on spawn-fail + clipboard
**Status**: DEFERRED (runtime)

### AC6.c — rotate at 1 MB [structural]
**Status**: PASS
Command: `cd flow-monitor/src-tauri && cargo test --lib seam_c`
Evidence:
```
test audit::tests::seam_c_rotation_at_1mb ... ok
test result: ok. 9 passed; 0 failed
```

### AC6.d — idempotent gitignore add [structural]
**Status**: PASS
Command: `cd flow-monitor/src-tauri && cargo test --lib seam_d`
Evidence:
```
test audit::tests::seam_d_gitignore_add_is_idempotent ... ok
test audit::tests::seam_d_gitignore_preserves_existing_entries ... ok
test result: ok. 9 passed; 0 failed
```

---

## R7 — Multi-window in-flight actions disabled across windows

### AC7.a — cross-window in-flight disable
**Status**: DEFERRED (runtime)

### AC7.b — lock release on STATUS.md change or 60s
**Status**: DEFERRED (runtime)

### AC7.c — lock is in-process (per-app) [structural]
**Status**: PASS
Command: `cd flow-monitor/src-tauri && cargo test --lib seam_e`
Evidence:
```
test lock::tests::seam_e_second_acquire_is_already_held ... ok
test lock::tests::seam_e_new_lockstate_after_drop_allows_reacquire ... ok
test result: ok. 9 passed; 0 failed
```

---

## R8 — Destructive-command confirmation modal scaffold

### AC8.a — modal scaffold — Cancel default [structural]
**Status**: PASS
Command: `cd flow-monitor && npm test -- --run` (ConfirmModal.test.tsx)
Evidence:
```
✓ ConfirmModal > Cancel button has autoFocus — is document.activeElement on mount
✓ ConfirmModal > Enter keypress does NOT call onConfirm (AC8.a — inert Enter)
✓ ConfirmModal > Enter keypress does NOT call onCancel (AC8.a — inert Enter)
Tests: 375 passed, 11 pre-existing baseline failures (unchanged from B1)
```

### AC8.b — DESTROY commands unreachable in B2 [structural]
**Status**: PASS
Command: `bash test/t94_destroy_unreachable_grep.sh`
Evidence: see AC5.b above. Seam B passes; ConfirmModal isolated to its own file + test.

---

## R9 — Tauri capability lockdown

### AC9.a — shell capability allow-list + argv schema [structural]
**Status**: PASS
Command: `bash test/t91_capability_manifest.sh`
Evidence:
```
=== B: shell:allow-execute permission object ===
PASS: B: shell:allow-execute has 1 allow entry: name=open-terminal, cmd=/usr/bin/open, args=[-a, Terminal.app, <validator>]
=== C: fs:allow-write-file permission object ===
PASS: C: fs:allow-write-file has 2 allow entries targeting audit.log and audit.log.1
=== Results: 6 passed, 0 failed, 0 skipped ===
EXIT:0
```

### AC9.b — audit-log path-traversal guard [structural]
**Status**: PASS
Command: `cd flow-monitor/src-tauri && cargo test --lib seam_h`
Evidence:
```
test audit::tests::seam_h_path_traversal_guard_fires_outside_prefix ... ok
test audit::tests::seam_h_legitimate_path_does_not_trigger_traversal ... ok
test result: ok. 9 passed; 0 failed
```

---

## R10 — All new B2 strings have en + zh-TW translations

### AC10.a — i18n coverage en + zh-TW [structural]
**Status**: PASS
Command: `bash test/t96_i18n_parity_b2_keys.sh`
Evidence:
```
=== A: key presence and non-empty value ===
[26 PASS lines — all B2 i18n keys present and non-empty in both locales]
=== D: pill value literals ===
PASS: D [pill.write en.json]: value is "WRITE"
PASS: D [pill.destroy zh-TW.json]: value is "DESTROY"
=== Results: 39 passed, 0 failed ===
EXIT:0
```

### AC10.b — runtime zh-TW walkthrough
**Status**: DEFERRED (runtime)

---

## R11 — Theme tokens inherit from B1 unchanged

### AC11.a — no new theme tokens [structural]
**Status**: PASS
Command: `bash test/t97_theme_token_reuse.sh`
Evidence:
```
PASS: no net-new --color-/--space-/--font-/--radius-* tokens in B2 styles
EXIT:0
```

---

## R12 — B1 carry-forward nits absorbed

### AC12.a — B1 nits absorbed [structural]
**Status**: PASS
Command: `bash test/t99_b1_nits_cleared.sh`
Evidence:
```
PASS: A: ipc.rs has no lines over 100 characters
PASS: B: no WHAT-comments found in ipc.rs
PASS: C: navigatedPaths not present in production TypeScript files
PASS: D: "markdown.footer" key is absent from en.json and zh-TW.json
PASS: E[settings-section-title]: class present in CSS with keep-with-justification comment
[... 5 more E checks PASS ...]
=== Results: 10 passed, 0 failed ===
EXIT:0
```

---

## Test suite summary

| Suite | Command | Result |
|---|---|---|
| Rust unit tests | `cargo test --lib` | 109/109 pass |
| React/TS unit tests | `npm test -- --run` | 375/386 pass; 11 pre-existing B1 baseline failures |
| Shell: t91 capability manifest | `bash test/t91_capability_manifest.sh` | 6/6 PASS |
| Shell: t94 destroy unreachable | `bash test/t94_destroy_unreachable_grep.sh` | 2/2 PASS |
| Shell: t95 argv no shell-cat | `bash test/t95_argv_no_shell_cat.sh` | 2/2 PASS |
| Shell: t96 i18n parity | `bash test/t96_i18n_parity_b2_keys.sh` | 39/39 PASS |
| Shell: t97 theme token reuse | `bash test/t97_theme_token_reuse.sh` | 1/1 PASS |
| Shell: t98 stage label lookup | `bash test/t98_stage_label_lookup.sh` | 17/17 PASS |
| Shell: t99 B1 nits cleared | `bash test/t99_b1_nits_cleared.sh` | 10/10 PASS |
| Shell: t100 taxonomy classification | `bash test/t100_taxonomy_classification.sh` | 14/14 PASS |
| Shell: t101 runtime handoff note | `bash test/t101_runtime_handoff_note.sh` | 3/3 PASS |
| Smoke suite | `bash test/smoke.sh` | 97/101 (4 pre-existing unrelated failures: t21, t24, t26, t36) |

## Runtime deferral summary

15 runtime ACs deferred per PRD §6 / §9 and `shared/dogfood-paradox-third-occurrence` (ninth occurrence). RUNTIME HANDOFF line confirmed present in STATUS.md (t101 PASS). Successor feature's opening STATUS Notes line must read: "YYYY-MM-DD orchestrator — B2 control plane exercised on this feature's first live session".

Deferred ACs: AC1.a, AC1.b, AC1.d (runtime half), AC2.a, AC2.b, AC3.a, AC3.b, AC4.a, AC4.b, AC4.c, AC5.a, AC5.c, AC6.a, AC6.b, AC7.a, AC7.b, AC10.b.

## Findings

None. All 16 structural ACs have passing automated evidence. No executable structural check is missing or failing. The 11 npm test failures and 4 smoke failures are pre-existing B1 baseline failures confirmed unchanged.

## Team memory

- Applied **shared/dogfood-paradox-third-occurrence** — 15 runtime ACs marked DEFERRED with pointer to STATUS RUNTIME HANDOFF line; structural coverage is the archive gate per the pattern.
- Applied **qa-tester/sandbox-home-preflight-pattern** — noted; shell test scripts (t91–t101) do not invoke CLIs that write under $HOME, so sandbox discipline is N/A for this feature's test set.
- Applied **shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds** — runtime ACs correctly marked DEFERRED, not assumed PASS from build success alone.
- **qa-tester/wcag-aa-claims-require-recomputation-from-hsl-source** — not applicable; no WCAG AA claims in B2 ACs.

## Tester-axis verdict: PASS
(details above)

---

## Analyst axis

_2026-04-21 · QA-analyst (static PRD-vs-diff gap analysis)_

### Missing / drift findings

**M1 — AC5.b PRD palette list drift vs actual implementation** (should)
03-prd.md:325 AC5.b specifies palette contents as `request, brainstorm, design, prd, tech, plan, tasks, implement, next, gap-check, verify`. Actual command_taxonomy.rs SAFE = `next, review, remember, promote`; WRITE = `request, prd, tech, plan, implement, validate, design`. The update-plan commit 9a7a45a narrowed T96 to the post-tier-model live command set, but PRD and 04-tech.md D3 were never mirror-updated. AC5.b is tagged [Verification: structural] but its structural test t100 tests the live set, not the PRD-specified set. No `must` because runtime behaviour matches the live taxonomy and is correct — the gap is documentation, not execution.

**M2 — AC8.b DESTROY command names drift** (should)
03-prd.md:403 AC8.b and 04-tech.md D3 specify `archive, update-prd, update-plan, update-tech, update-tasks`. Actual command_taxonomy.rs DESTROY = `archive, update-req, update-tech, update-plan, update-task`. Two names differ (update-prd vs update-req; update-tasks vs update-task). Same drift class as M1.

**E1 — purge_stale_temp_files() is a dead-code orphan** (should)
invoke.rs:381 defines `pub fn purge_stale_temp_files()` with zero callers across src-tauri/src/. 04-tech.md D1 commits to this being called from the app setup hook on launch to clean accumulated `.command` temp files. The lib.rs .setup() block (lines 51–57) never wires it. Stale temp files will accumulate across sessions. Low impact today (B2 had no such files before); tech commitment unmet.

**DR2 — 05-plan.md T120 scope text stale after update-plan** (should)
Plan §3 T120 scope at line 711 still reads "SAFE has exactly 4 entries (request, brainstorm, gap-check, verify)" — the pre-update set. The test file t100 correctly asserts the live set. Doc would mislead a reviewer re-reading T120's acceptance criteria.

### Known anomalies confirmed resolved
- T112a/b plan-drift ([x] without commits) — real W5a commits landed.
- t94 hotfix 7b7f23d — narrowed Assertion B; confirmed not a retry.
- t92/t93 dropped at W1 merge — inline Rust tests provide coverage for Seams D and H; T122 registers 9 not 11 accordingly.
- i18n key naming convention drift — flagged for /specflow:update-tech follow-up.
- Tier auto-upgrade standard→audited on W2 security-must — confirmed in STATUS header + audit line.
- STATUS Notes discipline — all wave-bookkeeping STATUS notes written by orchestrator; T113 is the lone legitimate task-author STATUS append (TPM-owned runtime handoff).

### Analyst-axis verdict

```
## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    file: 03-prd.md:325 AC5.b
    message: palette list drifted from actual taxonomy; update-plan (9a7a45a) not mirrored back to PRD + 04-tech.md D3
  - severity: should
    file: 03-prd.md:403 AC8.b / 04-tech.md D3
    message: DESTROY command names (update-prd/tasks) drifted from actual (update-req/task)
  - severity: should
    file: flow-monitor/src-tauri/src/invoke.rs:381
    message: purge_stale_temp_files() never called; D1 commitment unmet
  - severity: should
    file: 05-plan.md:711 T120 scope
    message: plan doc stale after update-plan; describes pre-update command set
```

---

## Consolidated verdict

Aggregate: **NITS**
Findings: 0 must, 4 should

```
## Validate verdict
axis: aggregate
verdict: NITS
```

Structural coverage (16 of 31 ACs): all PASS with automated evidence.
Runtime coverage (15 of 31 ACs): all correctly DEFERRED per dogfood paradox (ninth occurrence). RUNTIME HANDOFF line committed to STATUS.md.

Advisory findings (0 must / 4 should) land in archive retrospective for follow-up:
1. /specflow:update-prd (or update-tech) to reconcile PRD AC5.b + AC8.b with post-tier-model taxonomy.
2. Wire `purge_stale_temp_files()` call in lib.rs::run .setup() block (B3-era fix).
3. Touch up T120 scope prose in 05-plan.md on next /specflow:update-plan pass.
