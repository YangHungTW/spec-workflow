# Request

**Raw ask**: Rename the product from spec-workflow / specflow to **Specaffold** (portmanteau of "spec" + "scaffold"), and introduce **`scaff`** as the short CLI alias; update slash commands, agent names, documentation, README, and internal references accordingly.

**Context**: The product has lived under two overlapping names — `spec-workflow` (repo / directory) and `specflow` (CLI, slash-command namespace, agent prefix). Users and contributors hit the name collision every time they mention the tool. A product-naming brainstorm with the user selected **Specaffold** as the single canonical name (spec + scaffold captures the feature-intake-to-archive flow) and **`scaff`** as the short CLI alias (9-letter `specaffold` is painful to type at a shell prompt). No deadline; the motivation is reducing contributor friction and preparing the repo for a public identity before the next round of feature work builds on top of the current names.

**Success looks like**:
- A new contributor reading the README and running the tool sees one name — **Specaffold** — with `scaff` as the short-form CLI they actually type.
- Slash commands are invoked under the new namespace (e.g. `/specaffold:request` or a shorter form — see open question below); agent names no longer start with `specflow-`.
- All user-facing documentation (README, top-level docs, slash-command descriptions, agent frontmatter) refers to Specaffold; no lingering `spec-workflow` or `specflow` strings remain in user-visible surfaces.
- Internal references (script names, directories, rule/memory paths, hook script contents) are updated consistently; `grep -r "spec-workflow\|specflow"` on the repo returns either zero hits or only intentional carryover (e.g. git history, archived-feature slugs, explicit migration-notes).
- The harness still runs end-to-end on itself (self-dogfood): a fresh `/specaffold:request <ask>` (or the renamed equivalent) on a new feature works without any leftover `specflow-*` dispatch errors.

**Out of scope**:
- No functional changes to the workflow stages, tier model, or orchestration logic — this is a rename-only feature.
- No new features, agents, or rules; existing behaviour is preserved verbatim under the new names.
- No public release, package-publishing, or repo-transfer steps (the GitHub repo rename, if any, is a separate operational decision; this feature scopes only the in-tree rename).
- No change to archived features' slugs or historical STATUS/PRD/plan text — archived artifacts retain their original names as a historical record.
- No UX / visual-identity work (logo, brand palette, marketing copy beyond the README tagline).

**UI involved?**: no — this is a dev-tooling / CLI and documentation rename; there is no application UI to restyle. (`has-ui: false`.)

## Open questions for the user

- **TODO(user): slash-command prefix** — should the new prefix be the full `/specaffold:*` (matches product name) or the short `/scaff:*` (matches CLI alias)? Brainstorm will sketch both and recommend one.
- **TODO(user): agent-name prefix** — rename `specflow-*` agents to `specaffold-*` (long, matches product) or `scaff-*` (short, matches CLI)? Must match the slash-command decision above for consistency.
- **TODO(user): on-disk directory rename** — should `.spec-workflow/features/` become `.specaffold/features/` (clean break) or stay put (avoid migrating every archived feature)? If renamed, is a backwards-compat symlink needed during transition?
- **TODO(user): repo directory rename** — the working tree currently sits at `/Users/yanghungtw/Tools/spec-workflow`. Rename to `specaffold` on disk? (Affects any absolute-path references in agent prompts, rules, archived STATUS files.)
- **TODO(user): deprecation period for old names** — should `specflow`-prefixed commands/agents keep working as aliases for one cycle (with a deprecation warning) or be removed outright at cutover? Alias period reduces user disruption but doubles the surface to maintain.
- **TODO(user): global install paths** — entries under `~/.claude/` (agents, rules, hooks, team-memory) currently use `specflow` in paths. Rename these too, or leave as-is until the next `claude-symlink install` cycle?
