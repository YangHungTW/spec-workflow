# spec-workflow

Role-based spec-driven development workflow for Claude Code. A small virtual team (PM, Designer, Architect, TPM, Developer, QA-analyst, QA-tester) drives every feature through numbered markdown artifacts.

## Flow

```
/specflow:request      → PM intake
/specflow:brainstorm   → PM explores approaches
/specflow:design       → Designer (only if has-ui: true) — uses pencil/figma MCP if available, else HTML mockup
/specflow:prd          → PM writes requirements
/specflow:tech         → Architect picks tech + designs system architecture
/specflow:plan         → TPM produces implementation plan
/specflow:tasks        → TPM decomposes into ordered tasks
/specflow:implement    → Developer runs each wave of tasks in parallel via git worktrees (TDD per task)
/specflow:gap-check    → QA-analyst: PRD/tech ↔ tasks ↔ diff
/specflow:verify       → QA-tester: runs acceptance criteria
/specflow:archive      → TPM closes out
```

Shortcut — advance one stage at a time based on STATUS:

```
/specflow:next <slug>
```

Revisions:

```
/specflow:update-req    /specflow:update-tech    /specflow:update-plan    /specflow:update-task
```

Team memory:

```
/specflow:remember <role> "<lesson>"   # manual save
/specflow:promote <role>/<file>        # local → global
```

Two-tier memory: `~/.claude/team-memory/<role>/` (global) + `<repo>/.claude/team-memory/<role>/` (local). Agents read both on every invocation. `/specflow:archive` runs a retro that polls each role for lessons. See `.claude/team-memory/README.md` for the full protocol.

## Layout

```
.claude/
  agents/   pm.md designer.md architect.md tpm.md developer.md qa-analyst.md qa-tester.md
  commands/ request.md brainstorm.md design.md prd.md tech.md plan.md tasks.md
            implement.md gap-check.md verify.md archive.md
            update-req.md update-tech.md update-plan.md update-task.md
.spec-workflow/
  features/<slug>/
    00-request.md
    01-brainstorm.md
    02-design/           # only if has-ui
    03-prd.md
    04-tech.md
    05-plan.md
    06-tasks.md
    07-gaps.md
    08-verify.md
    STATUS.md
  archive/<slug>/
```

## Using in another project

Symlink or copy `.claude/` and `.spec-workflow/features/_template/` into the target repo.

---

## bin/claude-symlink — share .claude across projects

`bin/claude-symlink` is a zero-dependency bash script that creates, removes, and
reconciles symlinks from `~/.claude/` back to this repo's `.claude/` tree. It lets
Claude Code in any other project pick up the specflow agents, commands, and team-memory
without copying files.

### What it does

The tool manages exactly three kinds of targets under `~/.claude/`:

| Target (under `~/.claude/`) | Source (under `<repo>/.claude/`) |
|-----------------------------|----------------------------------|
| `agents/specflow`               | `agents/specflow` (directory symlink) |
| `commands/specflow`             | `commands/specflow` (directory symlink) |
| `team-memory/<relpath>`     | one file symlink per regular file under `team-memory/` |

Every symlink points at an **absolute path** inside the repo, so `ls -l` is always
diagnosable. Moving the repo requires re-running `install` (see Recovery below).

### Install / uninstall / update

```sh
# First-time setup — creates all managed symlinks
bin/claude-symlink install

# Remove only the symlinks this tool created; leaves other ~/.claude/ content alone
bin/claude-symlink uninstall

# After adding, renaming, or deleting files under .claude/team-memory/
# Adds missing links, replaces broken owned links, prunes orphaned owned links
bin/claude-symlink update
```

All three subcommands are safe to re-run. A second `install` on an already-installed
state reports `[already]` for every path and exits 0.

### --dry-run preview

Pass `--dry-run` to see exactly what any subcommand would do without touching the
filesystem:

```sh
bin/claude-symlink install --dry-run
bin/claude-symlink update --dry-run
```

`--dry-run` prints `would-create`, `would-remove`, or `would-skip` verbs and always
exits 0 (unless planning itself fails, e.g. the repo root cannot be resolved).

### Supported platforms

- macOS (bash 3.2+, BSD userland)
- Linux (bash 3.2+, GNU userland)

Windows (MINGW / MSYS / Cygwin) is not supported; the script exits 2 with a clear
message on those shells.

### Recovery from a moved repo

All symlinks created by this tool are absolute. If you move or re-clone the repo to
a new path:

1. `bin/claude-symlink uninstall` from the **old** location (if still accessible), or
   manually remove the broken links.
2. `bin/claude-symlink install` from the **new** location.

Alternatively, `update` in the new location will detect any `broken-ours` links
(broken symlinks whose raw target was inside the old repo path) and replace them with
fresh links pointing at the new location — then report `created:replaced-broken`.

### Conflict reference

When a target path cannot be safely managed, the tool skips it and reports a
`skipped:<reason>` verb. Exit code is 1 when any skip occurs. Resolve conflicts
manually; there is no `--force` flag in v1.

| Verb | What it means | Manual remediation |
|------|---------------|--------------------|
| `skipped:real-file` | A real file occupies the target path. | Inspect (`ls -la $target`), back it up if needed, `rm` it, then re-run `install`/`update`. |
| `skipped:real-dir` | A real directory occupies the target path. | Inspect, back it up, `rm -rf` if confirmed unwanted, re-run. |
| `skipped:foreign-symlink` | A live symlink at this path points outside this repo (likely from another tool). The tool refuses to overwrite it. | Manually `rm` the foreign symlink, then re-run. |
| `skipped:foreign-broken-symlink` | A broken symlink at this path points outside this repo. | Manually `rm` the broken symlink, then re-run. |
| `skipped:not-ours` (uninstall only) | A symlink at a managed path is not owned by this tool. Left untouched. | Manual cleanup if you intended to remove it. |

### Caveats

**Orphan-walk and user-created symlinks under `team-memory/`.** The `update`
subcommand walks `~/.claude/team-memory/` for owned orphan links to prune. Ownership
is determined by a single rule: the resolved link target begins with
`<repo>/.claude/` (with trailing slash). This means a user-created symlink under
`~/.claude/team-memory/` that **happens to point into this repo** is
indistinguishable from one the tool created. If that path is not in the current
managed plan, `update` will treat it as an orphan and remove it. This is documented
behavior, not a bug — the ownership contract is prefix-based, and the remedy is to
not place hand-crafted symlinks pointing into this repo under `~/.claude/team-memory/`.
