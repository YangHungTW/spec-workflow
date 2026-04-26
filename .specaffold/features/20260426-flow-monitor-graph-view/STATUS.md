# STATUS

- **slug**: 20260426-flow-monitor-graph-view
- **has-ui**: true
- **work-type**: feature
- **tier**: audited
- **stage**: plan
- **created**: 2026-04-26
- **updated**: 2026-04-26

## Stage checklist
- [x] request       (00-request.md)              — PM
- [x] design        (02-design/)                 — Designer (skip if has-ui: false)
- [x] prd           (03-prd.md)                  — PM
- [x] tech          (04-tech.md)                 — Architect
- [x] plan          (05-plan.md)                 — TPM  [merged: narrative + task checklist]
- [ ] implement     (05-plan.md tasks checked off) — Developer
- [ ] validate      (08-validate.md, verdict PASS) — QA-tester + QA-analyst  [merged: verify + gap-check]
- [ ] archive       (moved to .specaffold/archive/)     — TPM

## Notes
<!-- date + role + what changed -->
- 2026-04-26 PM — request intake; has-ui=true; raw ask captured; ComfyUI parallels (DAG view + FS-watch) recorded in Context section
- 2026-04-26 request — tier standard proposed (standard) accepted by user
- 2026-04-26 Designer — produced 3-screen HTML mockup: DAG graph view (plan state), partial-tasks implement state, live-update affordance closeup; 5 open questions filed in notes.md
- 2026-04-26 design — user resolved 5 open questions (340px card, keep bypass arc, progress bar for tasks, parse tasks.md on frontend, grey pip + toast on watcher drop); recorded under "Resolved decisions" in notes.md
- 2026-04-26 PM — wrote 03-prd.md: R1–R19 (graph view R1–R9, tasks contract R10–R11, live updates R12–R16, preservation R17–R19); §7 zero blockers; resolved decisions folded into ACs; six B1 smoke checks pinned as R17 baseline
- 2026-04-26 Architect — wrote 04-tech.md: D1–D10 + 0 blockers + 8 risks; D1 hand-laid SVG over React Flow (bundle + read-only by-construction); D2 notify 8.x + notify-debouncer-full 0.6 with 150ms window watching .specaffold/ per repo; D3 three IPC events (sessions_changed kept, artifact_changed new, watcher_status new); D4 hooks-not-store (useArtifactChanges/useWatcherStatus/useTaskProgress); D5 frontend regex parse for tasks.md; D6 full polling removal, slider becomes inert vestige; D7 component delta (+SessionGraph/TaskProgressBar/LiveWatchFooter, −StageChecklist/PollingFooter); D9 maps every AC1–AC19 to unit/integration/static/manual; D10 sandbox-HOME flagged for measure-latency.sh
- 2026-04-26 TPM — wrote 05-plan.md: 18 tasks across 5 waves (W1 foundations T1–T4, W2 frontend leaves + setup wiring T5–T9, W3 integration + polling removal T10–T12, W4 tests + smoke T13–T16, W5 polish T17–T18); critical path T1→T5→T11→T13→T16; T5 carries explicit Wiring task marker; T11 has consumer-grep gate + STATUS Notes hook

- 2026-04-26 orchestrator — tier upgrade standard→audited: security-must finding in T2 (slug/repoPath input-validation gap on read_artefact IPC, W1 review)
- 2026-04-26 review result — wave 1 verdict=BLOCK blocking-tasks=T2; T1/T4 non-blocking (T1 sec/perf NITS, T4 style NITS); auto-retry T2 (attempt 1/2)
- 2026-04-26 review result — wave 1 retry=PASS; T2 fix `9f65e1f` cleared all 3 axes; final aggregate=NITS (T1 + T4 retain NITS findings; folded into merge commits)
- 2026-04-26 implement wave 1 done — T1, T2, T3 (folded), T4 merged (Cargo.toml conflict resolved: dedup notify deps + keep tokio sync feature); cargo build PASS post-merge
- 2026-04-26 Developer — T5: .setup() swap complete; spawn_watcher wired; cargo build PASS; notify_dedupe_test 4/4 PASS
- 2026-04-26 review result — wave 2 verdict=NITS (15 reviewers, 0 must, ~6 should/advisory across T5/T6/T8/T9 — all WHAT-comments or already-flagged W1 items); all 5 tasks merged
- 2026-04-26 implement wave 2 done — T5, T6, T7, T8, T9 merged (theme.css + components.css conflicts auto-resolved per parallel-safe-append-sections; both T6/T8 token blocks kept disjoint); tsc clean on new files
- 2026-04-26 review result — wave 3 verdict=BLOCK blocking-tasks=T12 (style must: `_allow` key embeds scaff-lint directive as dead JSON in i18n bundle); T10 NITS (2 should — duplicate useTaskProgress, repoPath traversal); T11 PASS all 3 axes; auto-retry T12 (attempt 1/2)
- 2026-04-26 review result — wave 3 retry=PASS; T12 fix `5eead94` removed `_allow` sentinel; allowlist clause added in bin/scaff-lint for flow-monitor/src/i18n/*.json (narrow scope); all 3 axes PASS; final wave 3 aggregate=NITS
- 2026-04-26 Developer — T11 polling fully removed; consumer-grep gate clean; lib.rs run_session_polling deleted
- 2026-04-26 implement wave 3 done — T10, T11, T12 merged (STATUS.md merge conflict resolved); cargo build PASS, tsc clean (only 2 pre-existing RepoSidebar errors)
- 2026-04-26 review result — wave 4 verdict=BLOCK blocking-tasks=T16 (perf must: `date +%s` shell-out per loop iteration in measure-latency.sh write-loop); T13/T15 PASS all 3 axes; T14 style NITS (1 unused const); T16 sec advisory (FIXTURE_SLUG traversal in sandbox); auto-retry T16 (attempt 1/2)
- 2026-04-26 review result — wave 4 retry=PASS; T16 fix `84e4c53` removed date shell-out from write loop + added FIXTURE_SLUG traversal guard (advisory→PASS); all 3 axes PASS; final wave 4 aggregate=NITS
- 2026-04-26 implement wave 4 done — T13, T14, T15, T16 merged (all clean merges; 1452 LOC total: integration test + 5 vitest files + 2 bash scripts + DEV log instrument)
