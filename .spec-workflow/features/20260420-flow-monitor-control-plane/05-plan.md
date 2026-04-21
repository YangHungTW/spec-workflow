# Plan — flow-monitor B2 (control plane)

**Feature**: `20260420-flow-monitor-control-plane`
**Stage**: plan
**Author**: TPM
**Date**: 2026-04-20
**Shape**: **new merged form** — narrative + task checklist in one file per tier-model R19. No `06-tasks.md` will be authored.

Inputs consumed: `03-prd.md` (R1–R12, 31 ACs — 15 runtime / 15 structural / 1 both), `04-tech.md` (D1–D11 + §4 Testing seams A–M), `02-design/notes.md` (10 locked decisions + Q8 i18n key list).

No decisions re-litigated. No gap surfaced requiring escalation. PRD §7 (blockers) = 0; tech §5 (blockers) = 0.

---

## 1. Wave plan (narrative)

### 1.1 Sequencing rationale

B2 is a **single-app Tauri feature** touching one Rust backend + one React renderer + one capability manifest + one test harness (`flow-monitor/` plus repo-level `test/`). Wave boundaries are driven by:

- **Call-graph dependencies** — modules that several other tasks import (`command_taxonomy`, `audit`, `lock`, `invoke`) must land before the IPC handler and the UI that calls them.
- **Shared-file constraints** per `tpm/parallel-safe-requires-different-files.md` — `flow-monitor/src-tauri/src/lib.rs`, `flow-monitor/src-tauri/src/ipc.rs`, `flow-monitor/src-tauri/Cargo.toml`, `flow-monitor/src-tauri/capabilities/default.json`, `flow-monitor/src/i18n/en.json`, and `flow-monitor/src/i18n/zh-TW.json` are touched by multiple concerns; tasks that write them must be serialised within a wave (one writer per file per wave).
- **Single-file CLI with N subcommands** (`tpm/same-file-sequential-wave-depth-accepted.md`) does NOT apply here — B2 has no such shape. The CLI equivalent here is `ipc::invoke_command` which is authored once (W2) and not re-edited per UI surface; UI surfaces call into the already-existing IPC.
- **Dogfood paradox (ninth occurrence)** per PRD §6 — 15 of 31 ACs are runtime-deferred; structural seams A–M (tech §4) cover the 16 structural ACs during this feature's validate. No code path in this plan depends on the flow-monitor app being *running* during implement.

Seven waves:

- **W0 — Foundation (plugins + capability manifest).** Lays down `tauri-plugin-shell` + `tauri-plugin-fs` in `Cargo.toml`, expands `capabilities/default.json` per D1 (shell `open -a Terminal.app` allow-list + fs:allow-append-file scoped to audit-log paths), and adds the capability-shape unit test (Seam G). Nothing downstream can use the shell-exec or fs-append surface until this wave lands. Single-file collisions in Cargo.toml and the manifest JSON are the reason this wave is narrow: both files are touched here exactly once.
- **W1 — Pure Rust modules.** `command_taxonomy.rs` (D3 hardcoded list + `classify()` / `allow_list_contains()`), `audit.rs` (D7 TSV + D4 rotation + AC6.d gitignore-bootstrap + AC9.b path-traversal guard), `lock.rs` (D2 in-process `Mutex<HashSet>` + 60s watchdog), and `invoke.rs` (D6 dispatcher: terminal-spawn via temp `.command` script + clipboard-plugin + pipe-Err). These four modules are independent files; they compile and unit-test without touching `lib.rs` or `ipc.rs`. Each ships with its own `#[cfg(test)]` block (Rust-idiomatic) and a dedicated shell smoke test under `test/` where a structural grep is needed. This wave is fully parallel across four Rust files plus their test shells.
- **W2 — Backend wiring (lib.rs + ipc.rs + TS bridge).** `lib.rs::run_session_polling` gains the `store::diff` + `notify::fire_stalled_notification` wiring (R1). `ipc.rs` gains three `tauri::command` handlers: `invoke_command`, `get_audit_tail`, `get_in_flight_set`, plus event emitters `in_flight_changed` / `audit_appended` / `session_advanced`. The build-script generator `src-tauri/build.rs` writes `src/generated/command_taxonomy.ts`. Both `lib.rs` and `ipc.rs` are single-writer within this wave (one task each); the build.rs + TS projection is a third distinct file. This wave has three parallel tasks.
- **W3 — Renderer stores + TS wrapper.** `src/stores/invokeStore.ts` (in-flight set + dispatch wrapper that calls the IPC from W2), Seam E's component fixture for `ConfirmModal` props, theme reuse mapping doc (tiny companion under `src/styles/b2-reuse-map.md` or similar, per D10 — NOT a token file; documents which existing tokens each new class uses). Parallel across three distinct files.
- **W4 — Renderer components.** Six new React components authored in parallel: `ActionStrip.tsx`, `CommandPalette.tsx`, `SendPanel.tsx`, `PreflightToast.tsx`, `ConfirmModal.tsx`, `AuditPanel.tsx`. Each component ships with its own `__tests__/<Component>.test.tsx` per existing flow-monitor convention. Each is a distinct file; no dispatcher or shared selector is edited. Parallel-safe across all six.
- **W5 — Integration (UI plumbing) + i18n + B1 nits.** Five integration tasks: `SessionCard.tsx` gains the ActionStrip render gate (R2 stalled-only); `CardDetailHeader.tsx` gains Advance + Message buttons + SendPanel mount (R3); `App.tsx` mounts the CommandPalette + PreflightToast overlays + ⌘K keybinding (R5); `src/i18n/en.json` adds the new B2 keys (D9 list, 26 keys); `src/i18n/zh-TW.json` adds the zh-TW values for the same 26 keys; a separate B1-nits sweep task (R12 absorbs 5 items). Three of these edit distinct TSX files and are parallel-safe. The two i18n JSON files are distinct files and are parallel-safe with each other. The B1-nits task touches `ipc.rs`, `App.tsx`, `themeStore.ts`, `en.json` — we serialise it as **the last task in the wave** to avoid collisions with the concurrent `en.json` / `App.tsx` / `ipc.rs` writers.
- **W6 — Structural tests (shell seams) + docs wave bookkeeping.** Eight `test/tNN_*.sh` files (Seams A–M that aren't covered by Rust inline or TSX component tests — specifically the cross-file greps and the repo-level harness). One task appends registrations to `test/smoke.sh` (append-only per `tpm/parallel-safe-append-sections.md`). The seven test files + one smoke-registration task run parallel for the eight authorings, then the smoke-registration is a mechanical-merge accept.

### 1.2 Dogfood paradox handling (ninth occurrence)

Per PRD §6 / §9 and `shared/dogfood-paradox-third-occurrence`:

- This feature's own validate covers the 16 structural ACs (AC1.c, AC1.d-structural, AC2.c, AC4.d, AC5.b, AC6.c, AC6.d, AC7.c, AC8.a, AC8.b, AC9.a, AC9.b, AC10.a, AC11.a, AC12.a) via Seams A–M. One AC (AC1.d) is split: the structural part is in Seam A; the runtime re-fire of the notification banner is runtime-deferred.
- The 15 runtime ACs (AC1.a, AC1.b, AC1.d-runtime, AC2.a, AC2.b, AC3.a, AC3.b, AC4.a, AC4.b, AC4.c, AC5.a, AC5.c, AC6.a, AC6.b, AC7.a, AC7.b, AC10.b) are **not exercised during B2 validate**. Runtime handoff is a TPM deliverable at archive time: the successor feature's STATUS opening line must record `B2 control plane exercised on this feature's first live session` (or equivalent). This is tracked as a task-list item at W6 (T113) so it doesn't get lost at archive.
- No opt-out flag is added (per tech D11 — the feature modifies the app but does not run it during implement, so there is no bypass to trace).

### 1.3 What is NOT in this plan (out-of-scope carries)

Per PRD §3 and tech §6, explicitly excluded from the task list:

- DESTROY-command reachability (palette entries, context menu wiring, button strip) — B3 scope. The scaffold (`ConfirmModal` component, `classify()` returning `Destroy`, audit-log `Outcome::DestroyConfirmed` reserved enum value) DOES ship in B2; no caller imports it.
- Pipe delivery method runtime — the `DeliveryMethod::Pipe` variant lands in the enum, `invoke::dispatch` returns `Err(NotAvailable)` when called with it, and `SendPanel.tsx` renders the Pipe tab disabled with tooltip. No pipe-IPC surface is built.
- N-file audit log rotation (`.log.2`, `.log.3`, …) — exactly two files per D4.
- Notification action buttons (inline Advance on banner) — tech §6 deferred.
- Configurable terminal app (iTerm, Alacritty) — one new plugin-shell allow entry if requested later.
- Windows / Linux terminal-spawn variants — macOS-first per B1 baseline.
- Notification re-fire after N minutes — PRD §8 Q-ux-future.
- Cross-session bulk actions — PRD §3.
- Chat / transcript UI — PRD §3.
- "Advance all stalled" — PRD §3.

### 1.4 Risks (flagged to Developer, not TPM-resolvable)

- **RA — `lib.rs` is the B1 polling loop's hot path.** T108 (W2) adds the `store::diff` call and the `prev_map` / `prev_stalled_set` locals inside the already-running `loop {}`. Developer must preserve the existing 3-second tick cadence (B1 AC13.c budget) and not introduce a `HashMap::clone` inside a hot inner loop. Per-tick diff cost budget: <50 ms warn threshold (tech §4 Performance). Reviewer must read the diff against B1's archived `lib.rs`, not against `main`, to verify no reshaping of unrelated polling logic.
- **RB — Capability manifest regex validator is brittle.** D1 commits a regex in `capabilities/default.json` that must match the runtime-generated temp-file path generated by `invoke.rs`. T91 (capability manifest) and T93 (invoke.rs terminal-spawn) must ship a **shared constant** (the path template) referenced by both — if T91 changes the regex and T93 changes the path shape independently, the spawn will fail silently. Developer on T91 writes a comment linking to T93's path generator, and T93's task briefing includes the exact regex to satisfy.
- **RC — `src-tauri/build.rs` generates `src/generated/command_taxonomy.ts`.** T109 (W2) adds a new `build.rs` side effect. If `build.rs` is absent from B1 (it is), this task creates the file. The generated file must not be checked in as a hand-written source — add `src/generated/` to `.gitignore` if not already. Reviewer verifies: (a) `build.rs` runs in `cargo build`, (b) the generated file's modtime is newer than `command_taxonomy.rs`, (c) both Rust const array and TS `as const` array have the same list.
- **RD — Audit log's `ensure_gitignore` writes to the repo's top-level `.gitignore`.** This is a user-owned file. Per `.claude/rules/common/no-force-on-user-paths.md`, T92's `audit.rs::ensure_gitignore` reads existing content, idempotent-checks the line, and appends via atomic write-temp-then-rename — never a blind overwrite. Backup discipline: no `.gitignore.bak` is written (the idempotent-check is itself the safety; a backup of every pre-write `.gitignore` would noise up user repos). Developer must cite `no-force-on-user-paths.md` in the task commit message.
- **RE — In-process lock's 60s watchdog uses `tokio::time::sleep_until`.** T94 (lock.rs) spawns a tokio task per acquired lock; Developer must use `tokio::select!` with the `session_advanced` event so the watchdog cancels cleanly on STATUS.md change (AC7.b "whichever comes first"). A naive `sleep + release` without cancellation would cause a "double-release" on fast session advance.
- **RF — Cross-window event broadcast requires Tauri 2 emit semantics.** T108 (ipc.rs events) emits `in_flight_changed` / `audit_appended` / `session_advanced` on the Tauri app handle. All windows subscribe in W5's App.tsx integration. If events are emitted on a single window handle, only that window receives them — breaks R7 (cross-window disable). Developer must use `app.emit(...)` (app-level) not `window.emit(...)` (window-local).
- **RG — The `ConfirmModal` has no caller in B2.** The structural check is two greps: (a) no import of `ConfirmModal` other than the component file + its test; (b) DESTROY command names appear only in `command_taxonomy.rs` / `command_taxonomy.ts`. Both greps live in T115 (Seam B shell test). If a Developer on any UI task imports the modal speculatively ("we'll need it soon"), T115 will fail and block merge. This is intentional; flagged so Developers don't waste effort on early wiring.
- **RH — B1 nits sweep (T114) is the only task that edits 4 files across the repo.** Per `tpm/parallel-safe-requires-different-files.md`, T114 conflicts with W5's i18n and App.tsx tasks. T114 is sequenced **as the last task in W5** to land after the other W5 writers; its own commit serialises behind them. Developer reads the B1 archive retrospective's exact nits list at task start.

### 1.5 Escalations

None. PRD §7 and tech §5 both report 0 blocker questions. If a gap surfaces during implement (e.g. Tauri plugin-shell can't express the exact regex validator D1 commits), Developer escalates via `/specflow:update-plan` with a cited line number; TPM re-issues the task with the architect-refined approach.

---

## 2. Wave schedule

- **W0** — T91, T92-cap-test (2 tasks; T91 writes the plugin deps + manifest, T92-cap-test writes Seam G structural test — distinct files, parallel)
- **W1** — T93, T94, T95, T96 (4 tasks; four Rust modules — `command_taxonomy.rs`, `audit.rs`, `lock.rs`, `invoke.rs` — all distinct files, all parallel)
- **W2** — T108, T109, T110 (3 tasks; `lib.rs` polling wiring, `ipc.rs` handlers + TS projection generator, `invokeStore.ts` renderer wrapper — three distinct files, all parallel)
- **W3** — T97, T98, T99 (3 tasks; theme reuse map doc, invokeStore test, DESTROY scaffold unreachability grep — distinct files, parallel)
- **W4** — T100, T101, T102, T103, T104, T105 (6 tasks; six new React components each with its own `__tests__` file — all parallel)
- **W5** — T106, T107, T111, T112, T114 (5 tasks; T106 `SessionCard.tsx` + T107 `CardDetailHeader.tsx` + T111 `App.tsx` palette/toast mount are three distinct TSX files; T112 splits en.json + zh-TW.json as two parallel writes; **T114 B1 nits sweep runs serial after** because it touches `ipc.rs`, `App.tsx`, `themeStore.ts`, `en.json`, and a CSS file — collides with T111 and T112)
- **W6** — T113 (runtime handoff pre-commit, 1 task — TPM-owned, no code), T115–T121 (7 structural shell tests covering Seams B/I/L/M and the cross-file greps), T122 smoke.sh registration (append-only)

**Total tasks**: 30.
**Total waves**: 7 (W0–W6).
**Widest wave**: 7 (W6 — 7 parallel test authorings).
**Test file range**: `test/t91_*.sh` through `test/t100_*.sh` (exact allocation in §3).

### 2.1 Parallel-safety per wave

**W0 — Foundation.**
- T91 edits `flow-monitor/src-tauri/Cargo.toml` AND `flow-monitor/src-tauri/capabilities/default.json`. Single task, no intra-wave collision. The two files are semantically linked (plugin deps + their permissions) and must land in the same commit.
- T92-cap-test edits `test/t91_capability_manifest.sh` (new file). Distinct from T91's files.
- File-set check: ✓ no overlap.
- Parallel-safe: ✓ T91 + T92-cap-test in parallel.

**W1 — Pure Rust modules.** 4 parallel, all distinct files.
- T93 `flow-monitor/src-tauri/src/invoke.rs` (new).
- T94 `flow-monitor/src-tauri/src/audit.rs` (new) + `test/t92_audit_gitignore.sh` (new) + `test/t93_audit_path_traversal.sh` (new).
- T95 `flow-monitor/src-tauri/src/lock.rs` (new).
- T96 `flow-monitor/src-tauri/src/command_taxonomy.rs` (new).
- File-set check: ✓ no overlap. Each Rust module is authored with its own `#[cfg(test)]` block for the Rust-idiomatic seams (Seam A's existing diff test is untouched; Seam E lock-re-acquire is in `lock.rs`; Seam C audit-rotate + Seam H path-traversal are in `audit.rs`). The two shell tests attached to T94 are the greppable repo-level checks that cross-verify the gitignore append and the path-traversal rejection at the CLI boundary.
- Parallel-safe: ✓ T93 + T94 + T95 + T96.

**W2 — Backend wiring.** 3 parallel, all distinct files.
- T108 `flow-monitor/src-tauri/src/lib.rs` (edit existing — `run_session_polling` wiring).
- T109 `flow-monitor/src-tauri/src/ipc.rs` (edit existing — add 3 handlers, emit 3 events) + `flow-monitor/src-tauri/build.rs` (new) + `flow-monitor/src/generated/command_taxonomy.ts` (generated; first-commit tracked if `.gitignore` says so; otherwise untracked). Bundled into one task because the handlers in `ipc.rs` import the TS projection's backing consts; the build.rs is the generator for that TS file.
- T110 `flow-monitor/src/stores/invokeStore.ts` (new) — renderer wrapper calling `invoke_command` IPC.
- File-set check: ✓ no overlap (`lib.rs` and `ipc.rs` are distinct files; B1's `ipc.rs` gains handlers but does not reshape existing ones — append-only in a non-dispatcher-table sense).
- Dispatcher check: `ipc.rs` has no central dispatch table (Tauri 2's `tauri::command` macro wires each handler independently). Safe.
- Parallel-safe: ✓ T108 + T109 + T110.

**W3 — Renderer stores + scaffolds.** 3 parallel, all distinct files.
- T97 `flow-monitor/src/styles/b2-reuse-map.md` (new documentation file, records D10 token-reuse mapping).
- T98 `flow-monitor/src/stores/__tests__/invokeStore.test.ts` (new).
- T99 `test/t94_destroy_unreachable_grep.sh` (new — Seam B partial; cross-file grep assertion that no TSX file under `src/` other than `ConfirmModal.tsx` and its test imports `ConfirmModal`, AND that DESTROY command names appear only in `command_taxonomy.ts`).
- Parallel-safe: ✓ T97 + T98 + T99.

**W4 — Renderer components.** 6 parallel, all distinct files. Each component ships with its own `__tests__` file.
- T100 `flow-monitor/src/components/ActionStrip.tsx` + `__tests__/ActionStrip.test.tsx`.
- T101 `flow-monitor/src/components/CommandPalette.tsx` + `__tests__/CommandPalette.test.tsx`.
- T102 `flow-monitor/src/components/SendPanel.tsx` + `__tests__/SendPanel.test.tsx`.
- T103 `flow-monitor/src/components/PreflightToast.tsx` + `__tests__/PreflightToast.test.tsx`.
- T104 `flow-monitor/src/components/ConfirmModal.tsx` + `__tests__/ConfirmModal.test.tsx` (Seam F).
- T105 `flow-monitor/src/components/AuditPanel.tsx` + `__tests__/AuditPanel.test.tsx`.
- File-set check: ✓ no overlap. Each TSX component is its own file; each test is its own file under the `__tests__` sibling dir.
- Parallel-safe: ✓ all six in parallel.

**W5 — Integration + i18n + nits.** Mixed (4 parallel, then 1 serial).
- T106 `flow-monitor/src/components/SessionCard.tsx` (edit — mount ActionStrip on stalled cards per R2/AC2.b).
- T107 `flow-monitor/src/components/CardDetailHeader.tsx` (edit — Advance + Message buttons + inline SendPanel per R3/AC3.a/AC3.b).
- T111 `flow-monitor/src/App.tsx` (edit — mount CommandPalette + PreflightToast overlays + ⌘K keybinding per R5/AC5.a/AC5.c).
- T112a `flow-monitor/src/i18n/en.json` (edit — add 26 new keys per D9).
- T112b `flow-monitor/src/i18n/zh-TW.json` (edit — add 26 new keys per D9).
- T114 **B1 nits sweep** (edit multiple: `flow-monitor/src-tauri/src/ipc.rs` line-length, `flow-monitor/src/App.tsx` unused `navigatedPaths` state, `flow-monitor/src/i18n/en.json` + `zh-TW.json` dead `markdown.footer` key, 6 non-BEM classes in `flow-monitor/src/styles/`, WHAT-comments in files listed in B1 archive).
- File-set check: T114 conflicts with T111 (App.tsx) and T112a+b (i18n JSONs) and the ipc.rs that T109 already touched in W2 (but W2 is merged before W5 starts, so T114 is editing a committed file — OK across waves; the concern is intra-W5).
- **Grouping decision**: **W5a = {T106, T107, T111, T112a, T112b}** (5 parallel — each writes a distinct file), **W5b = {T114}** (serial after W5a — re-reads the post-W5a tree and sweeps nits in one commit).
- Parallel-safe list per task (see §3 for the explicit lists).

**W6 — Structural tests + docs.** Mixed (7 parallel authorings, 1 serial append-only registration).
- T115 `test/t95_argv_no_shell_cat.sh` (Seam I — grep `src-tauri/src/` for `Command::new("sh"` or `exec("sh …")` patterns; assert 0 matches).
- T116 `test/t96_i18n_parity_b2_keys.sh` (Seam J — load en + zh-TW, assert the 26 new B2 keys present in both).
- T117 `test/t97_theme_token_reuse.sh` (Seam K — grep `src/styles/` for net-new `--(color|space|font|radius)-` declarations vs B1 archive baseline).
- T118 `test/t98_stage_label_lookup.sh` (Seam L — assert every stage in the enum has an `action.advance_to.<stage>` i18n key in both bundles).
- T119 `test/t99_b1_nits_cleared.sh` (Seam M — 5 assertions matching the B1 archive NITS list: ipc.rs line-length, WHAT-comments absent in listed files, unused `navigatedPaths` state removed, dead `markdown.footer` key removed, 6 non-BEM classes either renamed or documented keep-with-justification).
- T120 `test/t100_taxonomy_classification.sh` (Seam B full — unit test that asserts the 11 WRITE+safe names, the 5 DESTROY names, total=16; cross-file grep that DESTROY names appear only in `command_taxonomy.rs` + `command_taxonomy.ts` + `audit.rs` outcome enum).
- T121 `test/t101_runtime_handoff_note.sh` (structural verification of T113's STATUS note append — assert the successor-feature handoff line is committed to B2's STATUS at archive time; implemented as a grep against B2's STATUS.md).
- T113 **runtime handoff pre-commit** (TPM-owned, W6) — writes the exact STATUS line the successor feature should emit into B2's archive RETROSPECTIVE; no code, just the handoff instruction.
- T122 `test/smoke.sh` registration — append-only append for the 7 new shell tests. Per `tpm/parallel-safe-append-sections.md`: expected textual collision on mechanical keep-both resolution; T122 runs **last in the wave** (serial after T115–T121) so the registration references committed test files.
- File-set check: ✓ no overlap among T115–T121 (each a new file). T122 appends to the existing `test/smoke.sh`.
- Parallel-safe: W6a = {T113, T115, T116, T117, T118, T119, T120, T121} (8 parallel); W6b = {T122} (serial after W6a).

### 2.2 Merge gate per wave (inline reviewers)

Default per-wave gate is **inline review on** (repo's normal posture). No `--skip-inline-review` invoked anywhere in this plan.

- **W0**: security (capability manifest edits touch the app's trust boundary — R9; reviewer reads D1 exact grants) + style (JSON + TOML formatting) + performance (low risk).
- **W1**: security (audit.rs path-traversal guard — AC9.b; invoke.rs argv-only posture — AC4.d; `ensure_gitignore` atomic write — `no-force-on-user-paths.md`) + style (Rust idioms + inline `#[cfg(test)]` test shape) + performance (audit append is user-action-bound, not polling — low risk; D4 on-write rotation is one `metadata()` per append).
- **W2**: security (lib.rs + ipc.rs gain the Tauri-command surface; reviewer checks the `invoke_command` handler's classify→allow-list→lock→dispatch order per tech §2.2 Flow C) + performance (lib.rs polling loop budget — RA above) + style (Rust + TS).
- **W3**: style (doc + test + grep).
- **W4**: style (TSX components) + security (PreflightToast is informational, not a gate — reviewer verifies no "confirm" semantics accidentally wired) + performance (low risk; React component render budgets).
- **W5**: style (integration points) + security (App.tsx ⌘K keybinding doesn't accidentally expose DESTROY commands — AC5.b; reviewer greps the palette render list) + performance (low risk). **Reviewer must also verify**: (a) T114 nits sweep doesn't re-introduce removed dead code, (b) T112a/b i18n additions land in both JSON files with the same key set.
- **W6**: style (shell test shape consistency) + security (grep assertions covering DESTROY unreachability, no-shell-string-cat, path-traversal) + performance (low risk).

Per `.claude/rules/bash/sandbox-home-in-tests.md`, every shell test that invokes a CLI reading `$HOME` must sandbox-home. Flagged on: T92-cap-test (reads repo capability file, no HOME — exempt); T94 shell tests (sandbox if they invoke `ensure_gitignore` against a repo — **required**); T99, T115–T121 (most are greps against the repo working tree, HOME-safe — **none required unless the test invokes a binary that expands `$HOME`**). Developer on each test task confirms at task start.

**STATUS Notes enforcement** (per `shared/status-notes-rule-requires-enforcement-not-just-documentation`): plan §4 below asserts that only the orchestrator writes STATUS Notes (not Developer subagents). Reviewer (style axis) on every wave must verify no task's commit appends a STATUS Notes line — if a task appends its own, flag as `must` style finding and refer to this plan's §4.

### 2.3 Structural-vs-runtime verification matrix

Per PRD §9 and `shared/dogfood-paradox-third-occurrence`.

| AC | Coverage at this feature's validate | Deferred to next feature |
|---|---|---|
| AC1.a (stalled card render) | — | Runtime (next feature) |
| AC1.b (macOS banner fires once) | — | Runtime |
| AC1.c (no second banner while stalled) | Structural (Seam A — `store::diff` existing unit test, one new fixture added in T108's inline tests) | — |
| AC1.d (re-fire after recovery) | Structural half only (Seam A new fixture in T108 inline tests); runtime half deferred | Runtime half → next feature |
| AC2.a (stage-specific advance label) | — | Runtime |
| AC2.b (no action strip on non-stalled) | — | Runtime (T106 renders the gate, but visual verification requires live grid) |
| AC2.c (label lookup table-driven) | Structural (Seam L / T118) | — |
| AC3.a (detail buttons gated) | — | Runtime |
| AC3.b (send-panel tabs default) | — | Runtime |
| AC4.a (Advance spawns terminal) | — | Runtime |
| AC4.b (clipboard fallback setting) | — | Runtime |
| AC4.c (terminal-fail → clipboard + toast) | — | Runtime |
| AC4.d (no shell string-cat — argv form) | Structural (Seam I / T115) | — |
| AC5.a (⌘K palette open/close) | — | Runtime |
| AC5.b (palette scope = WRITE+safe only) | Structural (Seam B / T120 + T99) | — |
| AC5.c (3s preflight toast) | — | Runtime |
| AC6.a (one audit line per invoke) | — | Runtime |
| AC6.b (two lines on spawn-fail + clipboard) | — | Runtime |
| AC6.c (rotate at 1 MB) | Structural (Seam C — inline Rust test in audit.rs, T94) | — |
| AC6.d (idempotent gitignore add) | Structural (Seam D — inline Rust test in audit.rs + `test/t92_audit_gitignore.sh`, T94) | — |
| AC7.a (cross-window in-flight disable) | — | Runtime |
| AC7.b (lock release on STATUS change or 60s) | — | Runtime |
| AC7.c (lock is in-process per-app) | Structural (Seam E — inline Rust test in lock.rs, T95) | — |
| AC8.a (modal Cancel default) | Structural (Seam F — component test in T104) | — |
| AC8.b (DESTROY unreachable) | Structural (Seam B partial / T99 + T120 cross-file grep) | — |
| AC9.a (capability allow-list + argv schema) | Structural (Seam G — `test/t91_capability_manifest.sh` / T92-cap-test) | — |
| AC9.b (audit path-traversal guard) | Structural (Seam H — `test/t93_audit_path_traversal.sh` / T94 + inline Rust test) | — |
| AC10.a (i18n parity en + zh-TW) | Structural (Seam J / T116) | — |
| AC10.b (runtime zh-TW walkthrough) | — | Runtime |
| AC11.a (no new theme tokens) | Structural (Seam K / T117) | — |
| AC12.a (B1 nits absorbed) | Structural (Seam M / T119) | — |

**Totals**: 16 structural (covered in this feature's validate), 15 runtime (deferred to next feature), 1 split (AC1.d — structural half covered, runtime half deferred).

---

## 3. Task checklist

Conventions in this section (new merged shape):

- Tasks numbered T91..T122 (non-contiguous; T91–T107 are content tasks in waves W0–W5; T108–T112 are wave-W2/W5 content tasks; T113–T122 are W6 test + handoff tasks). The numbering gap vs tier-model's T1–T35 is intentional: B2 uses test files `test/t91_*.sh` onward (tier-model used t74–t90) per `tpm/pre-declare-test-filenames-in-06-tasks.md`.
- `Files:` lists the exact paths each task creates or modifies. Overlap within a wave is a planning bug.
- `Requirement:` cites ≥1 PRD R-id. `Decisions:` cites the tech D-id(s) the task realises.
- `Verify:` is a runnable command. For tasks whose verification lives in a sibling test task (e.g. T93 verified by inline Rust `cargo test` + T115), `Verify:` names both.
- `Depends on:` lists in-plan task IDs only.
- `Parallel-safe-with:` lists same-wave tasks this task is explicitly safe to run alongside. Tasks missing from a peer's `Parallel-safe-with:` list must run in different waves even if `Depends on:` is empty.
- Orchestrator checks off `[x]` in a post-wave bookkeeping commit per `tpm/wave-bookkeeping-commit-per-wave.md`. Developers do NOT flip their own checkbox and do NOT append their own STATUS Notes line (orchestrator does both in one post-wave commit).
- Test fixture paths under sandbox `$REPO_ROOT/.test-tNN.XXXXXX` per `developer/test-fixture-path-under-repo-root`; `.test-*` is added to `.gitignore` at T91 task-start time if not already covered.
- Any task that removes files uses `/bin/rm -f` per `developer/shell-alias-intercepts-rm-use-absolute-path`.
- Any sourced bash library uses `return`, not `exit`, per `developer/sourced-library-exit-vs-return` — B2 has no new sourced bash library (all bash is one-shot tests), so this is vacuously satisfied; flagged anyway for future-proofing.

### Wave 0 — Foundation (2 tasks)

## T91 — [x] [ ] Add tauri-plugin-shell + tauri-plugin-fs + capability manifest expansion
- **Milestone**: M0
- **Requirements**: R4, R6, R9
- **Decisions**: D1, D8
- **Scope**: Two coordinated edits landing in one commit:
  1. `flow-monitor/src-tauri/Cargo.toml`: add `tauri-plugin-shell = "2"` and `tauri-plugin-fs = "2"` under `[dependencies]` alongside the existing `tauri-plugin-*` lines. Also register both plugins in `flow-monitor/src-tauri/src/lib.rs::run`'s builder chain (one line each: `.plugin(tauri_plugin_shell::init())` + `.plugin(tauri_plugin_fs::init())`). Note: this is the ONLY W0 edit to `lib.rs`; T108 in W2 adds the polling-loop wiring — sequential across waves is safe.
  2. `flow-monitor/src-tauri/capabilities/default.json`: append the two permission blocks verbatim from tech D1 concrete manifest delta — `shell:allow-execute` with the single `open-terminal` entry (cmd `/usr/bin/open`, args `-a Terminal.app <regex-validator>`), `fs:allow-write-text-file` scoped to `$APPLOCALDATA/tmp/invoke-*.command`, and `fs:allow-append-file` scoped to the two audit-log paths. Preserve the existing four permissions (`core:default`, `dialog:default`, `clipboard-manager:default`, `notification:default`).
  3. Add `src/generated/` and `.test-*` to the repo's top-level `.gitignore` if not already present (idempotent check before append, per `no-force-on-user-paths.md`).
  4. Include a code comment in both files linking to tech D1 and to T93's invoke.rs path generator: `// See D1 / T93 — regex validator must match invoke.rs's tmpdir pattern`.
- **Deliverables**: modified `flow-monitor/src-tauri/Cargo.toml`, modified `flow-monitor/src-tauri/capabilities/default.json`, modified `flow-monitor/src-tauri/src/lib.rs` (plugin register lines only — not the polling wiring), modified top-level `.gitignore` (idempotent).
- **Verify**: `cd flow-monitor && cargo build --manifest-path src-tauri/Cargo.toml` exits 0. Structural: `grep -q 'tauri-plugin-shell' flow-monitor/src-tauri/Cargo.toml` and `grep -q 'shell:allow-execute' flow-monitor/src-tauri/capabilities/default.json` both exit 0. Full verification of the manifest shape is in T92-cap-test.
- **Depends on**: —
- **Parallel-safe-with**: T92-cap-test
- [x]

## T92-cap-test — [x] [ ] Seam G: capability manifest structural test
- **Milestone**: M0
- **Requirements**: R9
- **Decisions**: D1
- **Scope**: Author `test/t91_capability_manifest.sh`. The test parses `flow-monitor/src-tauri/capabilities/default.json` (use `python3 -c 'import json, sys; …'` per `bash-32-portability.md` — no `jq`) and asserts:
  - `permissions[]` contains a `core:default` string, `dialog:default` string, `clipboard-manager:default` string, `notification:default` string.
  - `permissions[]` contains an object with `identifier == "shell:allow-execute"` whose `allow` array has exactly one entry with `name == "open-terminal"`, `cmd == "/usr/bin/open"`, and `args` array beginning with `"-a"`, `"Terminal.app"`, then a regex-validator object.
  - `permissions[]` contains `identifier == "fs:allow-append-file"` with two entries targeting `audit.log` and `audit.log.1`.
  - Malformed JSON in the fixture path causes the test to exit 2 (fail-loud).
  - Sandbox-HOME NOT required (this test only reads a repo file and does not invoke any CLI that expands `$HOME`).
- **Deliverables**: `test/t91_capability_manifest.sh` (exec bit).
- **Verify**: `bash test/t91_capability_manifest.sh` exits 0 against the T91-committed manifest.
- **Depends on**: —
- **Parallel-safe-with**: T91
- [x]

### Wave 1 — Pure Rust modules (4 tasks)

## T93 — [x] `invoke.rs` — terminal-spawn + clipboard + pipe-Err dispatcher
- **Milestone**: M1
- **Requirements**: R4, R7
- **Decisions**: D1, D6, D8
- **Scope**: Author `flow-monitor/src-tauri/src/invoke.rs`. Exports:
  - `enum DeliveryMethod { Terminal, Clipboard, Pipe }` — closed enum per `classify-before-mutate.md` (classifier + dispatch pattern).
  - `enum InvokeError { UnknownCommand, DestroyUnreachable, InFlight, SpawnFailed, ClipboardFailed, PathTraversal, NotAvailable }` — typed errors; no string-escape hatch.
  - `struct InvokeResult { outcome: Outcome }` where `enum Outcome { Spawned, Copied, Failed }` — Outcome is a closed set; `DestroyConfirmed` is reserved for B3 (present in the enum, never written by B2 code).
  - `fn dispatch(delivery: DeliveryMethod, cmd: &str, slug: &str, repo: &Path) -> Result<InvokeResult, InvokeError>`.
  - **Terminal arm**: write the specflow command to a temp `.command` script at `$APPLOCALDATA/tmp/invoke-<16hex>.command` (mode 0755); exec `/usr/bin/open -a Terminal.app <script-path>` via `tauri-plugin-shell` argv-form (NO string concatenation — AC4.d). The tmpdir path MUST match the regex validator in T91's capability manifest — use a constant `TEMP_INVOKE_PATH_TEMPLATE` in this file and document the coupling.
  - **Clipboard arm**: call `tauri-plugin-clipboard-manager` `writeText(cmd_string)`. No shell, no spawn.
  - **Pipe arm**: return `Err(InvokeError::NotAvailable)`.
  - Inline `#[cfg(test)]` tests covering: (a) Pipe arm returns NotAvailable; (b) Terminal arm constructs the argv Vec correctly without any shell-string interpolation (unit test that inspects the argv shape before spawn); (c) temp-file path matches the capability manifest regex. Tests are Rust-idiomatic `#[test]` fns.
  - Add `purge_stale_temp_files()` helper invoked from app setup (tech D1 — "removed on next app launch").
- **Deliverables**: `flow-monitor/src-tauri/src/invoke.rs` (new). Also add `mod invoke;` to `flow-monitor/src-tauri/src/lib.rs` — this is a single-line append to lib.rs's module declarations; T108 in W2 separately edits lib.rs for polling wiring (different region of the file, safe across waves but **T108 must re-read lib.rs at task start** per tpm `tasks-doc-format-migration` discipline).
- **Verify**: `cd flow-monitor/src-tauri && cargo test -p flow-monitor --lib invoke::` exits 0. Cross-reference T115 (Seam I — no `Command::new("sh"` in src-tauri).
- **Depends on**: T91 (needs `tauri-plugin-shell` in Cargo.toml to compile)
- **Parallel-safe-with**: T94, T95, T96
- [x]

## T94 — [x] `audit.rs` — TSV append + rotation + gitignore bootstrap + path-traversal guard
- **Milestone**: M1
- **Requirements**: R6, R9
- **Decisions**: D4, D7
- **Scope**: Author `flow-monitor/src-tauri/src/audit.rs`. Exports:
  - `struct AuditLine { ts: DateTime, slug: String, command: String, entry_point: EntryPoint, delivery: DeliveryMethod, outcome: Outcome }` — all closed enums (EntryPoint ∈ {CardAction, CardDetail, Palette, ContextMenu, CompactPanel}).
  - `fn append_line(repo: &Path, line: AuditLine) -> Result<(), AuditError>` — the workflow:
    1. Classify target path via `canonicalise_and_check_under_repo(repo, target)` which returns `Err(AuditError::PathTraversal)` if the canonicalised write path does not start with `<repo>/.spec-workflow/.flow-monitor/`. This reuses B1's `ipc.rs::read_artefact` boundary-check pattern (reviewer on this task cites the B1 source file).
    2. `ensure_flow_monitor_dir_exists(repo)` — mkdir -p `.spec-workflow/.flow-monitor/`.
    3. `ensure_gitignore(repo)` — idempotent: read `<repo>/.gitignore`, check for existing line matching `^\.spec-workflow/\.flow-monitor/$`, append via atomic write-temp-then-rename only if absent. NEVER overwrite wholesale. Per `.claude/rules/common/no-force-on-user-paths.md`.
    4. `metadata().len()` on `audit.log`; if ≥ 1_048_576 → rotate (rename `audit.log` → `audit.log.1`, overwriting any existing `.1`). Per D4.
    5. Open `audit.log` with `OpenOptions::new().append(true).create(true)` and write one TSV line per tech D7 format (6 tab-separated fields + LF).
  - `fn read_tail(repo: &Path, limit: usize) -> Result<Vec<AuditLine>, AuditError>` — tail N lines for `get_audit_tail` IPC in T109.
  - Inline `#[cfg(test)]` tests: (a) Seam C — write a 1 MB fixture to `audit.log`, call `append_line`, assert `audit.log.1` exists with old content + `audit.log` is one line. (b) Seam D — call `ensure_gitignore` twice on a tempdir, assert one line added not two. (c) Seam H — call `append_line` with a crafted path traversal and assert `Err(PathTraversal)`.
- **Deliverables**: `flow-monitor/src-tauri/src/audit.rs` (new); also append `test/t92_audit_gitignore.sh` (shell-level cross-check that invokes audit behaviour via a small Rust harness binary or a `cargo test` wrapper — simpler: grep-verify after the inline test runs that the gitignore line pattern is correct) AND `test/t93_audit_path_traversal.sh` (same shell-level wrapper for the path-traversal case). Also add `mod audit;` to `flow-monitor/src-tauri/src/lib.rs` (single-line append).
- **Verify**: `cd flow-monitor/src-tauri && cargo test -p flow-monitor --lib audit::` exits 0. `bash test/t92_audit_gitignore.sh` and `bash test/t93_audit_path_traversal.sh` exit 0. Sandbox-HOME discipline required for both shell tests per `sandbox-home-in-tests.md`.
- **Depends on**: T91 (needs `tauri-plugin-fs` + capability scope)
- **Parallel-safe-with**: T93, T95, T96
- [x]

## T95 — [x] `lock.rs` — in-process `Mutex<HashSet>` + 60s watchdog
- **Milestone**: M1
- **Requirements**: R7
- **Decisions**: D2
- **Scope**: Author `flow-monitor/src-tauri/src/lock.rs`. Exports:
  - `struct LockState { locks: Mutex<HashSet<(PathBuf, String)>> }` — Tauri-managed state, app-scoped (not window-scoped — per risk RF).
  - `fn acquire(&self, repo: PathBuf, slug: String) -> bool` — true if lock acquired, false if already held.
  - `fn release(&self, repo: &Path, slug: &str)`.
  - `fn current(&self) -> Vec<(PathBuf, String)>` — snapshot for `get_in_flight_set` IPC.
  - `async fn spawn_watchdog(&self, repo: PathBuf, slug: String, advance_rx: Receiver<()>)` — `tokio::select!` between `tokio::time::sleep(Duration::from_secs(60))` and the `advance_rx` channel; whichever fires first triggers `release()` + emits `in_flight_changed` event. Per risk RE above.
  - Inline `#[cfg(test)]` tests: Seam E — create a `LockState`, acquire `(repo, slug)`, assert second `acquire` returns false; drop the `LockState`; create a new one; assert `acquire` returns true. Models the "closed-and-reopened window" AC7.c case.
- **Deliverables**: `flow-monitor/src-tauri/src/lock.rs` (new). Also `mod lock;` append to `lib.rs`.
- **Verify**: `cd flow-monitor/src-tauri && cargo test -p flow-monitor --lib lock::` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T93, T94, T96
- [x]

## T96 — [x] `command_taxonomy.rs` — hardcoded 16-command list + classifier
- **Milestone**: M1
- **Requirements**: R5, R8
- **Decisions**: D3
- **Scope**: Author `flow-monitor/src-tauri/src/command_taxonomy.rs`. Exports:
  - `enum Classification { Safe, Write, Destroy }` — closed set.
  - `const SAFE: &[&str] = &["next", "review", "remember", "promote"];`
  - `const WRITE: &[&str] = &["request", "prd", "tech", "plan", "implement", "validate", "design"];`
  - `const DESTROY: &[&str] = &["archive", "update-req", "update-tech", "update-plan", "update-task"];`
  - Note: these reflect the post-tier-model live command set. `brainstorm`, `tasks`, `verify`, `gap-check` are RETIRED stubs — do NOT include them in the taxonomy.
  - `fn classify(cmd: &str) -> Option<Classification>` — pure function, returns `Some(Safe|Write|Destroy)` if cmd is in one of the three arrays, else `None`.
  - `fn allow_list_contains(cmd: &str) -> bool` — returns true if cmd is in SAFE ∪ WRITE ∪ DESTROY.
  - Inline `#[cfg(test)]` tests: Seam B partial — unit test that asserts the 4+7+5 = 16 count; unknown command returns None; each of the 16 returns the expected Classification.
- **Deliverables**: `flow-monitor/src-tauri/src/command_taxonomy.rs` (new). Also `mod command_taxonomy;` append to `lib.rs`.
- **Verify**: `cd flow-monitor/src-tauri && cargo test -p flow-monitor --lib command_taxonomy::` exits 0. The TS projection is NOT generated in this task — T109's build.rs handles that.
- **Depends on**: —
- **Parallel-safe-with**: T93, T94, T95
- [x]

### Wave 2 — Backend wiring (3 tasks)

## T108 — [x] `lib.rs::run_session_polling` — wire store::diff + notify::fire_stalled_notification
- **Milestone**: M2
- **Requirements**: R1
- **Decisions**: D5
- **Scope**: Edit `flow-monitor/src-tauri/src/lib.rs`. Inside `run_session_polling`'s existing `loop {}` (the 3-second tick):
  1. Maintain two locals across tick iterations: `prev_map: HashMap<SessionKey, State>` and `prev_stalled_set: HashSet<SessionKey>`. Initialise both to empty before the loop.
  2. After the existing `new_list = …parse…` step, build `new_map: HashMap<SessionKey, State>` from `new_list`.
  3. Call `let diff_event = store::diff(prev_map.clone(), new_map.clone(), prev_stalled_set.clone(), settings.stalled_threshold_mins);`. Note: B1's `store::diff` signature is already in place; this task wires, does not modify.
  4. For each key in `diff_event.stalled_transitions`: call `notify::fire_stalled_notification(app, slug, duration)`. The `notify::fire_stalled_notification` helper already exists (B1); no new function signature.
  5. Assign `prev_map = new_map; prev_stalled_set = diff_event.next_stalled_set;` BEFORE the sleep, so the next tick sees the post-diff state.
  6. Extend the existing `sessions_changed` emit payload with the diff's `stalled_transitions` list (payload extended, not deleted — B1 retains its own consumers).
  7. Add one inline `#[cfg(test)]` test exercising Seam A's new fixture: a session stays stalled for 2 consecutive ticks, `prev_stalled_set` contains the key on tick N, and `stalled_transitions` is empty on tick N+1 — verifies AC1.c and the structural half of AC1.d.
  8. Per RA: DO NOT clone the entire session list on the hot path unnecessarily; `diff` takes ownership of the clones only inside its block. Per-tick diff cost budget: <50 ms; add a `tracing::warn` if exceeded.
- **Deliverables**: modified `flow-monitor/src-tauri/src/lib.rs` (in-loop wiring region only; module declarations from W1's T93/T94/T95/T96 already land).
- **Verify**: `cd flow-monitor/src-tauri && cargo test -p flow-monitor --lib` exits 0 (exercises the new inline Seam A test plus all B1 tests). Manual review: the diff shape and the `prev_*` local carry correctly across tick iterations.
- **Depends on**: T91 (plugin registration), T96 (command_taxonomy module — not directly used here but T108's scope is to land lib.rs polling wiring cleanly against the W1 module set)
- **Parallel-safe-with**: T109, T110
- [x]

## T109 — [x] `ipc.rs` handlers + `build.rs` TS taxonomy projection
- **Milestone**: M2
- **Requirements**: R4, R5, R6, R7, R8
- **Decisions**: D3, D6
- **Scope**: Two coupled edits landing in one commit:
  1. Edit `flow-monitor/src-tauri/src/ipc.rs`. Add three new `#[tauri::command]` handlers:
     - `invoke_command(state: State<'_, LockState>, app: AppHandle, repo: String, slug: String, command: String, delivery: String, entry_point: String) -> Result<InvokeResult, IpcError>` — the dispatcher per tech §2.2 Flow C: classify → allow-list check → lock::acquire → invoke::dispatch → audit::append_line → emit events → return InvokeResult. If `classify` returns `Destroy`, return `Err(DestroyUnreachable)` — belt-and-braces guard per AC8.b.
     - `get_audit_tail(repo: String, limit: usize) -> Result<Vec<AuditLine>, IpcError>` — delegates to `audit::read_tail`.
     - `get_in_flight_set(state: State<'_, LockState>) -> Vec<(PathBuf, String)>` — delegates to `lock::current`.
  2. Wire event emitters using **app-level `app.emit(...)`** per risk RF:
     - `in_flight_changed` with payload `{ locks: Vec<(PathBuf, String)>, timestamp }` — emitted from lock::acquire and lock::release.
     - `audit_appended` with payload `{ repo, line: AuditLine }` — emitted after audit::append_line.
     - `session_advanced` with payload `{ repo, slug }` — emitted from `run_session_polling` when STATUS.md mtime changes (this is a cross-module concern; T108 emits, T109 declares the event shape via a shared struct in `ipc.rs`).
  3. Create `flow-monitor/src-tauri/build.rs` (new file). The build script:
     - Reads `src/command_taxonomy.rs` via a simple text parser for the three `const` arrays (regex on `const (SAFE|WRITE|DESTROY): &\[&str\] = &\[([^\]]+)\];`).
     - Writes `flow-monitor/src/generated/command_taxonomy.ts` with matching `export const SAFE = [...] as const;` arrays.
     - Fail-loud on parse mismatch (Rust compile fails if the generator can't parse command_taxonomy.rs).
  4. Add `src/generated/` to `flow-monitor/.gitignore` if not already. T91 handled the repo-level; this handles the app-level.
  5. Register `build = "build.rs"` under `[package]` in `flow-monitor/src-tauri/Cargo.toml` — a one-line addition to a file T91 already edited in W0; **W0 merged before W2 starts** so this is safe across waves.
  6. Register each tauri::command in `lib.rs::run`'s `invoke_handler! { … }` block — a small, targeted edit to lib.rs. **Coordination with T108**: T108 edits the polling-loop region; T109 edits the invoke_handler region. Different regions of the same file — per `tpm/parallel-safe-requires-different-files.md` a same-file write from two tasks in the same wave is a **planning bug UNLESS the regions are genuinely disjoint**. Mitigation: T109's lib.rs edit is restricted to the `invoke_handler!` macro argument list; T108's edit is inside the async polling loop 30+ lines away. Developer on T109 reads T108's diff first (T108 should have committed first within the wave if possible; otherwise use git's 3-way merge). Flag to reviewer: confirm regions are disjoint at merge time.
- **Deliverables**: modified `flow-monitor/src-tauri/src/ipc.rs`, new `flow-monitor/src-tauri/build.rs`, generated `flow-monitor/src/generated/command_taxonomy.ts` (first commit; subsequent regens are build-script output — gitignored), modified `flow-monitor/src-tauri/Cargo.toml` (one line), modified `flow-monitor/src-tauri/src/lib.rs` (invoke_handler region only), modified `flow-monitor/.gitignore`.
- **Verify**: `cd flow-monitor/src-tauri && cargo build` exits 0 AND regenerates the TS projection. `cd flow-monitor && npm test` exits 0 (the TS projection is importable). Manual: diff lib.rs to confirm the invoke_handler region edit is disjoint from T108's polling-loop edit.
- **Depends on**: T93, T94, T95, T96 (needs all four W1 modules to compile).
- **Parallel-safe-with**: T108, T110 (with the "disjoint regions of lib.rs" caveat above — developer coordinates)
- [x]

## T110 — [x] `invokeStore.ts` — renderer dispatch wrapper + in-flight set
- **Milestone**: M2
- **Requirements**: R2, R3, R4, R5, R7
- **Decisions**: D6
- **Scope**: Author `flow-monitor/src/stores/invokeStore.ts` (new file). Per tech §2.2 Flow C renderer half:
  - `type Delivery = 'terminal' | 'clipboard' | 'pipe';` (matches Rust enum).
  - `interface InvokeStore { inFlight: Set<string>; dispatch(command: string, slug: string, repo: string, entry: EntryPoint, delivery: Delivery): Promise<void>; … }`.
  - `dispatch()` workflow: (a) classify(command) — imports from `src/generated/command_taxonomy.ts` produced by T109's build.rs. (b) If `Destroy` → open `ConfirmModal` (in B2: this branch is unreachable because no caller emits a destroy command, but the branch exists for B3). (c) If `(repo, slug)` in `inFlight` → show "Action already in flight" toast, return. (d) `inFlight.add(…)`, await `tauri.invoke('invoke_command', …)`. (e) If Delivery is terminal and result.outcome === 'spawned' → show PreflightToast for 3s. (f) If result.outcome === 'failed' → AC4.c fallback: call `invoke_command` again with `delivery: 'clipboard'` + show error toast.
  - Subscribe to Tauri events `in_flight_changed` / `audit_appended` / `session_advanced` and update `inFlight` set accordingly.
  - Zustand-style store matching B1's `sessionStore.ts` / `themeStore.ts` shape. No new state-library dep.
- **Deliverables**: `flow-monitor/src/stores/invokeStore.ts` (new).
- **Verify**: T98 (W3) authors the unit test that exercises this store. Compile check here: `cd flow-monitor && npm run build` exits 0.
- **Depends on**: T109 (needs the generated TS projection + the IPC handlers).
- **Parallel-safe-with**: T108, T109 (distinct file)
- [x]

### Wave 3 — Renderer stores + scaffolds (3 tasks)

## T97 — [x] Theme token reuse mapping doc
- **Milestone**: M3
- **Requirements**: R11
- **Decisions**: D10
- **Scope**: Author `flow-monitor/src/styles/b2-reuse-map.md` (a tiny doc, ~40 lines). Contents: a table mapping every new B2 CSS class to the existing B1 token it reuses. Concrete mapping from tech D10:
  - ActionStrip primary button → `--button-primary-bg` + `--button-primary-fg`
  - ActionStrip secondary button → `--button-secondary-*`
  - Palette overlay background → `--overlay-bg`
  - Stalled badge red → `--color-status-stalled`
  - WRITE pill yellow → `--color-status-stale` (reused; both "warn" semantic)
  - DESTROY pill red → `--color-status-stalled` (reused; both "danger" semantic)
  - Confirm modal backdrop → `--overlay-bg`
  - Audit panel background → `--surface-subtle` (existing B1 token)
  - Preflight toast background → `--surface-raised`
- **Deliverables**: `flow-monitor/src/styles/b2-reuse-map.md` (new).
- **Verify**: T117 (W6) grep-asserts no net-new `--(color|space|font|radius)-` declarations. This doc is the reviewer's reference during W4.
- **Depends on**: —
- **Parallel-safe-with**: T98, T99
- [x]

## T98 — [x] `invokeStore.test.ts` — unit test for renderer dispatch wrapper
- **Milestone**: M3
- **Requirements**: R4, R5, R7
- **Decisions**: D6
- **Scope**: Author `flow-monitor/src/stores/__tests__/invokeStore.test.ts`. Cases:
  - classify('prd') returns 'write' (imported from generated TS projection).
  - classify('archive') returns 'destroy'.
  - classify('unknown-cmd') returns null.
  - dispatch() adds `(repo, slug)` to inFlight on call; removes on session_advanced event.
  - If `(repo, slug)` already in inFlight, dispatch() does not call `tauri.invoke`.
  - Mock `tauri.invoke` returning `{ outcome: 'failed' }` triggers a second `invoke` call with `delivery: 'clipboard'` (AC4.c fallback).
  - Mock `tauri.invoke` returning `{ outcome: 'spawned' }` with Write-classified command triggers PreflightToast state.
- **Deliverables**: `flow-monitor/src/stores/__tests__/invokeStore.test.ts` (new).
- **Verify**: `cd flow-monitor && npm test -- invokeStore.test` exits 0.
- **Depends on**: T110 (needs `invokeStore.ts` source).
- **Parallel-safe-with**: T97, T99
- [x]

## T99 — [x] Seam B partial: DESTROY unreachability cross-file grep test
- **Milestone**: M3
- **Requirements**: R8
- **Decisions**: D3
- **Scope**: Author `test/t94_destroy_unreachable_grep.sh`. Two assertions:
  1. `grep -rE 'from .+ConfirmModal|import.+ConfirmModal' flow-monitor/src/ --include='*.ts*'` returns only matches from `ConfirmModal.tsx` itself and its `__tests__/ConfirmModal.test.tsx`. Any other hit is a failure.
  2. `grep -rwE '(archive|update-prd|update-plan|update-tech|update-tasks)' flow-monitor/src/ --include='*.ts*'` returns only matches from `src/generated/command_taxonomy.ts` (the authoritative list). Any other hit is a failure.
  - Exit 0 on pass; exit 1 on violation with a clear diagnostic.
  - Bash 3.2 portability; no GNU-only flags.
- **Deliverables**: `test/t94_destroy_unreachable_grep.sh` (exec bit).
- **Verify**: `bash test/t94_destroy_unreachable_grep.sh` exits 0 after W4 + W5 commits land. During W3 the test should pass vacuously (ConfirmModal doesn't exist yet) — this is acceptable because W4's T104 will author the first definition, and W5's T107 must NOT import it. **The real binding test moment is in W6 after W5 settles**; scheduling the test authoring in W3 keeps the plan parallel-safe but the test's effective enforcement starts at W4 merge.
- **Depends on**: —
- **Parallel-safe-with**: T97, T98
- [x]

### Wave 4 — Renderer components (6 tasks)

## T100 — [x] `ActionStrip.tsx` + component test
- **Milestone**: M4
- **Requirements**: R2
- **Decisions**: (none — pure UI)
- **Scope**: Author `flow-monitor/src/components/ActionStrip.tsx` — two-button row per designer's Screen 1. Primary: "Advance to [stage]" (label from i18n key `action.advance_to.<next_stage>` — stage lookup imported from existing session type). Secondary: "Message" (opens Card Detail). Component props: `{ session: SessionState, onAdvance: () => void, onMessage: () => void }`. Renders only when parent decides (T106 gates on stalled). No render gating inside this component — keep it a pure display component per D10 reuse map. Uses `--button-primary-*` / `--button-secondary-*` tokens from T97's map.
  - Author `flow-monitor/src/components/__tests__/ActionStrip.test.tsx`: renders with fixture session at stage `prd`, asserts primary button text resolves to the en i18n value `"Advance to Tech"`; asserts secondary button text `"Message / Choice"`; click each button calls the respective prop callback.
- **Deliverables**: `flow-monitor/src/components/ActionStrip.tsx` (new) + `flow-monitor/src/components/__tests__/ActionStrip.test.tsx` (new).
- **Verify**: `cd flow-monitor && npm test -- ActionStrip` exits 0.
- **Depends on**: T110, T112a (needs invokeStore + en.json i18n keys — but i18n is in W5; for the test, use a jest mock of the i18n module per existing flow-monitor test convention).
- **Parallel-safe-with**: T101, T102, T103, T104, T105
- [x]

## T101 — [x] `CommandPalette.tsx` + component test
- **Milestone**: M4
- **Requirements**: R5, R8
- **Decisions**: D3
- **Scope**: Author `flow-monitor/src/components/CommandPalette.tsx` — overlay modal per designer's Screen 3. Props: `{ open: boolean, onClose: () => void, focusedSession?: SessionState }`. Renders three groups (Control Actions, Specflow Commands, Destructive Commands) BUT per AC5.b the Destructive group is empty in B2 (the component imports `SAFE ∪ WRITE` from `src/generated/command_taxonomy.ts` and iterates; DESTROY is NOT imported). Keyboard: arrow up/down to navigate, Enter to select, Esc to close. WRITE pill shown on WRITE commands. No shell invocation in this component — calls `invokeStore.dispatch(cmd, slug, …)` on select.
  - Component test: mount with fixture focused session; assert 4 safe + 7 write commands render (total 11, per AC5.b); assert no DESTROY command name in the DOM; Esc calls onClose.
- **Deliverables**: `flow-monitor/src/components/CommandPalette.tsx` + `__tests__/CommandPalette.test.tsx`.
- **Verify**: `cd flow-monitor && npm test -- CommandPalette` exits 0.
- **Depends on**: T109 (needs generated TS projection), T110 (invokeStore).
- **Parallel-safe-with**: T100, T102, T103, T104, T105
- [x]

## T102 — [x] `SendPanel.tsx` + component test
- **Milestone**: M4
- **Requirements**: R3
- **Decisions**: D6
- **Scope**: Author `flow-monitor/src/components/SendPanel.tsx` — 3-tab strip per designer's Screen 2. Tabs: `pipe` (disabled with tooltip `"Deferred to future release"` — English fixed, no i18n key per designer note 11 on tooltip brevity), `terminal-spawn` (default selected — AC3.b), `clipboard`. Body: textarea + Send button. On Send with `terminal-spawn` tab → `invokeStore.dispatch(…, delivery: 'terminal')`; with `clipboard` tab → `invokeStore.dispatch(…, delivery: 'clipboard')`; with `pipe` tab → button is disabled (tab click doesn't select it because disabled).
  - Component test: mount; assert pipe tab has `disabled` attr and the tooltip text; assert terminal-spawn tab has `aria-selected="true"` at mount; click clipboard tab → `aria-selected="true"` on clipboard; send action calls dispatch with the right Delivery enum value.
- **Deliverables**: `flow-monitor/src/components/SendPanel.tsx` + `__tests__/SendPanel.test.tsx`.
- **Verify**: `cd flow-monitor && npm test -- SendPanel` exits 0.
- **Depends on**: T110.
- **Parallel-safe-with**: T100, T101, T103, T104, T105
- [x]

## T103 — [x] `PreflightToast.tsx` + component test
- **Milestone**: M4
- **Requirements**: R5
- **Decisions**: D6
- **Scope**: Author `flow-monitor/src/components/PreflightToast.tsx` — 3s auto-dismissing toast in toolbar. Props: `{ command: string, slug: string, onDismiss: () => void }`. On mount, `setTimeout(onDismiss, 3000)`. Click-to-dismiss also supported. Body copy: formatted from i18n key `toast.preflight` with `{command}` + `{slug}` substitution. **Informational, not cancelable** — the command is already dispatched (AC5.c: "No modal").
  - Component test: mount; assert setTimeout scheduled with 3000; advance timers; assert onDismiss called. Click toast body → onDismiss called immediately.
- **Deliverables**: `flow-monitor/src/components/PreflightToast.tsx` + `__tests__/PreflightToast.test.tsx`.
- **Verify**: `cd flow-monitor && npm test -- PreflightToast` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T100, T101, T102, T104, T105
- [x]

## T104 — [x] `ConfirmModal.tsx` + component test (Seam F)
- **Milestone**: M4
- **Requirements**: R8
- **Decisions**: D6
- **Scope**: Author `flow-monitor/src/components/ConfirmModal.tsx` — DESTROY confirmation modal per designer's Screen 4. Props: `{ command: string, slug: string, onCancel: () => void, onConfirm: () => void }`. Cancel button has `autoFocus`. Enter keypress does NOT trigger onConfirm (AC8.a). Uses i18n keys `modal.destroy.title`, `modal.destroy.cancel`, `modal.destroy.confirm`. **No caller imports this in B2** — T99's grep enforces this. The component is a pure scaffold for B3.
  - Component test (Seam F): mount with `{ command: 'archive', slug: 'test-session' }`. Assert `document.activeElement === cancelButton`. Press Enter → onConfirm NOT called; onCancel NOT called either (Enter is inert). Click Cancel → onCancel called. Click Confirm → onConfirm called.
- **Deliverables**: `flow-monitor/src/components/ConfirmModal.tsx` + `__tests__/ConfirmModal.test.tsx`.
- **Verify**: `cd flow-monitor && npm test -- ConfirmModal` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T100, T101, T102, T103, T105
- [x]

## T105 — [x] `AuditPanel.tsx` + component test
- **Milestone**: M4
- **Requirements**: R6
- **Decisions**: D7
- **Scope**: Author `flow-monitor/src/components/AuditPanel.tsx` — Card Detail left-rail section per designer's Screen 2. Props: `{ repo: string, limit?: number }` (default limit 50). On mount, `tauri.invoke('get_audit_tail', { repo, limit })` returns `Vec<AuditLine>`; render as a reverse-chronological list. Subscribe to Tauri `audit_appended` event and prepend new entries. Each entry shows: ISO-8601 timestamp (formatted), command name, entry-point, delivery method, outcome. Read-only — no click actions.
  - Component test: mock `tauri.invoke` to return a 3-line fixture; assert 3 entries render with correct fields. Fire a simulated `audit_appended` event; assert the new entry appears at the top.
- **Deliverables**: `flow-monitor/src/components/AuditPanel.tsx` + `__tests__/AuditPanel.test.tsx`.
- **Verify**: `cd flow-monitor && npm test -- AuditPanel` exits 0.
- **Depends on**: T109.
- **Parallel-safe-with**: T100, T101, T102, T103, T104
- [x]

### Wave 5 — Integration + i18n + B1 nits (5 + 1 tasks; 5 parallel then 1 serial)

## T106 — [x] `SessionCard.tsx` — mount ActionStrip on stalled cards (R2 gate)
- **Milestone**: M5
- **Requirements**: R2
- **Decisions**: (none)
- **Scope**: Edit `flow-monitor/src/components/SessionCard.tsx`. Add conditional render: `{session.stalled && <ActionStrip session={session} onAdvance={…} onMessage={…} />}`. AC2.b: non-stalled cards do NOT render the strip. Import `ActionStrip` from W4. Wire `onAdvance` to `invokeStore.dispatch(nextStage(session.stage), session.slug, session.repo, 'card-action', 'terminal')`. Wire `onMessage` to navigate to Card Detail view. No new i18n key introduced here (ActionStrip owns its i18n).
- **Deliverables**: modified `flow-monitor/src/components/SessionCard.tsx`.
- **Verify**: `cd flow-monitor && npm test -- SessionCard` exits 0 (existing B1 test plus any B2 adjustments). Manual: `session.stalled = false` case renders no ActionStrip.
- **Depends on**: T100, T110.
- **Parallel-safe-with**: T107, T111, T112a, T112b
- [x]

## T107 — [x] `CardDetailHeader.tsx` — Advance + Message buttons + SendPanel toggle
- **Milestone**: M5
- **Requirements**: R3
- **Decisions**: (none)
- **Scope**: Edit `flow-monitor/src/components/CardDetailHeader.tsx`. Add two new buttons to the header per designer Screen 2: "Advance" (calls `invokeStore.dispatch(nextStage(…), …, 'card-detail', 'terminal')`) and "Message / Choice" (toggles an inline `SendPanel` mount below the header). Hide both buttons when `nextStage(session.stage) === null` (AC3.a: session at `validate` pending archive — no valid next stage). Mount `SendPanel` conditionally based on a local React state `showSendPanel`.
- **Deliverables**: modified `flow-monitor/src/components/CardDetailHeader.tsx`.
- **Verify**: `cd flow-monitor && npm test -- CardDetailHeader` exits 0.
- **Depends on**: T102, T110.
- **Parallel-safe-with**: T106, T111, T112a, T112b
- [x]

## T111 — [x] `App.tsx` — mount CommandPalette + PreflightToast overlays + ⌘K keybinding
- **Milestone**: M5
- **Requirements**: R5
- **Decisions**: D6
- **Scope**: Edit `flow-monitor/src/App.tsx`. Add top-level mounts for `<CommandPalette>` (controlled by local state `paletteOpen`) and `<PreflightToast>` (controlled by `invokeStore`'s toast-visibility signal). Register a keydown listener at document level: if `(event.metaKey || event.ctrlKey) && event.key === 'k'`, set `paletteOpen` true. Esc closes both overlays. Subscribe to Tauri events `in_flight_changed` and `audit_appended` at App level (broadcast to child stores).
- **Deliverables**: modified `flow-monitor/src/App.tsx`.
- **Verify**: `cd flow-monitor && npm test -- App.test` exits 0. Structural: grep for `'k'` and `metaKey` in App.tsx.
- **Depends on**: T101, T103, T110.
- **Parallel-safe-with**: T106, T107, T112a, T112b
- [x]

## T112a — [x] `flow-monitor/src/i18n/en.json` — add 26 B2 keys
- **Milestone**: M5
- **Requirements**: R10
- **Decisions**: D9
- **Scope**: Append the 26 new B2 i18n keys to `flow-monitor/src/i18n/en.json`. Exact list per tech D9 — reproduced verbatim in this task briefing:
  - `action.advance_to.design`, `.prd`, `.tech`, `.plan`, `.tasks`, `.implement`, `.validate`, `.archive` (8 keys)
  - `action.message`, `action.send_panel.title` (2 keys)
  - `audit.panel.title`, `audit.entry.via` (2 keys)
  - `stalled.badge` (1 key, contains `{duration}` placeholder)
  - `palette.group.control`, `palette.group.specflow`, `palette.group.destroy` (3 keys)
  - `modal.destroy.title`, `modal.destroy.cancel`, `modal.destroy.confirm` (3 keys)
  - `pill.write`, `pill.destroy` (2 keys, values both stay English WRITE/DESTROY per designer note 11)
  - `toast.in_flight`, `toast.terminal_failed`, `toast.preflight` (3 keys; `toast.preflight` contains `{command}` + `{slug}` placeholders)
  - `notification.stalled.title`, `notification.stalled.body` (2 keys; body contains `{slug}` + `{duration}` placeholders)
  - Total: 8+2+2+1+3+3+2+3+2 = 26 keys. All values verbatim from tech D9 English column.
  - Preserve existing B1 key order; append new keys at the end of their logical section per convention.
- **Deliverables**: modified `flow-monitor/src/i18n/en.json`.
- **Verify**: T116 (Seam J / W6) + T118 (Seam L / W6) assert parity and stage-label presence.
- **Depends on**: —
- **Parallel-safe-with**: T106, T107, T111, T112b
- [x]

## T112b — [x] `flow-monitor/src/i18n/zh-TW.json` — add 26 B2 keys
- **Milestone**: M5
- **Requirements**: R10
- **Decisions**: D9
- **Scope**: Same 26 keys as T112a, with values from tech D9 zh-TW column (except `pill.write` / `pill.destroy` which stay English). Symmetry with en.json is enforced by T116 (Seam J).
- **Deliverables**: modified `flow-monitor/src/i18n/zh-TW.json`.
- **Verify**: T116 / T118 (W6).
- **Depends on**: —
- **Parallel-safe-with**: T106, T107, T111, T112a
- [x]

## T114 — [x] B1 nits sweep (R12 absorb)
- **Milestone**: M5
- **Requirements**: R12
- **Decisions**: (none)
- **Scope**: Re-read B1's archived `RETROSPECTIVE.md` at `.spec-workflow/archive/20260419-flow-monitor/RETROSPECTIVE.md` to extract the exact NITS list. Address each of the 5 items in one commit:
  1. **`ipc.rs` line-length violations** — fix any lines over the project's line-length convention in `flow-monitor/src-tauri/src/ipc.rs` (wrap argument lists, break long strings).
  2. **WHAT-comments in noted files** — remove comments that restate the code (per `.claude/rules/reviewer/style.md` rule 3); files named in the B1 retrospective.
  3. **Unused `navigatedPaths` state** — grep `flow-monitor/src/` for `navigatedPaths`; remove the state declaration and any dead handlers. If any consumer exists (retrospectively added in B2), document the keep-with-justification inline.
  4. **Dead `markdown.footer` i18n key** — remove from both `en.json` and `zh-TW.json` (must not conflict with T112a/b — coordinate by editing the separate region of the file).
  5. **6 non-BEM classes** — rename in `flow-monitor/src/styles/` to BEM convention, or document each as `keep-with-justification` in the same file's comment.
  - **Sequencing**: T114 runs serial AFTER T106, T107, T111, T112a, T112b merge (per risk RH). Developer re-reads each file at task start against the W5a-merged tree.
- **Deliverables**: modified `flow-monitor/src-tauri/src/ipc.rs`, `flow-monitor/src/App.tsx` (if navigatedPaths lived there), `flow-monitor/src/i18n/en.json`, `flow-monitor/src/i18n/zh-TW.json`, and any CSS files containing the 6 non-BEM classes (paths discovered at task start).
- **Verify**: T119 (Seam M / W6) asserts each of the 5 nits is cleared.
- **Depends on**: T106, T107, T111, T112a, T112b (serial after all of W5a).
- **Parallel-safe-with**: — (W5b — runs alone, serial after W5a merge)
- [x]

### Wave 6 — Structural tests + runtime handoff + docs bookkeeping (9 tasks)

## T113 — [x] Runtime handoff pre-commit note
- **Milestone**: M6
- **Requirements**: PRD §6, §9 handoff clause
- **Decisions**: D11
- **Scope**: TPM-owned task (no code). Write a one-line instruction into `.spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md` under `## Notes` that names the exact STATUS Notes line the successor feature must emit on its first `/specflow:request` / `/specflow:next` invocation. Exact string to commit:
  - `RUNTIME HANDOFF (for successor feature): opening STATUS Notes line must read "YYYY-MM-DD orchestrator — B2 control plane exercised on this feature's first live session". 15 runtime ACs deferred; list at .spec-workflow/archive/20260420-flow-monitor-control-plane/03-prd.md §9.`
  - Also add a checklist item to B2's eventual RETROSPECTIVE section in STATUS.md reminding the archiving TPM to carry the successor-feature handoff forward per `shared/dogfood-paradox-third-occurrence`.
- **Deliverables**: modified `.spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md` (Notes section only; stage checklist untouched).
- **Verify**: T121 (W6) grep-asserts the handoff line is present in STATUS.md. `grep -q 'RUNTIME HANDOFF' .spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T115, T116, T117, T118, T119, T120, T121
- [x]

## T115 — [x] Seam I: `test/t95_argv_no_shell_cat.sh` — no-shell-string-cat structural grep
- **Milestone**: M6
- **Requirements**: R4
- **Decisions**: D6
- **Scope**: Author `test/t95_argv_no_shell_cat.sh`. Assertions:
  - `grep -rE 'Command::new\("sh"|Command::new\("/bin/sh"|exec\("sh ' flow-monitor/src-tauri/src/` returns 0 matches (fail-loud on any hit).
  - `grep -rE '\.arg\("-c"\)' flow-monitor/src-tauri/src/` returns 0 matches.
  - Bash 3.2 portability; no GNU-only flags.
  - Sandbox-HOME NOT required (pure grep).
- **Deliverables**: `test/t95_argv_no_shell_cat.sh` (exec bit).
- **Verify**: `bash test/t95_argv_no_shell_cat.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T113, T116, T117, T118, T119, T120, T121
- [x]

## T116 — [x] Seam J: `test/t96_i18n_parity_b2_keys.sh` — en + zh-TW parity for 26 new keys
- **Milestone**: M6
- **Requirements**: R10
- **Decisions**: D9
- **Scope**: Author `test/t96_i18n_parity_b2_keys.sh`. Load both `flow-monitor/src/i18n/en.json` and `flow-monitor/src/i18n/zh-TW.json` via `python3 -c 'import json, sys; …'`. For each of the 26 B2 keys enumerated in T112a/b, assert:
  - Key is present in BOTH files.
  - Value is non-empty string in BOTH files.
  - Keys containing `{placeholder}` syntax have the same set of placeholders in both locales (e.g. `toast.preflight` must have `{command}` and `{slug}` in both).
  - `pill.write` and `pill.destroy` have the same value in both files (both "WRITE" / "DESTROY" per designer note 11).
- **Deliverables**: `test/t96_i18n_parity_b2_keys.sh` (exec bit).
- **Verify**: `bash test/t96_i18n_parity_b2_keys.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T113, T115, T117, T118, T119, T120, T121
- [x]

## T117 — [x] Seam K: `test/t97_theme_token_reuse.sh` — no new theme tokens
- **Milestone**: M6
- **Requirements**: R11
- **Decisions**: D10
- **Scope**: Author `test/t97_theme_token_reuse.sh`. Compare B2's CSS to B1 archive baseline:
  - `grep -rE '^\s*--(color|space|font|radius)-' flow-monitor/src/styles/` captures all currently-declared tokens.
  - Compare to the B1 archived baseline at `.spec-workflow/archive/20260419-flow-monitor/` (if preserved; otherwise to the current B1 archive CSS snapshot inline in this test file). Assert: the set of currently-declared tokens is a SUBSET of (or equal to) the B1 baseline.
  - Any net-new token is a fail with a diagnostic showing which file and which line.
  - Bash 3.2 portability.
- **Deliverables**: `test/t97_theme_token_reuse.sh` (exec bit).
- **Verify**: `bash test/t97_theme_token_reuse.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T113, T115, T116, T118, T119, T120, T121
- [x]

## T118 — [x] Seam L: `test/t98_stage_label_lookup.sh` — every stage has `action.advance_to.<stage>` i18n key
- **Milestone**: M6
- **Requirements**: R2
- **Decisions**: D9
- **Scope**: Author `test/t98_stage_label_lookup.sh`. Enumerate every stage that appears in the flow-monitor stage enum (`design`, `prd`, `tech`, `plan`, `tasks`, `implement`, `validate`, `archive` — 8 stages per tech D9). For each stage, assert:
  - `action.advance_to.<stage>` key present in `flow-monitor/src/i18n/en.json` with non-empty value.
  - Same key present in `flow-monitor/src/i18n/zh-TW.json` with non-empty value.
  - No component hardcodes the display string: `grep -rE '"Advance to (Design|PRD|Tech|Plan|Tasks|Implement|Validate|Archive)"' flow-monitor/src/components/` returns 0 matches. (AC2.c: table-driven.)
- **Deliverables**: `test/t98_stage_label_lookup.sh` (exec bit).
- **Verify**: `bash test/t98_stage_label_lookup.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T113, T115, T116, T117, T119, T120, T121
- [x]

## T119 — [x] Seam M: `test/t99_b1_nits_cleared.sh` — 5 B1-nits assertions
- **Milestone**: M6
- **Requirements**: R12
- **Decisions**: (none)
- **Scope**: Author `test/t99_b1_nits_cleared.sh`. Five assertions matching B1 archive retrospective:
  1. `flow-monitor/src-tauri/src/ipc.rs` — assert no line exceeds the project line-length limit. Use `awk 'length>120' flow-monitor/src-tauri/src/ipc.rs | wc -l` equals 0 (adjust limit to match B1's convention — Developer confirms at task start by reading `.rustfmt.toml` or equivalent).
  2. No WHAT-comments: grep for comment patterns like `// increment counter` or `// set variable X` in the 3 files named in B1 archive retrospective (Developer reads the exact file list at task start). Heuristic is imperfect; the test tolerates false positives as long as the 3 files named in B1 retrospective are clean.
  3. `grep -r 'navigatedPaths' flow-monitor/src/` returns 0 matches (unused state removed).
  4. `grep -E '"markdown\.footer"' flow-monitor/src/i18n/en.json flow-monitor/src/i18n/zh-TW.json` returns 0 matches (dead key removed).
  5. For the 6 non-BEM classes named in B1 retrospective (exact list at task start): assert each either: (a) no longer appears in any CSS selector, OR (b) has a `/* keep-with-justification: <reason> */` comment within 3 lines.
- **Deliverables**: `test/t99_b1_nits_cleared.sh` (exec bit).
- **Verify**: `bash test/t99_b1_nits_cleared.sh` exits 0.
- **Depends on**: T114 (nits sweep must land first — but test authoring can be parallel; the verify step checks T114's committed state).
- **Parallel-safe-with**: T113, T115, T116, T117, T118, T120, T121
- [x]

## T120 — [x] Seam B full: `test/t100_taxonomy_classification.sh` — 16-command taxonomy + DESTROY-only-in-taxonomy grep
- **Milestone**: M6
- **Requirements**: R5, R8
- **Decisions**: D3
- **Scope**: Author `test/t100_taxonomy_classification.sh`. Three assertions:
  1. Parse `flow-monitor/src-tauri/src/command_taxonomy.rs` for the three const arrays; assert SAFE has exactly 4 entries (`request`, `brainstorm`, `gap-check`, `verify`); WRITE has exactly 7 entries (`design`, `prd`, `tech`, `plan`, `tasks`, `implement`, `next`); DESTROY has exactly 5 entries (`archive`, `update-prd`, `update-plan`, `update-tech`, `update-tasks`). Total 16.
  2. Parse `flow-monitor/src/generated/command_taxonomy.ts` for the three `export const` arrays; assert the contents match the Rust source exactly (byte-equal after whitespace normalisation).
  3. `grep -rwE '(archive|update-prd|update-plan|update-tech|update-tasks)' flow-monitor/` returns matches ONLY from: `flow-monitor/src-tauri/src/command_taxonomy.rs`, `flow-monitor/src/generated/command_taxonomy.ts`, `flow-monitor/src-tauri/src/audit.rs` (Outcome enum may mention DestroyConfirmed — OK), inline Rust tests, and this test file itself. Any match in `src/components/`, `src/App.tsx`, `src/stores/invokeStore.ts`, or similar UI surfaces is a failure.
- **Deliverables**: `test/t100_taxonomy_classification.sh` (exec bit).
- **Verify**: `bash test/t100_taxonomy_classification.sh` exits 0.
- **Depends on**: —
- **Parallel-safe-with**: T113, T115, T116, T117, T118, T119, T121
- [x]

## T121 — [x] `test/t101_runtime_handoff_note.sh` — verify T113's STATUS note
- **Milestone**: M6
- **Requirements**: PRD §6
- **Decisions**: D11
- **Scope**: Author `test/t101_runtime_handoff_note.sh`. Assertions:
  - `grep -q 'RUNTIME HANDOFF' .spec-workflow/features/20260420-flow-monitor-control-plane/STATUS.md` exits 0.
  - The grepped line mentions `B2 control plane exercised on this feature's first live session` (or substring match).
  - The grepped line references the PRD §9 location.
- **Deliverables**: `test/t101_runtime_handoff_note.sh` (exec bit).
- **Verify**: `bash test/t101_runtime_handoff_note.sh` exits 0.
- **Depends on**: T113.
- **Parallel-safe-with**: T113, T115, T116, T117, T118, T119, T120
- [x]

## T122 — [x] Register 7 new shell tests in `test/smoke.sh`
- **Milestone**: M6
- **Requirements**: (all B2 structural ACs)
- **Decisions**: (none)
- **Scope**: Append 7 registration lines to `test/smoke.sh` for the new B2 tests: `t91_capability_manifest.sh`, `t92_audit_gitignore.sh`, `t93_audit_path_traversal.sh`, `t94_destroy_unreachable_grep.sh`, `t95_argv_no_shell_cat.sh`, `t96_i18n_parity_b2_keys.sh`, `t97_theme_token_reuse.sh`, `t98_stage_label_lookup.sh`, `t99_b1_nits_cleared.sh`, `t100_taxonomy_classification.sh`, `t101_runtime_handoff_note.sh`. That's 11 registrations total (not 7 — T92/T93/T94 also need registering; I under-counted at wave-plan step — the final figure is 11 registrations). The append format matches existing `test/smoke.sh` convention (Developer reads the last 10 lines of `smoke.sh` at task start and mirrors the shape). Per `tpm/parallel-safe-append-sections.md`, this is append-only; keep-both mechanical merge accepted if any concurrent edit lands.
  - **Sequencing**: T122 runs serial AFTER T115–T121 and T113 merge. The 11 test file paths it references must exist and be executable.
- **Deliverables**: modified `test/smoke.sh` (append only).
- **Verify**: `bash test/smoke.sh` runs all 11 new registrations and each exits 0 against the post-W5-merge tree.
- **Depends on**: T113, T115, T116, T117, T118, T119, T120, T121, and the T94 shell tests (t92/t93), the T99 grep test (t94), and the T92-cap-test manifest test (t91).
- **Parallel-safe-with**: — (W6b — serial after W6a)
- [x]

---

## 4. STATUS Notes discipline

Per `shared/status-notes-rule-requires-enforcement-not-just-documentation` and B1's archive retrospective, this plan mandates:

- **Only the orchestrator writes STATUS Notes** during implement. Developer subagents MUST NOT append a STATUS Notes line in their per-task commits — the orchestrator creates one bookkeeping commit per wave per `tpm/wave-bookkeeping-commit-per-wave.md` that flips `[x]` checkboxes AND appends STATUS Notes lines.
- **Reviewer (style axis) on every wave** verifies no task's commit adds a STATUS Notes line. If found, flag as `must` style finding citing this plan §4. This is the enforcement mechanism the memory calls for (documentation alone has failed across ≥3 features).
- **Checkbox discipline**: each task's `- [ ]` / `- [x]` flip happens in the orchestrator's post-wave bookkeeping commit, never inside a Developer's task commit. Per `tpm/checkbox-lost-in-parallel-merge`, the orchestrator audits every `05-plan.md` post-merge and re-flips any checkbox silently dropped during parallel-merge conflict resolution.
- **Archive-time retrospective**: at archive, TPM runs the retrospective per `.claude/team-memory/README.md`. The candidate entries probed at archive time:
  - `shared/tauri-capability-static-plus-runtime-boundary` (tech-proposed) — the two-layer pattern of narrow static manifest + runtime path-boundary check used in T91 + T94. If a third feature needs this pattern, it's promotable.
  - `tpm/b2-to-b3-runtime-handoff-for-destroy-scaffold` — the explicit runtime-handoff discipline for scaffold-only features where the caller lands in the next feature. Similar to B1→B2 split but now with scaffold-only deferral rather than delivery-method deferral.
  - `pm/terminal-spawn-as-v1-default-for-command-invocation` (PRD-proposed) — why spawn-terminal was chosen over pipe/clipboard.

---

## 5. Stop/escalate gates

This plan is complete. No escalation is required at plan-stage. Implement stage proceeds with wave W0.

If a gap surfaces during any wave:
- Developer halts and reports to orchestrator with the specific cited line.
- Orchestrator invokes `/specflow:update-plan` with a focused delta.
- TPM re-issues the affected task(s); downstream artefacts tagged stale if needed.
- PRD ambiguity → punt to PM (`/specflow:update-prd`).
- Architect-level decision needed → punt to Architect (`/specflow:update-tech`).

---

## Team memory

- Applied **tpm/pre-declare-test-filenames-in-06-tasks.md** — every test-writing task names its exact `test/tNN_*.sh` filename; range t91–t101 allocated to avoid collision with tier-model's t74–t90.
- Applied **tpm/parallel-safe-requires-different-files.md** — W2's lib.rs coordination note (T108 polling-loop region vs T109 invoke_handler region) explicitly flags the same-file concern; W5a's 5-parallel / W5b T114-serial split enforces the different-files invariant.
- Applied **tpm/parallel-safe-append-sections.md** — T122 smoke.sh registration is scheduled serial in W6b; keep-both mechanical merge accepted if a concurrent edit lands.
- Applied **tpm/wave-bookkeeping-commit-per-wave.md** — §4 explicitly assigns checkbox-flip + STATUS Notes append to the orchestrator's post-wave bookkeeping commit, not Developer per-task commits.
- Applied **shared/dogfood-paradox-third-occurrence.md** (ninth occurrence) — §1.2 + §2.3 structural-vs-runtime matrix splits coverage; T113 pre-commits the runtime-handoff STATUS note to the successor feature.
- Applied **shared/status-notes-rule-requires-enforcement-not-just-documentation.md** — §4 makes STATUS Notes enforcement a reviewer-style check, not just a discipline reminder; this is the enforcement the memory calls for.
- Applied **tpm/task-scope-fence-literal-placeholder-hazard.md** — all `tNN_*.sh` filenames in this plan are concrete numbers (91–101), no `tN_` or `<fill>` placeholders anywhere.

**Proposed memory entry (archive-time candidate)**: `tpm/b1-b2-scaffold-to-caller-split-pattern` — the B2 pattern of shipping a DESTROY-scaffold without callers (ConfirmModal + classification map) and deferring the first caller to B3. Distinct from B1-B2 delivery-method split; captures the "structural-only feature that readies the next feature's work" shape.
