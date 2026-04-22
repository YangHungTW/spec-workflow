# PRD — rename-flow-monitor

**Feature**: `20260421-rename-flow-monitor`
**Stage**: prd
**Author**: PM
**Date**: 2026-04-21
**Tier**: audited
**has-ui**: true

## 1. Summary

The previous feature `20260421-rename-to-specaffold` (archived commit `68d673b`)
renamed the top-level repo identity (`bin/`, `.claude/`, hooks, tests, docs) to
Specaffold / `scaff` but explicitly carved `flow-monitor/` out of scope. Roughly
124 references to the legacy brand (`spec-workflow`, `specflow`, `Specflow`)
remain inside the Tauri app subtree — Rust backend path literals and doc
comments, the Tauri capability allow-list, React/TypeScript display strings,
i18n bundles (`en.json` and `zh-TW.json`), tests, and `flow-monitor/README.md`.

Flow-monitor continues to work today only because `bin/scaff-seed::ensure_compat_symlink`
creates the compat symlink `.spec-workflow → .specaffold` in every seeded repo,
so the app's hard-coded `.spec-workflow/` path resolves via that symlink. This
feature closes the rename gap product-wide: flow-monitor reads `.specaffold/`
directly, its UI / tests / docs say **Scaff** and **Specaffold**, and the Tauri
capability allow-list grants access only to the post-rename paths. This is a
**rename-only** feature: no behavioural change, no new surfaces, no refactors.

Tier is `audited` because the Tauri capability allow-list
(`src-tauri/capabilities/default.json`) is a security boundary; changing
allow-listed paths re-grants filesystem access and requires Architect review.

## 2. Goals

- Zero occurrences of `specflow` / `spec-workflow` (any case) in
  `flow-monitor/` source, tests, i18n bundles, Tauri capabilities, or docs,
  except for the allow-listed historical references enumerated in R10.
- Flow-monitor launches against a freshly-seeded `.specaffold/` repo,
  discovers features, opens cards, and writes audit-log entries to the new
  `.specaffold/.flow-monitor/` path — all with no user-visible regressions
  relative to pre-rename behaviour.
- The Tauri capability allow-list grants filesystem access only to the new
  canonical path (`$REPOS/.specaffold/.flow-monitor/audit.log*`) — no legacy
  path remains on the allow-list.
- UI strings are consistent across `en.json` and `zh-TW.json`; Designer has
  already signed off on the string delta (see `02-design/string-delta.md`).
- The shell script emitted by `src-tauri/src/invoke.rs` invokes `scaff`, not
  `specflow`.
- Pre-rename audit logs under `.spec-workflow/.flow-monitor/audit.log` remain
  readable on disk (not deleted) but are not surfaced in the new UI; users
  are notified of this in the README.

## 3. Non-goals

- No functional changes to flow-monitor behaviour: feature-discovery logic,
  card rendering, audit-log format, IPC shapes, and polling cadence are
  unchanged.
- No rename of the `flow-monitor/` directory itself. Slug strings that
  reference it (e.g. the feature slug `20260419-flow-monitor` appearing in
  README path examples) are preserved — those are date-based identifiers,
  not brand copy.
- No changes to `bin/scaff-seed::ensure_compat_symlink`. The compat symlink
  is the mechanism that keeps any *consumer* still scripting against
  `.spec-workflow/` working; its discipline belongs to the seed binary, not
  to this feature.
- No one-time migration of pre-rename audit logs. See Decision D4.
- No dual-path read support in flow-monitor
  (`read-from-either(".specaffold/", ".spec-workflow/")`). See Decision D2.
- No transition-window support in the Tauri capability allow-list (keeping
  both legacy and new paths allow-listed during a cutover). See Decision D3.
- No UX / visual identity work beyond the literal string substitutions in
  the design delta.

## 4. Users and scenarios

**Primary users**: a human developer running flow-monitor against one or more
Specaffold-seeded repos to observe in-flight `scaff` sessions.
**Secondary users**: flow-monitor contributors reading the Tauri backend
source, Rust doc comments, tests, and the README.

### 4.1 Scenarios

| # | Actor | Scenario | Outcome |
|---|---|---|---|
| S1 | Developer | Launches flow-monitor against a freshly-seeded `.specaffold/` repo | App discovers features under `.specaffold/features/`, populates sidebar, opens detail cards; audit writes land at `.specaffold/.flow-monitor/audit.log` |
| S2 | Developer (zh-TW locale) | Opens the empty-state screen and the command palette | Copy reads "新增含有 `.specaffold/` 資料夾的倉庫...開始監控您的 scaff 工作階段" and "Scaff 指令"; no `specflow` / `spec-workflow` leaks |
| S3 | Developer | Triggers an invoke from the command palette | Generated shell script executes `scaff <cmd>`, not `specflow <cmd>` |
| S4 | Developer with pre-rename logs on disk | Opens flow-monitor against a repo that still has `.spec-workflow/.flow-monitor/audit.log` from a prior release | App ignores the legacy log, starts a fresh log under `.specaffold/.flow-monitor/`; the README explains the legacy log is preserved on disk but unsurfaced |
| S5 | Contributor | Runs `cargo test` / `vitest` in `flow-monitor/` | Test names, fixture paths, and seam4 markers all reference the new brand; all tests pass |
| S6 | Reviewer | Runs the repo-wide grep assertion from `20260421-rename-to-specaffold` (AC1) | The assertion still returns zero hits outside the R10 allow-list after this feature merges |

## 5. Requirements

Each requirement is testable. "Legacy names" means the strings `specflow`,
`Specflow`, and `spec-workflow` (cases defined per the design delta §). "New
names" means `scaff`, `Scaff`, and `specaffold` / `.specaffold/` per the delta.

All string-level replacements are enumerated in
`02-design/string-delta.md`; that file is the canonical delta reference. The
requirements below group the changes by surface and impose correctness
properties that exceed pure find-replace.

### Rust backend

- **R1** — Every Rust source file under `flow-monitor/src-tauri/src/**/*.rs`
  has its path literals, doc comments (`///` and `//!`), inline comments,
  and error-message strings replaced per the design delta. The repository
  state scanner reads `.specaffold/` as its root directory — not
  `.spec-workflow/` — with no dual-path fallback.
- **R2** — The shell script generated by `flow-monitor/src-tauri/src/invoke.rs`
  invokes the `scaff` binary (e.g. `scaff implement …`), not `specflow`.
  This is a correctness requirement, not a preference: post-rename systems
  do not have a `specflow` binary on `PATH`, so the legacy form would fail
  at exec time.
- **R3** — The Tauri capability allow-list
  (`flow-monitor/src-tauri/capabilities/default.json`) grants read/write
  access to `$REPOS/.specaffold/.flow-monitor/audit.log` and
  `$REPOS/.specaffold/.flow-monitor/audit.log.1` only. The two legacy
  entries (`$REPOS/.spec-workflow/.flow-monitor/audit.log`,
  `$REPOS/.spec-workflow/.flow-monitor/audit.log.1`) are removed. No
  transition-window dual grant.

### Rust tests

- **R4** — Every file under `flow-monitor/src-tauri/tests/**` (test sources,
  fixture paths, and seam4 markers) has its path literals, test names, and
  brand strings replaced per the delta. Specifically:
  - The constant `SPEC_WORKFLOW_MARKER` (currently at line 31 of
    `tests/seam4_no_writes.rs`) is renamed to `SPECAFFOLD_MARKER`.
  - The test function `seam4_no_write_call_references_spec_workflow_path`
    is renamed to `seam4_no_write_call_references_specaffold_path`.
  These are internal test identifiers; mechanical rename is safe.

### React / TypeScript frontend

- **R5** — Every `.tsx` file under `flow-monitor/src/components/` and
  `flow-monitor/src/views/` has its in-code brand comments, rendered path
  literals, and display strings replaced per the delta
  (`02-design/string-delta.md §3`).
- **R6** — `flow-monitor/src/components/SettingsRepositories.tsx:33`
  constructs the existence-check path as `${pickedPath}/.specaffold` (not
  `${pickedPath}/.spec-workflow`). Implementation ordering constraint: the
  Rust backend scanner change (R1) lands in the same wave as, or in a wave
  before, this frontend change — so that `path_exists` does not silently
  fail for every repo during a partial-merge window.
- **R7** — Every `t("palette.group.specflow")` call site is updated to
  `t("palette.group.scaff")`; the i18n key itself is renamed (per design
  decision Q1 → Option A). After the rename, the string
  `palette.group.specflow` does not appear anywhere in
  `flow-monitor/src/**` or `flow-monitor/src-tauri/**` — QA adds a grep
  assertion to verify.

### i18n bundles

- **R8** — `flow-monitor/src/i18n/en.json` and
  `flow-monitor/src/i18n/zh-TW.json` both contain the three keys
  `empty.body`, `settings.repoNotSpecflow`, and `palette.group.scaff`
  (note: the last key is renamed per R7). The English and Traditional
  Chinese strings at each key match the replacement column of the delta
  tables in `02-design/string-delta.md §1` and `§2` exactly.
- **R9** — Both i18n files are valid JSON after the changes (parse check
  in CI or test). No orphaned keys: the file must not still contain
  `palette.group.specflow`.

### Docs

- **R10** — `flow-monitor/README.md` has its brand prose, path prefixes,
  and user-visible section copy updated per the delta
  (`02-design/string-delta.md §4`). The feature-slug reference at line 9
  (`20260419-flow-monitor`) is preserved — date-based identifier, not
  brand copy. One new line is added to the README under a "Known
  limitations" or "Upgrade notes" subsection (placement at Developer's
  discretion) stating: pre-rename audit logs under
  `.spec-workflow/.flow-monitor/` are preserved on disk but are not
  surfaced in the new UI.

### Repo-wide grep allow-list

- **R11** — The repo-wide grep assertion authored by
  `20260421-rename-to-specaffold` AC1 — `grep -rE
  "spec-workflow|specflow" .` against the allow-list at
  `.claude/carryover-allowlist.txt` — continues to produce zero unlisted
  hits after this feature merges. If any legitimate carryover is
  introduced by this feature (e.g. the README line added per R10
  referring to the legacy `.spec-workflow/.flow-monitor/` log path for
  upgrade-notes purposes, or a Rust doc comment that cites the prior
  behaviour for historical context), its path is added to the allow-list
  as part of the same commit.

## 6. Edge cases and open risks

### Tauri capability allow-list is the primary security-axis change

R3 modifies the Tauri capability allow-list. In a sandboxed desktop app, the
allow-list is the boundary that gates filesystem access from the webview;
changing an allow-listed path is a security-boundary edit. Architect review
(mandated by `tier=audited`) focuses here. The change is a clean swap (old
paths removed, new paths added) rather than a widen-then-narrow sequence —
least-privilege is preserved, not degraded, across the diff. The reviewer
security axis `must` checks (hardcoded paths, secure defaults) apply.

### Breaking change for pre-rename monitored repos that bypass the compat symlink

Flow-monitor post-rename reads `.specaffold/` only. A repo that was seeded
before the rename shipped (`.spec-workflow/` is the real directory, no
compat symlink exists) is no longer monitorable by this build. Mitigation:

- Any repo seeded with a post-rename `bin/scaff-seed` has the compat symlink
  (`ensure_compat_symlink`), so `.specaffold/` resolves either way.
- Repos that pre-date the rename and have not been re-seeded need to either
  (a) re-run `bin/scaff-seed update` to get the symlink, or (b) manually
  rename `.spec-workflow/` → `.specaffold/` and create the symlink.
- The migration pathway was documented by the predecessor feature in
  `docs/rename-migration.md`; the flow-monitor README (R10) references it
  by pointer — not by restatement.

This matches Decision D2 below and the user's brief.

### Implementation risk: merge-order of frontend vs backend

R1 (Rust scanner reads `.specaffold/`) and R6 (frontend builds
`${pickedPath}/.specaffold` for `path_exists`) are paired. If R6 lands
before R1, every real repo will fail validation because the backend is
still probing `.spec-workflow/`. If R1 lands before R6, freshly-seeded
repos work via the compat symlink (transient `.spec-workflow/` probe
still resolves). TPM must plan this as a single wave, or as two strictly
ordered waves with R1 first — called out in the PRD so the constraint
survives to the plan stage.

### Pre-rename audit logs are preserved on disk, not surfaced

Decision D4 below resolves this. The README line added per R10 is the user-
facing acknowledgement.

### zh-TW brand copy is stable

The design delta confirms that all three renamed zh-TW strings read
naturally — the Latin-script product token (`scaff` / `Scaff`) substitutes
cleanly inside Chinese sentences without awkward prose. No additional
Designer pass is needed.

## 7. Open questions (blockers)

None. All four request-stage questions are resolved by Decisions D1–D4
below; the three design-stage questions are resolved in
`02-design/string-delta.md §6`.

## 8. Decisions (PM-resolved, reversible)

- **D1 — invoke.rs script renames `specflow <cmd>` → `scaff <cmd>`.**
  Resolves 00-request Q1. This is a correctness requirement, not a
  preference: the `specflow` binary does not exist on post-rename systems
  (it was renamed to `scaff` in `20260421-rename-to-specaffold` R7), so
  leaving the legacy form would fail at exec time the first time a user
  invoked a command from the palette. The Rust constant
  `SPEC_WORKFLOW_MARKER` and the test-function name
  `seam4_no_write_call_references_spec_workflow_path` are internal test
  identifiers and are renamed along with the rest of the brand tokens (R4).

- **D2 — flow-monitor reads `.specaffold/` only; no dual-path fallback.**
  Resolves 00-request Q2. A dual-path `read-from-either(".specaffold/",
  ".spec-workflow/")` helper doubles the filesystem-traversal surface and
  the mental model in the Rust backend. Post-rename repos have the compat
  symlink (authored by `bin/scaff-seed`), so legacy monitored repos that
  have been re-seeded keep working; repos that pre-date the rename and
  have not been re-seeded are out of support — the migration path is one
  `bin/scaff-seed update` invocation, documented in
  `docs/rename-migration.md`.

- **D3 — Tauri capability allow-list: outright swap, no transition window.**
  Resolves 00-request Q3. Dual allow-listing (keeping both
  `$REPOS/.spec-workflow/...` and `$REPOS/.specaffold/...` during a
  cutover) widens the security surface for no continuing benefit once
  freshly-seeded repos have the compat symlink in place. The allow-list
  switches outright in this feature. Architect review (mandated by
  `tier=audited`) confirms the least-privilege posture is preserved, not
  degraded, across the diff.

- **D4 — No one-time migration of pre-rename audit logs; fresh log at new
  path on first write.** Resolves 00-request Q4. A one-shot migration
  script would introduce (a) a once-per-repo operational step users
  reliably skip, (b) race conditions during migration, (c) ambiguity when
  both old and new files exist. Lazy migration at first write — the new
  path gets a fresh log; the old file stays untouched on disk — is the
  discipline recommended by `shared/lazy-migration-at-first-write-beats-
  oneshot-script.md`. The README (R10) documents that legacy logs are
  preserved but unsurfaced.

- **D5 — i18n key `palette.group.specflow` renamed to `palette.group.scaff`.**
  Resolves design-stage Q1. Clean long-term state, no legacy key leaks
  into future codebase. Developer updates every consumer and QA adds a
  grep assertion. (From `02-design/string-delta.md §6`.)

- **D6 — `SettingsRepositories.tsx:33` updates to `${pickedPath}/.specaffold`
  with merge-order constraint.** Resolves design-stage Q2. TPM orders the
  Rust backend scanner rename at or before the frontend change; see §6
  edge case "merge-order". (From `02-design/string-delta.md §6`.)

- **D7 — `flow-monitor/README.md:9` updates the path prefix only; feature
  slug `20260419-flow-monitor` is preserved as a date-based identifier.**
  Resolves design-stage Q3. (From `02-design/string-delta.md §6`.)

## 9. Acceptance criteria

Structural ACs gate archive. Runtime ACs require a manual live-app
walkthrough per `shared/runtime-verify-must-exercise-end-to-end-not-just-
build-succeeds.md` (has-ui is true).

### Grep assertions (structural)

- **AC1** — `grep -rnE "spec-workflow|specflow" flow-monitor/` returns
  zero unlisted hits: every returned line is either (a) inside the
  `.claude/carryover-allowlist.txt` file extended per R11, or (b) the
  explicit README upgrade-notes line added per R10. Any other hit is a
  FAIL.
- **AC2** — `grep -rn "palette.group.specflow" flow-monitor/src/` returns
  zero hits. Verified by QA-analyst at gap-check.

### Rust backend (structural)

- **AC3** — The Tauri capability allow-list file
  `flow-monitor/src-tauri/capabilities/default.json` contains exactly the
  two paths `$REPOS/.specaffold/.flow-monitor/audit.log` and
  `$REPOS/.specaffold/.flow-monitor/audit.log.1` in its filesystem-access
  section; neither legacy path remains. Verified by JSON parse +
  key-value inspection.
- **AC4** — The shell-script template in
  `flow-monitor/src-tauri/src/invoke.rs` references `scaff` as the
  executable name, not `specflow`. Verified by grep / snapshot of the
  generated script for a representative invocation.
- **AC5** — `cargo test` inside `flow-monitor/src-tauri/` passes. Every
  test function previously named with `spec_workflow` has been renamed
  to its `specaffold` counterpart per R4; no test source file retains the
  legacy identifiers.

### Frontend (structural)

- **AC6** — `flow-monitor/src/i18n/en.json` and
  `flow-monitor/src/i18n/zh-TW.json` both parse as valid JSON, both
  contain the key `palette.group.scaff`, and neither contains the key
  `palette.group.specflow`. The three affected keys (`empty.body`,
  `settings.repoNotSpecflow`, `palette.group.scaff`) have values that
  match the replacement column of the delta tables exactly. Verified by
  parsing and string equality.
- **AC7** — `vitest` (or the frontend test runner in use for
  flow-monitor) passes against the updated sources. Snapshot tests that
  previously asserted on legacy strings have been updated to the new
  strings.
- **AC8** — `flow-monitor/src/components/SettingsRepositories.tsx:33`
  constructs the path string `${pickedPath}/.specaffold`. Verified by
  grep + AST-level or line-level check.

### Docs (structural)

- **AC9** — `flow-monitor/README.md` contains **Scaff** and **Specaffold**
  (per the delta table in `02-design/string-delta.md §4`) and contains a
  single line under a limitations or upgrade-notes subsection stating
  that pre-rename audit logs at `.spec-workflow/.flow-monitor/` are
  preserved on disk but not surfaced in the UI (R10). Verified by grep
  for the brand tokens and for the upgrade-notes sentence.

### Runtime (live-app walkthrough, mandatory per has-ui)

- **AC10** — [runtime] With flow-monitor launched as a built artifact
  against a freshly-seeded `.specaffold/` repo, a developer can: (a) see
  the sidebar populate with features under `.specaffold/features/`, (b)
  click a session card and see the detail view render, (c) trigger an
  invoke from the command palette and observe the generated shell
  command starts with `scaff`, (d) observe a new audit-log entry appear
  at `.specaffold/.flow-monitor/audit.log` on disk. Steps recorded in
  `08-validate.md` under a **Runtime walkthrough** section.
- **AC11** — [runtime, zh-TW] With the app locale switched to
  Traditional Chinese, the empty-state copy, the "not a scaff
  repository" error, and the command-palette group heading read as
  specified in `02-design/string-delta.md §2` — no `specflow` or
  `spec-workflow` leaks into the displayed UI. Recorded in the Runtime
  walkthrough section.

### Capability-allow-list audit (architect gate)

- **AC12** — Architect records in `04-tech.md` that the Tauri capability
  allow-list change is a clean swap (old paths removed, new paths added
  atomically in the same commit), that no other capability scopes are
  widened, and that least-privilege posture is preserved. This is a
  `tier=audited` gating condition.

## Team memory

Applied:

- `shared/lazy-migration-at-first-write-beats-oneshot-script.md` — justifies
  D4 (fresh audit log on first write; legacy file untouched on disk; no
  one-shot migration script).
- `shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds.md`
  — mandates AC10 / AC11 runtime walkthroughs for this `has-ui: true`
  feature; build-green + tests-green alone do not close validate.
- `pm/ac-must-verify-existing-baseline.md` — ACs that reference "match the
  design delta" cite the specific delta section (e.g.
  `02-design/string-delta.md §4`) rather than vague "match design", so
  parity is unambiguous.

Not applicable this feature (documented so the reader sees the scan was
run):

- `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap.md` —
  this feature is not a B1/B2 blast-radius split; it is the
  product-naming continuation of `20260421-rename-to-specaffold`, and
  that feature's archive notes already pre-committed the follow-up slug
  space this feature occupies. No functional gap to preserve — the
  predecessor covered the read-only rename; this covers the flow-monitor
  subtree.
- `pm/split-by-blast-radius-not-item-count.md` — the rename is one
  coherent item (the flow-monitor subtree); splitting into sub-features
  would fragment the grep-zero goal artificially.
- `pm/scope-extension-at-design-is-cheapest.md` — not applicable, no
  scope extension requested by the user.
- `pm/catalog-tone-anchor-parallel-drafting.md` — not applicable, no
  catalog authoring in this feature.
- `pm/housekeeping-sweep-threshold.md` — not a sweep feature.
- `shared/dogfood-paradox-third-occurrence.md` — not applicable: this
  feature renames the flow-monitor Tauri app, which is not the harness
  running the rename. No paradox.

Proposed for promotion at archive if the pattern holds (not yet promoted):

- `pm/rename-continuation-feature-inherits-allow-list.md` — a
  continuation feature that extends an earlier rename should extend, not
  re-author, the earlier feature's carryover allow-list; treat AC1 of
  the predecessor as a continuing invariant the continuation feature
  must not break (R11 encodes this). Evaluate at archive.
