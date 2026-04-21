# Plan — rename-flow-monitor

**Feature**: `20260421-rename-flow-monitor`
**Stage**: plan
**Author**: TPM
**Date**: 2026-04-21
**Tier**: audited
**has-ui**: true
**Shape**: **new merged form** (narrative + task checklist in one file per new-shape `/scaff:plan` contract; tier field present in STATUS). No `06-tasks.md` will be authored for this feature.

PRD: `03-prd.md` (R1–R11, AC1–AC12, §8 D1–D7 user-pinned).
Tech: `04-tech.md` (§3 D1–D6, §4.4 architect sign-off on AC12, §6 allow-list delta).
Design delta: `02-design/string-delta.md` (14-row rename table; §6 user decisions).

---

## 1. Approach and wave choice

This is a **rename-only** pass inside the `flow-monitor/` Tauri sub-project. No functional changes, no new abstractions, no refactors. Every `specflow` / `spec-workflow` reference outside the tightly-scoped R10 allow-list entry is replaced with `scaff` / `specaffold` per the design delta.

### Wave choice: **Option B — two strictly-ordered waves**

- **W1** — Rust backend (`src-tauri/src/**/*.rs`) + Rust tests + fixtures + Tauri capability swap.
- **W2** — React frontend (`src/**/*.tsx`) + i18n bundles + README + carryover allow-list edit.

**Rationale** (one paragraph): Tier is `audited` because `src-tauri/capabilities/default.json` is the filesystem-access boundary (PRD §6; tech §4.4). Splitting into W1 = backend-only lets the security reviewer audit the capability-swap diff (T7) inside a smaller, backend-only wave with no React noise interleaved, which is the primary leverage the tier-audited gate offers. W1 also satisfies PRD D6's merge-order constraint automatically — the Rust scanner rename (R1) lands before the frontend `path_exists` consumer (R6). Within each wave, every task writes to disjoint files, so intra-wave parallelism is real and git-safe per `tpm/parallel-safe-requires-different-files`. Option A (single wave) was considered but rejected because it merges a ~30-line security boundary change into the same diff as ~11 TSX files + two i18n JSON bundles, forcing the security reviewer to grep the diff for the capability block rather than read it as the wave's defining feature.

---

## 2. Wave schedule

| Wave | Purpose | Task IDs | Parallelisation notes |
|------|---------|----------|-----------------------|
| **W1** | Rust backend path/doc/error rewrites + Rust tests + fixtures + Tauri capability swap | T1–T8 | T1–T7 edit disjoint files (parallel-safe among themselves). T8 (`cargo test` gate) depends on T1–T7 completing; serial within W1. |
| **W2** | React/TS frontend + i18n + README + carryover allow-list + final structural gates | T9–T16 | T9–T14 edit disjoint files (parallel-safe among themselves). T11 depends on W1 merged (D6 merge-order). T15 (`vitest` gate) and T16 (grep-assertion gate) are post-wave gates; T15 depends on T9–T13; T16 depends on every W1 and W2 task. |

**Wave count**: 2. **Task count**: 16 total (T1–T16). **Per-wave counts**: W1 = 8 · W2 = 8.

### Parallel-safety analysis per wave

**W1** — Seven content tasks touch seven disjoint file groups inside `flow-monitor/src-tauri/`:

- T1 edits `src/audit.rs` only.
- T2 edits `src/poller.rs` and `src/repo_discovery.rs` (sibling files, no shared import that either task modifies).
- T3 edits `src/ipc.rs`, `src/store.rs`, and `src/command_taxonomy.rs` (three sibling files; each task's edits are doc-comment + path-literal rewrites confined to its own file).
- T4 edits `src/invoke.rs` only (isolated because it carries PRD D1 — the shell-script body `specflow <cmd>` → `scaff <cmd>` correctness change — which is semantically distinct from pure path rename).
- T5 edits four Rust test sources under `tests/` (no test file is touched by any other W1 task).
- T6 edits five `.md` fixture files under `tests/fixtures/status/` (no other task touches fixtures).
- T7 edits `capabilities/default.json` only (security-boundary diff, grouped alone for reviewer focus).

No two W1 content tasks share a file. T8 is the wave close-out gate: it runs `cargo test` against the merged W1 tree and depends on T1–T7.

**W2** — Six content tasks touch six disjoint file groups inside `flow-monitor/`:

- T9 edits `src/i18n/en.json` and `src/i18n/zh-TW.json` (i18n bundles; one task owns both for tone/parity per `tpm/catalog-as-append-only-cross-wave-owner` — though this feature has only one catalog-contributing wave, the single-owner discipline still serves the EN↔zh-TW parity check). T9 also spot-checks `src/i18n/i18n.test.tsx` for references to the renamed key and updates if needed (same file group — i18n).
- T10 edits five TSX files under `src/components/` and `src/views/CardDetail.tsx` (doc comments + path literals; `AuditPanel.tsx`, `SessionCard.tsx`, `NotesTimeline.tsx`, `StagePill.tsx`, `views/CardDetail.tsx`). No overlap with T11 or T12.
- T11 edits `src/components/SettingsRepositories.tsx` line 33 only — **depends on W1 merged** (PRD D6: Rust scanner change must land first so `path_exists` does not fail during the partial-merge window). Disjoint from T10 and T12.
- T12 edits five TSX test files: `src/components/__tests__/CommandPalette.test.tsx`, `CardDetailHeader.test.tsx`, `RepoSidebar.test.tsx`, `DesignFolderIndex.test.tsx`, and `src/views/__tests__/Settings.test.tsx`. **Depends on T9** because `CommandPalette.test.tsx` asserts on the renamed i18n key `palette.group.scaff` (PRD D5 / AC2) — if T12 lands first, the test's assertion would target a key that does not yet exist. Disjoint from T10 and T11 at file level.
- T13 edits `flow-monitor/README.md` only (prose rewrites + one new upgrade-notes line per PRD R10 / D4 / design-delta §4).
- T14 edits `.claude/carryover-allowlist.txt` only (remove the blanket `flow-monitor/**` entry; add a narrow `flow-monitor/README.md` entry with a leading `#` comment explaining the self-reference). **Depends on T13** — the narrow allow-list entry must target the post-T13 README content; if T14 lands before T13, the grep-assertion gate (T16) could spuriously pass on a README that still contains legacy brand strings that are no longer allow-listed under `flow-monitor/**`.

T15 (`vitest` gate) depends on T9–T13 (all frontend edits). T16 (grep-assertion + AC2 + AC3 structural gate) depends on T1–T15 — wave close-out.

Pair T11↔T12 note: both depend on earlier W2 tasks but edit different files, so they are parallel-safe with each other once their respective deps (T9 for T12; W1 merged for T11) are satisfied.

---

## 3. Risks

1. **Tauri capability allow-list is the security-boundary change (AC12).** T7 swaps two paths in `capabilities/default.json`: `$REPOS/.spec-workflow/.flow-monitor/audit.log{,1}` → `$REPOS/.specaffold/.flow-monitor/audit.log{,1}`. Architect-gate signed off in `04-tech.md §4.4`: least-privilege preserved (clean swap, no widen-then-narrow window, no other capabilities touched). Mitigation: T7 is grouped as its own single-file task so the security reviewer audits the diff in isolation; `.claude/rules/reviewer/security.md` check 6 (secure defaults) and check 2 (path traversal — `canonicalise_and_check_under` in `audit.rs` still rejects paths outside the new prefix) apply.

2. **Merge-order constraint (PRD D6 / tech §4.1).** R1 (Rust scanner reads `.specaffold/`) must land at or before R6 (`SettingsRepositories.tsx:33` builds `${pickedPath}/.specaffold`). Two-wave split with W1-before-W2 satisfies this automatically; T11 also carries an explicit `Depends on: W1 merged` to make the constraint legible to the developer agent.

3. **i18n key rename ripple (PRD D5 / R7 / AC2).** `palette.group.specflow` → `palette.group.scaff`. T9 does the JSON key rename; T12 updates consumer test files (`CommandPalette.test.tsx` asserts on the key). If the two land out of order inside W2, vitest fails. Mitigation: T12 `Depends on: T9` — serial within W2.

4. **Allow-list narrowing surfaces new grep hits if R10 upgrade-notes line drifts.** Current `flow-monitor/**` entry is removed in T14 and replaced with a narrow `flow-monitor/README.md` entry. If T13's README content contains any `spec-workflow` / `specflow` reference outside the one intentional upgrade-notes line, T16's grep assertion fails. Mitigation: T13's acceptance includes `grep -Ec "spec-workflow|specflow" flow-monitor/README.md` returning exactly 1 (the upgrade-notes line that R10 mandates), not 0 and not >1.

5. **Rust test identifier renames (PRD R4 / D1 corollary).** `SPEC_WORKFLOW_MARKER` constant and `seam4_no_write_call_references_spec_workflow_path` function name must rename to their `specaffold` counterparts in `tests/seam4_no_writes.rs`. These are internal test identifiers; a missed rename causes a compile error caught by T8's `cargo test` gate. Mitigation: T5's scope fence explicitly calls out both identifiers by name; T8 is the safety net.

6. **Runtime AC10/AC11 are validate-stage concerns, not implement-stage tasks.** Per PRD §9 and `shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds`, the has-ui runtime walkthroughs run at the validate stage (`08-validate.md`). This plan's T16 closes the structural gates (AC1, AC2, AC3, AC5, AC7); AC6, AC8, AC9, AC12 are verified by the individual task acceptances; AC4 is verified by T4's acceptance (grep for `scaff` in generated shell-script template). AC10 and AC11 are explicitly out of scope for the implement stage and will be recorded in `08-validate.md` under a **Runtime walkthrough** section per tech §7.

7. **Pre-checked checkboxes anti-pattern (`tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern`).** Every `- [ ]` below stays unchecked at plan-authoring time. Orchestrator's per-wave bookkeeping commit is the sole `[x]` writer. After writing this plan, the TPM greps `grep -c '^- \[x\]' 05-plan.md` and `grep -c '^## T[0-9]*.*\[x\]' 05-plan.md` — both must return 0.

---

## 4. Architect-gate grouping (AC12)

The architect-gate concern is the Tauri capability allow-list diff. It is grouped as **T7 alone** in W1:

- T7 edits exactly one file: `flow-monitor/src-tauri/capabilities/default.json`.
- T7's diff is two string edits (legacy path `$REPOS/.spec-workflow/.flow-monitor/audit.log{,1}` → new path `$REPOS/.specaffold/.flow-monitor/audit.log{,1}`).
- No other task in W1 or W2 touches `capabilities/default.json` (verified by the file-disjointness check in §2).
- The security reviewer axis (`.claude/rules/reviewer/security.md`) runs at W1 merge-gate per tier=audited; T7's isolated diff is the only capability-boundary change in the feature. Architect sign-off is already recorded in `04-tech.md §4.4` (AC12); the wave-merge reviewer confirms the diff matches the sign-off.

This grouping satisfies `architect/tier-auto-upgrade-on-security-must-is-a-wave-merge-time-boundary-check`: the audited-tier gate is enforceable at wave-merge verdict time on a single-file diff.

---

## 5. Open questions

None. All PRD §7 open questions are resolved by D1–D7; all design-stage questions are resolved in `02-design/string-delta.md §6`; all tech-doc §5 questions are empty. If a genuine blocker surfaces during implement (e.g. a file the grep inventory missed), the orchestrator runs `/scaff:update-plan` with an explicit rationale rather than free-form-editing this plan (per `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md` and `tpm/update-plan-must-mirror-to-prd-and-tech-when-touching-acceptance-values.md`).

---

## 6. Review posture

Audited tier per `04-tech.md §4.4`. Inline reviewers run per wave merge on security + performance + style axes:

- **Security** — T7 (capabilities swap) is the primary axis hit; architect sign-off in `04-tech.md §4.4` is the pre-declared verdict shape; `.claude/rules/reviewer/security.md` check 2 (path traversal) and check 6 (secure defaults, atomic swap) apply. No other W1 or W2 task touches a security boundary.
- **Performance** — no hot-path code added; no loop counts change; no new IPC shapes. Expected verdict: PASS with no findings, per tech §4.5. `.claude/rules/reviewer/performance.md` hook-latency check (<200ms) does not apply — this feature touches no hooks.
- **Style** — bash 3.2 portability rule (`.claude/rules/bash/bash-32-portability.md`) does not apply in-code (no new shell scripts authored). Rust style matches existing conventions in each edited file; TS style matches existing conventions. i18n bundle edits preserve JSON formatting (two-space indent, trailing newline).

Aggregated verdict = PASS or NITS gates the wave merge. This is not a dogfood feature — the running harness is scaff, not flow-monitor; there is no dogfood paradox to absorb per `shared/dogfood-paradox-third-occurrence`.

---

## 7. Task list

Each task below is a new-shape task block per `tpm.appendix` with `Milestone:`, `Requirements:`, `Decisions:`, `Scope:`, `Deliverables:`, `Verify:`, `Depends on:`, `Parallel-safe-with:` fields. Every `- [ ]` is unchecked at authoring time.

### W1 — Rust backend + Rust tests + fixtures + Tauri capability swap

- [x] **T1. Rewrite `flow-monitor/src-tauri/src/audit.rs` — path literals, doc comments, gitignore append, helper body**
  - **Milestone**: W1 core backend sweep (heaviest single file; 14 line-level edits).
  - **Requirements**: R1, R3 (the `canonicalise_and_check_under` guard still rejects anything outside the new prefix — no semantic change, new prefix string).
  - **Decisions**: tech-D2 (inline replace, no shared constant; `flow_monitor_dir(repo)` helper remains the single `PathBuf` construction site and is the one-line semantic change at line 144).
  - **Scope**: `flow-monitor/src-tauri/src/audit.rs` only. Edits include: module doc comment (lines 3, 8, 11), `audit_dir()` / `flow_monitor_dir()` helper (lines 141–144), `.gitignore` append logic around lines 197–204, append-path doc comment / error strings, test-helper strings, test assertion lines (lines 96, 190, 197, 204, 246, 425, 478, 488, 516). Replacement order per the delta rename-rules table at `02-design/string-delta.md §rename-rules`: `.spec-workflow/` → `.specaffold/`; `.spec-workflow` → `.specaffold`; `spec-workflow` → `specaffold`; `specflow` → `scaff`; `Specflow` → `Scaff`. Do NOT introduce a `const SPECAFFOLD_DIR` (tech-D2).
  - **Deliverables**: modified `flow-monitor/src-tauri/src/audit.rs` with all 14 hits rewritten; body-of-`flow_monitor_dir()` reads `repo.join(".specaffold").join(".flow-monitor")` (was `.spec-workflow`).
  - **Verify**: `grep -Ec "spec-workflow|specflow" flow-monitor/src-tauri/src/audit.rs` returns 0; `cargo build --manifest-path flow-monitor/src-tauri/Cargo.toml` succeeds (syntax / borrow-check gate — full test gate is T8).
  - **Depends on**: none.
  - **Parallel-safe-with**: T2, T3, T4, T5, T6, T7.

- [x] **T2. Rewrite `flow-monitor/src-tauri/src/poller.rs` + `src/repo_discovery.rs` — path literals, doc comments**
  - **Milestone**: W1 core backend sweep (two sibling modules; small hit counts).
  - **Requirements**: R1.
  - **Decisions**: tech-D2 (inline replace).
  - **Scope**: `flow-monitor/src-tauri/src/poller.rs` (lines 303, 484 per the main-assistant inventory) and `flow-monitor/src-tauri/src/repo_discovery.rs` (lines 5, 25, 60, 66, 72). Replacement order same as T1.
  - **Deliverables**: both files rewritten; `repo_discovery::scan(<repo>)` reads `<repo>/.specaffold/features/*` (was `.spec-workflow/features/*`).
  - **Verify**: `grep -Ec "spec-workflow|specflow" flow-monitor/src-tauri/src/poller.rs flow-monitor/src-tauri/src/repo_discovery.rs | awk -F: '$2>0 {print}' | wc -l` returns 0.
  - **Depends on**: none.
  - **Parallel-safe-with**: T1, T3, T4, T5, T6, T7.

- [x] **T3. Rewrite `flow-monitor/src-tauri/src/ipc.rs` + `src/store.rs` + `src/command_taxonomy.rs` — path literals + doc comments**
  - **Milestone**: W1 core backend sweep (three sibling modules with mixed doc/string hits).
  - **Requirements**: R1.
  - **Decisions**: tech-D2 (inline replace).
  - **Scope**: `flow-monitor/src-tauri/src/ipc.rs` (lines 5, 214, 389, 533, 581, 590, 1271); `flow-monitor/src-tauri/src/store.rs` (line 21, doc comment only); `flow-monitor/src-tauri/src/command_taxonomy.rs` (lines 3, 8, 12, doc comments only). Replacement order same as T1.
  - **Deliverables**: all three files rewritten; no behaviour change.
  - **Verify**: `grep -Ec "spec-workflow|specflow" flow-monitor/src-tauri/src/ipc.rs flow-monitor/src-tauri/src/store.rs flow-monitor/src-tauri/src/command_taxonomy.rs | awk -F: '$2>0 {print}' | wc -l` returns 0.
  - **Depends on**: none.
  - **Parallel-safe-with**: T1, T2, T4, T5, T6, T7.

- [x] **T4. Rewrite `flow-monitor/src-tauri/src/invoke.rs` — path literals + shell-script body `specflow <cmd>` → `scaff <cmd>`**
  - **Milestone**: W1 core backend sweep — correctness-critical. The shell-script body rename is PRD D1 (correctness, not preference: the `specflow` binary does not exist on post-rename systems).
  - **Requirements**: R1, R2 (correctness: emitted shell script invokes `scaff`).
  - **Decisions**: tech-D1 (inline literal change at the one shell-script build site); tech-D2 (inline for path literals).
  - **Scope**: `flow-monitor/src-tauri/src/invoke.rs` only (lines 3, 240, 285, 291, 304, 432, 504, 510, 694, 724, 728, 771, 776 per the main-assistant inventory). Line 304 is the shell-script body `build_script_content()` that currently emits `specflow '<cmd>'` — rewrite to `scaff '<cmd>'`. Snapshot/assertion strings in any `#[test]` blocks inside `invoke.rs` update in the same task. Do NOT introduce a `const SCAFF_BIN: &str = "scaff"` (tech-D1).
  - **Deliverables**: `invoke.rs` fully rewritten; generated shell-script template references `scaff`, not `specflow`.
  - **Verify**: `grep -Ec "spec-workflow|specflow" flow-monitor/src-tauri/src/invoke.rs` returns 0; `grep -q "scaff '" flow-monitor/src-tauri/src/invoke.rs` returns 0 (new shell-script body form present). Full cargo-test gate is T8.
  - **Depends on**: none.
  - **Parallel-safe-with**: T1, T2, T3, T5, T6, T7.

- [x] **T5. Rewrite `flow-monitor/src-tauri/tests/` Rust test sources — path literals, marker const, fn name**
  - **Milestone**: W1 Rust-test sweep. Includes the two internal identifier renames mandated by PRD R4 / D1 corollary.
  - **Requirements**: R4 (test sources rewritten; `SPEC_WORKFLOW_MARKER` → `SPECAFFOLD_MARKER`; `seam4_no_write_call_references_spec_workflow_path` → `seam4_no_write_call_references_specaffold_path`).
  - **Decisions**: tech-D2 (inline replace).
  - **Scope**: four test source files — `flow-monitor/src-tauri/tests/wall_clock_budget.rs` (line 39); `flow-monitor/src-tauri/tests/seam4_no_writes.rs` (lines 6, 10, 12, 15, 30, 31, 34, 68, 70, 73, 84, 85; includes the const rename at line 31 and the fn rename around lines 34+); `flow-monitor/src-tauri/tests/repo_discovery_tests.rs` (lines 9, 25, 45, 57, 72, 90, 178, 186); `flow-monitor/src-tauri/tests/poller_integration.rs` (lines 30, 92, 309). Replacement order same as T1. Do NOT rename the test *file* names — only their contents.
  - **Deliverables**: all four test source files rewritten; `seam4_no_writes.rs` exports `SPECAFFOLD_MARKER` (not `SPEC_WORKFLOW_MARKER`) and contains the `#[test] fn seam4_no_write_call_references_specaffold_path()` (not `..._spec_workflow_path`).
  - **Verify**: `grep -Ec "spec-workflow|specflow" flow-monitor/src-tauri/tests/wall_clock_budget.rs flow-monitor/src-tauri/tests/seam4_no_writes.rs flow-monitor/src-tauri/tests/repo_discovery_tests.rs flow-monitor/src-tauri/tests/poller_integration.rs | awk -F: '$2>0 {print}' | wc -l` returns 0; `grep -q "SPECAFFOLD_MARKER" flow-monitor/src-tauri/tests/seam4_no_writes.rs` returns 0; `grep -q "seam4_no_write_call_references_specaffold_path" flow-monitor/src-tauri/tests/seam4_no_writes.rs` returns 0; `grep -cE "SPEC_WORKFLOW_MARKER|seam4_no_write_call_references_spec_workflow_path" flow-monitor/src-tauri/tests/seam4_no_writes.rs` returns 0. Full cargo-test gate is T8.
  - **Depends on**: none (file-disjoint from T1–T4).
  - **Parallel-safe-with**: T1, T2, T3, T4, T6, T7.

- [x] **T6. Rewrite Rust test fixtures under `flow-monitor/src-tauri/tests/fixtures/status/`**
  - **Milestone**: W1 fixture sweep (5 `.md` files; mechanical one-line-per-file edit).
  - **Requirements**: R4 (fixture paths per design delta; each fixture's line 20 contains `- [ ] archive       (moved to .spec-workflow/archive/)` → `.specaffold/archive/`).
  - **Decisions**: tech-D2 / §1.3 soft preference (no fixture generator — mechanical find-replace).
  - **Scope**: five fixture files — `flow-monitor/src-tauri/tests/fixtures/status/template_baseline.md`, `recent_updated.md`, `recent_notes.md`, `notes_multi.md`, `mtime_fallback.md`. Each has a single `.spec-workflow/archive/` → `.specaffold/archive/` replacement at line 20 per the main-assistant scope notes. Preserve all other fixture content byte-for-byte (these are test inputs; unintended edits are test-semantic changes).
  - **Deliverables**: five fixture files rewritten; no other fixture files are touched. `malformed_partial.md` is not in scope (it had no matches per the plan-time grep).
  - **Verify**: `grep -rEc "spec-workflow|specflow" flow-monitor/src-tauri/tests/fixtures/status/ | awk -F: '$2>0 {print}' | wc -l` returns 0 (no fixture file carries legacy brand); `grep -lE "specaffold/archive" flow-monitor/src-tauri/tests/fixtures/status/template_baseline.md flow-monitor/src-tauri/tests/fixtures/status/recent_updated.md flow-monitor/src-tauri/tests/fixtures/status/recent_notes.md flow-monitor/src-tauri/tests/fixtures/status/notes_multi.md flow-monitor/src-tauri/tests/fixtures/status/mtime_fallback.md | wc -l` returns 5 (every in-scope fixture file contains the new path reference).
  - **Depends on**: none.
  - **Parallel-safe-with**: T1, T2, T3, T4, T5, T7.

- [x] **T7. Swap Tauri capability allow-list `flow-monitor/src-tauri/capabilities/default.json` (SECURITY-AUDITED)**
  - **Milestone**: W1 security-boundary change; AC12 gate (architect sign-off pre-recorded in `04-tech.md §4.4`).
  - **Requirements**: R3 (allow-list grants access only to `$REPOS/.specaffold/.flow-monitor/audit.log{,.1}` — legacy paths removed outright; no transition-window dual-grant).
  - **Decisions**: tech-D3 (outright swap, no dual-grant).
  - **Scope**: `flow-monitor/src-tauri/capabilities/default.json` only. Edit lines 34 and 35 (per the main-assistant inventory): swap `$REPOS/.spec-workflow/.flow-monitor/audit.log` → `$REPOS/.specaffold/.flow-monitor/audit.log` and `$REPOS/.spec-workflow/.flow-monitor/audit.log.1` → `$REPOS/.specaffold/.flow-monitor/audit.log.1`. Do NOT add a new entry; do NOT widen any other permission block; do NOT touch `core:default`, `dialog:default`, `clipboard-manager:default`, `notification:default`, or `shell:allow-execute` (tech §4.4 explicit out-of-scope).
  - **Deliverables**: `capabilities/default.json` with exactly two filesystem-access entries pointing at `$REPOS/.specaffold/.flow-monitor/audit.log{,.1}`; neither legacy path present. File remains valid JSON.
  - **Verify**: `python3 -c "import json; d=json.load(open('flow-monitor/src-tauri/capabilities/default.json'))" ` exits 0 (JSON parse); `grep -Ec "spec-workflow" flow-monitor/src-tauri/capabilities/default.json` returns 0; `grep -c ".specaffold/.flow-monitor/audit.log" flow-monitor/src-tauri/capabilities/default.json` returns 2.
  - **Depends on**: none.
  - **Parallel-safe-with**: T1, T2, T3, T4, T5, T6.

- [x] **T8. W1 cargo-test gate — `cargo test` green inside `flow-monitor/src-tauri/`**
  - **Milestone**: W1 close-out gate; AC5 structural verification.
  - **Requirements**: R1, R2, R4 (all Rust-side rewrites must leave the test suite green).
  - **Decisions**: tech §4.3 testing strategy item 3 (cargo-test gate per `has-ui: true` audited tier).
  - **Scope**: no file edits. Runs the test suite.
  - **Deliverables**: a clean `cargo test` run against the merged W1 tree; logged output recorded in STATUS for the wave.
  - **Verify**: `cargo test --manifest-path flow-monitor/src-tauri/Cargo.toml` exits 0. The renamed Seam-4 test `seam4_no_write_call_references_specaffold_path` appears in the test listing (verified via `cargo test --manifest-path flow-monitor/src-tauri/Cargo.toml -- --list 2>/dev/null | grep -q seam4_no_write_call_references_specaffold_path`).
  - **Depends on**: T1, T2, T3, T4, T5, T6, T7.
  - **Parallel-safe-with**: none (serial W1 close-out).

### W2 — React/TS frontend + i18n + README + allow-list + final structural gates

- [ ] **T9. Rewrite i18n bundles `flow-monitor/src/i18n/en.json` + `zh-TW.json` (catalog-owner pattern; includes `palette.group.specflow` → `palette.group.scaff` key rename)**
  - **Milestone**: W2 i18n owner — one task owns both language bundles and is responsible for EN↔zh-TW parity. Carries PRD D5 key rename.
  - **Requirements**: R7 (every call site updated — consumer updates land in T12), R8 (both files contain `empty.body`, `settings.repoNotSpecflow`, `palette.group.scaff` with values matching design delta §1 and §2 exactly), R9 (valid JSON; no `palette.group.specflow` key present).
  - **Decisions**: tech-D5 (rename the key; clean long-term state); tech-D4 (inline replace for path literals in strings).
  - **Scope**: two files — `flow-monitor/src/i18n/en.json` and `flow-monitor/src/i18n/zh-TW.json`. Edit three keys per design delta §1 and §2:
    - `empty.body` — EN and zh-TW rewritten per delta table.
    - `settings.repoNotSpecflow` — EN and zh-TW rewritten per delta table. (Note: the JSON *key identifier* `settings.repoNotSpecflow` itself contains the token `Specflow` but is an internal key name, not user-facing copy; preserve the key identifier verbatim — only the value is rewritten. Design delta §1/§2 value column is the source of truth.)
    - `palette.group.specflow` — rename the key to `palette.group.scaff` AND rewrite both values ("Specflow Commands" → "Scaff Commands" for EN; "Specflow 指令" → "Scaff 指令" for zh-TW). The key identifier `palette.group.specflow` MUST NOT remain in either file after this task.
  - Also spot-check `flow-monitor/src/i18n/i18n.test.tsx` for any reference to the renamed key; if the file references `palette.group.specflow`, update to `palette.group.scaff` in this same task (it is in the same i18n file group; mixing into T12 would create an inter-task dep without benefit).
  - **Deliverables**: both JSON files rewritten; optionally `i18n.test.tsx` updated if it referenced the renamed key.
  - **Verify**: `python3 -c "import json; json.load(open('flow-monitor/src/i18n/en.json')); json.load(open('flow-monitor/src/i18n/zh-TW.json'))"` exits 0 (both parse as valid JSON); `grep -c 'palette.group.specflow' flow-monitor/src/i18n/en.json flow-monitor/src/i18n/zh-TW.json | awk -F: '$2>0 {print}' | wc -l` returns 0 (old key absent in both); `grep -c 'palette.group.scaff' flow-monitor/src/i18n/en.json flow-monitor/src/i18n/zh-TW.json` returns 2 (new key present in both); `grep -F '"Scaff Commands"' flow-monitor/src/i18n/en.json` returns 1 line; `grep -F '"Scaff 指令"' flow-monitor/src/i18n/zh-TW.json` returns 1 line.
  - **Depends on**: none (no W1 dep — i18n is independent of Rust).
  - **Parallel-safe-with**: T10, T11, T13, T14.

- [ ] **T10. Rewrite TSX doc comments + path literals — 5 component/view files**
  - **Milestone**: W2 frontend doc/display sweep.
  - **Requirements**: R5 (TSX doc comments + rendered path literals updated per design delta §3).
  - **Decisions**: tech-D4 (inline replace).
  - **Scope**: five files — `flow-monitor/src/components/AuditPanel.tsx` (line 16 doc comment); `flow-monitor/src/components/SessionCard.tsx` (line 53 doc comment); `flow-monitor/src/components/NotesTimeline.tsx` (line 2 doc comment); `flow-monitor/src/components/StagePill.tsx` (lines 4, 28 doc comments); `flow-monitor/src/views/CardDetail.tsx` (lines 119–120 — path literal `${repoFullPath}/.spec-workflow/features/${validSlug}` → `${repoFullPath}/.specaffold/features/${validSlug}` and the fallback form `/${validRepoId}/.spec-workflow/features/${validSlug}` → `/${validRepoId}/.specaffold/features/${validSlug}`). Replacement order per delta rename-rules table.
  - **Deliverables**: all five files rewritten per the design delta tables.
  - **Verify**: `grep -Ec "spec-workflow|specflow" flow-monitor/src/components/AuditPanel.tsx flow-monitor/src/components/SessionCard.tsx flow-monitor/src/components/NotesTimeline.tsx flow-monitor/src/components/StagePill.tsx flow-monitor/src/views/CardDetail.tsx | awk -F: '$2>0 {print}' | wc -l` returns 0; `grep -q '.specaffold/features/' flow-monitor/src/views/CardDetail.tsx` returns 0.
  - **Depends on**: none.
  - **Parallel-safe-with**: T9, T11, T13, T14.

- [ ] **T11. Rewrite `flow-monitor/src/components/SettingsRepositories.tsx:33` path-check (depends on W1 merged)**
  - **Milestone**: W2 frontend correctness fix — PRD D6 merge-order consumer.
  - **Requirements**: R6 (frontend builds `${pickedPath}/.specaffold` for `path_exists` IPC; Rust backend scanner rename must have landed — W1 merged).
  - **Decisions**: tech-D4 (inline replace); PRD D6 (merge-order constraint).
  - **Scope**: `flow-monitor/src/components/SettingsRepositories.tsx` only; edit line 33 — `${pickedPath}/.spec-workflow` → `${pickedPath}/.specaffold`. No other edits to this file in this task.
  - **Deliverables**: `SettingsRepositories.tsx:33` references `.specaffold` only.
  - **Verify**: `grep -Ec "spec-workflow|specflow" flow-monitor/src/components/SettingsRepositories.tsx` returns 0; `grep -q '${pickedPath}/\\.specaffold' flow-monitor/src/components/SettingsRepositories.tsx || grep -q '`\\${pickedPath}/.specaffold`' flow-monitor/src/components/SettingsRepositories.tsx` returns 0 (new path present — matches whichever backtick/escape form the file uses).
  - **Depends on**: W1 merged (PRD D6 / tech §4.1 — Rust scanner change at or before this frontend change). In two-wave serial scheduling this is automatic; developer agent confirms by checking that `flow-monitor/src-tauri/src/repo_discovery.rs` no longer contains `spec-workflow` before editing.
  - **Parallel-safe-with**: T9, T10, T13, T14.

- [ ] **T12. Rewrite TSX test files — 5 files; depends on T9 for i18n key rename**
  - **Milestone**: W2 frontend test sweep; consumer side of the PRD D5 key rename.
  - **Requirements**: R5 (test snapshots / mock strings), R7 (every `t("palette.group.specflow")` call site updated to `t("palette.group.scaff")`).
  - **Decisions**: tech-D4 (inline replace); tech-D5 (key rename consumer).
  - **Scope**: five test files — `flow-monitor/src/components/__tests__/CommandPalette.test.tsx` (primary consumer of the renamed `palette.group.specflow` key — line 26 per design delta §5 Q1 note); `flow-monitor/src/components/__tests__/CardDetailHeader.test.tsx`; `flow-monitor/src/components/__tests__/RepoSidebar.test.tsx`; `flow-monitor/src/components/__tests__/DesignFolderIndex.test.tsx`; `flow-monitor/src/views/__tests__/Settings.test.tsx` (lines 412, 418, 422, 424, 434 per main-assistant inventory). Replacement order per delta rename-rules table; additionally every `palette.group.specflow` → `palette.group.scaff` in `CommandPalette.test.tsx`.
  - **Deliverables**: all five test files rewritten; no test file retains `specflow` / `spec-workflow` or the legacy i18n key.
  - **Verify**: `grep -Ec "spec-workflow|specflow" flow-monitor/src/components/__tests__/CommandPalette.test.tsx flow-monitor/src/components/__tests__/CardDetailHeader.test.tsx flow-monitor/src/components/__tests__/RepoSidebar.test.tsx flow-monitor/src/components/__tests__/DesignFolderIndex.test.tsx flow-monitor/src/views/__tests__/Settings.test.tsx | awk -F: '$2>0 {print}' | wc -l` returns 0; `grep -c 'palette.group.specflow' flow-monitor/src/components/__tests__/CommandPalette.test.tsx` returns 0; `grep -q 'palette.group.scaff' flow-monitor/src/components/__tests__/CommandPalette.test.tsx` returns 0 (new key referenced).
  - **Depends on**: T9 (i18n key must exist before its consumer test asserts on it).
  - **Parallel-safe-with**: T10, T11, T13, T14.

- [ ] **T13. Rewrite `flow-monitor/README.md` — prose, path prefixes, and one new upgrade-notes line (R10)**
  - **Milestone**: W2 docs sweep; includes the intentional upgrade-notes line preserved by the R10 allow-list carve-out.
  - **Requirements**: R10 (README prose per design delta §4; add one new line under a "Known limitations" or "Upgrade notes" subsection stating that pre-rename audit logs under `.spec-workflow/.flow-monitor/` are preserved on disk but not surfaced in the new UI).
  - **Decisions**: PRD D4 (lazy migration; README is the user-facing acknowledgement); PRD D7 (preserve feature slug `20260419-flow-monitor` as a date-based identifier — do NOT rewrite).
  - **Scope**: `flow-monitor/README.md` only. Rewrite prose per design delta §4 at lines 3, 9, 76, 77, 80, 99, 100, 136 (per main-assistant inventory, cross-referenced with delta §4 line-numbers 3–4, 9, 73, 99–101, 134). Add exactly one new line, placed at the Developer's discretion under a "Known limitations" or "Upgrade notes" subsection, that reads a sentence of the form:

    > Pre-rename audit logs under `.spec-workflow/.flow-monitor/audit.log` are preserved on disk but are not surfaced in the new UI; see `docs/rename-migration.md` for the migration path.

    The exact wording is left to Developer discretion but MUST contain the literal path `.spec-workflow/.flow-monitor/` (this is the one legitimate legacy-name reference in this feature's scope — R10 / R11 / tech §6 allow-list carve-out). Preserve the feature-slug reference `20260419-flow-monitor` at line 9 verbatim (PRD D7 — date-based identifier, not brand copy).
  - **Deliverables**: `flow-monitor/README.md` rewritten with exactly ONE remaining `.spec-workflow/` reference (the upgrade-notes line) and zero other `specflow` / `spec-workflow` references.
  - **Verify**: `grep -Ec "spec-workflow|specflow" flow-monitor/README.md` returns exactly 1 (the upgrade-notes line is the sole remaining hit); `grep -q "20260419-flow-monitor" flow-monitor/README.md` returns 0 (feature slug preserved); `grep -q "Scaff" flow-monitor/README.md` returns 0 (new brand present); `grep -q "Specaffold" flow-monitor/README.md` returns 0 (new product name present).
  - **Depends on**: none.
  - **Parallel-safe-with**: T9, T10, T11, T12.

- [ ] **T14. Carryover allow-list edit — remove `flow-monitor/**`, add `flow-monitor/README.md`**
  - **Milestone**: W2 allow-list narrowing — the change that makes this whole feature necessary per tech §6 "the reason we are here".
  - **Requirements**: R11 (repo-wide grep assertion continues to produce zero unlisted hits; this feature's legitimate carve-out is the R10 upgrade-notes line only, so the allow-list narrows to exactly `flow-monitor/README.md`).
  - **Decisions**: tech §6 "Carry-over allow-list additions" — remove the blanket `flow-monitor/**` entry (lines 27–28 of `.claude/carryover-allowlist.txt` at plan time, per the pre-read); add one narrow entry `flow-monitor/README.md` with a `#` leading comment explaining the R10 upgrade-notes carve-out.
  - **Scope**: `.claude/carryover-allowlist.txt` only. Remove the two-line block:
    ```
    # flow-monitor/** — independent co-located Tauri sub-project; rename is out of scope
    flow-monitor/**
    ```
    Add in its place the two-line block:
    ```
    # flow-monitor/README.md — R10 upgrade-notes line documents legacy .spec-workflow/.flow-monitor/ audit-log path per D4 lazy-migration
    flow-monitor/README.md
    ```
    Preserve every other entry in the file byte-identically.
  - **Deliverables**: `.claude/carryover-allowlist.txt` with the narrowed entry.
  - **Verify**: `grep -c "^flow-monitor/\*\*" .claude/carryover-allowlist.txt` returns 0 (blanket entry removed); `grep -c "^flow-monitor/README.md$" .claude/carryover-allowlist.txt` returns 1 (narrow entry present); total non-comment non-blank entry count unchanged except for the swap (`grep -cvE '^(#|$)' .claude/carryover-allowlist.txt` returns the same count as before the edit).
  - **Depends on**: T13 (the README must already contain only the one legitimate legacy reference before the allow-list narrows to `README.md` only; if T14 lands before T13, T16's grep assertion could fail or pass spuriously).
  - **Parallel-safe-with**: T9, T10, T11, T12.

- [ ] **T15. W2 vitest gate — `npm run test` (or equivalent) green inside `flow-monitor/`**
  - **Milestone**: W2 frontend test gate; AC7 structural verification.
  - **Requirements**: R5, R7, R8 (frontend rewrites + i18n key rename + consumer tests all green).
  - **Decisions**: tech §4.3 testing strategy item 4 (vitest gate).
  - **Scope**: no file edits. Runs the test suite.
  - **Deliverables**: a clean vitest run against the merged W2 tree; logged output recorded in STATUS.
  - **Verify**: `cd flow-monitor && npm test -- --run` exits 0 (or the equivalent `vitest --run` invocation this repo uses — Developer confirms the exact invocation from `flow-monitor/package.json` scripts before running). All snapshot assertions pass; zero legacy-brand strings in test output.
  - **Depends on**: T9, T10, T11, T12, T13.
  - **Parallel-safe-with**: T14, T16.

- [ ] **T16. Repo-wide grep-assertion + AC2/AC3 structural gate — final W2 close-out**
  - **Milestone**: W2 close-out gate; AC1 + AC2 + AC3 + AC6 + AC8 + AC9 structural verification.
  - **Requirements**: R11 (grep assertion against `.claude/carryover-allowlist.txt` returns zero unlisted hits), PRD AC1 / AC2 / AC3 / AC6 / AC8 / AC9.
  - **Decisions**: tech §4.3 testing strategy items 1, 2, 5, 6 (structural gates).
  - **Scope**: no file edits. Runs five structural checks:
    1. `bash test/t_grep_allowlist.sh` — AC1 (repo-wide grep-allow-list assertion).
    2. `grep -rn "palette.group.specflow" flow-monitor/src/` — AC2 (must return zero hits).
    3. `python3 -c "import json; d=json.load(open('flow-monitor/src-tauri/capabilities/default.json'))"` + key inspection — AC3 (capability JSON parses; contains exactly two filesystem entries under `$REPOS/.specaffold/.flow-monitor/`; neither legacy path remains).
    4. JSON parse + key presence on both i18n files — AC6 (both files valid JSON; both contain `palette.group.scaff`; neither contains `palette.group.specflow`).
    5. `grep -q '.specaffold' flow-monitor/src/components/SettingsRepositories.tsx` — AC8 (SettingsRepositories line 33 check).
  - **Deliverables**: verbatim commands and their observed outputs logged in STATUS Notes for the wave; a single PASS/FAIL summary. If any check fails, the wave is BLOCKED and the orchestrator escalates before advancing to validate.
  - **Verify**: all five structural checks pass. Specifically:
    - `bash test/t_grep_allowlist.sh` exits 0 and prints `PASS: all carryover hits allow-listed`.
    - `grep -rn "palette.group.specflow" flow-monitor/src/ | wc -l` returns 0.
    - `python3 -c "import json, sys; d=json.load(open('flow-monitor/src-tauri/capabilities/default.json')); entries=[e for e in d.get('permissions', []) if isinstance(e, dict)]; fs=[e for e in entries if 'identifier' in e and 'fs' in e.get('identifier','')]; assert not any('spec-workflow' in json.dumps(e) for e in fs), 'legacy path present'; specaffold_hits=sum(json.dumps(e).count('.specaffold/.flow-monitor/audit.log') for e in fs); assert specaffold_hits >= 2, 'new paths missing'"` exits 0 (a single-line shell-embeddable JSON check — Developer may substitute an equivalent `python3 -c "import json; ..."` that asserts the same invariants, provided the invariants are preserved).
    - `python3 -c "import json; a=json.load(open('flow-monitor/src/i18n/en.json')); b=json.load(open('flow-monitor/src/i18n/zh-TW.json')); ks_a=[k for k in (x for x in a if '.' in str(x))]; assert 'palette' in a and 'scaff' in a['palette'].get('group', {}), 'en missing new key'; assert 'palette' in b and 'scaff' in b['palette'].get('group', {}), 'zh-TW missing new key'"` exits 0 — Developer may substitute equivalent Python if the JSON nesting differs (flat-dotted-keys vs nested); the invariant is "both files contain a path to a `scaff` label under the palette.group namespace, and neither contains a `specflow` label there".
    - `grep -q '.specaffold' flow-monitor/src/components/SettingsRepositories.tsx` exits 0.
  - **Depends on**: T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15.
  - **Parallel-safe-with**: none (final close-out).

---

## 8. STATUS notes convention

Every task completion appends one line in STATUS.md:

```
- YYYY-MM-DD <Role> — T<n> done: <brief summary>
```

Blocked tasks:

```
- YYYY-MM-DD <Role> — T<n> blocked: <observed behavior or missing info>
```

The orchestrator checks off `[x]` in task entries via per-wave bookkeeping commits after wave merge — NEVER inside a Developer's per-task worktree commit (prevents parallel-merge checkbox loss per `tpm/checkbox-lost-in-parallel-merge.md`) and NEVER at plan-authoring time (per `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern.md`).

Runtime AC10 and AC11 walkthroughs are validate-stage concerns; they are NOT implement tasks and will be recorded in `08-validate.md` under a **Runtime walkthrough** section per tech §7.

---

## Team memory

Applied:

- `tpm/parallel-safe-requires-different-files` — every W1 and W2 same-wave pair edits file-disjoint scopes; §2 parallel-safety analysis walks through each pair and confirms no two same-wave tasks share a file.
- `tpm/pre-checked-checkboxes-without-commits-are-a-plan-drift-anti-pattern` — every `- [ ]` above stays unchecked at plan-authoring time; §3 risk 7 codifies the authoring-time grep check; §8 codifies the orchestrator-only `[x]`-writer discipline.
- `tpm/plan-gap-surfaces-at-reviewer-or-dry-run-not-at-plan-time` — §7 T16 runs `bash test/t_grep_allowlist.sh` as a wave-close gate (not deferred to validate); the grep assertion also re-runs during W1 close (verified implicitly by T8's `cargo test` not producing legacy-string-dependent test output).
- `tpm/catalog-as-append-only-cross-wave-owner` — T9 is the single i18n catalog owner for this feature (two bundles + spot-check of `i18n.test.tsx`); this feature has only one i18n-contributing wave, so the one-owner discipline still applies — T10 and T12 may draft references but do not edit the JSON bundles directly.
- `tpm/pre-declare-test-filenames-in-06-tasks` — not directly applicable (no new test files authored this feature), but the same discipline is applied: §7 enumerates every test file edited in T5 and T12 by full path, so the collision grep (`grep -hE '^ *Files:' 05-plan.md | grep test | sort | uniq -d`) is empty.
- `shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds` — AC10 and AC11 are runtime-deferred to validate stage; §3 risk 6 makes this explicit so the Developer and QA-tester don't conflate structural close-out with validate close-out.

Not applicable this feature (documented so the reader sees the scan was run):

- `tpm/same-file-sequential-wave-depth-accepted` — no single-file CLI with N subcommands; inapplicable.
- `tpm/cross-package-parallel-wave-pair-pattern` — two-wave serial schedule driven by PRD D6 merge-order; the wave pair is *not* file-disjoint by package (W1 edits Rust+capability+Rust tests inside `flow-monitor/`; W2 edits TS+JSON+Markdown inside `flow-monitor/`), so the paired-parallel compression is unsafe.
- `tpm/wave-bookkeeping-commit-per-wave` — standing orchestrator discipline; §8 restates it for the developer agent.
- `tpm/checkbox-lost-in-parallel-merge` — parallelism is modest (7 parallel tasks in W1, 5–6 in W2); the pattern's main mitigation (single orchestrator bookkeeping commit per wave) is captured in §8.
- `tpm/reviewer-blind-spot-semantic-drift` — this feature is a pure rename; cross-artefact semantic drift (verb renamed in code but not in docs) is unlikely, but T16's grep assertion catches any residual reference outside the one R10 allow-list carve-out.
- `tpm/update-plan-must-mirror-to-prd-and-tech-when-touching-acceptance-values` — consulted; §5 codifies the `/scaff:update-plan` flow if an implement-time gap surfaces.
- `tpm/orchestrator-cwd-drift-across-bash-calls` — standing orchestrator discipline; not a plan-time concern.
- `tpm/briefing-contradicts-schema` — applied: T9's i18n scope quotes the design delta §1 and §2 tables directly rather than paraphrasing the key names.
- `tpm/task-scope-fence-literal-placeholder-hazard` — applied: every `Scope:` / `Files:` / `Verify:` line names files by full path with no unfilled placeholder tokens. Authoring-time grep `grep -nE 'tN_|<[a-z-]+>|<new |<fill>' 05-plan.md` does hit 7 lines, but every hit is either (a) a literal shell-syntax reference inside prose describing PRD D1 (`specflow <cmd>` → `scaff <cmd>` — this *is* the rename the feature performs), (b) a Rust function-signature placeholder `<repo>` describing existing code, or (c) the STATUS Notes convention template in §8 (`<Role>`, `<n>`, `<brief summary>`). No placeholder appears inside any task's `Scope:` / `Files:` / `Verify:` / `Deliverables:` field where a developer agent would interpret it literally.
- `shared/dogfood-paradox-third-occurrence` — inapplicable. This feature renames the flow-monitor Tauri app, not the scaff orchestration surface running the rename. No paradox.

Proposed for promotion at archive if the pattern holds (not yet promoted):

- `tpm/rename-continuation-inherits-and-narrows-predecessor-allow-list` — this feature's T14 narrows the predecessor's `flow-monitor/**` blanket entry to `flow-monitor/README.md` alone, consuming the carve-out the predecessor authored for follow-up work. The mirror-image of the discipline captured at the predecessor's archive. Evaluate at archive.
