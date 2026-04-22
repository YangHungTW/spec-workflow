# String Delta — flow-monitor rename: specflow / spec-workflow → scaff / .specaffold

## Rename rules applied

| Legacy form | Replacement form | Notes |
|---|---|---|
| `specflow` | `scaff` | lowercase brand token |
| `Specflow` | `Scaff` | title-case at sentence start or heading |
| `.spec-workflow/` | `.specaffold/` | directory path literal shown to user |
| `.spec-workflow` | `.specaffold` | directory path without trailing slash |
| `spec-workflow` | `specaffold` | bare name without leading dot |

---

## 1. i18n string-rename table — `flow-monitor/src/i18n/en.json`

| key | legacy | replacement | notes |
|---|---|---|---|
| `empty.body` | `"Add a repository that contains a .spec-workflow/ folder to start monitoring your specflow sessions."` | `"Add a repository that contains a .specaffold/ folder to start monitoring your scaff sessions."` | Two tokens replaced: `.spec-workflow/` and `specflow` |
| `settings.repoNotSpecflow` | `"Not a specflow repository: missing .spec-workflow/ folder."` | `"Not a scaff repository: missing .specaffold/ folder."` | Two tokens replaced |
| `palette.group.specflow` | `"Specflow Commands"` | `"Scaff Commands"` | Display label only — see Open Questions Q1 on key name |

All other `en.json` strings contain no brand copy; they are not in scope.

---

## 2. i18n string-rename table — `flow-monitor/src/i18n/zh-TW.json`

| key | legacy | replacement | notes |
|---|---|---|---|
| `empty.body` | `"新增含有 .spec-workflow/ 資料夾的倉庫，以開始監控您的 specflow 工作階段。"` | `"新增含有 .specaffold/ 資料夾的倉庫，以開始監控您的 scaff 工作階段。"` | `.spec-workflow/` → `.specaffold/`; `specflow` → `scaff` (Latin script retained — see note below) |
| `settings.repoNotSpecflow` | `"不是 specflow 倉庫：缺少 .spec-workflow/ 資料夾。"` | `"不是 scaff 倉庫：缺少 .specaffold/ 資料夾。"` | Both tokens replaced |
| `palette.group.specflow` | `"Specflow 指令"` | `"Scaff 指令"` | Display label; Latin script brand token inside Chinese sentence |

**zh-TW brand note:** Both `specflow` and `scaff` are Latin-script product names that appear unchanged inside Chinese sentences (no localised Chinese equivalent exists). The substitution `specflow` → `scaff` and `Specflow` → `Scaff` is applied literally; this is consistent with how the original strings treated `specflow`. The result reads naturally: "不是 scaff 倉庫" parallels "不是 specflow 倉庫" and follows the same sentence pattern.

No zh-TW strings produce awkward copy under the default rule. All three changed strings read naturally with `scaff` substituted for `specflow`.

---

## 3. TSX display-string table — `flow-monitor/src/components/` and `flow-monitor/src/views/`

### In-code comments that contain brand copy (visible to readers of the source; may appear in generated docs)

| file | line(s) | legacy | replacement |
|---|---|---|---|
| `src/components/AuditPanel.tsx` | 16 | `/** specflow command name (e.g. "implement"). */` | `/** scaff command name (e.g. "implement"). */` |
| `src/components/SessionCard.tsx` | 53 | `* SessionCard — presentational card for one specflow session.` | `* SessionCard — presentational card for one scaff session.` |
| `src/components/StagePill.tsx` | 4 | `* The 11 named stages in specflow order.` | `* The 11 named stages in scaff order.` |
| `src/components/StagePill.tsx` | 28 | `* Pure presentational pill showing the current specflow stage.` | `* Pure presentational pill showing the current scaff stage.` |
| `src/components/NotesTimeline.tsx` | 2 | `* NotesTimeline — renders the STATUS Notes timeline for a specflow feature.` | `* NotesTimeline — renders the STATUS Notes timeline for a scaff feature.` |

### Path literals rendered to the user (featurePath construction in CardDetail.tsx)

| file | line(s) | legacy | replacement |
|---|---|---|---|
| `src/views/CardDetail.tsx` | 119 | `` `${repoFullPath}/.spec-workflow/features/${validSlug}` `` | `` `${repoFullPath}/.specaffold/features/${validSlug}` `` |
| `src/views/CardDetail.tsx` | 120 | `` `/${validRepoId}/.spec-workflow/features/${validSlug}` `` | `` `/${validRepoId}/.specaffold/features/${validSlug}` `` |

**Note:** Line 119 is the primary code path (used when `repoFullPath` is resolved); line 120 is the fallback. Both render the path in an accessible element; both must change. This is a logic path, not a pure display string, but the rendered path is user-visible in the file-picker and Finder-reveal calls.

### Path literal used in SettingsRepositories.tsx IPC call (shown in error messages indirectly)

| file | line(s) | legacy | replacement |
|---|---|---|---|
| `src/components/SettingsRepositories.tsx` | 33 | `` `${pickedPath}/.spec-workflow` `` | `` `${pickedPath}/.specaffold` `` |

**Note:** This literal feeds `path_exists` IPC; if the check fails, `settings.repoNotSpecflow` (already renamed above) is shown. The path string itself must match the real directory name `.specaffold`, so this is both a logic fix and a user-visible correctness fix.

---

## 4. README / doc-comment table — `flow-monitor/README.md`

| line(s) | legacy | replacement | notes |
|---|---|---|---|
| 3–4 | `"monitoring multiple parallel specflow sessions"` | `"monitoring multiple parallel scaff sessions"` | Product description paragraph |
| 9 | `"See .spec-workflow/features/20260419-flow-monitor/"` | `"See .specaffold/features/20260419-flow-monitor/"` | Path in Status section |
| 73 | `"any repository that runs specflow sessions (e.g. this spec-workflow repo itself)."` | `"any repository that runs scaff sessions (e.g. this specaffold repo itself)."` | Dogfood handoff section |
| 99–101 | `"use flow-monitor to observe the specflow sessions that are building flow-monitor"` ... `"new specflow session"` | `"use flow-monitor to observe the scaff sessions that are building flow-monitor"` ... `"new scaff session"` | Filing-bugs paragraph |
| 119 | `"B1 flow-monitor runtime confirmed: first real session appeared in sidebar within 5 s"` | unchanged | This is a STATUS Notes template — it does not contain brand copy |
| 134 (Known B1 limitations) | `"the app reads .spec-workflow/ state files"` | `"the app reads .specaffold/ state files"` | Limitations section, user-visible |

---

## 5. Open questions

**Q1 — i18n key name `palette.group.specflow`: rename the key identifier or leave it?**

The JSON key `"palette.group.specflow"` is referenced in consumer TypeScript code (CommandPalette component and its test at line 26 of `CommandPalette.test.tsx`). Two options:

- **Option A (recommended):** Rename the key to `"palette.group.scaff"` and update every call site that references `t("palette.group.specflow")`. This is the cleaner long-term state; no legacy key leaks into a future codebase.
- **Option B:** Keep the key name `"palette.group.specflow"` and change only the display value. Zero call-site churn; backward-compatible for any external consumer mocking the i18n map.

*This design stage recommends Option A*, but the Developer must confirm there are no consumers outside the scanned tree (e.g. Rust backend reading the key names) before applying. The QA stage should add a grep assertion that `palette.group.specflow` does not appear in any non-test source file after the rename.

**Q2 — `SettingsRepositories.tsx` path check: is `.specaffold` the correct folder name?**

Line 33 checks for `.spec-workflow` via `path_exists` IPC. The Developer must confirm that the Tauri backend's repository-state scanner has also been updated (in a parallel task) to read from `.specaffold/` rather than `.spec-workflow/`. If the Rust scanner has not yet been updated, updating line 33 alone will cause all repos to fail validation until the backend rename lands. Coordinate merge order.

**Q3 — README line 9: should the feature path also update the feature slug?**

`See .specaffold/features/20260419-flow-monitor/` — the date-slug `20260419-flow-monitor` references the original specflow-era feature. No action needed (slug is a date-based identifier, not brand copy), but confirm the path is still accurate after the folder rename.

---

## 6. User decisions (2026-04-21)

- **Q1 → Option A**: rename the i18n key `palette.group.specflow` → `palette.group.scaff`; Developer must update every `t("palette.group.specflow")` call site. QA adds a grep assertion that `palette.group.specflow` is absent from non-test source after the rename.
- **Q2 → yes**: update `SettingsRepositories.tsx:33` `${pickedPath}/.spec-workflow` → `${pickedPath}/.specaffold`. TPM must order this in Plan so the Rust backend scanner rename lands at or before this line, to avoid a window where all repos fail `path_exists`.
- **Q3 → yes**: change only the path prefix in `flow-monitor/README.md:9`; keep the feature slug `20260419-flow-monitor` unchanged (date-based identifier, not brand copy).
