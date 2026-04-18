# PRD — per-project-install

_2026-04-18 · PM_

## 1. Problem statement

Specflow's current global install model (`bin/claude-symlink install`) forces every consumer repo on a machine onto the same specflow checkout via `~/.claude/` symlinks. Two repos cannot run different specflow versions concurrently, and each project's team-memory leaks into a shared `~/.claude/team-memory/` tree that semantically belongs to the project. Users need per-project isolation — each consumer repo owns its own specflow install, pinned to a ref chosen at init time — reached through a single global `init` skill that seeds a target repo from the source repo and a per-project `update` flow that pulls newer bits when the user chooses.

## 2. Users and use cases

1. **New-consumer onboarder.** A developer inside a fresh repo (no `.claude/specflow` tree yet) invokes the global `init` skill once; the repo becomes a fully-functional specflow consumer without any further touches to `~/.claude/`. Expects: pinned ref captured, agents/commands/hooks/team-memory skeleton copied in, settings.json wired.
2. **Existing-consumer updater.** A developer inside a repo that was previously initialised invokes `specflow:update` at their discretion. Expects: newer source-repo bits pulled in at a newly-chosen ref, local edits preserved, backups available for any file that had to be replaced.
3. **Global-to-per-project migrator.** A developer on a machine still running the old `bin/claude-symlink` global install wants to convert a specific consumer repo to the per-project model. Expects: one invocation that seeds the repo from the current global source, removes the corresponding global symlinks, leaves the consumer self-contained — and is safe to run repo-by-repo over time while the global install stays functional for un-migrated repos.
4. **Source-repo maintainer (dogfood case).** The maintainer of this very source repo wants to continue using specflow *on this repo* while implementing the feature that changes how specflow is installed. Expects: the existing global mechanism keeps working throughout this feature's implement stage; this repo is migrated only as the final act.

## 3. Goals

1. **Per-project isolation.** Each consumer repo holds its own copy of specflow's agents, commands, hooks, and a team-memory skeleton, pinned to a specific source-repo ref chosen at init time. Two consumer repos on the same machine can run different specflow versions concurrently.
2. **Single global bootstrap entry.** Exactly one artefact ships globally (the `init` skill); everything else the consumer needs is seeded into the consumer's own tree. No shared-mutable state under `~/.claude/` beyond that entry point.
3. **Team-memory stays local.** Each consumer's team-memory lives in its own committed tree. `init` seeds an empty skeleton (role dirs + indexes only, no inherited lessons), and no flow in this feature ever writes from a consumer back into the source repo's memory.
4. **Safe, classify-before-mutate update and migrate.** `update` and `migrate` never silently clobber user-modified files; both classify each destination into a closed state enum before dispatching any write, back up before replace, and report-and-skip on conflict in the same shape as the existing `bin/claude-symlink` tool.
5. **Source-repo decoupling at runtime.** Once a consumer is initialised, moving, renaming, or deleting the source-repo clone does not break the consumer. The consumer repo is self-contained with respect to subsequent sessions.

## 4. Non-goals

Pulled from `00-request.md` §Out of scope plus clarifications from brainstorm:

- Symlink, git-submodule, or shallow-clone transports (brainstorm approaches B / C / D — rejected).
- Publishing specflow to a package registry (npm, Homebrew tap, etc.) — the install source remains this git repo.
- Retrofitting historical archived features' memory back into per-project stores.
- Any change to how `.claude/rules/` loads — it already reads from `<cwd>/.claude/rules/` and is out of scope.
- Cross-machine distribution of a consumer's team-memory back to the source repo (explicit non-feature — the whole point is local isolation).
- A `--force` flag on `init`, `update`, or `migrate` (forbidden by `.claude/rules/common/no-force-on-user-paths.md`).
- Three-way merge of user-modified files during `update` (rejected in R7 — skip-and-report is the v1 policy).
- Designing the `update` CLI verb surface (global skill vs per-project command) at the PRD level — deferred to tech stage; the PRD pins only the contract.
- Deciding the on-disk format of the pinned-ref manifest (plain ref file, JSON manifest with hashes, etc.) — tech's call.
- Deciding whether the installed `.claude/` tree should be `.gitignore`d or committed by the consumer — tech's call; documentation updates (R12) will state whichever the tech stage selects.

## 5. Requirements

Each R has at least one concrete acceptance criterion (AC). R-numbering is stable; AC IDs are scoped per R.

### Transport and pinning

**R1 — Copy at a pinned source-repo ref.** `init` seeds the consumer repo by copying specflow's agents, commands, hooks, and the team-memory skeleton out of a source-repo clone at a ref chosen at init time. No symlinks back to the source repo may be created in the consumer's `.claude/` tree. The ref is recorded inside the consumer (exact file and format is tech's call); subsequent `update` and `migrate` flows read that recorded ref as the current-state baseline.

- **AC1.a.** After `init` completes against a fresh consumer repo, every file under the consumer's `.claude/agents/specflow/`, `.claude/commands/specflow/`, and `.claude/hooks/` is a regular file (not a symlink) and every byte matches the source-repo content at the captured ref.
- **AC1.b.** The captured ref is machine-readable inside the consumer repo (tech stage picks the file and format); `update` reads it and reports it at the start of the run. The ref value is a real commit SHA or tag from the source repo at init time, not a placeholder or empty string.
- **AC1.c.** No path under the consumer's `.claude/` tree created by `init` resolves through `readlink` to a path outside the consumer repo.

### `init` contract

**R2 — `init` seeds a fresh consumer repo.** Invoked from inside a target repo that does not yet have a specflow install (no recorded ref, no `.claude/agents/specflow/`, no `.claude/commands/specflow/`), `init` copies the full specflow payload (agents, commands, hooks, team-memory skeleton per R4, and the `.spec-workflow/features/_template/` directory) into the consumer's tree, records the chosen ref (R1), and wires the SessionStart and Stop hooks into the consumer's `settings.json` using the existing `bin/specflow-install-hook` helper's read-merge-write discipline (backup before mutation, atomic rename).

- **AC2.a.** Running `init` in a sandboxed consumer repo with no prior specflow content exits 0 and produces a self-contained install: agents/commands/hooks/team-memory directories populated per R4, recorded ref per R1, and a `settings.json` containing exactly one SessionStart and one Stop entry pointing at paths under the consumer's own `.claude/hooks/`.
- **AC2.b.** Running `init` a second time on an already-initialised consumer repo (the same ref already recorded and no drift) exits 0 and reports per-path `already` for every file, producing byte-identical filesystem state (verifiable by hashing the `.claude/` tree before and after).
- **AC2.c.** If any destination path exists and is not byte-identical to the source at the chosen ref, `init` classifies the target per R6 and dispatches via R7's conflict policy — it never overwrites without going through the classifier.

**R3 — `init` is the single global entry point.** Exactly one specflow artefact is permitted to live outside any consumer repo (i.e., under `~/.claude/` or similarly global): the `init` skill (or whatever surface the tech stage selects). No shared-mutable directory (`agents/specflow`, `commands/specflow`, `hooks`, `team-memory`) may remain required for runtime correctness once a consumer is migrated.

- **AC3.a.** After `init` completes on a consumer, deleting or renaming any subtree of the source-repo clone does not break a subsequent Claude Code session opened inside the consumer (agents, commands, hooks all resolve locally within the consumer).
- **AC3.b.** The `init` skill's on-disk footprint outside the consumer is enumerable and bounded (tech stage defines the exact set; PRD requires only that no agent/command/hook/team-memory *content* lives there — only the bootstrap skill itself).

**R4 — Team-memory starts as an empty skeleton.** `init` seeds the consumer's `.claude/team-memory/` with exactly the role subdirectories and their `index.md` files (empty-but-present), plus the `shared/README.md` and `shared/index.md`. No inherited lesson content (no `*.md` memory entries beyond index files and role README skeletons) is copied from the source repo into the consumer — lessons accumulate in the consumer's own tree and never travel back.

- **AC4.a.** After `init` in a fresh consumer, listing `.claude/team-memory/*/` shows exactly the role directories the source repo ships (pm, architect, tpm, developer, qa-analyst, qa-tester, designer, shared) and each contains at most its index file and any README skeleton the source repo ships; no other `.md` files are present.
- **AC4.b.** No flow in this feature (`init`, `update`, `migrate`) writes to any path under the source-repo clone's `.claude/team-memory/` or under `~/.claude/team-memory/` during normal operation.

**R5 — Rules are copied fresh per consumer.** `init` copies the source repo's `.claude/rules/` subtree into the consumer's `.claude/rules/` as a starter kit. Post-init, the consumer's rules are the consumer's own; `update` handles them under the same conflict policy as other copied content (R7). This requirement does not change how rules load at session time (the SessionStart hook already reads `<cwd>/.claude/rules/`).

- **AC5.a.** After `init` on a fresh consumer, `.claude/rules/` exists with the same file tree as the source repo at the captured ref, and each file is byte-identical to the source at that ref.
- **AC5.b.** Edits the consumer makes to `.claude/rules/` after init are preserved across subsequent `update` runs per the R7 conflict policy (skip-and-report).

### Classifier and dispatcher (shared across init / update / migrate)

**R6 — Every destination path is classified into a closed state enum before any write.** `init`, `update`, and `migrate` each classify every destination path into exactly one of: `missing`, `ok` (byte-identical to expected content at the chosen ref), `user-modified` (exists but differs from both the previous-ref baseline and the new-ref expected content — where applicable), `drifted-ours` (exists, differs from expected, but is byte-identical to a previous-ref baseline the flow can recognise — safe to replace), `real-file-conflict` (exists and is not a regular file under our managed prefix, e.g. a directory where a file is expected), or `foreign` (a path outside what the flow expected to manage). The classifier is a pure function — no side effects, no mutations. A separate dispatcher reads the state and performs exactly one action per state. This pattern is mandatory per `.claude/rules/common/classify-before-mutate.md`.

- **AC6.a.** The classifier can be invoked with `--dry-run` (or an equivalent stage-selector tech chooses) and produce the full per-path state plan without touching any file. Filesystem state before and after a `--dry-run` invocation is byte-identical (hash-verified).
- **AC6.b.** For every destination path in the plan, the dispatcher takes exactly one branch (per R7's action table); there is no fall-through default that silently mutates.

**R7 — Update conflict policy is skip-and-report with backup-before-replace.** When `update` or `migrate` encounters a user-modified destination file (state `user-modified` per R6), the flow **skips the file, leaves it untouched, reports `skipped:user-modified` with the file path, and sets a non-zero exit code at run end** — matching the transparency discipline of `bin/claude-symlink`'s existing conflict reporting. For `drifted-ours` (replaceable) files, the flow **writes a `.bak` sibling of the existing file first, then atomically replaces via write-to-tmp-then-rename, and reports `replaced:drifted`**. No silent clobber; no three-way-merge in v1. Cross-reference: `.claude/rules/common/no-force-on-user-paths.md`.

- **AC7.a.** Given a consumer where one copied command file has been hand-edited by the user since init, running `update` to a newer ref exits non-zero, reports `skipped:user-modified` with the edited file path, leaves that file byte-identical to its pre-update content, and still updates every other non-conflicting path.
- **AC7.b.** Given a consumer where one file is `drifted-ours` (identifiable as the previous-ref baseline, not user-modified), `update` writes `<path>.bak` with the pre-update content, then replaces `<path>` atomically, and reports `replaced:drifted`. The `.bak` file is byte-identical to the pre-update content.
- **AC7.c.** The exit-code contract matches `bin/claude-symlink`: 0 iff every path converged (no skips); non-zero if any path was skipped due to conflict or any mutation failed. Closed verb set (tech stage finalises the exact vocabulary) is enumerated in `bin/claude-symlink`-equivalent documentation updated per R12.
- **AC7.d.** No path in any flow uses a `--force` flag, `rm -rf`, or unconditional overwrite; every replace goes through backup + atomic-rename.

### `update` contract

**R8 — `update` re-copies at a newly-chosen ref with conflict preservation.** Invoked from inside a consumer repo with a recorded ref, `update` accepts a new ref (how — arg, prompt, or default-to-HEAD — is tech's call) and re-runs the copy against every destination path per R6's classifier and R7's dispatcher. After a successful run, the consumer's recorded ref (R1) is updated to the new ref, provided no `skipped:user-modified` occurred on a managed path (on conflict, the ref is *not* advanced, so a subsequent `update` re-attempts against the same target ref). The team-memory tree is never touched by `update` — lessons accumulated in the consumer stay put (R4).

- **AC8.a.** After an `update` run with no conflicts, the consumer's recorded ref matches the newly-chosen ref, and every non-team-memory managed file is byte-identical to the source at that ref.
- **AC8.b.** After an `update` run with at least one `skipped:user-modified`, the consumer's recorded ref is **unchanged** (still the pre-update value), exit code is non-zero, and every skipped file is byte-identical to its pre-update content. Re-running `update` against the same target ref after the user resolves the conflict advances the ref.
- **AC8.c.** No file under the consumer's `.claude/team-memory/` is read, written, or deleted during an `update` run.

### `migrate` contract (global-to-per-project)

**R9 — `migrate` converts a single consumer repo from the global-symlink model to per-project install.** Invoked from inside a target repo that currently resolves specflow via the global `~/.claude/` symlinks (no recorded ref, no consumer-local `.claude/agents/specflow/`, etc.), `migrate` (a) inventories what the global install is exposing at the moment, (b) copies the corresponding content into the consumer at whatever ref the source-repo clone is currently on (or an explicitly provided ref), (c) updates the consumer's `settings.json` hook wiring to point at the newly-local hooks, and (d) removes only the `~/.claude/` symlinks that this particular migration replaced (leaves any other consumer's symlinks in place, since `~/.claude/` is shared across consumers). `migrate` is idempotent (re-running after success reports `already` and exits 0), is safe to run repo-by-repo over time, and never deletes user-owned content.

- **AC9.a.** Running `migrate` in a consumer repo that was previously wired via `bin/claude-symlink install` produces a consumer matching R2's post-`init` shape (agents/commands/hooks/team-memory skeleton/rules all local, ref recorded, settings.json wired to local hooks) and removes only the corresponding `~/.claude/` symlinks that were resolving to the source repo for this consumer. Other projects' data under `~/.claude/` is unaffected (verifiable by hashing `~/.claude/` content unrelated to the migrated bits before and after).
- **AC9.b.** Re-running `migrate` in an already-migrated consumer exits 0 with every managed path reported `already` and produces byte-identical filesystem state.
- **AC9.c.** `migrate --dry-run` (or equivalent) produces the full plan without mutating the consumer's tree, `~/.claude/`, or the source repo. Filesystem state is byte-identical before and after (hash-verified on all three roots).
- **AC9.d.** If any destination in the consumer is `user-modified` (per R6), `migrate` skips that file, reports `skipped:user-modified`, leaves the corresponding `~/.claude/` symlink in place (does not tear down), and exits non-zero. The user resolves manually and re-runs.

### Dogfood staging of this source repo

**R10 — This source repo is the last consumer migrated.** The existing `bin/claude-symlink` global mechanism must remain operational throughout this feature's implement stage; no task in this feature's plan may tear down or modify `bin/claude-symlink`'s external contract as delivered by feature `shareable-hooks`. This source repo itself is migrated to the per-project install model as the **final** act of this feature — after `init`, `update`, and `migrate` all exist and have structurally passed verification. Until that final migration commit lands, this repo continues to run under the global symlinks already installed at `~/.claude/`.

- **AC10.a.** At the start of this feature's verify stage (prior to the final migration task), `bin/claude-symlink install`, `uninstall`, and `update` still exit 0 with the pre-feature external contract, and the machine's `~/.claude/agents/specflow`, `~/.claude/commands/specflow`, and `~/.claude/hooks` still resolve back into this source repo.
- **AC10.b.** The final task in this feature's plan runs `migrate` in this repo, removes the corresponding `~/.claude/` symlinks, and leaves this repo as its own self-contained per-project consumer. After that task, `bin/claude-symlink install` is no longer required for this repo's own sessions (though it remains available for any consumer that has not yet been migrated).
- **AC10.c.** The feature's verify stage distinguishes structural from runtime PASS per `.claude/team-memory/shared/dogfood-paradox-third-occurrence.md`. Structural PASS is the gate for archive; runtime PASS on `init` / `update` / `migrate` exercising *this* repo is observed in the final migration task itself and re-confirmed on the **next feature after session restart**.

### Documentation

**R11 — README documents the new flow and deprecates the old one.** The repo-root `README.md` must be updated to: (a) present `init` / `update` / `migrate` as the primary install flow for new and existing consumers, (b) explain the per-project isolation guarantee (version pinning, local team-memory), (c) mark the existing `bin/claude-symlink install` and `bin/specflow-install-hook add SessionStart ~/.claude/hooks/…` sections as **deprecated** with a pointer to `migrate`, and (d) explain the recovery path if a consumer's ref needs to change. The tech stage finalises the exact verbs and file paths the docs reference.

- **AC11.a.** `README.md` contains a top-level "Install" or "Getting started" section that describes `init` as the first command a new consumer runs, without referencing `~/.claude/` symlinks as the current model.
- **AC11.b.** The existing "bin/claude-symlink" and "Per-project opt-in" sections carry a deprecation notice with an explicit link to the `migrate` flow.
- **AC11.c.** Grep-verifiable: `grep -l "migrate"` finds `README.md`; `grep -l "deprecated"` finds `README.md`; the documented `init` command surface appears verbatim enough that a user following the README can run it.

**R12 — Conflict-verb vocabulary is documented alongside the flow.** The verb vocabulary for `init` / `update` / `migrate` (at minimum: `created`, `already`, `replaced:drifted`, `skipped:user-modified`, `skipped:real-file-conflict`, `skipped:foreign`, and the `would-*` `--dry-run` variants) is enumerated in user-facing docs (README or equivalent file per tech's call) with one row per verb explaining what it means and how the user remediates. This mirrors the existing conflict table in the `bin/claude-symlink` section.

- **AC12.a.** Every verb emitted by any of the three flows appears in the documented vocabulary table with a one-line explanation and a remediation pointer.
- **AC12.b.** No flow emits a verb not in the documented closed set (greppable against the docs as the authoritative list).

### Rule compliance

**R13 — Compliance with hard rules.** All three flows (`init`, `update`, `migrate`) comply with:
- `.claude/rules/common/no-force-on-user-paths.md` — no `--force`; backup before any mutation; atomic swap for all writes.
- `.claude/rules/common/classify-before-mutate.md` — pure classifier, closed state enum, dispatcher table, reads-first writes-second.
- `.claude/rules/common/absolute-symlink-targets.md` — not applicable in the consumer's copied tree (no symlinks created per R1), but applies to any symlinks the tech stage decides to create elsewhere (e.g., for the global `init` skill's own distribution).
- `.claude/rules/bash/sandbox-home-in-tests.md` — any bash test or verify script that invokes these flows and exercises `$HOME` (which `migrate` does, since it walks `~/.claude/`) uses the mktemp sandbox + preflight pattern.
- `.claude/rules/bash/bash-32-portability.md` — no `readlink -f`, `realpath`, `jq`, `mapfile`, `[[ =~ ]]` for portability-critical logic, or GNU-only flags in any shipped bash script.

- **AC13.a.** Every bash script shipped by this feature passes `bash -n` syntax check and conforms to the bash-32-portability rule (spot-check by grep for prohibited tokens).
- **AC13.b.** Every test script that invokes `init`, `update`, or `migrate` begins with the mktemp sandbox + preflight pattern per `.claude/rules/bash/sandbox-home-in-tests.md`.
- **AC13.c.** No code path in any of the three flows uses `rm -rf`, `--force`, or unconditional file overwrite (greppable).

## 6. Success metrics

- A second consumer repo on the same machine can be initialised at a different ref than this repo; sessions in each repo run against their respective specflow versions without interference.
- Running `update` in one consumer does not produce any filesystem change in any other consumer or in `~/.claude/`.
- A consumer's team-memory contains zero entries inherited from the source repo's memory at init time (only the empty skeleton).
- The existing global-install users on this machine (and any other) can migrate repo-by-repo at their own pace; the global mechanism is not torn down until every consumer that needs it has migrated or opted out.
- Post-archive, the next feature after session restart confirms runtime PASS on `init` / `update` / `migrate` via normal operation (per `shared/dogfood-paradox-third-occurrence.md`'s "next feature after session restart" clause).

## Team memory

- `pm/ac-must-verify-existing-baseline.md` — applied. R7's cross-reference to `bin/claude-symlink`'s conflict-reporting shape names one file as the canonical anchor for the verb vocabulary rather than saying "match all the existing tools"; the exact verb set is deferred to R12's documentation requirement with grep-verifiable coverage, avoiding the under-specified "parity" trap.
- `pm/housekeeping-sweep-threshold.md` — does not apply because this is a functional feature, not a post-review nits sweep.
- `pm/split-by-blast-radius-not-item-count.md` (global) — does not apply because this feature is a single-surface install-model change (all three flows share one blast radius: consumer-repo filesystem); no split needed.
- `shared/dogfood-paradox-third-occurrence.md` — applied, 6th occurrence. R10 is the entire dogfood-staging requirement (this repo is the last migrated, structural-only verify, runtime exercise on next feature after session restart). Propose: on next update to that memory, bump occurrence count to 6 and add this feature to the examples list.
