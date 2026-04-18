# Brainstorm — per-project-install

_2026-04-18 · PM_

## Problem restatement

Today every consumer repo on a machine is forced onto one shared specflow checkout: `bin/claude-symlink install` creates symlinks under `~/.claude/` and every Claude Code session picks up the same version of agents, commands, hooks, and team-memory. Two consumer repos cannot run different specflow versions concurrently, and each project's lessons bleed into a global `~/.claude/team-memory/` that semantically belongs to the project. We want per-project isolation — each repo owns its own specflow install — with a single global `init` entry point that seeds a target repo from this source repo, and a `specflow:update` path to pull newer bits per project when the user chooses.

## Approaches considered

### Approach A — `init` copies specflow bits into `<target>/.claude/` at a chosen ref

**Sketch.** The global `init` skill, invoked from inside any target repo, does a shallow plain-file copy of this repo's `.claude/agents/specflow/`, `.claude/commands/specflow/`, `.claude/hooks/`, `.claude/team-memory/` (seed content only), and the `.spec-workflow/features/_template/` into the target repo. The copy is pinned to a specific git ref (tag or commit) captured in a small manifest file inside the target. `specflow:update` re-runs the copy at a newer ref with a backup-and-replace discipline. The target repo commits the copied files; they're now its own tracked artefacts.

**Pros.**
- Clean semantic isolation — the target repo owns a full copy, no runtime dependency on the source repo path.
- Survives the source repo being moved, renamed, or deleted — the consumer is self-contained.
- Easy to diff per-project divergence: "what did I change locally in this project's copy?" is a plain `git diff` on tracked files.
- Per-project team-memory is automatic — each project's memory lives in its own committed tree.
- Works cleanly with the existing `classify-before-mutate` and `no-force-on-user-paths` rules: the `init`/`update` flows classify each target file state and skip-and-report on conflicts, back up before replace.

**Cons.**
- Tracked copy of framework files increases repo size and shows up in blame/log; cosmetic noise.
- "Update propagation" is manual per-project and could drift silently if users ignore `update` prompts.
- No single place to fix a bug across all consumers — every consumer re-runs `update`.

**Risks.**
- Update conflicts: if the user hand-edited a copied command file, `update` must not clobber their local edits — needs a classify-before-overwrite plan per file.
- Backup discipline must be airtight (atomic swap + `.bak` per file), or a bad update wipes local tuning.

### Approach B — `init` symlinks specflow bits from the source repo into `<target>/.claude/`

**Sketch.** Same shape as today's `bin/claude-symlink`, but targets are inside the consumer repo (`<target>/.claude/agents/specflow/`, etc.) rather than `~/.claude/`. Each consumer repo gets its own symlinks that resolve back into a chosen source-repo clone on disk. `init` records the source repo path in a small manifest; `specflow:update` re-points the symlinks at a newer ref (which requires the source clone to have that ref checked out, or switches the source clone to that ref).

**Pros.**
- Zero duplication of content on disk — one source-repo clone, N consumer links.
- Fixes to the source repo propagate immediately on the next session (no explicit update step for in-place source-repo edits).
- Reuses the existing `classify_target` / `owned_by_us` machinery almost verbatim — the code exists and is proven.

**Cons.**
- Consumer repo is no longer self-contained: moving or deleting the source repo breaks every consumer. This is the **same fragility** the current global model has, just with the broken-repo blast radius narrowed.
- Version pinning is awkward: the source clone can only be at one ref at a time, so "consumer A on v1.2, consumer B on v1.5" requires multiple source clones — and then the manifest has to track which clone, not just which ref.
- `git status` in the consumer repo shows symlinks, which some teams disallow in committed trees (Windows-hostile, `.gitignore` discipline needed).
- Team-memory symlinked back to the source repo **re-creates the semantic leak** we're trying to fix — a project's lessons would write back into the source repo's tree.

**Risks.**
- The team-memory leak is a design-level conflict with goal #3 ("team-memory/ entries stay inside that project"). Symlinks for team-memory specifically would need to be copy-or-owned differently — mixing transports within one `init` run is complicated.
- Absolute symlink targets baked at `init` time bind the consumer to a specific source-clone path, which conflicts with moving either repo (same recovery story as today but per-project, so N-times worse).

### Approach C — `init` copies stable content + symlinks live content + git-submodules the source repo

**Sketch.** Hybrid: copy static content (agents, commands, hooks) because they rarely change; symlink nothing (too fragile per B); git-submodule the source repo into `<target>/.vendor/specflow/` and drive `init`/`update` from the submodule. Team-memory is always a fresh per-project directory (no copy, no link — starts empty per project). `specflow:update` is `git submodule update --remote` followed by a re-copy from the submodule into the consumer's `.claude/` tree.

**Pros.**
- Version pinning is native to git — the submodule commit IS the pin, and `git log` in the consumer shows update history.
- The consumer repo can be distributed without the source repo (submodule clones on init).
- Team-memory isolation is clean and explicit.

**Cons.**
- Submodules are notoriously user-hostile: fresh clones need `--recurse-submodules`, CI needs special handling, many teams actively avoid them.
- Adds `.vendor/specflow/` checkout weight to every consumer repo.
- The "just copy from the submodule" step is essentially Approach A plus a submodule layer — the submodule adds operational cost without materially improving the core update flow.
- Requires users on fresh machines to understand git submodules, which raises the bar for adoption well beyond "run one `init`".

**Risks.**
- Submodule UX friction is the dominant risk: any feature that makes the common path harder is a feature that fails to get adopted. Team has not built with submodules before in this repo; unknown unknowns.

### Approach D — `init` does a shallow clone of the source repo into `<target>/.specflow-vendor/`, then copies out

**Sketch.** `init` runs `git clone --depth 1 --branch <ref>` of this repo into a vendor dir inside the consumer, then copies the needed subtrees out into `<target>/.claude/`. Vendor dir is `.gitignore`d (not committed). `update` re-clones at a new ref and re-copies. No submodule machinery.

**Pros.**
- Version pinning via clone ref, same semantics as Approach C without the submodule pain.
- Consumer repo commits only the copied framework files — no submodule, no vendor blob in the tree.
- Works offline after first init; update requires network but that's expected.

**Cons.**
- Requires network access at init time (this is arguably fine but is a new requirement — today `bin/claude-symlink` works offline from a local checkout).
- Two-step indirection (clone → copy) is more moving parts than a plain-copy-from-source-clone (Approach A).
- Ambiguous "source": once the vendor clone exists, the consumer has two copies of the framework (the clone and the copied-out files under `.claude/`). If someone edits the vendor clone directly, it's silently ignored by the consumer's live `.claude/` — confusing.

**Risks.**
- The vendor-dir-as-source-of-truth muddles the mental model. Approach A with "source = wherever the user has a local clone, specified via the manifest" is cleaner.

## Recommendation

**Adopt Approach A — `init` copies at a pinned ref, `update` re-copies with classify-before-overwrite.** High confidence on the core shape; lower confidence on the precise update-conflict policy (flagged below for PRD).

### Why this trade-off

1. **Semantic isolation is the core goal.** A copy-based model makes the consumer repo self-contained in the same way the existing per-project `.claude/rules/` already is. Symlink-based approaches (B, C partially) keep a live runtime coupling that contradicts the isolation goal.
2. **Team-memory fits naturally.** A project's memory lives in the project's own committed `.claude/team-memory/` tree — no leak, no special transport exception.
3. **Reuses existing discipline.** `classify-before-mutate` and `no-force-on-user-paths` both apply cleanly: `init` classifies each destination file (missing / ok-ours / user-modified / real-file-conflict) and `update` does the same plus "backup before replace". The existing `bin/claude-symlink` case ladder is a direct template for the port to a new verb surface.
4. **Failure modes are user-visible.** If a copy conflicts, the user sees a `skipped:<reason>` line and acts on it — the same transparency discipline that made the current global install trustworthy.
5. **Source repo is decoupled at runtime.** Moving, renaming, or deleting the source repo does not break any consumer. This is a strict improvement over today's model.

### What I'm giving up

- Duplication of content across consumers (disk cost — small).
- "One edit fixes all consumers" behaviour — users now have to run `update` explicitly per project. Given the two consumer repos in play are maintained by the same person today, and the explicit opt-in is the whole point of version isolation, this is a feature, not a cost.

### Runners-up

- **Approach B (symlinks)** is the runner-up only if copy size turns out to be prohibitive in practice (unlikely given the content footprint). Its team-memory leak is a showstopper as-designed.
- **Approach D (shallow clone + copy)** is viable if the PRD decides pinning-via-clone-ref is more ergonomic than pinning-via-manifest. Revisit at PRD if the manifest file proves awkward to author.

## Open items for PRD

1. **Transport confirmation.** PRD must explicitly reject B/C/D and state the copy model's contract (what gets copied, what gets generated fresh, what the consumer may hand-edit).
2. **Versioning story.** Pin-at-init-time is the recommended shape (user-explicit; survives a 6-month gap with no surprise upgrades), but PRD must decide:
   - Does `init` prompt for a ref, default to HEAD of the source repo, or require an explicit `--ref`?
   - Where does the pin live — a `.claude/specflow.manifest` file, a comment in an existing file, or elsewhere?
   - What does `update` do when the user never pinned (tracking-HEAD case)?
3. **Update conflict policy.** When `update` finds a user-modified copy, does it:
   - skip-and-report (current `bin/claude-symlink` discipline — recommended), or
   - three-way-merge (complex; needs git merge-file), or
   - backup-and-replace with a loud warning?
   PRD should pick one and write ACs for the conflict matrix.
4. **Update surfacing location.** Global skill (`/specflow:update`) vs per-project command (`<target>/.claude/commands/specflow/update.md`) — my lean is **per-project**, because a per-project command:
   - reads the target's manifest for the source repo path at invocation time (robust to source-repo moves if the user updates the manifest);
   - is self-contained (consumer repo is fully self-documenting);
   - is consistent with the rest of `/specflow:*` being per-project commands.
   Flagged as "best-guess, revisit at PRD" because it depends on how the `init` skill itself is distributed.
5. **`init` skill distribution.** Where does the global `init` live? Options:
   - Lives under this repo's `.claude/skills/` and is installed once per machine with a tiny bootstrap (a one-liner the user runs from the source-repo clone to put the skill under `~/.claude/skills/`).
   - Lives outside this repo entirely (separate package) — rejected: adds a new publishing surface (out of scope per 00-request).
   - Inlined as a bash one-liner a user copies from the README — possible but loses UX polish.
   PRD needs to pick one and define the bootstrap contract.
6. **Source-repo path discovery.** At `init` time the skill needs to know where the source repo clone lives on disk. Env var? Hardcoded default (`~/tools/spec-workflow`)? Prompt? PRD decides.
7. **Migration of existing consumers.** Today the two consumers on this machine use the global-symlink model. PRD must specify:
   - Does this feature deprecate `bin/claude-symlink` or can both models coexist during transition?
   - What's the one-shot migration command (e.g. `init --from-global`)?
   - Do we leave the global symlinks in place or tear them down as part of migration?
8. **What gets copied vs seeded fresh.** Team-memory content is ambiguous — does `init` copy the source repo's team-memory as a starting point, or seed the consumer with empty role dirs? My lean is **empty seed** (no leak), but the `shared/` subdir is arguably useful as a starter kit. PRD decides.
9. **Hooks wiring.** Today `bin/specflow-install-hook` wires `~/.claude/hooks/…` into the consumer's `settings.json`. Post-per-project-install, hooks live at `<target>/.claude/hooks/…` — should the wiring use relative paths, absolute paths into the consumer, or the existing global path? PRD decides.
10. **Rules content.** `.claude/rules/` is already per-project; 00-request states rule-loading is out of scope. But `init` still needs to decide whether to copy the source repo's `rules/` as a starter kit or leave the consumer's rules empty. PRD decides (this is cosmetically close to the team-memory question but has different answers likely).

## Dogfood-paradox note

This feature ships a tool this repo will itself want to use. The paradox: if `init` installs per-project specflow bits into this very repo, we'd be replacing the global symlinks that are currently powering the implement stage **of this same feature**. The mechanism ships the mechanism it needs.

**Staging proposal (to be ratified by Architect and TPM, not binding here):**

1. **This repo is NOT a per-project consumer during implement stage.** Keep the existing `~/.claude/` symlinks live for the duration of this feature's implement. Do not touch the global model until this feature archives.
2. **This repo becomes its own first per-project consumer post-archive.** A one-shot migration commit runs `init --from-global` (or equivalent) in this repo, wires its own `.claude/specflow.manifest`, and tears down the now-redundant global symlinks.
3. **Structural-only verification during this feature's own verify stage.** AC coverage during this feature's verify is structural: "the `init` skill file exists; the `update` command exists; the copy logic classifies correctly on a sandbox target". Runtime exercise ("does it actually bootstrap a fresh repo end-to-end") happens on the **next feature after this one archives**, in a clean sandbox or by observing the migration commit itself.
4. **Opt-out flag.** Any orchestration that assumes per-project installs (e.g. `specflow:update` inside a repo) must have a bypass or early-return for "this repo has no manifest yet" so that in-flight sessions on this repo during implement don't break. Architect: carry this forward as a design constraint.
5. **STATUS Notes trace.** TPM to document the paradox in STATUS explicitly at plan time ("this feature ships X; X cannot be exercised on itself during implement"), and the QA-tester to mark structural vs runtime PASS in `08-verify.md`.

This follows `shared/dogfood-paradox-third-occurrence.md` directly — now the fifth occurrence of the pattern. The memory file's "next feature after session restart following archive" clause applies: the first real runtime exercise will be on whatever feature lands **after** this one archives and this repo's session is restarted to pick up the migrated install.

## Team memory

- `shared/dogfood-paradox-third-occurrence.md` — applied. Entire "Dogfood-paradox note" section above follows the "structural during own verify, runtime next feature" pattern it prescribes. Fifth occurrence; consider tagging in the memory on next update.
- `pm/ac-must-verify-existing-baseline.md` — applied during brainstorm hygiene: no cross-file parity claims asserted here; PRD will need this rule active when writing update-conflict ACs (don't say "match bin/claude-symlink's conflict matrix" without citing the specific verbs).
- `pm/housekeeping-sweep-threshold.md` — does not apply (this is a functional feature, not a nits sweep).
