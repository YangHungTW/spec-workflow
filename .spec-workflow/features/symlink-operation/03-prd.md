# PRD — symlink-operation

_2026-04-16 · PM_

## 1. Overview

This repo (`spec-workflow`) is the source of truth for the YHTW virtual-team agents, commands, and team-memory that live under its local `.claude/` directory. To reuse them from any other project, a user needs those subtrees exposed under the global `~/.claude/` config directory that Claude Code reads. Today that's done by hand and drifts whenever new files are added. This feature delivers a single in-repo POSIX bash script with three subcommands — `install`, `uninstall`, `update` — that create, remove, and reconcile the necessary symlinks safely and idempotently on macOS and Linux.

## 2. Goals / Non-goals

### Goals
- Expose `.claude/agents/YHTW`, `.claude/commands/YHTW`, and `.claude/team-memory/**` from this repo under the user's `~/.claude/` tree via symlinks.
- Every subcommand is safe to re-run (idempotent), fails loudly on conflicts, never clobbers user data, and emits a clear per-path summary.
- `update` self-heals drift: adds missing managed links and removes orphans the tool can prove it owns.
- `uninstall` removes exactly what the tool created, leaving unrelated files untouched.
- Zero install-time dependencies on macOS + Linux (ships with the repo, runs under stock bash).

### Non-goals
- Windows support.
- Managing any `.claude/` subtree other than `agents/YHTW`, `commands/YHTW`, and `team-memory/`.
- Copy-based install, file watchers, or auto-sync daemons.
- Editing content inside agents / commands / memory files.
- Publishing as a standalone package for third parties.

## 3. User stories

1. **First-time setup.** As the repo owner on a fresh machine, I clone this repo and run `install` so that Claude Code in any other project can see my YHTW agents, commands, and team memory via `~/.claude/`.
2. **Keeping global in sync.** As the repo owner, after I add a new agent, command, or team-memory file (or rename/delete one), I run `update` so the global tree reflects the repo state without me having to tear down and reinstall.
3. **Clean removal.** As the repo owner, I run `uninstall` before deleting or moving the repo, and I'm confident it removes only the links this tool created and leaves any other files I keep under `~/.claude/` alone.
4. **Safe preview.** Before any mutating run, I can pass `--dry-run` to see every action the tool would take, with conflicts surfaced, and nothing changes on disk.

## 4. Functional requirements

### Path model

**R1 — Source paths.** The tool resolves its repo root as the parent of the directory containing the script itself (absolute path, symlinks resolved). All source paths are relative to that root:
- `<repo>/.claude/agents/YHTW/` (directory)
- `<repo>/.claude/commands/YHTW/` (directory)
- `<repo>/.claude/team-memory/**` (walked as a tree; see R4)

**R2 — Target paths.** Targets are under `$HOME/.claude/` (expanded from `$HOME`, never hard-coded). The tool must create any missing parent directories under `~/.claude/` as plain directories (not symlinks) to host the managed links.

**R3 — Symlink targets are absolute.** Every symlink the tool creates points at an absolute path inside the repo. Rationale: makes `ls -l` diagnosable and matches the decision in §2 of the brainstorm. Moving the repo requires re-running `install`; this is documented user-visible behavior, not a bug.

### Link inventory

**R4 — Managed link set.** The tool manages exactly this set of links; anything outside it is out of scope:

| Kind | Target (under `~/.claude/`) | Source (under `<repo>/.claude/`) |
|------|-----------------------------|-----------------------------------|
| directory symlink | `agents/YHTW` | `agents/YHTW` |
| directory symlink | `commands/YHTW` | `commands/YHTW` |
| file symlink (per file) | `team-memory/<relpath>` | `team-memory/<relpath>` for every regular file under the source subtree |

The `team-memory/` subtree is walked at tool-run time. Any regular file reachable from `<repo>/.claude/team-memory/` — including `README.md`, each role's `index.md`, and any `*.md` memory entry — becomes its own managed link at the mirrored path under `~/.claude/team-memory/`. Intermediate directories under `~/.claude/team-memory/` are created as plain directories, not linked.

**R5 — `team-memory/index.md` handling.** The source tree does not currently contain a top-level `team-memory/index.md`; per-role `index.md` files under `team-memory/<role>/` do exist and are required reading for every role agent (per the team-memory protocol). All regular files discovered by the walk in R4 are linked, with no exclusions. If a top-level `team-memory/index.md` is added later, it will be linked on the next run by the same rule. No filename is special-cased.

### `install`

**R6 — `install` creates the full managed set.** For every entry in the managed set (R4), `install` creates the symlink if the target path is empty. If any target is already in its desired state (a symlink into this repo's tree at the right source), `install` leaves it alone and reports `already`. If any target has a conflict (see R9), `install` reports and skips it, continuing with the remaining paths, and exits non-zero at the end (R12).

**R7 — `install` creates parents.** Missing directories along the target path (e.g. `~/.claude/`, `~/.claude/agents/`, `~/.claude/team-memory/<role>/`) are created as plain directories with default permissions. The tool records which directories it created so `uninstall` can optionally clean them up (R8).

### `uninstall`

**R8 — `uninstall` removes only tool-owned links.** A target path is considered tool-owned iff it is a symlink AND its resolved link-target path begins with this repo's absolute root AND the managed-set plan (R4) includes that target path. For each such path, `uninstall` removes the symlink. Any target that is a real file, a real directory, a symlink pointing outside this repo, or a symlink at a path not in the managed set is left untouched and reported as `skipped (not-ours)`. After removing links, `uninstall` removes the parent directories it would have created (R7) **only if they are empty**; non-empty dirs are left alone. `uninstall` never removes `~/.claude/` itself.

### `update`

**R9 — `update` is a reconciler.** `update` computes the managed-set plan (R4) and, for every target path:
- if the correct symlink exists → `already`;
- if the target is empty → create the link (`created`);
- if the target is a broken symlink pointing into this repo's tree → treat as tool-owned, replace it (`created`, with a note that a broken link was replaced);
- if the target has any other conflict → report and skip per R10.

Additionally, `update` walks the existing tool-owned links under `~/.claude/agents/YHTW`, `~/.claude/commands/YHTW`, and `~/.claude/team-memory/` and **prunes orphans**: a symlink at a path under the managed roots whose link-target is inside this repo but either (a) that source file/dir no longer exists, or (b) the path is no longer in the current managed-set plan (e.g. a team-memory file removed from the repo). Pruned links are reported as `removed (orphan)`. Empty managed parent dirs left behind after pruning are removed only if the tool created them.

### Conflict handling

**R10 — Conflict matrix.** For every target path, the tool classifies its current state and acts as follows. This applies uniformly to `install` and `update`.

| Current state at target | Action | Report |
|-------------------------|--------|--------|
| Nothing exists | Create symlink | `created` (or `would-create` under `--dry-run`) |
| Symlink → correct source in this repo | No-op | `already` |
| Symlink → wrong path in this repo | Skip | `skipped (conflict: wrong-source)` |
| Symlink → outside this repo | Skip | `skipped (conflict: foreign-symlink)` |
| Broken symlink → into this repo | Replace | `created (replaced-broken)` |
| Broken symlink → outside this repo | Skip | `skipped (conflict: foreign-broken-symlink)` |
| Real file | Skip | `skipped (conflict: real-file)` |
| Real directory | Skip | `skipped (conflict: real-dir)` |

**R11 — No `--force` flag in v1.** The tool ships with **no** `--force` option. Conflicts are reported and skipped; the user resolves them manually by inspecting and removing the offending path. Rationale: the cost of a wrong automated overwrite (losing a user-authored file or another repo's symlink) is strictly higher than the cost of one extra manual `rm`. This is a deliberate trade-off — simplicity and safety over convenience. A future `--force-symlinks` (wrong-symlinks only, never real files) may be added in a later iteration if demand appears, but is explicitly out of scope for v1.

### Flags, output, and exit status

**R12 — `--dry-run`.** Every subcommand accepts `--dry-run`. With it, the tool computes the full plan and prints the per-path report with verbs in the "would-" form (`would-create`, `would-remove`, `would-skip`) and performs **zero** filesystem mutations. Exit status under `--dry-run` is 0 unless planning itself failed (e.g. repo root could not be resolved).

**R13 — Per-path report.** Every run, including `--dry-run`, ends with one line per managed path plus any orphan it discovered. Each line has a verb label from this closed set: `created`, `created (replaced-broken)`, `already`, `removed`, `removed (orphan)`, `skipped (conflict: <reason>)`, `skipped (not-ours)`, plus the `would-*` variants under `--dry-run`. A final summary line counts each category.

**R14 — Exit codes.**
- `0` — every managed path converged to its desired state (or, under `--dry-run`, the plan was produced without error).
- non-zero (`1`) — at least one path was skipped due to a conflict, or any filesystem operation failed. Orphan pruning failures also yield non-zero.

The tool reports everything it can before exiting; it does not abort on first conflict.

**R15 — Verbose is default; no `--quiet` in v1.** The per-path report from R13 is always printed. There is no `--quiet` flag; users who want silence can redirect stdout. This keeps the tool transparent about what it's doing.

### Platform and dependencies

**R16 — POSIX bash on macOS + Linux.** The script runs under `/usr/bin/env bash` using only utilities available on stock macOS and mainstream Linux: `ln`, `readlink`, `rm`, `mkdir`, `find`, `test`. The script must tolerate BSD vs. GNU `readlink` differences (brainstorm §2 flag). Windows is not supported and the tool may refuse to run on it with a clear message.

## 5. Acceptance criteria

Each criterion is checkable end-to-end by QA-tester.

- **AC1 (install, clean host).** On a host with no `~/.claude/` present, `install` exits 0, creates `~/.claude/agents/YHTW`, `~/.claude/commands/YHTW`, and file-level links for every regular file under `<repo>/.claude/team-memory/`. Every link resolves back to the corresponding absolute path inside this repo. Maps to R1, R2, R3, R4, R6, R7.
- **AC2 (idempotent install).** Running `install` twice in a row produces the same filesystem state; the second run reports `already` for every managed path and exits 0. Maps to R6, R10.
- **AC3 (install with real-file conflict).** With a regular file pre-placed at `~/.claude/agents/YHTW`, `install` exits non-zero, leaves the real file untouched, and reports `skipped (conflict: real-file)` for that path while still creating the other managed links. Maps to R6, R10, R11, R14.
- **AC4 (uninstall scope).** After a successful `install`, `uninstall` exits 0 and removes every link in the managed set. A hand-placed real file or foreign symlink under `~/.claude/team-memory/` (at a path not in the managed set, or at a managed path pointing outside this repo) is left untouched and reported as `skipped (not-ours)`. `~/.claude/` itself is not removed. Maps to R8.
- **AC5 (uninstall empty-dir cleanup).** After `uninstall` on a host where the tool created `~/.claude/agents/`, `~/.claude/commands/`, and `~/.claude/team-memory/<role>/` dirs and they are now empty, those directories are removed. If any of them contains an unrelated file, it is left in place. Maps to R8.
- **AC6 (update adds missing).** After `install`, add a new file `<repo>/.claude/team-memory/shared/glossary.md`. Running `update` creates the matching link at `~/.claude/team-memory/shared/glossary.md`, reports `created` for it and `already` for every other path, exits 0. Maps to R9.
- **AC7 (update prunes orphans).** After `install`, delete `<repo>/.claude/team-memory/shared/glossary.md` (having been linked previously, so a now-broken managed symlink remains globally). Running `update` removes the broken link at `~/.claude/team-memory/shared/glossary.md` and reports `removed (orphan)`, exits 0. A foreign broken symlink under the same dir is left untouched and not reported as ours. Maps to R9.
- **AC8 (update with conflict).** With a real file sitting at a managed target path, `update` skips that path with `skipped (conflict: real-file)`, still reconciles every other path, and exits non-zero. Maps to R9, R10, R14.
- **AC9 (`--dry-run` mutates nothing).** `install --dry-run`, `uninstall --dry-run`, and `update --dry-run` all exit 0 on a solvable plan, print a full `would-*` report, and leave the filesystem byte-identical to before. Verified by hashing the target tree before and after. Maps to R12.
- **AC10 (absolute link targets).** Every link the tool creates has an absolute link-target path starting with this repo's resolved absolute root. Verified with `readlink` on each managed path. Maps to R3.
- **AC11 (per-path report + exit code consistency).** Every run emits one labeled line per managed path plus any orphan, ending with a summary count. Exit code is 0 iff no line was a `skipped (conflict:*)` or a failure. Maps to R13, R14.
- **AC12 (cross-platform bash).** The script runs end-to-end on macOS (BSD userland) and on a mainstream Linux distro (GNU userland) without modification. Maps to R16.

## 6. Edge cases explicitly addressed

- **Target is correct symlink already** — reported `already`, not re-created (R10).
- **Target is wrong symlink into another clone of this repo** — classified as `wrong-source` if the path matches the managed set but the source path differs; skipped with conflict (R10). The tool does not attempt to detect "another clone" heuristically; it compares absolute link-target to the expected source.
- **Target is a symlink pointing outside this repo** — `foreign-symlink`, skipped (R10).
- **Target is a broken symlink into this repo** (source deleted between installs) — replaced on `install`/`update`; reported `created (replaced-broken)` (R10) or pruned as orphan on `update` (R9) depending on whether the path is still in the managed plan.
- **Target is a broken symlink pointing outside this repo** — skipped, not considered ours (R10).
- **Target is a real file or real directory** — always skipped; never clobbered; no `--force` exists (R11).
- **Parent dir `~/.claude/` missing** — created by `install` / `update`; never removed by `uninstall` (R7, R8).
- **Repo moved after `install`** — all managed links become broken; `update` will prune them as orphans (since their targets no longer exist) and, because the repo root the script now sees is the new location, will create fresh links at the same managed paths pointing at the new location. Documented as supported recovery (R3, R9).
- **Tool run from a different cwd** — script resolves its own path and derives the repo root; cwd is irrelevant (R1).
- **`team-memory/` gains a new role subdir** — discovered by the walk; parent dir auto-created under `~/.claude/team-memory/`; files linked (R4, R7).
- **A user adds their own file under `~/.claude/team-memory/<role>/`** — ignored by the tool; not in the managed set, not a tool-owned link, never touched by `install`, `update`, or `uninstall` (R4, R8, R9).
- **Two clones of this repo both try to `install`** — second clone's `install` will find the managed links already pointing into the first clone, classify them as `wrong-source`, skip them, and exit non-zero. The user must `uninstall` from the first clone (or manually remove) before installing the second. This is explicitly the intended behavior: the managed paths have a single source of truth.

## 7. Open questions / blockers

None. Both open issues from the brainstorm are resolved above:
- Q1 (top-level `team-memory/index.md`) resolved in R5: no top-level index exists today; all regular files discovered by the walk are linked with no exclusions, including per-role `index.md` files which the protocol hard-depends on.
- Q2 (`--force` scope) resolved in R11: no `--force` flag ships in v1; conflicts are reported and skipped.

Nice-to-clarify (not blocking):
- Final script name and in-repo location (e.g. `bin/yhtw-claude-link` vs. `scripts/claude-links.sh`) — Architect's call.
- Whether to add a `make install` / `make uninstall` / `make update` wrapper as a convenience — orthogonal to this PRD.

## 8. Out of scope

- Windows.
- Any `.claude/` subtree other than `agents/YHTW`, `commands/YHTW`, `team-memory/`.
- Copy-based install, watchers, auto-sync daemons.
- Editing agent / command / memory content.
- Publishing as a third-party package.
- `--force` of any kind in v1 (may be revisited later, symlinks-only).
- `--quiet` / log-level flags in v1.
- A GUI or TUI.
