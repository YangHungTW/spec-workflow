# Request

**Raw ask**: preflight gate for scaff commands when repo not init'd

**Context**:

The `.claude/commands/scaff/*.md` command surface (18 files: archive, bug, chore, design, implement, next, plan, prd, promote, remember, request, review, tech, update-{plan,req,task,tech}, validate) is exposed user-globally on this machine via symlinks created by `bin/claude-symlink install` (the `symlink-operation` feature):

- `~/.claude/commands/scaff` → `/Users/yanghungtw/Tools/specaffold/.claude/commands/scaff`
- same pattern for `~/.claude/agents/scaff` and `~/.claude/skills/scaff-init`

As a consequence, every project on this machine — including projects that have never been `/scaff-init`'d — sees the full `/scaff:*` slash-command palette. The user observed this and asked why a non-init'd project shows `/scaff:request`.

A grep across all 18 command files for `scaff-init`, `config.yml`, or `specaffold/config` returns zero matches. None of the commands carry a deterministic preflight that refuses to run when `.specaffold/config.yml` is absent. The closest accidental gate is in `request.md` step 3 (`cp .specaffold/features/_template/ ...`), which would fail with a cryptic `cp: cannot stat` error when the template is missing — and even that protection is absent for commands that don't touch the template (e.g. `next`, `validate`, `implement`, `archive`).

Today the missing-init case is caught only when the assistant happens to notice — i.e. by judgment, not by mechanism. A less careful assistant could partially mutate the project (writing files under `.specaffold/`, leaving STATUS notes, even committing) before failing.

This contradicts the project's own `no-force-on-user-paths` and `classify-before-mutate` rules: we instruct scripts to classify before mutating, but the scaff command surface itself doesn't classify "is this a scaff project?" before mutating.

**Success looks like**:

- Every `/scaff:<name>` command except `scaff-init` deterministically checks for `.specaffold/config.yml` before doing any work.
- When the config file is absent, the invoked command emits a single-line refusal that points the user to `/scaff-init`, and exits without writing anything (no STATUS edits, no template copy, no commits).
- When the config file is present, behaviour is unchanged from today (no false positives, no extra prompts).
- The gate is implemented as a shared snippet (e.g. a `_preflight.md` include or a one-line directive at the top of each command file) rather than 17 hand-copied checks — so future scaff commands inherit the gate by construction.
- Any new `/scaff:*` command added later inherits the gate without the author having to remember to add it.

**Out of scope** (already discussed and agreed):

- NOT modifying `scaff-init` itself — it is the init entry point and must work pre-init by definition.
- NOT changing the symlink mechanism in `bin/claude-symlink` — global exposure is correct; the gate goes inside each command, not at the symlink layer.
- NOT auto-running `scaff-init` — gating means "stop and instruct", not "fix it for the user".
- NOT changing how commands behave once the project is init'd.

**Why now**:

Identified this session while reviewing whether agency-agents had anything worth borrowing — the scaff commands' lack of init gating surfaced as a UX hole that contradicts the project's own classify-before-mutate discipline. The friction is small per occurrence but unbounded across the population of non-scaff projects on a developer's machine, and the failure mode (partial mutation by a less careful assistant) is silent rather than loud.

**UI involved?**: no — CLI/markdown-only change to command files; no visual UI, no mockups needed.
