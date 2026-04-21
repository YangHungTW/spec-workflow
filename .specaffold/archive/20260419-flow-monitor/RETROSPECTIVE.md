# Retrospective — 20260419-flow-monitor

_2026-04-19 → 2026-04-20 · TPM archive retrospective_

## 1. Scope delta — original request vs shipped

**Original request (00-request.md, single sentence):** build a native macOS app that monitors specflow sessions across repos AND lets the user operate on stalled ones (nudge, advance, intervene).

**What B1 shipped (this feature):** read-only dashboard — session discovery across registered repos, two-tier idle detection (stale / stalled), fire-once macOS Notification Center on stalled transition, always-on-top compact panel, `02-design` preview with Reveal-in-Finder, light/dark theming with locked primary palette, en/zh-TW parity. No control-plane verbs; `Send instruction` surface explicitly suppressed.

**What went to B2 (`20260420-flow-monitor-control-plane`, intake committed on this branch):** the operate half — nudge, advance, intervene; the verbs that close the original request's promise.

**Scope delta summary:** the B1/B2 split was architecturally sound (read-only vs. control plane is a clean blast-radius boundary), but the user's original ask was _one sentence_ that bundled both halves. Shipping B1 alone is "half the promise" from the user's point of view. The PM judgement to split was correct; the obligation that follows is a tight B2 follow-up, which is why B2 intake landed on this branch rather than waiting for main.

## 2. Notable deviations from the original plan

**Rust pin bumped 1.83 → 1.88 (W0, T2 retry).** Tauri 2.10's transitive `time-core` dependency requires edition 2024, which Rust 1.83 does not support. Plan's Q-plan-1 was updated via `/specflow:update-plan`; no scope loss, but a toolchain assumption in `05-plan.md` did not survive first contact with `cargo build`.

**Multiple T14 retries (W2) on i18n key-depth style.** The locked-key convention is 2-level flat keys; T14's first draft used 3-level (`settings.theme.light`), review flagged must-style, retry 1 fixed `settings.theme.*` but missed `notification.stalled.{title,body}`, retry 2 finished the job. Two rounds of the same finding is a signal that the style rule would benefit from an automated lint (a `scripts/i18n-key-depth-check.sh` would have caught both in one pass).

**W5 re-merge after Cargo.lock conflict.** T30/T31/T35/T36/T41 were originally merged but lost to a Cargo.lock merge conflict during wave rollup. Rescued via direct-SHA `git merge` rather than re-running the tasks. Five checkboxes were re-flipped in a cleanup commit (see `tpm/checkbox-lost-in-parallel-merge`).

**Post-verify polish avalanche T44–T48 + seven inline runtime fix commits.** Structural verify returned PASS-DEFERRED (382/382 tests green, 37 runtime-deferred ACs per dogfood paradox). User launched the `.dmg`, screenshotted an unstyled app, verify flipped to FAIL. Recovery required:

- **T44** — component CSS (the unstyled app)
- **T45** — chrome navigation + 3 missing IPC stubs (`get_notification_permission_status`, `focus_main_window`, `dialog_open_directory`)
- **T46** — theme toggle deduplication (toolbar + Settings both wrote `html.dark`, creating a desync loop)
- **T47** — wire EmptyState into MainWindow + mockup polish
- **T48** — comprehensive mockup alignment (sidebar logo, sections, counts, filters, Settings placement, toolbar title/subtitle, card repo badge, UI badge, Active badge, text recolor)

Seven inline fix commits then landed (all before B2 intake) addressing:
- IPC shape mismatch (`ListSessionsResponse` typed on frontend vs flat `Vec<SessionRecord>` returned from Rust)
- Dialog deadlock (`blocking_pick_folder()` inside `async fn` deadlocked tokio; replaced with callback + oneshot)
- Plugin capabilities not granted (strict lockdown from T3 + plugins added in T25/T26/T27/T28/T45 never re-granted)
- Polling task never wired (diff produced but no background task actually ran)
- Card click did not navigate (missing `onClick` prop on `SessionCard` wrapper; `stopPropagation` on hover buttons absent)
- Tab content loaded synthetic stubs instead of real markdown (`read_artefact` not called)
- Theme reverted on CardDetail mount (`get_settings` IPC read clobbered the localStorage single-source-of-truth)
- Default language radio unselected (IPC Settings missing `locale` field; `DEFAULT_SETTINGS` not merged on frontend)

These are not "cleanup" — every one would have been a show-stopper on first real use. The structural test suite could not see them because all tests mocked the IPC layer.

## 3. Dogfood paradox status

**Closed on first run.** Per `shared/dogfood-paradox-third-occurrence`, the feature shipped PASS-DEFERRED with 37 runtime ACs queued for post-archive handoff. After T44-T48 polish landed, the user built the DMG, launched the app, added `/Users/yanghungtw/Tools/spec-workflow` as a watched repo, and observed the flow-monitor card appear in its own grid during this very feature's own conversation. The dogfood paradox is recorded as _closed on first run_ — the first dogfood launch successfully observed the session that was building the tool.

This is the first feature in this repo where the dogfood-paradox handoff produced an immediate observation rather than deferring to the next feature's STATUS notes. The protocol still holds: next feature (B2 `20260420-flow-monitor-control-plane`) should record first-session-observation in its early STATUS notes per the memory's "Next feature after a dogfood-paradox feature" clause.

## 4. Counts

| Metric | Count |
|---|---|
| Tasks authored | 48 (T1-T43 core + T44-T48 post-verify polish) |
| Task checkboxes flipped | 48/48 |
| Waves | W0 (scaffold), W1 (Rust modules), W1.5 cleanup (T43), W2 (React primitives), W3 (views), W4 (platform plugins), W5 (seam tests + dogfood handoff) + post-verify W6-W10 implicit (T44→T48) |
| Review retry rounds | 9+ (T2 retry pins, T11 retry canonicalise, T14 × 2 retries on key depth, T17 retry, T23 retry, T18 retry URL validation, T34 retry revert html:true, T19 fix i18n key) |
| Rust tests | 99 |
| Frontend tests | 303 (grew from 283 at verify checkpoint to 303 after T44-T48) |
| Total tests | 402 |
| Merge commits on branch | ~30 (per-task merges, W5 re-merge for Cargo.lock rescue) |
| Feature-branch commits | 139 ahead of main |
| Structural ACs PASS | all (R1.a-d, R2.c, R3.a-d, R4.b-c, R5.b-d, R6.a-e, R7.a-d, R8.a-b, R9.b-k, R11.c, R11.e, R13.a-c, R14.a-c, R15.a-c, R15.e-f) |
| Runtime ACs DEFERRED → exercised | 37 queued → all observed during dogfood launch |
| Runtime fix-up commits post-T44 | 7 (before B2 intake) |
| Inline diagnostic commits (`diag:` prefix) | 2 (EmptyState status readout, dialog error surfacing) |

## 5. What worked

- **Closed-enum classifier pattern** (`classify-before-mutate` rule applied to `repo_discovery::SessionKind` and status parser) made the parser code review-trivial and fuzz-testable. Zero parser bugs reached any review.
- **Architect Seams 1–7** (pure parser, store::diff, tempdir poller test, no-writes grep, settings round-trip, i18n parity, markdown XSS) caught every structural issue at unit-test granularity. None of the 402 tests was flaky.
- **Dogfood paradox protocol.** The verify stage shipped PASS-DEFERRED with explicit runtime-AC handoff groups (A-I) rather than stalling on the paradox; the handoff list made the post-build walkthrough systematic.
- **B1/B2 split discipline.** Control-plane verbs (Send instruction, nudge, advance) were suppressed cleanly — no leakage into IPC surface, no orphan UI placeholders. B2 inherits a clean read-only substrate.
- **Atomic settings write with `.bak`.** Write-temp-then-rename + backup discipline from `no-force-on-user-paths` rule held across all test scenarios including simulated crash between write and rename.

## 6. What went wrong — gap between structural PASS and runtime viability

The core lesson of this feature: **structural verify (build + tests green) is necessary but nowhere near sufficient for a native desktop app**. Of the 12+ runtime issues caught during dogfood launch, zero were visible to the 402-test structural suite. The test seams exercised the pure data functions beautifully; they exercised almost nothing about the live Tauri runtime wiring.

Specific gap categories:

1. **IPC shape validation.** TypeScript types do not validate at runtime. `ListSessionsResponse` was typed on the frontend and never matched what Rust returned; silent `.catch(() => undefined)` hid the crash; user saw "empty state forever". Structural tests mocked the IPC layer and so saw nothing.

2. **Tauri 2 capability lockdown vs plugin onboarding.** T3 locked down capabilities (correct, per security rule). Every subsequent plugin task (T25, T26, T27, T28, T45) added a plugin _without re-granting_ the `plugin:default` permission in the capability file. All plugin commands silently rejected at runtime. Tests mocked the plugins.

3. **Async-command blocking-API deadlock.** `blocking_pick_folder()` inside `#[tauri::command] async fn` deadlocks the tokio runtime. No structural test could detect this — the command was typed correctly, the function compiled, the unit test (if it existed) would have run against a mock.

4. **Missing wiring for already-built modules.** `poller::diff()` was unit-tested to perfection. The background task that was supposed to _call_ it on a tokio interval was never spawned from `setup`. Every test passed; nothing polled.

5. **Theme state desync between two toggles.** Toolbar toggle and Settings toggle both wrote to `html.dark`; on one write path the settings IPC `get_settings` would clobber the localStorage-set class. The theme-timing test passed because it tested one toggle in isolation.

6. **Navigation without an onClick.** `SessionCard` component tests asserted hover buttons and labels; no test asserted "clicking the card navigates to CardDetail" because the test rendered the card in isolation without a router.

**Lesson:** a _runtime walkthrough_ of the main user flow must be part of the verify stage for any UI-bearing feature, not a post-archive handoff. Structural PASS alone was misleading here.

## 7. Memory proposals for user approval

Each proposal below needs user yes/no before I write it. All proposals written as English file content; filenames are English.

### P1 — `shared/runtime-verify-must-exercise-end-to-end-not-just-build-succeeds` (global, shared)

_Rationale:_ both verify stages here passed PASS-DEFERRED based on build success + tests green, but end-to-end runtime exposed 12+ wiring gaps invisible to unit tests. Next feature's verify stage should explicitly demand a live-app walkthrough of the main user flow for any UI-bearing feature, not just "tests green + build green".

### P2 — `tpm/checkbox-lost-in-parallel-merge` (local tpm — update existing)

_Rationale:_ entry already exists locally. This feature reinforces it — W4 and W5 each silently dropped 5+ checkbox flips during parallel-wave merges; orchestrator flipped them manually in a cleanup commit. Update the existing entry with a third occurrence reference and a stronger recommendation (e.g. explicit post-merge checkbox audit step in the wave rollup checklist).

### P3 — `developer/tauri-2-capability-lockdown-must-re-grant-on-plugin-add` (local developer)

_Rationale:_ T3's strict capability lockdown plus T25/T26/T27/T28/T45 adding plugins without re-granting `plugin:default` permissions meant every plugin command silently rejected at runtime. Tests mocked the plugins. A capability-wiring audit belongs in the review-security rubric _or_ in a developer memory that says "after adding a Tauri plugin, always re-open the capability file and re-grant explicitly; never trust the default."

### P4 — `developer/tauri-2-async-command-blocking-api-deadlocks` (local developer)

_Rationale:_ `blocking_pick_folder()` inside `#[tauri::command] async fn` deadlocks the tokio runtime. The correct pattern is either (a) callback form with a oneshot channel, or (b) make the command sync. Short memory with the code pattern, reproduced once in this feature's dialog fix commit.

### P5 — `developer/ipc-shape-mismatch-swallowed-by-catch` (local developer)

_Rationale:_ frontend typed `ListSessionsResponse`, backend returned flat `Vec<SessionRecord>`; TypeScript types do not validate at runtime; silent `.catch(() => undefined)` hid the crash; user saw "empty state forever". Memory should prescribe either (a) single-source IPC type generation (e.g. `ts-rs`), or (b) dev-mode assertion that exhausts `.catch` errors visibly rather than swallowing them.

### P6 — `pm/b1-b2-split-validates-blast-radius-but-leaves-functional-gap` (local pm)

_Rationale:_ the B1/B2 split (read-only vs control plane) was architecturally sound, but the user's original request bundled both halves in one sentence. Shipping B1 alone is "half the promise" from the user's perspective. PM should acknowledge this explicitly when pitching a split and commit to a tight B2 follow-up (which in this feature landed as intake on the same branch — correct recovery).

---

## 8. Handoff to B2

`20260420-flow-monitor-control-plane` intake is already on this branch (commit `034c321`). After this archive completes, B2 continues on its own branch off main. First STATUS Notes line on B2 should confirm the post-archive first-session observation per `shared/dogfood-paradox-third-occurrence` "Next feature after a dogfood-paradox feature" clause — this has already been satisfied by the runtime fix-up commits here, but B2 should still surface it in its own Notes for traceability.
