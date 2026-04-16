# Brainstorm — symlink-operation

_2026-04-16 · PM_

## 1. Resolving the two open questions

### Q1. Granularity: directory-level vs. file-level symlinks

The repo already segregates its content under namespaced sub-paths:
- `.claude/agents/YHTW/` (7 agent files)
- `.claude/commands/YHTW/` (18 command files)
- `.claude/team-memory/` (per-role subdirs, no namespace layer)

**Option A — directory-level (3 links)**
- `~/.claude/agents/YHTW → <repo>/.claude/agents/YHTW`
- `~/.claude/commands/YHTW → <repo>/.claude/commands/YHTW`
- `~/.claude/team-memory → <repo>/.claude/team-memory`

Pros: one link per subtree, new files auto-appear, `update` becomes nearly trivial (idempotent re-check of 3 links), uninstall is surgical. The `YHTW/` namespace cleanly isolates this repo's agents/commands from anything else the user keeps under `~/.claude/agents/` or `~/.claude/commands/`, so multiple repos can coexist if each picks its own namespace.

Cons: for `team-memory/`, there is no namespace layer — linking the whole dir means this repo owns every role subdir globally. If another repo (or the user's own hand-written memories) also wants to write to `~/.claude/team-memory/pm/`, they will collide. The team-memory protocol (README line 8–10) already states the global tier is `~/.claude/team-memory/<role>/`, implying a shared namespace.

**Option B — file-level (N links, walk the tree)**
Pros: fine-grained; lets the user drop their own files into the same role subdir without them being swallowed by a directory symlink. Matches how `team-memory/` is meant to be shared-namespace.

Cons: `update` now has to diff source tree vs. global tree on every run; newly added files require re-running `update`; many more link points to reason about on conflict; uninstall has to remember what it created.

**Recommendation: hybrid, driven by whether a namespace layer exists.**
- `agents/YHTW/` and `commands/YHTW/` → **directory-level** (Option A). The `YHTW` namespace already exists precisely to prevent collision, so one link is the right unit.
- `team-memory/` → **file-level**, walking into each `<role>/` subdir and linking individual `*.md` files. This preserves the protocol's shared global namespace (README line 52: agents read `~/.claude/team-memory/<role>/index.md`) and lets other repos / the user contribute memories to the same role folders.

This hybrid costs PRD a little more prose but reflects how the content is actually structured. Blocker question for PRD: **does `index.md` get linked too, or is it treated as a shared file the user owns?** (Leaning: link it; this repo is the canonical source. But the user should confirm.)

### Q2. Should `update` prune dead links?

A "dead link" here means: a symlink under `~/.claude/` that this tool created, pointing at a source path in the repo that no longer exists (file was deleted/renamed).

**Option A — `update` prunes.** `update` becomes "reconcile global state to match repo state": add missing, remove orphaned. One-stop command.

**Option B — `update` only adds; `uninstall` is the only remover.** Simpler mental model per command, but forces the user to `uninstall && install` after a rename, which is heavy-handed.

**Recommendation: `update` prunes, but only symlinks it can prove it owns** (i.e. a symlink at an expected target path whose link target resolves into this repo's `.claude/` tree). Anything else is left alone and reported. This keeps `update` idempotent and self-healing without risking user data. `uninstall` remains the "remove everything this tool ever created" operation.

## 2. Implementation approach

**Option A — POSIX shell script (bash) in the repo.**
Pros: zero install-time dependencies on macOS + Linux (both ship bash / `ln -s` / `readlink`); contributors can read and edit without a toolchain; lives next to the content it manages. Scope is small (3 subcommands, hundreds of lines at most).
Cons: shell error handling is fiddly; `readlink -f` behaves differently on macOS (BSD) vs. Linux (GNU) and needs a workaround.

**Option B — Node.js script.**
Pros: richer stdlib, easier argument parsing, cross-platform path handling.
Cons: adds a Node dependency for a tool that is otherwise content-only; overkill for `ln -s` wrapping; less discoverable for "I just cloned the repo, how do I install?".

**Option C — Makefile with `install` / `uninstall` / `update` targets shelling out.**
Pros: conventional UX (`make install`), auto-lists targets.
Cons: Make on macOS is old; recipe quoting pitfalls; still need a shell script underneath, so this is additive, not a replacement.

**Recommendation: Option A — a single POSIX bash script**, e.g. `bin/yhtw-claude-link` or `scripts/claude-links.sh` (final name is PRD's call). Rationale: the job is symlink plumbing on Unix — match the tool to the problem. A thin `make install` wrapper is fine as a convenience if the user wants it, but the script is the source of truth.

## 3. Edge cases for the PRD to nail down

Target-path state when `install` / `update` runs:
- **(a) Correct symlink already** — no-op, report "ok".
- **(b) Wrong symlink** (points elsewhere, including a different clone of this repo) — fail loudly by default; offer `--force` to replace. Do not silently overwrite.
- **(c) Real file or directory** — fail loudly, never clobber. Exit non-zero, list the conflict, continue with other paths (partial success is allowed; summary reports per-path).
- **(d) Broken symlink** (target missing) — if it points into this repo's tree, treat as ours and replace; otherwise report and skip.

Environment:
- **Parent `~/.claude/` missing** — `install` creates it (and any missing intermediate dirs like `~/.claude/agents/`). `uninstall` does not remove parent dirs it didn't create.
- **Repo moved after install** — this is why link-target path choice matters. Recommend **absolute paths** from the symlink to the repo: simpler to debug (`ls -l` shows the real location) and matches "the repo is the source of truth, it lives somewhere specific". Relative paths would survive a repo move but are harder to reason about and the user's workflow doesn't require portability of an installed state. Document that moving the repo requires re-running `install`.
- **`install` run twice** — idempotent; behaves identically to `update`. In fact, consider making `install` a thin alias for `update` with a "first-time" banner, since the logic is the same: converge to desired state.
- **User hand-edited `~/.claude/` after install** — any target we didn't create is not ours; follow the conflict rules above. Never assume ownership without evidence (symlink resolving into this repo).

Multi-repo coexistence:
- Directory-level links for `agents/YHTW/` and `commands/YHTW/` are safe because the `YHTW` namespace is this repo's. Another repo using e.g. `FOO` namespace gets its own sibling link.
- File-level links for `team-memory/` share the global namespace by design; the hybrid approach (Q1) was chosen for exactly this reason.

Safety:
- Every subcommand supports `--dry-run` printing the exact actions it would take.
- Every run ends with a per-path summary: `created | skipped-exists | skipped-conflict | removed | pruned`.
- Non-zero exit on any conflict so CI / scripts can detect problems.

## 4. CLI shape

**Recommendation: single entrypoint, three subcommands.**

```
<script> install     # create all links, fail on conflict
<script> uninstall   # remove every link this tool created
<script> update      # reconcile: add missing, prune orphaned, skip correct
```

Shared flags: `--dry-run`, `--force` (overwrite wrong symlinks only, never real files), `--verbose`.

Location: committed in the repo, under something like `bin/` or `scripts/`, executable bit set, discoverable from the repo root. Invocation from any cwd via absolute path or via a top-level `make install` / `make uninstall` / `make update` wrapper (optional convenience).

Why one entrypoint: the three subcommands share ~90% of their logic (resolve the link plan, walk it, report). Three separate scripts would duplicate that plan-resolution code. PRD should name the script and subcommands but the three-verb shape matches the raw ask directly.

## Recommendation summary

- **Granularity**: hybrid — directory-level for `agents/YHTW` and `commands/YHTW`, file-level for `team-memory/*/*.md`.
- **Update semantics**: reconcile (add missing + prune orphaned links we own).
- **Implementation**: single POSIX bash script with `install` / `uninstall` / `update` subcommands, absolute link targets, `--dry-run` and per-path summary standard.

## Open questions blocking PRD

1. **`team-memory/index.md` files** — link them as canonical (this repo owns the index) or treat as user-owned and skip? Leaning: link them; confirm with user.
2. **`--force` scope** — should `--force` ever replace a real file/dir, or strictly wrong symlinks? Leaning: symlinks only; real files always require manual resolution.
3. **Script name and exact in-repo path** — nice-to-clarify, not blocking.
