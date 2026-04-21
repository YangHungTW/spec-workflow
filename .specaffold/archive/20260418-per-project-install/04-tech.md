# Tech — per-project-install

_2026-04-18 · Architect_

## Team memory consulted

- `architect/classification-before-mutation.md` — **load-bearing**: all three flows (`init`, `update`, `migrate`) classify into a closed state enum before any write; D4 extends the template from filesystem state to content-state (`drifted-ours` vs `user-modified`). Pairs with project rule `common/classify-before-mutate.md`.
- `architect/no-force-by-default.md` — **load-bearing**: skip-and-report is the v1 conflict policy; no `--force` flag on any of the three verbs. R7, R13 direct descendants. Pairs with project rule `common/no-force-on-user-paths.md`.
- `architect/settings-json-safe-mutation.md` — applies to D8 (hooks-wiring reuse): the existing `bin/specflow-install-hook` already honours read-merge-write + atomic swap + `.bak`. `init` re-uses it verbatim; no second copy of the discipline.
- `architect/shell-portability-readlink.md` — applies to every bash decision below. No `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic. `resolve_path` helper is ported from `bin/claude-symlink`.
- `architect/script-location-convention.md` — applies to D2: new CLIs go in `bin/<name>` (no extension, exec bit); `scripts/` reserved for dev-time helpers.
- `architect/byte-identical-refactor-gate.md` — applies to R10 dogfood migration: the migration-to-self task asserts byte-identical content between source `.claude/` subtree and consumer `.claude/` subtree after copy.
- `shared/dogfood-paradox-third-occurrence.md` — 6th occurrence. R10 staging (this repo migrated last; structural-only same-feature verify; runtime confirmation on next feature after session restart) is the direct application. D9 (opt-out sentinel) honours the companion `opt-out-bypass-trace-required.md` lesson from the shared-tier team memory.

---

## 1. Context & Constraints

### Existing stack (what's already in the repo)

- **Pure bash tooling** — `bin/claude-symlink` (single-file, 8-state classify-before-mutate symlink manager, bash 3.2 floor, pure POSIX filesystem ops); `bin/specflow-install-hook` (Python-3 read-merge-write helper for `settings.json`, atomic swap, single-slot `.bak`).
- **Two live hooks** under `.claude/hooks/` — `session-start.sh` (emits rule digest), `stop.sh` (appends to STATUS.md on matched feature branch). Both are fail-safe pure-bash, bash 3.2 safe.
- **Test harness** `test/smoke.sh` with 38 tests (t1–t38) covering the three `bin/claude-symlink` subcommands, the two hooks, and the hook installer. Every test uses the mktemp `$HOME` sandbox pattern.
- **Per-project surface already established** — `.claude/rules/` is already read from `<cwd>/.claude/rules/` by `session-start.sh`; `.spec-workflow/features/` is cwd-resolved by `stop.sh`. The per-project copy target for this feature is a **superset** of that discipline.
- **No `.claude/skills/` tree exists in this repo yet** — greenfield location for D1's `init` skill.

### Hard constraints

- **macOS bash 3.2 + BSD userland floor** (project rule `bash/bash-32-portability`; memory `shell-portability-readlink`). No GNU coreutils extensions in any shipped bash. Python 3 permitted only on install-time paths, never at session runtime.
- **Classify before mutate** (project rule `common/classify-before-mutate.md`) — every destination path enumerated through a pure classifier emitting a closed-enum state, then dispatched by a single `case` table. PRD R6 binds this.
- **No `--force`; backup before replace; atomic swap** (project rule `common/no-force-on-user-paths.md`) — every replacement writes a `.bak` first and commits via write-temp-then-rename. PRD R7, R13 bind this.
- **Absolute symlink targets only** (project rule `common/absolute-symlink-targets.md`) — does not apply inside the consumer's copied tree (PRD R1 forbids symlinks there) but applies if D1's `init` skill distribution uses a symlink.
- **Sandbox `$HOME` in tests** (project rule `bash/sandbox-home-in-tests.md`) — every smoke test that invokes `init` / `update` / `migrate` opens an `mktemp -d` sandbox, exports `HOME=$SANDBOX/home`, and asserts preflight.
- **Exactly one global artefact** (PRD R3) — no shared-mutable runtime state under `~/.claude/` beyond the `init` skill itself. Any design that proposes a second global thing must justify or be rejected.
- **Existing `bin/claude-symlink` must keep working throughout implement** (PRD R10, AC10.a) — no task in this feature's plan may modify its external contract until the final migration task.

### Soft preferences

- **Reuse the existing classifier scaffold**. `bin/claude-symlink`'s `resolve_path`, `owned_by_us`, `classify_target`, `apply_plan`, `report`, `emit_summary`, `ensure_parent` helpers are battle-tested and portable. The new tool structurally mirrors that file, extending the enum and plan-population to cover **content** (per-file) rather than just **linkage**.
- **One script per verb, sharing common helpers via a single sourced library** — clearer than a mega-script, friendlier to smoke-test isolation, matches the precedent of `bin/claude-symlink` + `bin/specflow-install-hook` (two separate tools sharing no code today, but adding a third would tip the balance toward extraction).
- **User-facing verb set stays small** — `init`, `update`, `migrate`, each with `--dry-run`. No hidden subcommands. Mirrors `bin/claude-symlink`'s surface.
- **Manifest format that is grep-verifiable** (not requiring a JSON parser at read time for the hot path) — plain shell can sniff the ref string with `awk`. Python 3 permitted for write-path (hashes, timestamps, manifest authoring).

### Forward constraints (must not make later backlog harder)

- **Third hook, fourth hook, Nth script under `.claude/hooks/`** — the copy plan walks `.claude/hooks/` as a directory; adding new hook scripts to the source repo requires no change to the copy tool.
- **Consumer may eventually extend its own `.claude/rules/`, `.claude/team-memory/`** — both already per-project; copy flow must preserve consumer additions under the R7 conflict policy (the `user-modified` state covers this).
- **Source-repo structure may add new top-level subtrees under `.claude/`** — the managed-subtree list is explicitly enumerated (not a blanket `.claude/*` copy), so new source-repo directories that are not part of specflow (e.g., user's own `.claude/agents/personal/`) are not swept into consumers. Adding a new subtree to specflow requires one line in the plan.
- **A future `publish` command** (e.g., syndicate a consumer's team-memory fragment back upstream) must not be made harder. Today `update` and `migrate` are unidirectional (source → consumer); that shape is deliberate, and the `update --dry-run` contract is the place a future bidirectional mode would attach.

---

## 2. System Architecture

### Components

```
+----------------------------------------+
| ~/.claude/skills/specflow-init/        |   (D1: single global artefact)
|   SKILL.md                             |
|   init.sh                              |   (delegates into bin/ tools in src)
+-------------------+--------------------+
                    |
                    | invoked once inside target consumer repo
                    v
+----------------------------------------+
| <source-repo-clone>/bin/specflow-seed  |   (D2: new CLI; classifier+copier)
|   init | update | migrate              |
|   (reads src, writes consumer tree)    |
+-------------------+--------------------+
                    |
        +-----------+-----------+
        |           |           |
        v           v           v
  <consumer>/.claude/      <consumer>/.spec-workflow/
    agents/specflow/**       features/_template/**
    commands/specflow/**    <consumer>/.claude/
    hooks/**                 specflow.manifest      (D3: pinned ref)
    rules/**
    team-memory/             <consumer>/settings.json  (hooks wired via
      <role>/index.md         bin/specflow-install-hook; unchanged helper)
      shared/README.md
      shared/index.md
```

### Data flow — key scenarios

**Scenario A: fresh `init` (R2, R4, R5).**

1. User, inside fresh consumer repo, invokes global `/specflow-init` skill (D1).
2. Skill locates the source-repo clone (D7) and invokes `<src>/bin/specflow-seed init --from <src> --ref <ref>` in the consumer's cwd.
3. `specflow-seed` resolves `<src>` root via `resolve_path`; resolves the consumer root via `git rev-parse --show-toplevel` (fallback: `pwd`).
4. `plan_copy` (ported from `plan_links`) enumerates the managed file set:
   - every file under `<src>/.claude/agents/specflow/`
   - every file under `<src>/.claude/commands/specflow/`
   - every file under `<src>/.claude/hooks/`
   - every file under `<src>/.claude/rules/` (R5)
   - every file under `<src>/.spec-workflow/features/_template/`
   - plus a **synthesized empty-skeleton set** for `<consumer>/.claude/team-memory/` (R4): one `index.md` per role directory, plus `shared/README.md` and `shared/index.md` — content is generated from the source's own skeleton (copied files only where the source already has an empty-ish skeleton), no lesson `.md` entries.
5. For each planned path, `classify_copy_target` runs (D5). First `init` on a fresh repo: every path classifies `missing`; dispatcher writes each file via write-temp + atomic-rename.
6. Manifest is authored at `<consumer>/.claude/specflow.manifest` (D3) recording: chosen ref, SHA of each copied file, ISO-8601 timestamp, source-repo remote URL (informational).
7. Hook wiring: `specflow-seed` invokes the consumer-tree's copy of `bin/specflow-install-hook` twice (D8) — `add SessionStart .claude/hooks/session-start.sh` and `add Stop .claude/hooks/stop.sh`, both referencing the **consumer-local** path (never `~/.claude/hooks/…`).
8. Emit summary; exit 0 if no skips.

**Scenario B: `update` with conflicts (R7, R8).**

1. User, inside already-initialised consumer, invokes `<src>/bin/specflow-seed update --to <new-ref>` (or `update` with default-HEAD — D6).
2. Seed reads `<consumer>/.claude/specflow.manifest` → previous ref + per-file SHA baseline.
3. `plan_copy` enumerates the managed set at `<new-ref>`.
4. For each destination, `classify_copy_target` compares three hashes: current consumer file, expected at `<new-ref>`, baseline (from manifest) — see D4/D5. Emits one of `missing` / `ok` / `drifted-ours` / `user-modified` / `real-file-conflict` / `foreign`.
5. Dispatcher runs per R7: `missing` → write; `ok` → report `already`; `drifted-ours` → write `.bak`, atomic-swap new content, report `replaced:drifted`; `user-modified` → report `skipped:user-modified`, set MAX_CODE=1, do not touch. Team-memory is **not** included in the plan (R4/R8 — `update` never walks the team-memory tree).
6. If any `skipped:user-modified` occurred, manifest ref is **not** advanced; exit non-zero. Otherwise manifest is rewritten atomically with the new ref + new per-file SHA set; exit 0.

**Scenario C: `migrate` from global install (R9, R10).**

1. User, inside a consumer repo currently wired via `~/.claude/` symlinks, invokes `<src>/bin/specflow-seed migrate` (or the global skill, which branch-dispatches).
2. Seed detects source repo: reads `~/.claude/agents/specflow` symlink via `readlink`, resolves to `<src>/.claude/agents/specflow`, strips `.claude/agents/specflow` suffix → `<src>` root (D7 fallback 2). Asserts the other expected symlinks (commands/specflow, hooks) also resolve into the same `<src>`.
3. Same `plan_copy` + `classify_copy_target` flow as `init`, against the source's current HEAD (or user-supplied `--ref`).
4. After copy succeeds with no `user-modified` skips:
   a. Rewrite `<consumer>/settings.json` hook entries: `bin/specflow-install-hook remove SessionStart ~/.claude/hooks/session-start.sh` (if present); `remove Stop ~/.claude/hooks/stop.sh` (if present); `add SessionStart .claude/hooks/session-start.sh`; `add Stop .claude/hooks/stop.sh`. All four calls go through the existing helper — read-merge-write, atomic swap, `.bak`.
   b. Migration-scope symlink teardown: remove **only** the `~/.claude/` symlinks that `owned_by_us` identifies as resolving into `<src>`, and **only if** `<src>` is the only consumer currently relying on them — but since `~/.claude/agents/specflow` is shared across every consumer, per-consumer teardown of the dir-level link is unsafe (AC9.a "Other projects' data under `~/.claude/` is unaffected"). Resolution: D10 below.
5. If any `skipped:user-modified`, leave `~/.claude/` symlinks in place, report the conflict, exit non-zero.

### Module boundaries

- **`~/.claude/skills/specflow-init/` (new)** — single SKILL.md + small `init.sh` bootstrap. Only non-consumer artefact. Purpose: locate the source clone and invoke `<src>/bin/specflow-seed`. Holds no business logic.
- **`bin/specflow-seed` (new)** — the core classify-copy tool. Three subcommands. Pure bash 3.2. Ships from the source repo; the consumer never needs its own copy (it's invoked from the source clone at `init` / `update` / `migrate` time, then the copied content in the consumer is self-sufficient at session runtime).
- **`bin/claude-symlink` (unchanged in body; extended only in `cmd_uninstall`)** — D10 adds a per-consumer teardown path that removes only this-consumer's hook-wiring pointer into `~/.claude/hooks/`, not the shared symlinks. **Every edit here is gated behind `--for-consumer <path>`** so the existing external contract (PRD R10, AC10.a) stays intact for un-migrated consumers.
- **`bin/specflow-install-hook` (unchanged)** — reused verbatim via `<src>/bin/specflow-install-hook` during `init` / `migrate`. Helper is idempotent and does not depend on its own filesystem location.
- **`<consumer>/.claude/specflow.manifest` (new per-consumer file)** — content hashes + ref. Grep-readable. Not a runtime dependency (hooks and agents don't read it); only `update` / `migrate` read it.

---

## 3. Technology Decisions

### D1. `init` skill distribution and bootstrap

- **Options considered**:
  - A. Ship `SKILL.md` under source-repo's `.claude/skills/specflow-init/` and distribute it to users by copying into `~/.claude/skills/specflow-init/` via a one-shot bootstrap command in the repo README.
  - B. Ship a project-local skill (under `<src>/.claude/skills/`) and require users to symlink `~/.claude/skills/specflow-init → <src>/.claude/skills/specflow-init` with `bin/claude-symlink`.
  - C. Ship a single global bash one-liner (`curl | bash` style) — users paste the one-liner from the README.
  - D. Publish a separate installer package (brew tap, npm, etc.) — rejected by PRD §4 out-of-scope.
- **Chosen**: **A — SKILL.md lives under `<src>/.claude/skills/specflow-init/` in the source repo AND is copied into `~/.claude/skills/specflow-init/` via a bootstrap step in the README: `cp -R <src>/.claude/skills/specflow-init ~/.claude/skills/`**. The copied skill is then invocable from any Claude Code session, anywhere on the machine.
- **Why**:
  - Claude Code's global skill convention is `~/.claude/skills/<slug>/SKILL.md`. Match the convention.
  - A plain `cp -R` bootstrap is 7 words of README ("copy this dir once; that's it"). No curl, no brew, no second repo. Satisfies R3 (single global artefact).
  - The skill is **static** (a markdown prompt + a tiny `init.sh`) — once bootstrapped, it reads the user's clone location from an env var or config and doesn't need updating when the source repo updates. Upgrading the skill itself is a deliberate act (re-run bootstrap) — same model as the rest of per-project-install.
  - Option B (symlink) fails R3: the symlink would need to resolve back into the source repo, which violates "consumer self-containment" for the bootstrap itself (not strictly required, but unclean — the skill and the source clone should have independent lifetimes).
  - Option C (curl|bash) adds a network dependency and a trust surface with no gain over a `cp -R` from a known local path.
- **Tradeoffs accepted**:
  - When the skill definition changes (add a prompt, tweak the bootstrap), every user must re-run the bootstrap `cp -R`. Mitigation: skill content is expected to be near-static.
  - Two physical copies of the skill: one in source repo, one under `~/.claude/skills/`. They can drift; doc ownership sits with the source repo.
- **Reversibility**: medium — changing to a symlink model later is a localized swap in the bootstrap paragraph of README.
- **Requirement link**: PRD R3 (single global artefact), AC3.b (footprint bounded and enumerable — the `specflow-init` directory is the entire footprint).

**`~/.claude/skills/specflow-init/SKILL.md` shape (sketch):**

```markdown
---
name: specflow-init
description: Seed a target repo with a per-project specflow install (init/update/migrate).
---

# /specflow-init

Locate the user's source-repo clone (env `SPECFLOW_SRC` or prompt),
invoke `<src>/bin/specflow-seed <subcmd>` with args inferred from the
user's task description. Subcommands: init / update / migrate.
```

### D2. CLI surface — one multi-subcommand bash script in source repo

- **Options considered**:
  - A. Three separate scripts: `bin/specflow-init`, `bin/specflow-update`, `bin/specflow-migrate`.
  - B. One script `bin/specflow-seed` with three subcommands (`init`, `update`, `migrate`).
  - C. A Claude Code skill/command that invokes bash under the hood; user never sees the bash.
  - D. Extend `bin/claude-symlink` with the new verbs.
- **Chosen**: **B — one script `bin/specflow-seed` with three subcommands**. Mirrors the shape of `bin/claude-symlink` (install/uninstall/update).
- **Why**:
  - The three verbs share 80% of their logic (classifier, copier, manifest read/write, emit_summary). Three separate scripts would copy-paste, three separate scripts would drift.
  - Matches the existing repo convention (`bin/claude-symlink` is also verb-dispatched) — contributor muscle memory.
  - Testable non-interactively: every verb accepts `--dry-run`, `--ref <ref>`, `--from <path>`, no interactive prompts.
  - Option D (extend `bin/claude-symlink`) is rejected because the two tools operate on different semantic domains: `bin/claude-symlink` manages `~/.claude/` symlinks (global, shared); `bin/specflow-seed` copies content into consumers (local, per-project). Mixing them breaks R10 (claude-symlink external contract frozen during implement) and muddles the mental model.
  - Option C (skill-only) is rejected: smoke tests need to drive the flow non-interactively; a skill is an agent prompt, not a CLI.
- **Tradeoffs accepted**: one script grows to ~400–500 lines (per claude-symlink precedent). Acceptable — still one file, one mental model, and can be extracted into a library if a fourth verb lands.
- **Reversibility**: medium — splitting into three scripts later is mechanical (same helpers extracted into `lib/specflow-lib.sh`).
- **Requirement link**: PRD R2, R8, R9 (three verbs in a cohesive surface).

### D3. Manifest on-disk format — `specflow.manifest`, simple KV + SHA table

- **Options considered**:
  - A. Plain-text single-line ref file: `<consumer>/.claude/specflow.ref` containing just `<sha>`.
  - B. JSON manifest with ref, timestamp, source-repo URL, per-file SHA map at `<consumer>/.claude/specflow.manifest`.
  - C. YAML with the same fields.
  - D. Per-file `.sha256` sidecars scattered under each managed subtree.
- **Chosen**: **B — a single JSON file at `<consumer>/.claude/specflow.manifest`** with this shape:

```json
{
  "specflow_ref": "<40-char git SHA or tag>",
  "source_remote": "<informational URL; never dereferenced>",
  "applied_at": "<ISO-8601 UTC>",
  "files": {
    ".claude/agents/specflow/architect.md": "<sha256>",
    ".claude/hooks/stop.sh": "<sha256>",
    ...
  }
}
```

- **Why**:
  - R1 mandates a machine-readable ref; AC1.b requires `update` read and report it. JSON is trivially parseable by Python 3 (available on install path) and grep-sniffable for the bare ref line without a parser (see below).
  - The `files` map IS the baseline for `drifted-ours` detection (D4); storing hashes avoids the need to re-fetch the previous ref from the source clone at update time — satisfies AC3.a ("source-repo clone can move or be deleted").
  - Option A (bare ref) would force `update` to re-check out the previous ref in the source clone to reconstruct the baseline — fails AC3.a.
  - Option D (sidecar `.sha256` files) pollutes every managed subtree with noise and doubles the file count; one central manifest keeps the footprint tidy.
  - File path `<consumer>/.claude/specflow.manifest` (not `<consumer>/.specflow/` or similar) keeps everything under the already-established `.claude/` umbrella; one less top-level tree for the consumer to manage.
- **Tradeoffs accepted**:
  - Manifest size scales with file count (hundreds of SHAs, ~50 bytes each → ~10–15 KB). Trivial.
  - JSON parsing at write time requires Python 3 (install-path only, per the `bash-32-portability` rule — Python 3 is allowed here because `init` and `update` are install-path flows, not hook-runtime flows).
  - Read-time grep sniff of the ref: `awk -F'"' '/"specflow_ref"/ { print $4 }' specflow.manifest` — does not need `jq`, bash 3.2 safe. This is how `update` reads the previous ref when Python 3 is unavailable (defensive).
- **Reversibility**: low-ish — changing the manifest schema later requires a migration path; users' consumers will have old-schema manifests that `update` must upgrade. Mitigation: include `"schema_version": 1` (added below in the §2 shape — treat as implied) so a future `update` can detect and migrate.
- **Requirement link**: R1 (machine-readable ref + file/format tech's call), R7 (`drifted-ours` detection), AC1.b, AC3.a.

**Exact shape with schema version:**

```json
{
  "schema_version": 1,
  "specflow_ref": "<sha>",
  "source_remote": "<url>",
  "applied_at": "<iso8601>",
  "files": { "<relpath>": "<sha256>", ... }
}
```

### D4. Classifier baseline for `drifted-ours` detection — manifest per-file SHA table

**This is the crux decision of the feature. PRD R6 enumerates `drifted-ours` and `user-modified` as distinct states, and distinguishing them is what enables `update` to be safe.**

- **Problem restated**: at `update` time, for every destination file, the classifier must emit one of:
  - `missing` — doesn't exist on disk
  - `ok` — exists, byte-identical to expected-at-new-ref
  - `drifted-ours` — exists, not byte-identical to expected-at-new-ref, BUT byte-identical to the **previous-ref baseline** that was on disk at the last init/update. The user has not touched it since; the source-repo content evolved. Safe to replace (after `.bak`).
  - `user-modified` — exists, not byte-identical to expected-at-new-ref, AND not byte-identical to the previous-ref baseline. The user edited it. Skip.
  - `real-file-conflict` — non-regular-file at a managed path (symlink where a file is expected, directory where file is expected).
  - `foreign` — outside the managed subtree altogether (should not appear in `plan_copy` by construction; included for defense).

The determining question: **how does `update` know the previous-ref baseline?**

- **Options considered**:
  - (a) **Per-file SHA table in the manifest** (D3 `files` map). At update time, the classifier hashes the current on-disk file and compares to the manifest's recorded SHA for that path. Match = unchanged-since-last-apply = can overwrite. Mismatch = user edited it = skip.
  - (b) **Re-fetch the previous ref from the source-repo clone**. At update time, `git show <previous-ref>:<path>` the previous content, hash it, compare to current on-disk hash. Requires the source clone to be reachable AND to still have that ref.
  - (c) **Store a full side-by-side baseline tree** at `<consumer>/.claude/.specflow-baseline/` — a literal copy of the last-applied content. Compare current to baseline via plain `cmp`.
  - (d) **Compute the SHA on demand from the source clone plus the SHA is ONLY used if computable**; if the source clone lacks the previous ref, every changed file conservatively classifies `user-modified` (skip all). Pessimistic fallback.
- **Chosen**: **(a) — per-file SHA256 table in the manifest**. Store at `init` and `update` time. Read at the next `update` time.
- **Why**:
  - **Satisfies AC3.a absolutely**: the source repo can move, be deleted, be pointed at a fresh clone that lacks the old ref — `update` still works because the baseline is a local file.
  - **Cheap to compute**: SHA256 of a few hundred small files in a single bash invocation is sub-second on any machine (`shasum -a 256` is BSD-safe on macOS; `sha256sum` is GNU-safe on Linux — dispatch by `uname -s` in a one-line wrapper, same pattern as `to_epoch` in the shareable-hooks tech doc). Python 3's `hashlib` is a fallback if neither binary is present (install-path allowed).
  - **Deterministic**: content-hash equality is a total function; no clock skew, no cache staleness, no partial-index problems.
  - **Reviews cleanly**: a diff of the manifest between two `update` runs shows exactly which files were replaced and which were skipped, with machine-checkable hashes.
  - **Option (b)** fails the AC3.a "source-repo clone can be deleted" test. Even if we make it a fallback when manifest hashes are missing, it's more moving parts for the same outcome.
  - **Option (c)** doubles the consumer's footprint by carrying a shadow tree. Fails disk-footprint hygiene and confuses newcomers browsing the consumer's `.claude/`.
  - **Option (d)** is too pessimistic: a user who's never edited any file will nevertheless see every changed file skipped as `user-modified` if their source clone is missing the previous ref. Breaks AC8.a (`update` with no conflicts advances the ref).
- **Tradeoffs accepted**:
  - Manifest must be updated (rewritten atomically) on every successful `update`. Handled by the same atomic-swap discipline as `settings.json`; see D5 classifier pseudocode.
  - If the user edits a file and **happens to edit it back to the previous-ref baseline** (unlikely but possible), `update` will classify `drifted-ours` and replace it — the user's (reverted) edit is lost. The `.bak` is written first, so no data is irrecoverable; this matches R7's "backup-before-replace on drifted-ours".
  - If the manifest itself is hand-edited (corrupted), `update` cannot distinguish `user-modified` from `drifted-ours`. Mitigation: manifest parser asserts schema shape and fails loud (`exit 2`, no mutation) if corrupt. User restores from `.bak` or re-runs `init` after manual cleanup.
  - If Python 3 is unavailable at update time, the fallback is `shasum`/`sha256sum` direct invocation for per-file hashing, plus a bash-only grep of the manifest `"<relpath>": "<sha>"` line. Manifest **write** requires Python 3 — refuse to proceed with a loud error if Python 3 is missing at install time.
- **Reversibility**: low. The manifest schema is now load-bearing; future migrations must read v1 and rewrite to vN. Mitigated by `schema_version: 1` in D3.
- **Requirement link**: R6 (closed state enum including `drifted-ours` and `user-modified`), R7 (conflict policy), R8 (update semantics), AC3.a (source clone movable/deletable).

**Classifier pseudocode (informs TPM's plan):**

```
classify_copy_target(consumer_root, relpath, expected_sha_at_new_ref, manifest) →
  dst = consumer_root + "/" + relpath
  if ! -e dst && ! -L dst:
      return "missing"
  if -L dst:
      return "real-file-conflict"    # we never create symlinks here (R1)
  if -d dst:
      return "real-file-conflict"    # dir where a file is expected
  if ! -f dst:
      return "real-file-conflict"    # other non-regular files (fifo, device)
  actual_sha = sha256(dst)
  if actual_sha == expected_sha_at_new_ref:
      return "ok"
  baseline_sha = manifest.files[relpath]    # may be absent (first-appeared-in-new-ref)
  if baseline_sha is None:
      # File is new in the new ref, but the destination already has content at
      # that path. The user must have created it manually — cannot be ours.
      return "user-modified"
  if actual_sha == baseline_sha:
      return "drifted-ours"
  return "user-modified"
```

Dispatcher (mutations here only):

```
case state in
  missing)             write_with_atomic_swap(dst, content);  report "created" ;;
  ok)                  report "already" ;;
  drifted-ours)        cp "$dst" "$dst.bak"; write_with_atomic_swap(dst, content); report "replaced:drifted"; ;;
  user-modified)       report "skipped:user-modified"; MAX_CODE=1 ;;
  real-file-conflict)  report "skipped:real-file-conflict"; MAX_CODE=1 ;;
  foreign)             report "skipped:foreign"; MAX_CODE=1 ;;
esac
```

### D5. `classify_copy_target` and `plan_copy` — ported from `classify_target` + `plan_links`

- **Options considered**:
  - A. Port `bin/claude-symlink`'s `classify_target` verbatim and bolt hash-comparison on top.
  - B. Write a fresh classifier from scratch that handles only the five content-state cases.
  - C. Reuse `classify_target` via sourcing a shared lib.
- **Chosen**: **A — port and extend**. `bin/specflow-seed` embeds a new `classify_copy_target` whose shape matches the claude-symlink classifier (pure function, stdout-only, closed enum, no side effects) but whose states are content-oriented (D4) rather than link-oriented.
- **Why**:
  - Keeps the mental model identical across tools: classify-before-mutate is the pattern; each tool instantiates it for its own domain.
  - Option C (shared lib) is tempting but premature — one shared helper at two callsites is not enough volume to justify extraction, and `bin/claude-symlink` is frozen during implement (R10).
- **Tradeoffs accepted**: 40–60 lines of classifier code duplicated in spirit (not in body — different enum, different branch table) between the two tools. Acceptable; if a third tool lands, extract.
- **Reversibility**: medium — extraction to a shared `lib/` is a refactor that preserves external contract.
- **Requirement link**: R6, project rule `common/classify-before-mutate.md`.

### D6. `update` ref selection — explicit `--to <ref>`, no default-HEAD

- **Options considered**:
  - A. `--to <ref>` required.
  - B. Default to HEAD of source-repo clone if `--to` omitted.
  - C. Prompt interactively.
- **Chosen**: **A — `--to <ref>` required on `update`**. If omitted, `update` exits 2 with usage.
- **Why**:
  - Version pinning is the whole point. Defaulting to HEAD silently surprises the user on any source-repo clone advancement; explicit choice every time honours PRD's "user chooses when" intent.
  - Non-interactive prompts break CI and agent invocation.
  - `migrate` differs (D10) — it defaults to the source-clone's current HEAD because migration is a one-shot at a known moment; for `migrate`, defaulting is ergonomic.
- **Tradeoffs accepted**: two extra keystrokes per `update` invocation. Accepted.
- **Reversibility**: high — flip to optional with a default later via one-line change.
- **Requirement link**: R8.

### D7. `migrate` source-repo discovery — multi-layered fallback

- **Options considered**:
  - A. Hardcode a conventional path (`~/tools/spec-workflow`).
  - B. Require `--from <path>` always.
  - C. Discover via `readlink ~/.claude/agents/specflow` → resolve to source-repo root.
  - D. Read env var `SPECFLOW_SRC`.
- **Chosen**: **Layered fallback**:
  1. `--from <path>` explicit arg (highest priority).
  2. Env var `$SPECFLOW_SRC` if set.
  3. **Auto-discover via `readlink ~/.claude/agents/specflow`** (portable readlink, no `-f`): resolve, then strip `.claude/agents/specflow` suffix. This IS the current global-install pointer by construction.
  4. Exit 2 with a clear error message listing the three options.
- **Why**:
  - `migrate` runs on machines where the global symlinks currently exist (PRD §2.3 user case). Option C is zero-config for the common case.
  - Options A (hardcoded path) and B (always require arg) both fail ergonomics for the common migration case where the symlink already points at exactly the right place.
  - The layered fallback is the same shape as most config-discovery flows — arg > env > auto-detect > error.
- **Tradeoffs accepted**:
  - If the user has multiple source clones on disk and the global symlink points at one but they want to migrate off a different one, they must pass `--from`. Documented.
  - Auto-discovery assumes the global install is intact; if the user has already manually torn it down, auto-discovery fails and the error message is the nudge to use `--from`.
- **Reversibility**: high.
- **Requirement link**: R9 (migrate semantics), AC9.a.

### D8. Hook-wiring reuse — `init` invokes `<src>/bin/specflow-install-hook` directly

- **Options considered**:
  - A. `init` shells out to `<src>/bin/specflow-install-hook add SessionStart …` and `add Stop …`.
  - B. `init` copies `bin/specflow-install-hook` into the consumer first, then invokes the local copy.
  - C. `init` inlines the read-merge-write logic in Python 3.
- **Chosen**: **A — invoke `<src>/bin/specflow-install-hook` directly during `init` / `migrate`**. The consumer never gets its own copy of this helper.
- **Why**:
  - `bin/specflow-install-hook` is needed only at install-time (init / migrate), not at session runtime. It does not count as "shared-mutable runtime state" per R3 — R3 forbids runtime dependencies, not install-time tooling that just happens to sit in the source clone.
  - Inlining (C) duplicates the discipline in a second place; the settings-json-safe-mutation memory explicitly warns against this.
  - Copying into the consumer (B) bloats the consumer's tree with a file the consumer will never invoke; adds maintenance surface.
  - Since `init` and `migrate` are already in the process of copying from `<src>/`, they definitionally have `<src>` reachable at invocation time. Using its `bin/specflow-install-hook` costs nothing.
- **Tradeoffs accepted**: if the user runs `init` by pointing at a snapshot of the source repo that happens to lack `bin/specflow-install-hook`, `init` exits 2. Mitigation: `init` preflights the presence of both `bin/specflow-install-hook` and the expected `.claude/` subtrees before any mutation; if preflight fails, no filesystem change occurs.
- **Reversibility**: high — switch to (B) later by adding one copy line in `plan_copy` and one invocation-path swap in hook-wiring.
- **Requirement link**: R2 (hooks wired via existing helper), R3 (single global artefact — this keeps the helper out of global).

### D9. Installed `.claude/` and manifest — committed to consumer git, with opt-out pattern

- **Options considered**:
  - A. Consumer commits `.claude/` + `.claude/specflow.manifest` to their git. Every file-level change is git-diff-visible.
  - B. Consumer `.gitignore`s `.claude/` entirely; must re-`init` after every fresh clone.
  - C. Commit only `.claude/specflow.manifest`; `.gitignore` the rest. Re-`init` using the manifest's ref on fresh clone.
- **Chosen**: **A — commit `.claude/` and `.claude/specflow.manifest`**. Documentation (R12) instructs the user. `.gitignore` additions are explicitly **not** added by `init`; `init` respects the consumer's existing `.gitignore`.
- **Why**:
  - **Team-memory provenance requires commit**: the consumer's team-memory grows over time as lessons accumulate; losing that on every fresh clone defeats the feature's purpose (PRD goal 3). B and C both break team-memory continuity unless team-memory is committed and the rest is ignored — which is option B-split, logically messy.
  - **Ergonomics on fresh clone**: under A, a fresh `git clone` gets a fully-working specflow consumer immediately; no bootstrap step. Under B, every CI run and every new-developer clone needs to re-run `init`, which requires the source-repo clone to be reachable — breaks the "consumer self-contained" goal at clone time.
  - **Per-project isolation** (PRD goal 1): version pinning requires the manifest to be committed (the ref IS the pin). Option B defeats this.
  - **Disk/git-history cost**: a few hundred files totalling <200 KB. Trivial in modern git. `git log --follow` on an individual agent.md file is actually a feature — contributors can see what changed in specflow at this consumer's version.
- **Tradeoffs accepted**:
  - Consumer's `git log` and `git blame` show specflow framework changes alongside project changes. Mitigation: documented in README (R11) that specflow framework files under `.claude/agents/specflow/`, `.claude/commands/specflow/`, `.claude/hooks/` are "owned upstream"; the consumer should not hand-edit them and should pull upstream changes via `update`.
  - Consumer's first commit after `init` is large (hundreds of added files). Acceptable — it's the bootstrap commit.
- **Reversibility**: medium — switching to split commit/ignore model later is doable but requires careful migration (users' .gitignore files need to be rewritten).
- **Requirement link**: PRD §4 ("installed `.claude/` committed or gitignored — tech's call"), R12 (docs document whichever).

### D10. `migrate` symlink teardown — scoped to hooks-pointer only

- **Options considered**:
  - A. `migrate` removes all global `~/.claude/` specflow symlinks as part of the migration.
  - B. `migrate` leaves all global symlinks in place; user runs `bin/claude-symlink uninstall` manually when ready.
  - C. `migrate` removes only the `~/.claude/hooks/` link because that's the one the consumer was consulting for hook-script path resolution; leaves `~/.claude/agents/specflow`, `~/.claude/commands/specflow`, and `~/.claude/team-memory/` in place because they're shared across un-migrated consumers.
- **Chosen**: **B — leave all global symlinks in place; document that `bin/claude-symlink uninstall` is the manual teardown step once every consumer on the machine has migrated.** `migrate` only rewires `<consumer>/settings.json` to point at local hooks.
- **Why**:
  - AC9.a: "Other projects' data under `~/.claude/` is unaffected (verifiable by hashing `~/.claude/` content unrelated to the migrated bits before and after)". **Every global symlink under `~/.claude/agents/specflow`, `~/.claude/commands/specflow`, `~/.claude/hooks`, `~/.claude/team-memory/` is shared across every consumer on the machine.** Removing any of them from one consumer's migrate would break every other consumer still relying on the global install.
  - Option A violates AC9.a directly. Rejected.
  - Option C is half-measures: removing `~/.claude/hooks/` does break other consumers whose `settings.json` still points at `~/.claude/hooks/session-start.sh`.
  - Option B is the only option that respects AC9.a absolutely.
  - The user-facing story: "`migrate` makes this consumer self-contained. Run `bin/claude-symlink uninstall` once every consumer on this machine has migrated." README documents this (R11).
- **Tradeoffs accepted**:
  - The global symlinks persist even after all consumers have migrated, until the user runs `claude-symlink uninstall`. Benign — they're unreferenced, no runtime effect.
  - The PRD phrasing "removes only the `~/.claude/` symlinks that this particular migration replaced" (R9 body) reads as if `migrate` should remove something; in practice, nothing under `~/.claude/` is "replaced by this migration" because the global symlinks are shared. **The real replacement happens in `settings.json`**: the hook path in the consumer's settings swaps from `~/.claude/hooks/...` to `.claude/hooks/...`. This is the only "teardown" `migrate` performs.
  - Update to R9 body needed (recommend: architect flags this for the PM's attention; marked as **note, not blocker** in §5 below).
- **Reversibility**: high — if future feedback demands teardown, opt-in flag `--teardown-global` can be added to `migrate` at that time.
- **Requirement link**: R9, AC9.a, AC10.a (claude-symlink external contract preserved).

### D11. Copy mechanism — per-file write via write-temp + rename (no cp -R)

- **Options considered**:
  - A. `cp -R <src>/.claude/... <consumer>/.claude/...`.
  - B. `rsync -a` with `--checksum`.
  - C. `tar -cf - | tar -xf -` pipeline.
  - D. Per-file loop: classify each planned path, then for each non-skip destination call Python 3 to write-temp + atomic-rename.
- **Chosen**: **D — per-file loop through the classifier**. Each non-skip destination written via Python 3 helper that reads the source bytes, writes `<dst>.tmp`, computes SHA256, `os.replace(tmp, dst)`.
- **Why**:
  - The classifier (D5) must run per-file anyway to emit `ok` / `drifted-ours` / `user-modified` verbs with file-granular output. So the write path is already per-file.
  - `cp -R` clobbers without classification. Rejected.
  - `rsync` has flags (`--ignore-existing`, `--update`) that approximate but don't match our five-state enum. Rejected — we want full control.
  - Atomic swap on every file ensures no partial-write window for any single file (no half-written agents/architect.md if the tool is interrupted mid-run).
- **Tradeoffs accepted**: per-file Python 3 invocation is slower than `cp -R`. Acceptable — payload is hundreds of small files, total runtime <1s on any modern machine.
- **Reversibility**: high — swap to `cp -R` for the "all missing" fast-path later if perf bites, but the classifier still has to run for conflict paths.
- **Requirement link**: R6, R7 (per-file dispatch), R13 (no `--force`/`rm -rf`/unconditional overwrite).

### D12. Smoke-test harness — reuse `test/smoke.sh`, add `t39`–`t5X` tests per AC

- **Options considered**:
  - A. Extend existing `test/smoke.sh`.
  - B. Start a new `test/per-project-install/` harness.
  - C. BATS test framework.
- **Chosen**: **A — extend `test/smoke.sh`**. Follow the existing `mktemp -d` sandbox + preflight `HOME=$SANDBOX/home` template for every new test.
- **Why**: matches repo convention; all existing 38 tests run there; reviewers know the pattern.
- **Tradeoffs accepted**: `test/smoke.sh` grows longer. Acceptable — can split files later (`test/smoke-seed.sh` sourced by `test/smoke.sh`) once past 100 tests.
- **Reversibility**: high.
- **Requirement link**: R13 (AC13.b — mktemp sandbox pattern in all tests).

---

## 4. Cross-cutting Concerns

### Error handling strategy

- **`bin/specflow-seed`**: same error model as `bin/claude-symlink` — `set -u -o pipefail`, no `set -e` (accumulate conflicts, continue loop), every mutation wrapped in `if ! <cmd>; then report failure; MAX_CODE=1; continue; fi`, exit code 0/1/2 per R7/AC7.c.
  - 0 = every managed path converged.
  - 1 = any `skipped:*` or any mutation failed.
  - 2 = usage error, unresolvable source repo, Python 3 missing (install-path needs it for manifest write), corrupt manifest.
- **Python 3 helpers invoked via heredoc** (manifest read/write, atomic file write, SHA compute) follow the existing `bin/specflow-install-hook` pattern: python3 preflight at top of script, loud error if missing.
- **Manifest parser is fail-loud**: schema mismatch, unparseable JSON, missing required keys → exit 2, no mutation. This is the "corrupt manifest" case from D4.

### Logging / tracing / metrics

- **stdout**: one line per managed path (`[created]  <rel-path>`, `[already]`, `[replaced:drifted]  <rel-path>`, `[skipped:user-modified]  <rel-path>`, etc.), final `summary: created=N already=N replaced=N skipped=N (exit K)` line. Mirrors `bin/claude-symlink`'s report format.
- **stderr**: only on error (source repo not found, Python 3 missing, manifest corrupt, atomic rename failed).
- **No metrics, no log file.** Matches precedent.

### Security / authn / authz posture

- **No secrets involved.** All paths local; no network.
- **Path confinement**: `specflow-seed` only writes under `<consumer>/.claude/`, `<consumer>/.spec-workflow/features/_template/`, and `<consumer>/settings.json` (via the existing hook helper). Never writes to `<src>`, never writes outside `<consumer>`.
- **No `rm -rf`**: the only removals are (a) hook-wiring entries in `settings.json` via the existing helper's `remove` verb, (b) the single-slot `.bak` files during atomic swap. No directory removal, no recursive removal.
- **Ownership check for `migrate` source-discovery**: when auto-discovering via `readlink ~/.claude/agents/specflow`, `specflow-seed` asserts the resolved path contains a `bin/specflow-seed` and a `.claude/agents/specflow/` subtree — both structural markers of a specflow source repo. If either is missing, refuse to proceed.
- **Symlinks**: none created in the consumer tree (R1). `init` skill distribution (D1) uses plain `cp -R`, no symlinks.

### Testing strategy (feeds Developer's TDD)

| Test | Level | What it asserts | Maps to AC |
|---|---|---|---|
| `t39_init_fresh_sandbox.sh` | integration | Fresh sandbox consumer; `init --from <src> --ref <sha>` creates `<consumer>/.claude/agents/specflow/**`, `commands/specflow/**`, `hooks/**`, `rules/**`, `team-memory/<role>/index.md`, `.spec-workflow/features/_template/**`, writes `specflow.manifest` with ref + SHAs; no symlinks created. | AC1.a, AC1.c, AC2.a, AC4.a, AC5.a |
| `t40_init_idempotent.sh` | integration | Re-run `init` on already-initialised consumer at same ref → every path reports `already`, byte-identical filesystem before/after. | AC2.b, byte-identical-refactor-gate memory |
| `t41_init_preserves_foreign.sh` | integration | Pre-existing real file at a managed path → `skipped:real-file-conflict`, exit non-zero, untouched. | AC2.c, AC7.c |
| `t42_update_no_conflict.sh` | integration | Initialised consumer at ref A; `update --to <ref-B>` → every changed file reports `replaced:drifted`, `.bak` exists, manifest advances to ref B. | AC8.a, AC7.b |
| `t43_update_user_modified.sh` | integration | Initialised consumer at ref A; user hand-edits one file; `update --to <ref-B>` → `skipped:user-modified` for that file, `replaced:drifted` for others, manifest **unchanged** (still ref A), exit non-zero. Re-run `update --to <ref-B>` after user reverts → advances. | AC7.a, AC8.b |
| `t44_update_never_touches_team_memory.sh` | integration | Initialised consumer; user seeds team-memory with a local lesson; `update --to <ref-B>` → no path under `.claude/team-memory/` is read/written (verified by mtime). | AC4.b, AC8.c |
| `t45_migrate_from_global.sh` | integration | Sandbox with a pre-staged global install (`~/.claude/agents/specflow` → `<src>/.claude/agents/specflow`, same for commands/hooks/team-memory), consumer `settings.json` pointing at `~/.claude/hooks/*`; `migrate` → consumer gets local `.claude/` tree, settings.json rewired to local paths, global symlinks **untouched**, hash of `~/.claude/` unrelated to migrated bits unchanged. | AC9.a, AC9.b, D10 |
| `t46_migrate_dry_run.sh` | integration | `migrate --dry-run` → filesystem state byte-identical before/after across consumer, source, and `~/.claude/`. | AC9.c, R6 AC6.a |
| `t47_migrate_user_modified.sh` | integration | Migration with one `user-modified` path → `skipped:user-modified`, global symlinks untouched, exit non-zero. | AC9.d |
| `t48_seed_rule_compliance.sh` | static | `grep -rn 'readlink -f\|realpath\|jq\|mapfile\|rm -rf\|--force' bin/specflow-seed` returns empty. `bash -n bin/specflow-seed` clean. | AC13.a, AC13.c |
| `t49_init_skill_bootstrap.sh` | static | `~/.claude/skills/specflow-init/SKILL.md` bootstrappable via `cp -R`; file exists in source repo; skill syntax valid. | D1, R3 AC3.b |
| `t50_dogfood_staging_sentinel.sh` | static/structural | Before final migration task: `bin/claude-symlink install/uninstall/update --dry-run` exit 0; `~/.claude/agents/specflow` still resolves to `<src>`. Covers the opt-out sentinel (D13 below). | AC10.a |

Every test sandboxes `$HOME` per `bash/sandbox-home-in-tests.md` with preflight, trap-on-EXIT cleanup, and refuses to run against real `$HOME`.

**R10 dogfood note**: `t39`–`t47` run in sandbox `$HOME` and **do not** exercise the live migration of THIS repo. The final migration task (R10 AC10.b) is not smoke-tested by the harness; it is executed once, manually, as the final task of the implement stage, with byte-identical verification (the byte-identical-refactor-gate memory's discipline applied to whole subtrees).

### Performance / scale targets

- **`init` / `update` / `migrate` runtime**: <2s on a warm machine for a payload of ~300 files. No AC specifies a perf budget; this is a soft target. No optimization effort beyond "don't do anything obviously wasteful" (e.g., read each source file exactly once per run; compute each SHA once per run; don't invoke Python 3 in a loop — batch the write operations through a single Python 3 invocation that reads the plan from stdin).
- **No runtime perf impact on Claude Code sessions**: the tools only run at install time. The hook runtime path is unchanged.

---

## 5. Open Questions

**None blocking.**

One **note** (not a blocker):

- **N1. PRD R9 body phrasing vs D10 chosen behaviour.** PRD R9 body says `migrate` "removes only the `~/.claude/` symlinks that this particular migration replaced". Per D10's analysis, no `~/.claude/` symlinks are safely removable by a single consumer's migration (they're all shared). The `settings.json` rewiring is the only "replacement" `migrate` performs. Recommendation: PM updates R9 body at `/specflow:update-req` time to match D10; AC9.a already encodes the correct behaviour ("other projects' data under `~/.claude/` unaffected"), so the AC set is consistent — this is a body-text clarification only. **Not a blocker**: implementation follows D10 and AC9.a; R9 body-text update is a downstream doc hygiene item surfaced to PM.

---

## 6. Non-decisions (deferred)

- **D13. Opt-out sentinel for same-feature-implement flows.** Per `shared/dogfood-paradox-third-occurrence.md` and `shared/opt-out-bypass-trace-required.md`, any orchestration that assumes per-project installs must have a bypass. The concrete shape (env var? sentinel file at `<consumer>/.claude/.specflow-no-manifest-yet`?) is deferred to TPM's plan: the only thing Architect mandates is that if `specflow-seed update` is invoked in a consumer with no manifest, it exits 2 with a message pointing the user at `init` or `migrate` — same consumer never silently runs against a manifest-less state. **Trigger to revisit**: TPM / Developer signal during plan stage that a specific orchestration path needs the bypass.
- **D14. Team-memory promotion pathway.** A future feature may need a flow that promotes a consumer's local lesson into the source repo (the opposite direction of `update`). Out of scope; the `--dry-run` contract on `update` is the attachment point. **Trigger**: user requests cross-machine lesson sharing.
- **D15. Schema migration for `specflow.manifest` v1 → v2.** Today's schema is v1. Future schema changes need a migration path (detect old schema, rewrite on next successful `update`). **Trigger**: first schema change after archive.
- **D16. CI-install flow** (fresh clone in a CI runner). Today the assumption is consumer commits `.claude/` (D9) so fresh clone = working consumer. If future consumers gitignore `.claude/`, a CI-install flow is needed. **Trigger**: user opts out of D9 and reports CI breakage.
- **D17. `--force` flag** — explicitly forbidden by project rule `common/no-force-on-user-paths`. No trigger; not reopening.
- **D18. Three-way merge of user-modified files** — explicitly rejected by PRD R7 and §4. **Trigger**: user reports that skip-and-report is too aggressive for routine conflicts. Until then, skip is the v1 policy.
- **D19. `update --to HEAD` default-to-HEAD shorthand** — D6 rejects. **Trigger**: repeated user friction.
- **D20. `.gitignore` additions by `init`** — D9 chooses not to. **Trigger**: user reports accidental commits of `.bak` or `.tmp` stragglers.

---

## 7. File-level impact map (feeds TPM's plan stage)

| File | Action | Purpose |
|---|---|---|
| `bin/specflow-seed` | **CREATE** | New multi-subcommand bash script: `init`, `update`, `migrate`, `--dry-run`. Ports the classifier scaffold from `bin/claude-symlink`; embeds `classify_copy_target` + `plan_copy` + manifest read/write (via Python 3 heredoc). |
| `.claude/skills/specflow-init/SKILL.md` | **CREATE** | Global `init` skill description; single source of truth for `/specflow-init` prompt. |
| `.claude/skills/specflow-init/init.sh` | **CREATE** | Tiny bootstrap script the skill invokes: locates source clone, shells out to `<src>/bin/specflow-seed`. |
| `bin/claude-symlink` | **UNCHANGED** during implement; **UNCHANGED external contract** through the final migration task. R10, AC10.a binding. No edits in tasks T1..T(N-1); the R10 final task does not edit this file either (it stays the tool that un-migrated consumers continue to use). |
| `bin/specflow-install-hook` | **UNCHANGED** | Re-used verbatim by `bin/specflow-seed` at install-time for `settings.json` rewiring. |
| `.claude/hooks/session-start.sh` | **UNCHANGED** | Copied into consumers by `init`/`migrate` as regular file. |
| `.claude/hooks/stop.sh` | **UNCHANGED** | Ditto. |
| `test/smoke.sh` | **EXTEND** | Add tests t39..t50 per §4. Existing t1..t38 stay green. |
| `README.md` | **UPDATE** | Document `init` / `update` / `migrate`; deprecation notice on `bin/claude-symlink install` section; verb vocabulary table (R11, R12). |
| `<consumer>/.claude/specflow.manifest` | **CREATE per consumer at `init` time** | Schema v1 JSON: ref + source_remote + applied_at + per-file SHA map. |
| `<this-repo>/.claude/specflow.manifest` | **CREATE at R10 final migration task** | Same schema; this repo becomes its own first per-project consumer. |
| `<this-repo>/settings.json` | **REWIRE at R10 final migration task** | Hook paths switch from `~/.claude/hooks/...` to `.claude/hooks/...` via `bin/specflow-install-hook remove` + `add`. Backup `.bak` produced. |

---

## 8. Acceptance checks the Architect stands behind

Developer must demonstrate:

1. **`bin/specflow-seed init` on a fresh sandbox consumer** produces all managed subtrees, a valid manifest, wired `settings.json` hooks at consumer-local paths, and zero symlinks under `<consumer>/.claude/`.
2. **Idempotent `init`** — second run at same ref reports `already` on every path, byte-identical before/after (`find <consumer> -type f | xargs shasum` identical).
3. **`update --to <new-ref>`** with no conflicts advances the manifest ref, creates `.bak` siblings for replaced files, exits 0.
4. **`update --to <new-ref>`** with one user-modified file skips that file, does **not** advance the manifest ref, exits non-zero. Re-running after revert advances it.
5. **`update` never touches `<consumer>/.claude/team-memory/`** — verified by mtime on the team-memory tree being unchanged by any `update` run.
6. **`migrate` from a sandboxed global install** produces a self-contained consumer AND leaves `~/.claude/` content unrelated to the migration byte-identical.
7. **`migrate --dry-run`** produces a byte-identical state on all three roots (consumer, source, `~/.claude/`).
8. **All bash scripts pass `bash -n`** and grep-clean against `readlink -f | realpath | jq | mapfile | \[\[ .*=~ | rm -rf | --force`.
9. **R10 staging holds**: at the start of verify (before the final migration task), `bin/claude-symlink install/uninstall/update --dry-run` all exit 0 with the pre-feature contract. After the final migration task, this repo's `settings.json` points at local hook paths, a `specflow.manifest` exists at the repo root, and the global `~/.claude/agents/specflow` symlink is left in place (per D10).

---

## 9. Memory candidates flagged for archive retro

Not written now. Flagged for PM/Architect at `/specflow:archive`:

- **`architect/manifest-sha-baseline-for-drifted-ours.md`** — pattern: "When a classifier needs to distinguish `user-modified` from `drifted-ours` on per-file replacements, the baseline MUST be a local content-hash table (not a re-fetch from upstream). Carrying per-file hashes in a single-file JSON manifest satisfies 'upstream unreachable' while keeping the classifier a pure function." Strong promote candidate.
- **`architect/init-skill-distribution-pattern.md`** — pattern: "Global Claude Code skills live under `~/.claude/skills/<slug>/SKILL.md`. For a specflow-style tool that needs exactly one global entry point and everything else consumer-local, ship the skill in the source repo and bootstrap to global via `cp -R` — no symlink, no network, no second package." Promote candidate.
- **`architect/migrate-vs-teardown-shared-state.md`** — pattern: "When migrating one consumer off shared global state, the migration MUST NOT tear down the shared state itself, because other consumers still depend on it. Migrate the *pointer*, not the *target*." Promote candidate if/when a second migrate-style feature appears.

---

## Summary

- **D-count**: 12 primary decisions (D1–D12), 8 deferred (D13–D20).
- **§5 blockers**: **none** (one PRD body-text note N1, not a blocker; implementation follows D10 + AC9.a).
- **Memory candidates**: 3 flagged for retro.
- **Applied memory entries**: `classification-before-mutation`, `no-force-by-default`, `settings-json-safe-mutation`, `shell-portability-readlink`, `script-location-convention`, `byte-identical-refactor-gate`, `dogfood-paradox-third-occurrence`, `opt-out-bypass-trace-required`.
