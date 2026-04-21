# Request

**Raw ask**: Switch specflow install model from global (`~/.claude` symlinks) to per-project, with a single global `init` skill as the bootstrap entry point.

**Context**: Today `bin/claude-symlink install` links specflow's agents, commands, hooks, and team-memory into `~/.claude/`, so every Claude Code session on the machine picks up the same specflow version. `bin/specflow-install-hook` then wires SessionStart + Stop hooks into each consumer project's `settings.json`. Rules (`.claude/rules/`) already live per-project because `session-start.sh` reads `<cwd>/.claude/rules/`. Two problems motivate the switch:

1. **No per-project version isolation** — every consumer repo on the machine is forced onto the same specflow checkout. Upgrading specflow globally upgrades every project at once, with no way to pin an older or branch version per repo.
2. **Shared team-memory is semantically wrong** — a project's lessons (decision logs, patterns, retrospectives) belong to that project. Globalising them leaks context between unrelated repos and muddles attribution.

User's proposed shape: each consumer repo gets specflow's `.claude/` contents inside its own `.claude/` tree. The only global artefact is a single `init` skill (e.g. `/init-specflow`) that users invoke from inside any project to seed it. A follow-up `specflow:update` flow pulls source-repo changes into each consumer project on demand, since "update once, propagate everywhere" no longer applies.

Open questions (deferred to brainstorm / PRD, do not resolve here):
- Should `init` symlink, copy, or git-submodule the specflow bits into the target project?
- Versioning story — pin a tag per project, track HEAD, or let the user choose at init time?
- How is `specflow:update` surfaced — another global skill, or a command inside the per-project install?

**Success looks like**:
- A user runs the global `init` skill from inside any target repo and that repo becomes a fully-functional specflow consumer without touching `~/.claude/` beyond the `init` entry point itself.
- Two repos on the same machine can run different specflow versions concurrently; upgrading one does not affect the other.
- A project's `team-memory/` entries stay inside that project — no cross-project leakage, no shared writes under `~/.claude/team-memory/`.
- A documented `specflow:update` path exists so a consumer project can pull newer specflow bits when the user chooses, independently per project.
- Existing consumer repos have a documented migration story off the current global-symlink model (exact shape TBD in PRD).

**Out of scope**:
- Resolving the symlink-vs-copy-vs-submodule choice (brainstorm / PRD decides).
- Specifying the versioning mechanism (pin / HEAD / prompt-at-init) in this intake.
- Designing the `specflow:update` UX beyond "it must exist" (separate stage, possibly a separate feature).
- Publishing specflow to a package registry (npm, Homebrew tap, etc.) — the install source stays this git repo for now.
- Retrofitting historical archived features' memory back into per-project stores.
- Any changes to how `.claude/rules/` loads (already per-project via `session-start.sh`).

**UI involved?**: no — CLI / tooling only.
