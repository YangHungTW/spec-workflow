# Request

**Raw ask**: 這個 repo 需要三個功能，一個是 install，會幫我把這個 project .claude 裡的 agents,commands,memory 在 global 建 symlink，另一個是 uninstall，把剛剛做的事都還原，第三個是 update，如果有沒建立的 symlink，就再補上

**Context**: This repo (`spec-workflow`) is the source of truth for the YHTW virtual-team agents, commands, and team-memory that live under its local `.claude/` directory. To reuse them from any other project, the user wants those three subtrees exposed via symlinks under the global `~/.claude/` config dir used by Claude Code. Today this has to be done by hand, which is error-prone and drifts whenever new agents/commands/memories are added. The feature is a small CLI/shell tool in this repo that manages those symlinks.

**Success looks like**:
- `install` creates symlinks under `~/.claude/` that point at this repo's `.claude/agents`, `.claude/commands`, and `.claude/team-memory` (the "memory" the user referenced), so their contents are visible globally to Claude Code.
- `uninstall` removes exactly the symlinks that `install` created and leaves any pre-existing global files or folders untouched.
- `update` is idempotent: it adds any missing symlinks (e.g. a newly added agent file) without touching ones already in place and without duplicating work.
- All three commands are safe to re-run, fail loudly on conflicts (e.g. a real file already sitting at a target path), and give a clear per-path summary of what was created / skipped / removed.

**Out of scope**:
- Windows support (macOS and Linux only, since symlinks + `~/.claude/` are the model).
- Touching any `.claude/` subtree other than `agents`, `commands`, and `team-memory` (e.g. `settings.json`, `skills/`, project-local configs).
- Copy-based install or a file watcher / auto-sync daemon; this is a one-shot CLI.
- Migrating or rewriting content inside agents/commands/memory files; the tool only manages links.
- Publishing as a standalone package / installer for other users.

**UI involved?**: no

**Open questions**:
- Granularity of the symlinks: link the three top-level directories (`agents/`, `commands/`, `team-memory/`) as single symlinks, or link each file inside them individually? This affects how `update` detects "missing" links and how it interacts with any files the user may already have under `~/.claude/agents` etc. — worth resolving in brainstorm.
- Should `update` also prune symlinks that now point at deleted source files, or is pruning strictly an `uninstall`-only concern?
