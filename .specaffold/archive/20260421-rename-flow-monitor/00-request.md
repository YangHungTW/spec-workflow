# Request

**Raw ask**: Rename remaining `spec-workflow`/`specflow` references inside `flow-monitor/` (paths, UI strings, tests, Tauri capabilities) to `specaffold`/`scaff` so the rename started in `20260421-rename-to-specaffold` is complete product-wide.

**Context**: The previous feature `20260421-rename-to-specaffold` (archived commit `68d673b`) renamed the top-level repo (bin/, .claude/, hooks, tests) but explicitly did not touch the `flow-monitor/` subtree. ~124 file hits in flow-monitor still reference the legacy names across Rust backend (`src-tauri/`), React frontend (`src/`), i18n bundles, Tauri capability allow-list, tests, and docs. Flow-monitor continues to work today only because `bin/scaff-seed::ensure_compat_symlink` creates `.spec-workflow → .specaffold` in seeded repos — so the legacy paths resolve via symlink. This feature closes the B1/B2 gap: without it, "product-wide rename" is only half-delivered and every flow-monitor contributor still sees the old brand. Open questions the user should confirm at /scaff:prd time: (1) **invoke-command rename** — does the shell script emitted by `src-tauri/src/invoke.rs` switch from `specflow <cmd>` to `scaff <cmd>`? (2) **backward-compat for monitored repos** — do we support both `.spec-workflow/` and `.specaffold/` roots, or only `.specaffold/` (relying on the compat symlink for legacy)? (3) **Tauri capability transition** — the allow-listed path `$REPOS/.spec-workflow/.flow-monitor/audit.log` is a security surface; rename outright, or keep both paths during a transition window? (4) **audit-log migration** — do existing deployments need a one-time copy/symlink from `.spec-workflow/.flow-monitor/audit.log` to `.specaffold/.flow-monitor/audit.log`, or accept a fresh log on first write?

**Success looks like**:
- Zero occurrences of `spec-workflow` or `specflow` in `flow-monitor/` source, tests, i18n, capabilities, and docs (excluding intentional compat/back-compat references explicitly flagged during PRD).
- Flow-monitor launches against a freshly-seeded `.specaffold/` repo, discovers features, opens cards, and writes audit-log entries to the new path without user-facing regressions.
- Tauri capability allow-list points at the new `.specaffold/.flow-monitor/audit.log` path (or both paths if the transition-window decision says so).
- UI strings in both `en.json` and `zh-TW.json` use the new brand consistently; Designer review signs off on the string delta.
- Invoke-command shell scripts call the renamed binary (pending Q1 answer).

**Out of scope**:
- Functional changes to flow-monitor behaviour (feature discovery logic, card rendering, audit-log format) — this is a rename, not a refactor.
- Renaming the `flow-monitor/` directory itself (out of scope unless the user flags it at /scaff:prd time).
- Changes to `bin/scaff-seed::ensure_compat_symlink` — the compat symlink is the mechanism that keeps legacy `.spec-workflow/` monitored repos working; touching it belongs in a separate feature.
- Migrating existing on-disk audit logs unless Q4 lands as "yes, migrate."

**UI involved?**: yes — i18n bundles (`src/i18n/en.json`, `zh-TW.json`), React component strings (`src/components/*.tsx`), view templates (`src/views/CardDetail.tsx`), and test snapshots include user-facing copy; Designer stage should run on the string delta at minimum.
