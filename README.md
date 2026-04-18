# spec-workflow

Role-based spec-driven development workflow for Claude Code. A small virtual team (PM, Designer, Architect, TPM, Developer, QA-analyst, QA-tester) drives every feature through numbered markdown artifacts.

## Install

### 1. One-time global bootstrap

Copy the init skill from this repo into your global Claude skills directory:

```sh
cp -R .claude/skills/specflow-init ~/.claude/skills/
```

This makes the `/specflow-init` slash-command available in every Claude Code session on this machine.

### 2. Per-consumer initialisation

From inside the **target consumer repo**, run the init skill:

```
/specflow-init
```

For headless or scripted use, invoke the seed binary directly:

```sh
<src>/bin/specflow-seed init --from <src> --ref HEAD
```

Replace `<src>` with the absolute path to this repo and `<ref>` with the pinned commit or tag you want to track.

**What `init` does:**

- Seeds `.claude/agents/specflow`, `.claude/commands/specflow`, `.claude/hooks`, `.claude/rules`, and `.claude/team-memory` skeleton into the consumer repo.
- Seeds `.spec-workflow/features/_template/` as the feature scaffold.
- Records `specflow.manifest` at the repo root with the pinned source ref and a per-file baseline hash for future `update` comparisons.
- Wires consumer-local hook paths into `settings.json` (SessionStart + Stop) using an atomic read-merge-write with `.bak` backup on any pre-existing file.

### 3. Updating to a newer ref

Re-run `update` whenever you want to adopt a newer specflow version:

```sh
bin/specflow-seed update --to <new-ref>
```

Behaviour per file:

- Files byte-identical to the source at the new ref: reported `already`, untouched.
- Files that match the **previous-ref baseline** stored in the manifest (i.e., not locally modified): replaced with new content and reported `replaced:drifted`; pre-replace bytes saved as `<path>.bak`.
- Files that differ from **both** the source and the baseline (user-modified): skipped and reported `skipped:user-modified`; your edits are preserved.
- The manifest ref only advances when the run completes with no `skipped:user-modified` outcomes. If any files are skipped, resolve conflicts first (see [Verb vocabulary](#verb-vocabulary) and [Recovery](#recovery)) then re-run.

### 4. Migrating from the global-symlink model {#migrating-from-the-global-symlink-model}

If this consumer repo currently uses the legacy `bin/claude-symlink` approach (symlinks in `~/.claude/`), run:

```sh
bin/specflow-seed migrate --from <src> --ref HEAD
```

`migrate` performs the same seeding as `init` but recognises that `.claude/agents/specflow` and related paths may already be present via symlinks. It does **not** tear down the shared `~/.claude/*` symlinks — those remain intact so other consumers on the same machine continue to work. Once **every** consumer on the machine has migrated, remove the shared symlinks manually:

```sh
bin/claude-symlink uninstall
```

### Per-project isolation guarantee

Each consumer repo is pinned to its own ref in its own `specflow.manifest`. Team-memory files are local to the consumer and never travel back to the source repo. Two consumers on the same machine can run different specflow versions concurrently without interference.

### Recovery

If a run of `update` leaves `skipped:user-modified` files, the manifest ref is **not** advanced. To resolve:

1. Inspect the diff between your file and the new source content.
2. Either preserve your edit (copy the file to `<path>.bak` manually, then re-run `update` — the tool will treat it as baseline-matched and replace it) or discard it (restore from the manifest baseline, then re-run).
3. After a conflict-free run the manifest advances to the new ref.

If you need to roll back, restore from the `.bak` files the tool produced.

---

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

Use the `init` flow described in [Install](#install) above. The init skill seeds all necessary `.claude/` content and `.spec-workflow/features/_template/` into the consumer repo with a pinned ref.

---

## bin/claude-symlink — share .claude across projects

> **Deprecated** — superseded by the per-project `migrate` flow (see [Install](#install) and [Migrating from the global-symlink model](#migrating-from-the-global-symlink-model)). `bin/claude-symlink` is retained only to maintain existing installs until every consumer on the machine has migrated.

`bin/claude-symlink` is a zero-dependency bash script that creates, removes, and
reconciles symlinks from `~/.claude/` back to this repo's `.claude/` tree. It lets
Claude Code in any other project pick up the specflow agents, commands, and team-memory
without copying files.

### What it does

The tool manages exactly four kinds of targets under `~/.claude/`:

| Target (under `~/.claude/`) | Source (under `<repo>/.claude/`) |
|-----------------------------|----------------------------------|
| `agents/specflow`               | `agents/specflow` (directory symlink) |
| `commands/specflow`             | `commands/specflow` (directory symlink) |
| `hooks`                         | `hooks` (directory symlink — SessionStart + Stop scripts) |
| `team-memory/<relpath>`     | one file symlink per regular file under `team-memory/` |

### Per-project opt-in: wire the hooks

> **Deprecated** — superseded by the per-project `init` / `migrate` flow (see [Install](#install)). The per-consumer `settings.json` wiring is now handled automatically by `specflow-seed init` / `specflow-seed migrate`.

The `hooks` symlink makes `~/.claude/hooks/session-start.sh` and
`~/.claude/hooks/stop.sh` resolvable globally, but each consumer project
still needs to wire them into its own `settings.json`:

```sh
# one-time per machine, run from this repo:
bin/claude-symlink install

# one-time per consumer project, run from the consumer's repo root:
bin/specflow-install-hook add SessionStart ~/.claude/hooks/session-start.sh

# (optional) enable STATUS auto-sync in the consumer project:
bin/specflow-install-hook add Stop ~/.claude/hooks/stop.sh
```

Rules stay per-project: `session-start.sh` reads `<cwd>/.claude/rules/`, so
each project maintains its own rule set.

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

## Verb vocabulary

The `specflow-seed` commands (`init`, `update`, `migrate`) emit exactly the following verbs on stdout, one per managed file. No flow emits a verb outside this set; if a future verb is introduced, the table must be updated first (AC12.b).

| Verb | Meaning | Remediation |
|---|---|---|
| `created` | New file written at a previously-missing path. | None — expected on first init. |
| `already` | Destination is byte-identical to source at the chosen ref. | None. |
| `replaced:drifted` | Destination differed from source but matched the previous-ref baseline in the manifest — replaced with new content; `<path>.bak` holds the pre-replace bytes. | Inspect `.bak`; delete once satisfied. |
| `skipped:user-modified` | Destination differs from source AND differs from the baseline — user edit preserved. | Decide whether to keep the edit (copy to `.bak`, then re-run `update`) or discard it (restore from baseline, then re-run). |
| `skipped:real-file-conflict` | Destination is a directory, symlink, or non-regular file where a regular file is expected. | Remove the offending path manually, then re-run. |
| `skipped:foreign` | Destination is outside the managed subtree. | Should not occur; file a bug if observed. |
| `skipped:unknown-state` | Classifier returned an unrecognised state (defensive wildcard arm). | Should not occur; file a bug if observed — indicates a classifier/dispatcher mismatch. |
| `would-create` / `would-replace:drifted` / `would-skip:already` / `would-skip:user-modified` / `would-skip:real-file-conflict` / `would-skip:foreign` / `would-skip:unknown` | `--dry-run` preview of the above; no mutation. | None. |

## `.claude/rules/` — session-wide guardrails

This repo ships a SessionStart hook that injects a digest of `.claude/rules/`
into every Claude Code session opened here. Rules are **hard** cross-role
guardrails (bash 3.2 portability, sandbox-HOME in tests, no `--force` on user
paths, etc.) — distinct from per-role `.claude/team-memory/` which is soft
craft advisory. The hook is wired in `settings.json`:

```json
{"hooks":{"SessionStart":[{"hooks":[{"type":"command","command":".claude/hooks/session-start.sh"}]}]}}
```

Details (schema, severity vocabulary, authoring checklist): see
[.claude/rules/README.md](.claude/rules/README.md).

## Review capability — multi-axis reviewer team

`/specflow:implement` now includes **inline multi-axis review** between wave
collection and per-task merge. For every completed task in a wave, three
reviewer subagents run in parallel (security / performance / style). Each
loads its own rubric from `.claude/rules/reviewer/<axis>.md`, stays in lane,
and emits a severity-tagged verdict. Any `must` finding blocks the wave
merge; `should` / `advisory` findings are logged to STATUS.

```sh
# one-shot multi-axis review of a feature branch, writes a timestamped report
bin/claude-symlink install
/specflow:review <slug>                  # all three axes in parallel
/specflow:review <slug> --axis security  # single-axis targeted re-review
```

Reports land at `<feature-dir>/review-YYYYMMDD-HHMM.md`. The one-shot command
never advances STATUS and is safe to run at any stage (implement, gap-check,
archive, post-archive).

Rubrics under `.claude/rules/reviewer/` are **agent-triggered**, not
session-loaded — the SessionStart hook deliberately skips this subdir so
rubric content only reaches the reviewer agents that invoke them.

**Escape hatch**: `/specflow:implement --skip-inline-review` bypasses the
inline reviewer dispatch entirely. Uses are logged to STATUS Notes for audit.
Intended for emergencies and for features (like B2.b itself) that deliver the
reviewer capability during their own implement waves.
