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
- 2026-04-22 Developer — T5 done (artefact_presence.rs + guards + inline tests)
