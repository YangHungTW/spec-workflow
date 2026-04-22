# Request

**Raw ask** (verbatim, user wrote three shorthand lines in zh-TW):

> AGENT 有顏色
> monitor 要能看到 archive
> monitor 還沒有文件就不應該能點進去

Interpretation (three UI polish items in the `flow-monitor` Tauri app, which is the GUI monitor for specaffold features):

1. **Agent column is color-coded** — each role (PM, Architect, TPM, Developer, QA-analyst, QA-tester, Designer) renders with a distinguishable color in the monitor's agent/role indicator so the active role is scannable at a glance.
2. **Archived features are visible in the monitor** — the monitor currently surfaces only active features under `.specaffold/features/<slug>/`; archived features under `.specaffold/archive/` must also be browsable (read-only is sufficient; the user did not ask to re-open archives).
3. **Stages with no file yet are not clickable** — if a feature has not yet produced a given artefact (e.g. `03-prd.md` before PRD stage runs), the corresponding tab / row in the monitor must be disabled or otherwise non-navigable; clicking must not land the user on a broken / empty / 404 view.
4. **CLI agent colors aligned with monitor palette** [CHANGED 2026-04-22] — the 10 scaff agents under `.claude/agents/scaff/` get `color:` frontmatter entries drawn from Claude Code's 8 predefined color names; the monitor's agent palette uses the same 8 names, mapped to CSS colors, so CLI transcripts and the monitor render the same role in the same color.

**Context**:
- Requester: repo owner (sole user), 2026-04-22.
- Why now: the flow-monitor Tauri app is in active use for observing feature runs; these three rough edges friction day-to-day use (agent identity hard to spot; archives invisible; empty stages produce confusing navigation dead-ends).
- Constraints: changes are confined to the `flow-monitor` Tauri frontend; no changes to specaffold CLI, features-tree schema, or archive layout.

**Success looks like**:
- (1) Opening the monitor on any feature shows the active agent rendered in a color distinct from the other roles; the mapping is consistent across features and sessions.
- (2) The monitor lists and lets the user inspect features located under `.specaffold/archive/` in addition to `.specaffold/features/`; archived features are visually distinguishable from active ones (e.g. badge or section header — exact treatment deferred to design stage).
- (3) In the monitor, any stage/artefact link whose underlying file does not yet exist on disk renders in a disabled state (non-clickable, visually muted); clicking a present artefact still opens it as today.
- (4) [CHANGED 2026-04-22] Each of the 10 scaff agents under `.claude/agents/scaff/` carries a `color:` frontmatter entry drawn from Claude Code's 8 predefined color names, and the monitor's agent palette maps those same 8 names to CSS colors, so a given role appears in the same color in CLI transcripts and in the monitor.

**Out of scope**:
- Editing / re-opening / mutating archived features from the monitor.
- Changing the set of stages shown or the on-disk layout of `.specaffold/features/*`.
- Theming / dark-mode / broader restyle of the monitor beyond the three items above.
- Accessibility audit of the agent-color palette (can be picked up separately if needed).

**UI involved?**: yes

**Scope widened on 2026-04-22**: original ask covered flow-monitor UI only; during design review the user accepted extending to `.claude/agents/scaff/*.md` color frontmatter so CLI and monitor share one palette.
