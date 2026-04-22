# STATUS

- **slug**: 20260422-monitor-ui-polish
- **has-ui**: true
- **tier**: standard
- **stage**: plan
- **created**: 2026-04-22
- **updated**: 2026-04-22

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
- 2026-04-22 PM — intake; ask covers three monitor UI polish items (agent color, archive visibility, disable-click-when-no-file); has-ui=true
- 2026-04-22 request — tier standard proposed (standard) accepted by user
- 2026-04-22 PM — scope widened: +CLI agent color frontmatter (option B) to align with monitor palette; out-of-scope "no CLI changes" bullet retired
- 2026-04-22 Designer — mockup.html + palette.md + notes.md approved by user; 10 roles mapped to 8 CC color names (reviewers share red + axis sub-badge); 4 open questions deferred to PRD
- 2026-04-22 PM — PRD locked R1..R27 / AC1..AC24; 4 open questions resolved with defaults (a=new-row, b=keep-hover, c=block-onSelect, d=defer-dark-mode)
- 2026-04-22 Architect — tech D1..D11 no blockers; palette SSOT = agentPalette.ts + agent-palette.css; 2 new Tauri cmds (list_archived_features, list_feature_artefacts); new AgentPill component; archived read-only via path swap
- 2026-04-22 TPM — plan 19 tasks across 5 waves (W0 foundations 3, W1 rust 4, W2 frontend 5, W3 sidebar+archive 3, W4 disabled-tab 4); D11 wiring as explicit T7
- 2026-04-22 Developer — T1 done (agentPalette.ts + agent-palette.css + test)
- 2026-04-22 Developer — T2 done (10 color: frontmatter added)
- 2026-04-22 review result — wave 0 phase 1 verdict=NITS (T1 dead import afterEach; T2 clean); T1, T2 merged
- 2026-04-22 Developer — T3 done (test/t76_agent_color_frontmatter.sh)
- 2026-04-22 review result — wave 0 phase 2 verdict=NITS (T3 file re-read NIT); T3 merged; wave 0 complete (T1, T2, T3)
- 2026-04-22 Developer — T4 done (archive_discovery.rs + classifier + inline tests)
- 2026-04-22 Developer — T5 done (artefact_presence.rs + guards + inline tests)
- 2026-04-22 review result — wave 1 phase 1 verdict=NITS (T4 path-trav settings, 2 comment WHAT; T5 canonicalize-after-join advisory, redundant metadata advisory); T4, T5 merged
- 2026-04-22 Developer — T6 done (archive_discovery_tests.rs + artefact_presence_tests.rs)
- 2026-04-22 Developer — T7 done (invoke_handler wiring for 2 cmds)
- 2026-04-22 review result — wave 1 phase 2 verdict=NITS (T6 6 WHAT comments in tests; T7 1 comment advisory); T6, T7 merged; wave 1 complete (T4 T5 T6 T7)
- 2026-04-22 Developer — T8 done (components.css: agent-pill + sidebar-dot + archived-section classes, zero hex leaks)
- 2026-04-22 review result — wave 2 phase 1 verdict=NITS (T8 4 style advisories: arch-badge naming, 3 WHAT comments); T8 merged
- 2026-04-22 Developer — T9 done (AgentPill.tsx + test + i18n role.* keys)
- 2026-04-22 review result — wave 2 phase 2 verdict=NITS (T9 test access pattern advisory); T9 merged
- 2026-04-22 Developer — T10 T11 T12 done (SessionCard row, CardDetailHeader next-to-StagePill, NotesTimeline role colouring + normaliseRoleLabel)
- 2026-04-22 review result — wave 2 phase 3 verdict=PASS (T10 T11 T12 all PASS); merged; wave 2 complete (T8 T9 T10 T11 T12). frontend baseline: 429 pass / 11 pre-existing failures unrelated to this feature
- 2026-04-22 Developer — T13 done (sessionStore archivedFeatures + archiveExpanded + settings persistence)
- 2026-04-22 review result — wave 3 phase 1 verdict=NITS (T13 IPC cast advisory, untranslated zh-TW strings, 1 WHAT comment); T13 merged
- 2026-04-22 Developer — T14 done (RepoSidebar agent dot + collapsible Archived section)
- 2026-04-22 Developer — T15 done (archived route + CardDetail path swap + read-only badges)
- 2026-04-22 review result — wave 3 phase 2 verdict=NITS (T14 2 WHAT comments; T15 unused lambda param); T14 T15 merged; wave 3 complete (T13 T14 T15)
- 2026-04-22 Developer — T16 done (TabStrip onClick guard + aria-disabled + tabIndex)
- 2026-04-22 Developer — T17 done (components.css disabled-tab opacity + ::after tooltip)
- 2026-04-22 review result — wave 4 phase 1 verdict=NITS (T16 2 WHAT comments; T17 rgba theme-var drift); T16 T17 merged
- 2026-04-22 Developer — T18 done (CardDetail exists wiring from list_feature_artefacts)
