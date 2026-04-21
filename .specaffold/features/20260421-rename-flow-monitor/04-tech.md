# 04-tech — rename-flow-monitor

**Feature**: `20260421-rename-flow-monitor`
**Stage**: tech
**Author**: Architect
**Date**: 2026-04-21
**Tier**: audited
**has-ui**: true

---

## 1. Context & Constraints

### Existing stack (committed; do not reopen)

- Rust backend: **Tauri v2** app (`flow-monitor/src-tauri/`) — `cargo test`
  gates correctness; integration tests under `tests/` already exercise
  feature-discovery, audit-log, IPC, and Seam-4 (no-write) invariants.
- Frontend: **React + TypeScript + vitest** (`flow-monitor/src/`). i18n via
  `react-i18next` with JSON bundles `en.json` and `zh-TW.json`.
- Capability model: **Tauri capabilities** JSON (`capabilities/default.json`)
  — filesystem and shell allow-list; security boundary per PRD §6.
- Compat bridge: `bin/scaff-seed::ensure_compat_symlink` creates
  `.spec-workflow → .specaffold` in every seeded repo (predecessor feature
  `20260421-rename-to-specaffold`, archived commit `68d673b`). Flow-monitor
  works today by traversing this symlink; PRD D2 binds: flow-monitor reads
  `.specaffold/` directly post-rename, **no dual-path fallback**.

### Hard constraints

- **Zero new abstractions.** Rename-only feature; no refactor. PRD §1 "no
  behavioural change, no new surfaces, no refactors". Architect rule: "every
  new tech choice is a maintenance burden" — the baseline stack covers the
  rename exhaustively.
- **Bash 3.2 portability** — no new shell scripts are required. If the plan
  adds a test harness wrapper it must follow
  `.claude/rules/bash/bash-32-portability.md`. Not restated here.
- **Merge-order**: PRD D6 — Rust backend scanner (R1) lands at or before
  frontend path-check rename (R6), else every repo fails `path_exists`
  during the partial-merge window. Drives §4 wave layout.
- **Least-privilege preservation**: Tauri capability path-prefix swap (R3)
  is a clean exchange — old paths removed, new paths added in the same
  commit. No widening, no dual-grant transition window. Drives AC12.

### Soft preferences

- Inline string replacements over a new shared constant. The audit-log
  path literal appears ~8 times inside `audit.rs` but always as the same
  segment pair `.spec-workflow` + `.flow-monitor`; introducing a
  `const SPECAFFOLD_DIR: &str = ".specaffold"` module-level constant buys
  little because the existing `flow_monitor_dir(repo)` helper (line 143)
  already centralises the `PathBuf` construction. See D2 below.
- Test fixture files (5 STATUS templates) are updated by mechanical
  find-replace — no fixture generator is introduced.

### Forward constraints

- Predecessor feature's grep-zero invariant (AC1 of
  `20260421-rename-to-specaffold`) continues to hold product-wide after
  this feature merges. New allow-list entries must be justified and
  minimal (R11).
- Future features touching `.specaffold/` filesystem paths in the Tauri
  app inherit the constant-or-inline discipline chosen here (D2).

---

## 2. System Architecture

This is a *locally-scoped mechanical rename*. The system is unchanged;
the component-to-subsystem mapping below shows **which subsystems hold
strings that must change** and **which boundary constraints govern the
merge order**.

```
 flow-monitor/                                 rename impact
 ├── src-tauri/                               [RUST BACKEND]
 │   ├── src/
 │   │   ├── audit.rs          ──┐
 │   │   ├── poller.rs           │  path literals .spec-workflow/features
 │   │   ├── repo_discovery.rs   ├─ .spec-workflow/.flow-monitor  (R1)
 │   │   ├── ipc.rs              │  doc comments, error strings
 │   │   ├── invoke.rs           │  + shell-script body "specflow <cmd>" → "scaff <cmd>" (R2)
 │   │   ├── command_taxonomy.rs │
 │   │   └── store.rs          ──┘
 │   │
 │   ├── tests/**              ── path literals, fixture content,
 │   │                              SPEC_WORKFLOW_MARKER, seam4 fn name (R4)
 │   │
 │   └── capabilities/
 │       └── default.json      ── 2 allow-list entries swap    (R3)   ★ security boundary
 │
 ├── src/                                     [REACT FRONTEND]
 │   ├── components/*.tsx      ── doc comments + path literal  (R5, R6)
 │   ├── views/CardDetail.tsx  ── featurePath string           (R5)
 │   ├── i18n/en.json          ── 3 keys, 1 key rename         (R7, R8, R9)
 │   ├── i18n/zh-TW.json       ── 3 keys, 1 key rename         (R7, R8, R9)
 │   └── **/__tests__/*.tsx    ── snapshot/mock strings        (R5)
 │
 └── README.md                 ── prose + path prefixes + 1 new upgrade-notes line (R10)
```

### Key scenario sequence (S1 launches into freshly-seeded `.specaffold/` repo)

```
 launch → ipc::discover_repos()
   → repo_discovery::scan(<repo>)
       reads <repo>/.specaffold/features/*    (was .spec-workflow/features/*)
   → frontend receives sessions[]
   → user clicks card → CardDetail renders
       featurePath = `${repoFullPath}/.specaffold/features/${slug}`
   → palette invoke → invoke::build_script_content()
       emits  scaff '<cmd>'                    (was specflow)
   → audit::append()
       writes <repo>/.specaffold/.flow-monitor/audit.log
       canonicalise-and-check prefix = `<repo>/.specaffold/.flow-monitor/`
       capability allow-list gates the write: $REPOS/.specaffold/.flow-monitor/audit.log{,1}
```

Every arrow's string literal is accounted for by the five decisions below.

---

## 3. Technology Decisions

### D1. Shell-script body in `invoke.rs` renames `specflow` → `scaff`

- **Options considered**:
  - (A) Change the literal in `build_script_content()` (one line: `invoke.rs:304`).
  - (B) Introduce a `const SCAFF_BIN: &str = "scaff"` module-level constant.
  - (C) Read the binary name from a config file at runtime.
- **Chosen**: **(A) inline literal change.**
- **Why**: The binary name appears once in production code (`invoke.rs:304`)
  plus snapshot-test assertions in `invoke.rs` tests. A module constant for a
  single call-site is over-engineered; runtime configurability is out of scope
  (no PRD requirement). Correctness requirement per PRD D1 — the `specflow`
  binary does not exist on post-rename systems.
- **Tradeoffs accepted**: If a future feature adds a second `scaff` invocation
  site, it will either inline again or introduce the constant then. Neither
  outcome is harmed by this decision.
- **Reversibility**: High — single-line revert.
- **Requirement link**: R2 (correctness), R4 (test renames paired —
  `SPEC_WORKFLOW_MARKER` → `SPECAFFOLD_MARKER`, test function name).

### D2. Rust path literal strategy: inline replace, no shared constant

- **Options considered**:
  - (A) Inline replacement of every `.spec-workflow` / `spec-workflow` literal
    per the PRD grep inventory. Keep `audit::flow_monitor_dir(repo)`
    helper as-is; change its body to `repo.join(".specaffold").join(".flow-monitor")`.
  - (B) Extract a new `const SPECAFFOLD_DIR: &str = ".specaffold"` plus
    `const FLOW_MONITOR_DIR: &str = ".flow-monitor"` at a new
    `src-tauri/src/paths.rs` module; rewrite every call site to use it.
  - (C) Accept a `PathRoot` enum parameter on every module function (invasive
    refactor for future dual-root support).
- **Chosen**: **(A) inline replace.** The existing `flow_monitor_dir(repo)`
  helper is already the single construction site for the `PathBuf`; doc
  comments and error strings are the remaining scattered literals and they
  should read naturally as prose, not as `{DIR}/.flow-monitor`-style format
  substitutions.
- **Why**: Rename-only feature. PRD §3 explicitly lists refactors as
  non-goals. (B) would add a new module and rewrite every call site — a
  taxonomy change under the cover of a rename; violates
  `architect/scope-extension-minimal-diff` memory. (C) is out of scope
  (PRD D2 — no dual-path support).
- **Tradeoffs accepted**: ~14 inline edits in `audit.rs` alone (doc
  comments, `ensure_gitignore` target line, `ensure_flow_monitor_dir_exists`
  doc comment, `append` doc comment, 2 test helper sites, 3 test
  assertion lines). All are mechanical find/replace; the `flow_monitor_dir`
  helper holds the one-line semantic change at line 144.
- **Reversibility**: High — a new `paths.rs` module can still be
  introduced in a future feature if a second on-disk root emerges.
- **Requirement link**: R1, R4.

### D3. Tauri capability allow-list: outright path-prefix swap

- **Options considered**:
  - (A) Swap the two entries in `capabilities/default.json`:
    `$REPOS/.spec-workflow/.flow-monitor/audit.log{,1}` →
    `$REPOS/.specaffold/.flow-monitor/audit.log{,1}`.
  - (B) Dual-grant (old + new) during a transition window, remove legacy in a
    follow-up feature.
- **Chosen**: **(A) outright swap.** Per PRD D3.
- **Why**: Dual-grant widens the capability surface for no continuing
  benefit — the compat symlink already unifies the resolved path at the OS
  layer, so a single new entry suffices. Least-privilege is *preserved*,
  not *degraded*, across the diff. The security-axis reviewer (`must`-scope)
  applies; architect-gate per `tier=audited`.
- **Tradeoffs accepted**: A repo that still has `.spec-workflow/` as the
  real directory (pre-rename, no compat symlink, no re-seed) is no longer
  writable by the app. This is the intentional cutover per PRD §6; README
  upgrade-notes line (R10) documents it; migration path is
  `bin/scaff-seed update`.
- **Reversibility**: High — capability JSON edit is two lines.
- **Requirement link**: R3. **Gates AC12 (architect sign-off below §6.)**

### D4. React frontend strategy: inline replace; i18n key rename per D5

- **Options considered**:
  - (A) Inline per the string delta for TSX files; apply i18n key rename
    `palette.group.specflow` → `palette.group.scaff` at every call site
    found by grep.
  - (B) Shared `const SPECAFFOLD_DIR_NAME = ".specaffold"` in a TS utility
    module; replace literals with interpolation.
- **Chosen**: **(A) inline replace.**
- **Why**: Only two TSX files hold path literals
  (`views/CardDetail.tsx` lines 119–120, `components/SettingsRepositories.tsx`
  line 33). Matches D2's discipline on the Rust side. Same
  minimal-diff logic from
  `architect/scope-extension-minimal-diff`.
- **Tradeoffs accepted**: Frontend path literal stays a string rather than a
  named constant. Acceptable at current call-site count of 3.
- **Reversibility**: High.
- **Requirement link**: R5, R6, R7.

### D5. i18n: rename the key `palette.group.specflow` → `palette.group.scaff`

- **Options considered**:
  - (A) Rename the key; update every `t("palette.group.specflow")` call site
    (PRD D5 / design Q1 → A).
  - (B) Keep the key, change only the display value.
- **Chosen**: **(A) rename.** Per PRD D5 (user-confirmed 2026-04-21).
- **Why**: Clean long-term state. Option B would leak the legacy token into
  every future scan of the codebase; PRD AC2 (`grep -rn "palette.group.specflow"
  flow-monitor/src/` returns zero) makes this choice structural, not
  cosmetic.
- **Tradeoffs accepted**: Must find and rename every call site. The PRD
  identifies consumers in `CommandPalette.tsx` + `CommandPalette.test.tsx`;
  grep will enumerate any others.
- **Reversibility**: High.
- **Requirement link**: R7, R8, R9, AC2, AC6.

### D6. Pre-rename audit logs: lazy migration, no one-shot script

- **Options considered**:
  - (A) Leave legacy `.spec-workflow/.flow-monitor/audit.log` on disk
    untouched; new path starts fresh on first write. README documents.
  - (B) One-time copy-or-rename migration on first app launch.
- **Chosen**: **(A) lazy migration.** Per PRD D4; aligns with
  `shared/lazy-migration-at-first-write-beats-oneshot-script`.
- **Why**: A migration script introduces the "please run" step users skip;
  the compat symlink already unifies the resolved path for any re-seeded
  repo, so the old-file race window is nil.
- **Tradeoffs accepted**: Users with pre-rename logs and a continued
  interest in inspecting them must read `.spec-workflow/.flow-monitor/`
  on disk themselves; the UI will not surface those entries.
- **Reversibility**: High (no code written here; the "lazy" side effect is
  simply that the old file is ignored).
- **Requirement link**: R10 (README upgrade-notes line is the user-facing
  acknowledgement).

---

## 4. Cross-cutting Concerns

### 4.1 Merge-order constraint (drives wave layout)

PRD D6 / §6 edge case: **Rust backend scanner rename (R1) lands at or before
the frontend path-check rename (R6).** TPM has two valid layouts:

- **Single wave (recommended).** All file edits in one wave; all tests in
  one `cargo test` + `vitest` pass. The atomic-swap shape is simpler to
  review and rollback.
- **Two strictly ordered waves.** Wave 1 = Rust backend + tests + capability.
  Wave 2 = React frontend + i18n + README. The predecessor feature shipped
  four waves; for this rename-only feature the coupling is low enough that a
  single wave is safe. TPM decides.

Either layout respects the constraint. A *three-wave split* that puts
frontend before backend is forbidden.

### 4.2 Error handling

No change. Every existing `Result<_, AuditError>` / `PathTraversalError`
flow continues to work because the allowed-prefix guard inside
`canonicalise_and_check_under` now accepts the new prefix and rejects
anything else — same semantics, different string.

### 4.3 Testing strategy (feeds Developer / QA plan)

Structural gates (fast, cheap, run by QA-analyst at gap-check):

1. `grep -rnE "spec-workflow|specflow" flow-monitor/` — AC1. Expect every
   hit to fall into the allow-list extensions enumerated in §6 below.
2. `grep -rn "palette.group.specflow" flow-monitor/src/` — AC2. Must
   return zero.
3. `cargo test` inside `flow-monitor/src-tauri/` — AC5. Expect all tests
   green, including the renamed Seam-4 test
   `seam4_no_write_call_references_specaffold_path` (was
   `..._spec_workflow_path`).
4. `vitest` inside `flow-monitor/` — AC7. Snapshot tests that assert on
   legacy strings are updated in the same commit as the source rename.
5. JSON-parse check on both i18n files + key-presence check for
   `palette.group.scaff`, key-absence check for `palette.group.specflow`
   — AC6.
6. JSON inspect of `capabilities/default.json` — AC3. Exactly two
   filesystem entries, both under `$REPOS/.specaffold/.flow-monitor/`.

Runtime gate (mandatory per `has-ui: true` +
`shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds`):

- **AC10 walkthrough** (see §7 below). Build `.dmg`, launch, exercise S1
  against a freshly-seeded `.specaffold/` repo, observe audit-log entry
  written to the new path, observe shell script body contains `scaff`.
- **AC11 walkthrough** (zh-TW locale). Switch locale, re-open empty-state,
  palette, and "not a scaff repository" error surfaces; assert zero
  `specflow` / `spec-workflow` leak.

### 4.4 Security posture (architect gate — AC12)

Tier is `audited` because the Tauri capability allow-list
(`capabilities/default.json`) is the filesystem-access boundary that gates
webview writes. This feature modifies that boundary.

**Architect sign-off (AC12):**

- **Shape of the change**: two string entries swap within the same
  `fs:allow-write-file` permission block. No new permission identifiers
  are added. No new paths outside the two existing rows.
- **Least-privilege analysis**: the new prefix
  `$REPOS/.specaffold/.flow-monitor/` is a *disjoint* path namespace from
  the legacy prefix `$REPOS/.spec-workflow/.flow-monitor/`. Because the
  compat symlink (`.spec-workflow → .specaffold`) resolves both names to
  the same canonical directory at the OS layer, the *effective* writable
  surface is unchanged for any re-seeded repo. For a pre-rename repo
  (no symlink), the effective writable surface **shrinks** (the legacy
  path is no longer allow-listed). This is strictly a narrowing, not a
  widening, of the capability surface.
- **Atomic swap**: old entries removed and new entries added in the same
  commit (enforced by the task that owns `default.json`). No widen-then-
  narrow window.
- **No other capabilities touched**: `core:default`, `dialog:default`,
  `clipboard-manager:default`, `notification:default`,
  `shell:allow-execute` (validator regex on `/usr/bin/open` args) are all
  unchanged.
- **Cross-reference**: `.claude/rules/reviewer/security.md` check 6
  (secure defaults — no silent clobber; the atomic swap is one-commit,
  with a matched revert path); check 2 (path traversal — the
  `canonicalise_and_check_under` guard in `audit.rs` still rejects
  anything outside the new prefix).

**Verdict**: least-privilege preserved. Change approved at architect gate.

### 4.5 Performance / scale

Non-concern. No hot-path code changes; no loop counts change; no new
IPC shapes. Reviewer-performance axis has nothing to flag beyond the
generic "shell-out in a loop" checks that this feature does not
introduce.

### 4.6 Logging / observability

Unchanged. Audit-log format (TSV fields `timestamp, slug, command,
entry_point, delivery, outcome`) is unchanged per PRD §3. Only the
on-disk path changes.

---

## 5. Open Questions

None.

All four request-stage open questions are resolved in PRD D1–D4; all
three design-stage open questions are resolved in
`02-design/string-delta.md §6` and echoed in PRD D5–D7. The architecture
proposed here is an inline mechanical rename that respects every
decision; no genuinely unresolvable item surfaces.

---

## 6. Non-decisions (deferred)

### N1. Future `paths.rs` module extraction

Deferred. Trigger: a second on-disk canonical root emerges (e.g. a
sibling `.scaff-cache/` directory or a per-user `XDG_STATE_HOME` path).
At that point the three inline sites (`audit.rs`, `repo_discovery.rs`,
`poller.rs`) would warrant a shared constants module. Until then, inline
literal is lower-friction.

### N2. Renaming `flow-monitor/` directory itself

Out of scope per PRD §3 non-goals. Trigger: a product-identity decision
to rebrand the Tauri app to a name that does not include "flow-monitor".
No such trigger exists today.

### N3. Dual-path read support (`.specaffold/` OR `.spec-workflow/`)

Explicitly rejected per PRD D2. Trigger that would force revisit: user
reports indicating a non-trivial population of monitored repos that (a)
pre-date the rename, (b) cannot be re-seeded, (c) cannot run
`bin/scaff-seed update`. None observed.

### Carry-over allow-list additions — **zero new entries required**

`.claude/carryover-allowlist.txt` already contains:

```
flow-monitor/**
```

This glob covers the entire subtree for the predecessor feature's
`20260421-rename-to-specaffold` AC1 — it is the exact carve-out that
made this follow-up feature necessary. **After this feature merges,
that allow-list line must be removed** (else AC1 still trivially
passes and the grep-zero invariant is unprovable). R11 in the PRD is
what requires that removal.

Proposed entries to keep / add:

- **Remove** (not add): `flow-monitor/**` — the blanket carve-out. This
  is the reason we are here.
- **Add** (exactly one): `flow-monitor/README.md` — because R10 requires
  one upgrade-notes line in the README that names the legacy path
  `.spec-workflow/.flow-monitor/` explicitly. That line is
  *user-facing documentation* of the legacy behaviour, analogous to
  `docs/rename-migration.md` which is already allow-listed.

Net change: one entry swaps for a narrower entry. No other files need
allow-listing — every other legacy-name reference in this feature's
scope is slated for mechanical rename.

TPM's plan owns the actual allow-list edit; this tech doc defines the
content.

---

## 7. Verification strategy (for QA-tester — AC10 / AC11)

### Fixture setup

1. `mkdir -p /tmp/fm-scratch && cd /tmp/fm-scratch && git init`.
2. `/path/to/specaffold/bin/scaff-seed` — seeds `.specaffold/` with the
   post-rename layout; `ensure_compat_symlink` creates `.spec-workflow
   → .specaffold`. This yields a clean target for the walkthrough.
3. Seed one feature dir: `mkdir -p .specaffold/features/20260421-demo/`
   with a minimal `STATUS.md` and `03-prd.md` to give the sidebar
   something to render.

### AC10 walkthrough steps (to be recorded in `08-validate.md`)

1. `cd flow-monitor && npm run tauri build` (or `bun run tauri dev`
   for a faster loop). Launch the resulting artifact.
2. Add `/tmp/fm-scratch` as a monitored repo via Settings → Add
   repository. Confirm the check succeeds (R6: `${pickedPath}/.specaffold`
   exists).
3. Observe the sidebar populates with the `20260421-demo` card (R1:
   backend scanner reads `.specaffold/features/`).
4. Click the card. Confirm CardDetail renders and the rendered
   `featurePath` string reads
   `/tmp/fm-scratch/.specaffold/features/20260421-demo` (R5: line 119).
5. Open the command palette (⌘K or equivalent). Confirm the group
   heading reads "Scaff Commands" (R7).
6. Trigger an invoke — e.g. `scaff next` from the palette. Observe
   the generated `.command` script: its body contains `scaff 'next'`
   (R2 / D1). A Terminal.app window opens; it may error if `scaff` is
   not on PATH in the sandboxed Terminal — that is expected and does
   not invalidate the walkthrough (exec-line verification is the
   AC, not the subprocess result).
7. Inspect `/tmp/fm-scratch/.specaffold/.flow-monitor/audit.log` —
   confirm a new TSV row was appended with today's timestamp.
   (R3: capability allow-list permitted the write.)
8. Confirm no file at `/tmp/fm-scratch/.spec-workflow/.flow-monitor/`
   was written — the directory resolves via the compat symlink, so the
   canonical write landed at `.specaffold/.flow-monitor/` not
   `.spec-workflow/.flow-monitor/`.

### AC11 walkthrough (zh-TW)

9. Switch the app locale to Traditional Chinese (Settings → Language,
   or `localStorage.setItem('i18nextLng', 'zh-TW')` + reload).
10. With no repo added, confirm the empty-state body reads
    "新增含有 .specaffold/ 資料夾的倉庫，以開始監控您的 scaff 工作階段。"
    (R8).
11. Open the command palette. Confirm the group heading reads "Scaff
    指令" (R8).
12. Attempt to add a non-`.specaffold` directory as a repo. Confirm
    the error reads "不是 scaff 倉庫：缺少 .specaffold/ 資料夾。"
    (R8).
13. Confirm no `specflow` / `spec-workflow` substring appears in any
    observed UI surface.

Record steps 1–13 in `08-validate.md` under a **Runtime walkthrough**
section with observed outputs and a zero-defect statement (or defects
found). Per
`shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds`,
structural pass alone does not close validate for this feature.

---

## Team memory

Applied:

- `architect/scope-extension-minimal-diff` — drives D2 / D4 (inline literal
  replacement over new shared constants); drives N1 deferral.
- `shared/lazy-migration-at-first-write-beats-oneshot-script` — drives D6
  (no one-shot audit-log migration; new path fresh on first write; old file
  untouched).
- `shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds`
  — drives §7 (runtime walkthrough steps 1–13 for AC10 / AC11; structural
  pass alone insufficient for `has-ui: true`).
- `architect/tier-auto-upgrade-on-security-must-is-a-wave-merge-time-boundary-check`
  — frames §4.4: the audited-tier gate is enforceable at wave-merge
  verdict time on the Tauri capability diff; informs the architect
  sign-off shape.
- `architect/setup-hook-wired-commitment-must-be-explicit-plan-task` — N/A
  (no lifecycle wiring introduced), but consulted to confirm no
  `called from setup` / `wired into lifecycle` commitments are hidden in
  this tech doc that would produce dead code.

Not applicable this feature (documented so the reader sees the scan ran):

- `architect/aggregator-as-classifier` — no reducer authored here.
- `common/classify-before-mutate` — no new mutation dispatch authored; the
  audit-path classifier is unchanged.

Proposed for promotion at archive if the pattern holds:

- *Rename-continuation feature inherits and narrows the predecessor's
  allow-list* — this feature's §6 carry-over discipline (swap a broad
  `flow-monitor/**` entry for a narrow `flow-monitor/README.md` entry)
  is the mirror-image of what the predecessor's archive committed. If
  future rename continuations follow the same pattern, promote to
  shared.
