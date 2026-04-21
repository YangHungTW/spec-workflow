# Plan — per-project-install

_2026-04-18 · TPM_

## Team memory consulted

- `tpm/parallel-safe-requires-different-files.md` (global + local) — load-bearing for §2 wave sequencing. The three flow implementations (`cmd_init`, `cmd_update`, `cmd_migrate`) ALL live inside one file (`bin/specflow-seed`, D2). Logical independence is insufficient — same-file dispatcher-arm edits collide textually. Must serialize across waves, OR bundle into one task and accept the one-developer sequencing cost.
- `tpm/parallel-safe-append-sections.md` (global + local) — applied to `test/smoke.sh` registrations (deferred to last wave per the B2.a / B2.b precedent — single-editor for smoke.sh, zero collision), `STATUS.md` Notes (standard keep-both), `.claude/rules/index.md` (not touched this feature). No over-serialization on append-only grounds.
- `tpm/checkbox-lost-in-parallel-merge.md` — this feature's widest wave is 3-way (see §2 Wave 3: three test files). Under the 7-way / 9-way precedent, 3-way is low risk for checkbox drops, but the post-merge audit remains a cheap cross-cutting discipline (§3).
- `tpm/briefing-contradicts-schema.md` — applied to the next stage: `/specflow:tasks` MUST quote the D3 manifest JSON schema verbatim from `04-tech.md` §3 into any task that authors the manifest. No paraphrase of `schema_version: 1`, `specflow_ref`, `files`.
- `shared/dogfood-paradox-third-occurrence.md` — 6th occurrence. R10 staging is the textbook application: this repo is migrated LAST (§6). Structural-only verify during same-feature 08-verify.md; runtime confirmation on the next feature after session restart.

## 1. Goal recap

Deliver per-project specflow install via a new `bin/specflow-seed` CLI with three subcommands (`init`, `update`, `migrate`), plus a single global `~/.claude/skills/specflow-init/` bootstrap (D1). Each consumer repo becomes self-contained at its own pinned ref, with its own team-memory, via classify-before-mutate + backup-before-replace semantics. The existing `bin/claude-symlink` external contract is preserved throughout implement (R10); this repo itself is migrated to the per-project model as the final task.

## 2. Wave breakdown

Six waves, 11–13 placeholder tasks total. Wave-internal parallelism is governed strictly by file independence (per `parallel-safe-requires-different-files.md`).

### Wave 0 — Manifest + classifier scaffolding (upstream of every flow)

**Tasks**:
- **T-seed-skeleton** (`bin/specflow-seed` create): shebang, `set -u -o pipefail` (no `set -e`, accumulate-and-continue), OS guard, flag parser (`--dry-run`, `--from`, `--to`, `--ref`), subcommand dispatcher (`init` / `update` / `migrate`), stub `cmd_init` / `cmd_update` / `cmd_migrate` that each echo their name + exit 0. Ports `die`, `resolve_path`, repo-root resolution helpers from `bin/claude-symlink`. NO mutation logic yet. Exit-code contract scaffolded (`MAX_CODE=0`, 0/1/2 semantics). Preflight: refuse to run if `python3` missing (install-path requires it per D4).

**Placeholder-task count this wave**: 1.

**Parallelism**: n/a (single task).

**Gating to advance**: `bash -n bin/specflow-seed` clean; `bin/specflow-seed --help` exits 0; all three subcommand stubs exit 0 and echo. No filesystem mutation on any invocation.

**Rationale**: the seed skeleton is a hard prerequisite for every downstream task — `init`, `update`, `migrate` implementations, and the classifier itself all live inside this file. Splitting the skeleton across tasks re-triggers the same-file-dispatcher collision pattern from `symlink-operation` Wave 2. Bundle.

### Wave 1 — Classifier + manifest library (shared by all three flows)

**Tasks**:
- **T-classify-copy-target** (into `bin/specflow-seed`): port `classify_target` shape from `bin/claude-symlink` into new `classify_copy_target` per D4/D5. Pure function; emits one of `missing | ok | drifted-ours | user-modified | real-file-conflict | foreign` on stdout. Hash helper `sha256_of <path>` dispatches on `uname -s` (BSD `shasum -a 256` vs GNU `sha256sum`; Python 3 fallback) — same wrapper shape as B2.a's `to_epoch`.
- **T-manifest-io** (into `bin/specflow-seed`): Python 3 heredoc helpers — `manifest_read <path>` (returns KV + file map; fail-loud on schema mismatch or unparseable JSON per D4 tradeoff), `manifest_write <path> <ref> <files-map>` (write-temp + atomic `os.replace`, schema_version=1 per D3). Grep-based bash fallback for reading just the ref line (bash 3.2 safe `awk -F'"' '/"specflow_ref"/'` per D3 rationale).
- **T-plan-copy** (into `bin/specflow-seed`): `plan_copy` enumerates the managed-set relpaths: `.claude/agents/specflow/**`, `.claude/commands/specflow/**`, `.claude/hooks/**`, `.claude/rules/**`, `.spec-workflow/features/_template/**`, plus the synthesized team-memory skeleton paths (one `index.md` per role dir + `shared/README.md` + `shared/index.md` per R4). Emits a flat plan array (indexed bash arrays per D1 / bash 3.2 floor, no associative arrays).

**Placeholder-task count this wave**: 3.

**Parallelism**: all three tasks edit the SAME file (`bin/specflow-seed`) — Parallel-safe-with: none. Serialize within the wave, OR merge into one task. TPM tasks stage must decide (§7 guidance: merge into one task given small logical blast radius of these helpers; splitting only buys developer-level bookkeeping, not parallel speed).

**Gating to advance**: `classify_copy_target` unit-fuzzable from a hidden `__probe` subcommand (echoes classifier output given a `(consumer_root, relpath, expected_sha, baseline_sha)` tuple); `manifest_read` / `manifest_write` round-trip a fixture JSON byte-identically; `plan_copy` emits every expected relpath under a fresh sandbox (count matches `find .claude/{agents/specflow,commands/specflow,hooks,rules} -type f | wc -l` + `_template` + team-memory skeleton count).

**Rationale**: this is the CRITICAL PATH — the classifier and manifest IO are consumed identically by `init`, `update`, `migrate`. Must land before ANY flow implementation. Per `parallel-safe-requires-different-files.md`, three same-file tasks cannot run in parallel; either serial-within-wave or merge-to-one. Sizing decision deferred to §7.

### Wave 2 — `init` flow + its smoke test (TDD-adjacent)

**Tasks**:
- **T-cmd-init** (into `bin/specflow-seed`): `cmd_init` dispatcher. Reads `--from <src>` / `--ref <ref>` args; resolves source-repo root (D7 fallback: arg > env > auto-discover via `readlink ~/.claude/agents/specflow`); invokes `plan_copy`; loops destinations calling `classify_copy_target`; dispatches per R7 table (`missing` → write via Python 3 atomic-swap heredoc per D11; `ok` → report `already`; `drifted-ours` → `.bak` + atomic-swap per R7; `user-modified` → skip; `real-file-conflict` → skip; `foreign` → skip). Writes manifest at `<consumer>/.claude/specflow.manifest` per D3 with schema_version=1, ref, timestamp, source_remote, per-file SHA map. Invokes `<src>/bin/specflow-install-hook add SessionStart .claude/hooks/session-start.sh` and `add Stop .claude/hooks/stop.sh` per D8, both referencing the **consumer-local** path. Emits summary per R7 exit-code contract.
- **T-test-init-fresh** (`test/t39_init_fresh_sandbox.sh`): sandbox `$HOME` per `.claude/rules/bash/sandbox-home-in-tests.md`; synthesize a fake consumer repo in sandbox; invoke `bin/specflow-seed init --from <this-repo> --ref <test-sha>`; assert every managed subtree populated (agents/commands/hooks/rules/template/team-memory-skeleton), manifest present with correct ref + non-empty files map, zero symlinks under `<consumer>/.claude/`, settings.json contains exactly one SessionStart + one Stop entry pointing at `.claude/hooks/*`, exit 0. Covers AC1.a, AC1.c, AC2.a, AC4.a, AC5.a.
- **T-test-init-idempotent** (`test/t40_init_idempotent.sh`): as t39, then re-run `init` against the same sandbox at the same ref; assert every path reports `already`, byte-identical filesystem before/after (via `find <consumer> -type f -exec shasum {} \; | sort | shasum`). Covers AC2.b.

**Placeholder-task count this wave**: 3.

**Parallelism**:
- T-cmd-init edits `bin/specflow-seed` — same-file as Wave 1 but Wave 1 has gated.
- T-test-init-fresh and T-test-init-idempotent each write a brand-new file (`t39_*.sh`, `t40_*.sh`) and do NOT register in `smoke.sh` (registration deferred to Wave 5 per the B2.a / B2.b single-editor pattern). Both parallel-safe-with each other AND with T-cmd-init (different files).
- TDD shape: both test tasks can land red-first (before T-cmd-init green) or green-first (after); both work. Recommend same-wave to match the TDD discipline prior features used.

**Gating to advance**: t39 + t40 both exit 0 standalone; `bin/specflow-seed init` in sandbox meets every AC in scope.

**Rationale**: `init` is the simplest flow (every destination is `missing` on a fresh consumer) and the TDD anchor for every classifier-state enum value. Land it first so `update`'s `drifted-ours` + `user-modified` logic has a proven baseline to build on.

### Wave 3 — `update` flow + its smoke tests (TDD-adjacent)

**Tasks**:
- **T-cmd-update** (into `bin/specflow-seed`): `cmd_update`. Requires `--to <ref>` explicit (D6 — no default-HEAD). Reads `<consumer>/.claude/specflow.manifest` to get previous ref + per-file SHA baseline; enumerates managed set at `<to-ref>` via `plan_copy`; for each destination, `classify_copy_target` compares current-on-disk SHA against expected-at-new-ref AND baseline-from-manifest (D4 tri-hash check); dispatches per R7. **Team-memory tree skipped entirely** per R4/R8 — `plan_copy` in `update` mode omits the team-memory skeleton from the plan. Ref-advance gate: if ANY `skipped:user-modified` occurred on a managed path, do NOT rewrite the manifest; exit non-zero. Else rewrite manifest atomically with new ref + new per-file SHA set; exit 0.
- **T-test-update-no-conflict** (`test/t42_update_no_conflict.sh`): sandbox; init at ref-A; synthesize a "newer" source state by editing a source-subtree in a second mktemp fixture; run `update --to <ref-B>`; assert every changed file reports `replaced:drifted`, `.bak` siblings exist byte-identical to pre-update content, manifest ref advanced to ref-B, exit 0. Covers AC7.b, AC8.a.
- **T-test-update-user-modified** (`test/t43_update_user_modified.sh`): sandbox; init at ref-A; hand-edit ONE copied command file; run `update --to <ref-B>`; assert that ONE file reports `skipped:user-modified` and is byte-identical to the pre-update (user-modified) content, OTHER changed files report `replaced:drifted`, manifest ref **unchanged** (still ref-A), exit non-zero; then revert the hand-edit and re-run `update --to <ref-B>`; assert ref advances. Covers AC7.a, AC8.b.
- **T-test-update-skips-team-memory** (`test/t44_update_never_touches_team_memory.sh`): sandbox; init; seed `.claude/team-memory/developer/my-lesson.md` with fake content; capture mtime tree of `.claude/team-memory/**`; run `update --to <ref-B>`; assert mtime tree unchanged and `my-lesson.md` byte-identical. Covers AC4.b, AC8.c.

**Placeholder-task count this wave**: 4.

**Parallelism**: T-cmd-update is same-file (`bin/specflow-seed`) — serialized against Wave 2's T-cmd-init by wave gate. The three test tasks each edit a NEW file (`t42_*.sh`, `t43_*.sh`, `t44_*.sh`) — Parallel-safe-with each other. T-cmd-update can also run parallel with the three test tasks IF tests land red-first; recommend that shape.

**Gating to advance**: t42 + t43 + t44 all exit 0 standalone; manifest ref-advance gate proven correct (advances on clean run; does not advance on conflict run; re-advances after conflict revert).

**Rationale**: `update` is the hardest-to-get-right flow — the `drifted-ours` vs `user-modified` distinction is the crux decision (D4). Landing it separately with its own focused tests, after `init` is green and the classifier's `missing`/`ok` states are proven, reduces blast radius if the manifest schema or tri-hash logic needs iteration.

### Wave 4 — `migrate` flow + its smoke tests (TDD-adjacent)

**Tasks**:
- **T-cmd-migrate** (into `bin/specflow-seed`): `cmd_migrate`. Source discovery per D7 layered fallback (arg > env > `readlink ~/.claude/agents/specflow` auto-discover > exit 2 with clear error). Auto-discovery assertion: resolved path must contain both `bin/specflow-seed` (self) and `.claude/agents/specflow/` (source marker) — refuse to proceed otherwise, per §4 security posture. Runs the same `plan_copy` + `classify_copy_target` + dispatcher as `init`, at the source clone's current HEAD (or `--ref`). After successful copy with no `user-modified` skips: (a) rewrite `<consumer>/settings.json` via `<src>/bin/specflow-install-hook`: `remove SessionStart ~/.claude/hooks/session-start.sh` → `add SessionStart .claude/hooks/session-start.sh`; same for Stop. (b) **Do NOT remove any `~/.claude/` symlinks** per D10 — they're shared across un-migrated consumers; settings.json rewiring is the only "teardown" migrate performs. Idempotent on re-run (every path reports `already`, no settings.json rewrite needed).
- **T-test-migrate-from-global** (`test/t45_migrate_from_global.sh`): sandbox with a pre-staged global install (`$HOME/.claude/agents/specflow` → `<src>/.claude/agents/specflow`, same for commands/hooks/team-memory fixtures), a sandbox consumer repo with `settings.json` pointing at `~/.claude/hooks/*`; capture hash of `~/.claude/` content unrelated to migration; run `migrate`; assert consumer has full local `.claude/` tree (matches init post-state), manifest present, settings.json rewired to `.claude/hooks/*`, global symlinks **untouched** (still resolving to `<src>`), `~/.claude/` unrelated-content hash **unchanged**. Covers AC9.a, AC9.b, D10.
- **T-test-migrate-dry-run** (`test/t46_migrate_dry_run.sh`): sandbox as above; run `migrate --dry-run`; assert byte-identical filesystem state on all three roots (consumer, source-clone fixture, sandboxed `~/.claude/`) before vs after, verified by `find <root> -type f -exec shasum {} \; | sort | shasum`. Covers AC9.c, AC6.a.
- **T-test-migrate-user-modified** (`test/t47_migrate_user_modified.sh`): sandbox with pre-existing hand-edited file at a managed path in the consumer; run `migrate`; assert `skipped:user-modified`, global symlinks still in place, settings.json **not** rewired (because migration did not succeed cleanly), exit non-zero. Covers AC9.d.

**Placeholder-task count this wave**: 4.

**Parallelism**: T-cmd-migrate same-file serialized by wave gate. Three test tasks are different-new-file — Parallel-safe-with each other. T-cmd-migrate can run in parallel with tests if TDD red-first.

**Gating to advance**: t45 + t46 + t47 all exit 0 standalone; D10 symlink-teardown abstention proven (global symlinks hash-identical pre/post); settings.json rewiring atomic and reversible via `.bak`.

**Rationale**: `migrate` is the only flow that touches `$HOME`, so it gets the strictest sandbox discipline per `.claude/rules/bash/sandbox-home-in-tests.md`. Separate wave isolates the D10 "leave symlinks alone" correctness decision — a single AC9.a regression would be catastrophic and the test is the only machine-checkable guard.

### Wave 5 — Init skill + smoke integration + docs

**Tasks**:
- **T-init-skill** (`.claude/skills/specflow-init/SKILL.md` + `.claude/skills/specflow-init/init.sh`): NEW directory. SKILL.md per D1 sketch (YAML frontmatter with `name: specflow-init` + description; body invoking `<src>/bin/specflow-seed <subcmd>` after locating source clone via `$SPECFLOW_SRC` env or prompt). `init.sh` is the tiny bootstrap-helper invoked by the skill: resolves source clone, validates presence of `bin/specflow-seed`, shells out. Bash 3.2 portable. Bootstrap-install documented in README (T-docs) as a one-shot `cp -R <src>/.claude/skills/specflow-init ~/.claude/skills/`.
- **T-test-skill-bootstrap** (`test/t49_init_skill_bootstrap.sh`): structural only — asserts `.claude/skills/specflow-init/SKILL.md` and `.claude/skills/specflow-init/init.sh` both exist in source repo; SKILL.md has the 5-key frontmatter shape; `init.sh` passes `bash -n`. Covers D1, R3 AC3.b.
- **T-test-rule-compliance** (`test/t48_seed_rule_compliance.sh`): static assert — `grep -rn 'readlink -f\|realpath\|jq\|mapfile\|rm -rf\|--force' bin/specflow-seed .claude/skills/specflow-init/` returns empty. `bash -n bin/specflow-seed` and `bash -n .claude/skills/specflow-init/init.sh` clean. Covers AC13.a, AC13.c.
- **T-test-dogfood-sentinel** (`test/t50_dogfood_staging_sentinel.sh`): static — BEFORE the final migration task runs, `bin/claude-symlink install --dry-run`, `uninstall --dry-run`, `update --dry-run` all exit 0 with the pre-feature contract; `readlink ~/.claude/agents/specflow` resolves to `<src>/.claude/agents/specflow`. Covers AC10.a. **Note**: this test asserts state at a specific moment (pre-final-migration); the orchestrator gates the final task on this test being green.
- **T-smoke-register** (`test/smoke.sh` edit): single editor for smoke.sh per the B2.a / B2.b precedent. Adds registrations for t39, t40, t42, t43, t44, t45, t46, t47, t48, t49, t50 — 11 new tests. Final count: 38 + 11 = 49 (structural only — some ACs like AC2.c skipped-real-file may merit a twelfth test; TPM tasks stage decides).
- **T-docs** (`README.md` edit): per R11/R12. Adds top-level "Install" section describing `init` → `update` → `migrate` as primary flow. Documents the `cp -R` bootstrap for the global `specflow-init` skill. Marks `bin/claude-symlink install` and `bin/specflow-install-hook add SessionStart ~/.claude/hooks/…` sections as **deprecated** with a pointer to `migrate`. Enumerates the closed verb vocabulary per R12 (`created`, `already`, `replaced:drifted`, `skipped:user-modified`, `skipped:real-file-conflict`, `skipped:foreign`, plus `would-*` dry-run variants) in a table with one row per verb + remediation pointer. Grep-verifiable per AC11.c.

**Placeholder-task count this wave**: 6.

**Parallelism**: T-init-skill creates 2 new files under a NEW directory — Parallel-safe-with everything in this wave. T-test-skill-bootstrap, T-test-rule-compliance, T-test-dogfood-sentinel each write a different new test file — Parallel-safe-with each other and with T-init-skill. T-smoke-register edits the existing `test/smoke.sh` — single-editor by convention; Parallel-safe-with all test-file tasks (tests DO NOT register themselves — see `parallel-safe-append-sections.md` precedent). T-docs edits `README.md` — solo editor; Parallel-safe-with every other task in this wave.

**Gating to advance**: `bash test/smoke.sh` → green (49/49 or the finalized count); all t48-t50 pass; `grep 'migrate' README.md` + `grep 'deprecated' README.md` both return hits; global skill bootstrap documented.

**Rationale**: Everything here is a different file or a single-editor role; maximum parallelism with zero collision risk. Dogfood sentinel test (t50) is the gate the orchestrator checks BEFORE running Wave 6.

### Wave 6 — Dogfood migration of this repo (final act)

**Tasks**:
- **T-dogfood-migrate** (this repo's filesystem): run `bin/specflow-seed migrate --from .` in this repo. Asserts: (a) t50 was green in Wave 5 (pre-condition sentinel — if fails, abort before any mutation), (b) byte-identical content check per `architect/byte-identical-refactor-gate.md` — this repo's copied `.claude/` subtree must byte-match the source (which is itself). Produces: `<this-repo>/.claude/specflow.manifest` with ref = current HEAD; `<this-repo>/settings.json` rewired from `~/.claude/hooks/*` to `.claude/hooks/*` via the existing hook helper (with `.bak`); `~/.claude/agents/specflow`, `~/.claude/commands/specflow`, `~/.claude/hooks`, `~/.claude/team-memory/*` symlinks **left in place** per D10 (this repo is now self-contained, but may not be the only consumer on the machine). STATUS update: add Notes line documenting the dogfood migration happened. Covers AC10.b.

**Placeholder-task count this wave**: 1.

**Parallelism**: single task. Absolutely last task of the feature — NOTHING follows it.

**Gating to advance to archive**: this repo's next shell invocation resolves specflow agents/commands/hooks from local `<this-repo>/.claude/*` rather than `~/.claude/*`. Runtime confirmation deferred to next feature after session restart per `shared/dogfood-paradox-third-occurrence.md`.

**Rationale**: PRD R10 AC10.b mandates this be the final task. Running it earlier would either (a) break mid-implement sessions of this very feature, or (b) force every subsequent wave to assume the dogfood state already. Running it last means every prior wave operates under the stable global-symlink baseline, and structural-only 08-verify.md can still issue a PASS verdict before this task executes.

## 3. Critical-path risks

### R1. The `drifted-ours` hash-manifest logic (D4 — the crux)

The entire feature's correctness hinges on `classify_copy_target` distinguishing `drifted-ours` (safe to replace after `.bak`) from `user-modified` (skip and report) via the tri-hash comparison (current-on-disk vs expected-at-new-ref vs baseline-from-manifest). Failure modes:
- Hash algorithm mismatch between `shasum -a 256` (BSD) and `sha256sum` (GNU) → wrapper dispatch bug → every file classifies `user-modified` on cross-platform moves.
- Manifest schema drift between init-time write and update-time read → `manifest_read` returns empty `files` map → every changed file classifies `user-modified` on ref-advance.
- Python 3 unavailable at install time → write-path fails → manifest not rewritten → next update misclassifies.

**Mitigation**: Wave 1 gates on manifest round-trip byte-identity + classifier unit coverage via a hidden `__probe` subcommand BEFORE any flow consumes it. Wave 3 (update) is the first flow to exercise the full tri-hash comparison on a non-trivial state graph — t42 + t43 together cover the decision boundary. Python 3 preflight at Wave 0 ensures fail-fast.

### R2. `migrate` → shared-symlink-state boundary (D10; architect's N1 note)

AC9.a: "Other projects' data under `~/.claude/` is unaffected." D10 resolves this by NOT removing any `~/.claude/` symlinks — only settings.json is rewired. The PRD R9 body text ("removes only the `~/.claude/` symlinks that this particular migration replaced") CONTRADICTS D10's implementation. Architect flagged this as N1 (note, not blocker) in tech §5.

**Mitigation**: TPM implements D10 and AC9.a, NOT R9's body text. t45 (migrate-from-global) hash-asserts the shared `~/.claude/` tree is untouched before/after migration — the hard behavioral guard. PM's R9 body-text update is a separate doc-hygiene follow-up (not in this plan). Flagged in STATUS notes at tasks-stage handoff.

### R3. Dogfood final-migration task (PRD R10 AC10.b)

This task migrates THIS repo from global-symlink to per-project install. Must be last because:
- Any earlier placement breaks mid-implement sessions of this feature (the agents / commands / hooks currently resolve via global symlinks that this task tears the pointer to).
- Structural-only 08-verify.md (per `shared/dogfood-paradox-third-occurrence.md`) needs the global model intact at verify-stage start (AC10.a).
- The migration itself is the runtime exercise of `migrate` — the first real end-to-end run. If it fails, recovery is mechanical (the `.bak` of settings.json restores the pre-migration wiring; the `.claude/specflow.manifest` can be deleted; nothing is lost). But it MUST be the last task so failure blocks only archive, not any other implementation work.

**Mitigation**: Wave 6 depends on t50 (dogfood sentinel) being green in Wave 5. Wave 6 gates archive-stage advancement. Per `shared/dogfood-paradox-third-occurrence.md`, 08-verify.md distinguishes structural PASS (gate for archive) from runtime PASS (deferred to next feature after session restart).

### R4. Same-file serialization across `bin/specflow-seed` (wave boundaries are load-bearing)

Waves 0, 1, 2, 3, 4 each edit `bin/specflow-seed`. Five consecutive waves of same-file edits cannot be collapsed into fewer waves without triggering the `parallel-safe-requires-different-files.md` conflict pattern. This is a deliberate sizing decision — each wave lands a cohesive slice (skeleton / library / init / update / migrate) with its own test gate, rather than one mega-task.

**Mitigation**: `parallel-safe-append-sections.md` does NOT apply here — these are dispatcher-arm edits, not append-only. Wave gating (each subsequent wave opens only after the prior wave's smoke tests pass) is the correct shape. Accept the 5-wave depth; do not compress.

### R5. Bash 3.2 portability regression in a new CLI

`bin/specflow-seed` is a new 400–500 line bash script (per D2 tradeoffs). Temptation to use `readlink -f` / `realpath` / `jq` / `mapfile` / `[[ =~ ]]` is high, especially for JSON manifest handling.

**Mitigation**: T-test-rule-compliance (t48, Wave 5) greps for all prohibited tokens against `bin/specflow-seed` and `.claude/skills/specflow-init/`. Landing t48 before Wave 5 closes means the portability floor is machine-checked before archive. Python 3 is explicitly permitted on install-path only (D3, D4) — JSON read/write, SHA compute, atomic write.

## 4. Test-first discipline

Every flow has a dedicated smoke test that lands in the SAME wave as (or the wave before) the flow implementation. Prior features (symlink-operation, shareable-hooks, review-capability) proved this shape; continuing here.

| Flow | Key AC | Test file | Test wave | Fixture shape |
|---|---|---|---|---|
| classifier / probe | AC6.a, AC6.b | (exercised via flow tests) | W1 (via hidden `__probe` harness) | tuple-in-stdout exercise |
| `init` fresh | AC1.a, AC1.c, AC2.a, AC4.a, AC5.a | `test/t39_init_fresh_sandbox.sh` | W2 | sandbox `$HOME`; fake fresh consumer repo under `$SANDBOX/consumer/`; invoke with `--from <this-repo> --ref HEAD` |
| `init` idempotent | AC2.b | `test/t40_init_idempotent.sh` | W2 | sandbox post-init; re-invoke at same ref; hash tree before/after |
| `update` no-conflict | AC7.b, AC8.a | `test/t42_update_no_conflict.sh` | W3 | sandbox init at ref-A; synthesize ref-B fixture via a `$SANDBOX/src-at-ref-b/` modified copy; invoke `update --to ref-B` |
| `update` user-modified | AC7.a, AC8.b | `test/t43_update_user_modified.sh` | W3 | as above + hand-edit one copied file mid-test; assert skip + ref-non-advance + revert-then-re-run |
| `update` skips team-memory | AC4.b, AC8.c | `test/t44_update_never_touches_team_memory.sh` | W3 | sandbox init; seed fake lesson under `.claude/team-memory/`; capture mtime tree; run update; assert unchanged |
| `migrate` from-global | AC9.a, AC9.b | `test/t45_migrate_from_global.sh` | W4 | sandbox `$HOME` with pre-staged global install; sandbox consumer with settings.json → `~/.claude/hooks/*`; hash unrelated `~/.claude/` content |
| `migrate` dry-run | AC9.c, AC6.a | `test/t46_migrate_dry_run.sh` | W4 | as t45 + `--dry-run`; assert three-root byte-identity (consumer, source, sandbox-HOME) |
| `migrate` user-modified | AC9.d | `test/t47_migrate_user_modified.sh` | W4 | as t45 + hand-edit in consumer; assert skip + no settings.json rewrite + global symlinks unchanged |
| rule compliance | AC13.a, AC13.c | `test/t48_seed_rule_compliance.sh` | W5 | static grep over `bin/specflow-seed` + skill; `bash -n` clean |
| init skill bootstrap | D1, R3 AC3.b | `test/t49_init_skill_bootstrap.sh` | W5 | structural: file presence, frontmatter shape, `bash -n` clean |
| dogfood staging sentinel | AC10.a | `test/t50_dogfood_staging_sentinel.sh` | W5 | `bin/claude-symlink install/uninstall/update --dry-run` all exit 0; `readlink ~/.claude/agents/specflow` resolves into `<src>` |

**Numbering**: continues from current test count (38 — last is `t38_hook_skips_reviewer.sh`). New range: t39, t40, **t41 reserved for AC2.c real-file-conflict coverage** (TPM tasks stage decides whether to fold into t39 or split), t42–t50. **`t41` is not explicitly planned here** — flagged for tasks-stage: if AC2.c deserves its own test, add as `t41_init_preserves_foreign.sh` in Wave 2 alongside t39/t40.

**Sandbox discipline**: EVERY new test begins with the mktemp `$SANDBOX` + `HOME=$SANDBOX/home` + case-pattern preflight per `.claude/rules/bash/sandbox-home-in-tests.md`. Non-negotiable. This is especially load-bearing for t45–t47 which mutate paths under `$HOME`.

## 5. File impact map

From `04-tech.md` §7, elaborated with wave assignment:

| File | Action | Wave | Placeholder task |
|---|---|---|---|
| `bin/specflow-seed` | **CREATE** (skeleton) | W0 | T-seed-skeleton |
| `bin/specflow-seed` | **EDIT** (classifier + manifest + plan_copy) | W1 | T-classify-copy-target / T-manifest-io / T-plan-copy (may bundle — §7) |
| `bin/specflow-seed` | **EDIT** (`cmd_init`) | W2 | T-cmd-init |
| `bin/specflow-seed` | **EDIT** (`cmd_update`) | W3 | T-cmd-update |
| `bin/specflow-seed` | **EDIT** (`cmd_migrate`) | W4 | T-cmd-migrate |
| `.claude/skills/specflow-init/SKILL.md` | **CREATE** | W5 | T-init-skill |
| `.claude/skills/specflow-init/init.sh` | **CREATE** | W5 | T-init-skill |
| `bin/claude-symlink` | **UNCHANGED** (R10, AC10.a frozen external contract through final migration task) | — | — |
| `bin/specflow-install-hook` | **UNCHANGED** (reused via `<src>/bin/specflow-install-hook` at install-time) | — | — |
| `.claude/hooks/session-start.sh` | **UNCHANGED** (copied into consumers as regular file by init/migrate) | — | — |
| `.claude/hooks/stop.sh` | **UNCHANGED** | — | — |
| `test/t39_init_fresh_sandbox.sh` | **CREATE** | W2 | T-test-init-fresh |
| `test/t40_init_idempotent.sh` | **CREATE** | W2 | T-test-init-idempotent |
| `test/t42_update_no_conflict.sh` | **CREATE** | W3 | T-test-update-no-conflict |
| `test/t43_update_user_modified.sh` | **CREATE** | W3 | T-test-update-user-modified |
| `test/t44_update_never_touches_team_memory.sh` | **CREATE** | W3 | T-test-update-skips-team-memory |
| `test/t45_migrate_from_global.sh` | **CREATE** | W4 | T-test-migrate-from-global |
| `test/t46_migrate_dry_run.sh` | **CREATE** | W4 | T-test-migrate-dry-run |
| `test/t47_migrate_user_modified.sh` | **CREATE** | W4 | T-test-migrate-user-modified |
| `test/t48_seed_rule_compliance.sh` | **CREATE** | W5 | T-test-rule-compliance |
| `test/t49_init_skill_bootstrap.sh` | **CREATE** | W5 | T-test-skill-bootstrap |
| `test/t50_dogfood_staging_sentinel.sh` | **CREATE** | W5 | T-test-dogfood-sentinel |
| `test/smoke.sh` | **EDIT** (register t39, t40, t42–t50) | W5 | T-smoke-register |
| `README.md` | **EDIT** (install / deprecation / verb vocabulary) | W5 | T-docs |
| `<this-repo>/.claude/specflow.manifest` | **CREATE** (dogfood — this repo's own manifest) | W6 | T-dogfood-migrate |
| `<this-repo>/settings.json` | **REWIRE** (hook paths → local) | W6 | T-dogfood-migrate |

## 6. Dogfood staging plan

Per PRD R10 and `.claude/team-memory/shared/dogfood-paradox-third-occurrence.md` (6th occurrence):

1. **Throughout implement (W0–W5)**: this repo stays on the global-symlink model. `~/.claude/agents/specflow`, `~/.claude/commands/specflow`, `~/.claude/hooks`, `~/.claude/team-memory/*` all continue to resolve back into this source repo via the existing `bin/claude-symlink install` output. NO task in W0–W5 modifies `bin/claude-symlink` or its external contract (AC10.a).
2. **Wave 5 landing gate**: t50 (dogfood staging sentinel) asserts `bin/claude-symlink install/uninstall/update --dry-run` all exit 0 AND `readlink ~/.claude/agents/specflow` still resolves into `<src>`. This is the pre-flight check for Wave 6.
3. **Wave 6 (T-dogfood-migrate)**: runs `bin/specflow-seed migrate --from .` in this repo. Produces `<this-repo>/.claude/specflow.manifest`, rewires `<this-repo>/settings.json` hook paths. Per D10, does NOT tear down global `~/.claude/*` symlinks (they remain available for any un-migrated consumer on the machine; user runs `bin/claude-symlink uninstall` manually when every consumer has migrated).
4. **08-verify.md structural PASS**: structural coverage of every AC is the gate for archive per `shared/dogfood-paradox-third-occurrence.md`. Runtime PASS of `init` / `update` / `migrate` against a fresh external consumer is deferred.
5. **Next-feature runtime exercise**: the first feature after THIS one archives, after session restart (per the 4th-occurrence dispatch-cache-lag clause), exercises the per-project install model live. That feature's own session picks up the migrated local `.claude/*` tree, confirming the migration produced a working consumer.
6. **STATUS Notes trace**: TPM adds a Notes line at plan stage (this file's landing) explicitly documenting: "dogfood staging plan: this repo stays on global-symlink model through W0–W5; W6 single-task migration is the final act; runtime confirmation deferred to next feature after session restart". The tasks stage, implement stage, and verify stage each re-affirm this trace.

**Opt-out / bypass**: Architect deferred D13 (opt-out sentinel for same-feature-implement flows) to TPM. This plan's answer: no sentinel needed for THIS feature's waves because `bin/specflow-seed` is never invoked against this repo during W0–W5 — it's only invoked in sandbox tests and in the single W6 task. The "bypass" is trivial: don't run the tool against this repo until W6. If W0–W5 needs to `migrate` this repo for some reason that surfaces later (e.g., test coverage demands it), Architect's stated design constraint (`specflow-seed update` in a manifest-less consumer exits 2 with a pointer to init/migrate) ensures fail-fast, not silent-break. Defer concrete sentinel implementation per D13 trigger.

## 7. What `/specflow:tasks` should produce next

Target **06-tasks.md** with ~12–13 atomic tasks across 6 waves, per the placeholder-task sizing in §2. Emphasis for tasks-stage:

- **Wave 1 sizing decision**: classifier + manifest IO + plan_copy all touch `bin/specflow-seed`. Three options: (a) bundle into one task (T-scaffold-lib, one commit, one test gate), (b) serialize within the wave (three tasks, sequential, developer accepts slight bookkeeping cost), (c) split across three waves (over-serialization, rejected — these are logically co-dependent scaffolding). **Recommend (a)** — one "library scaffold" task. Blast radius is small (~150 lines of pure bash + Python 3 heredocs), no external contract, single TDD anchor (hidden `__probe` subcommand). Developer reviews as one unit. Saves two wave gates.
- **Cmd-flow tasks are one task each, NOT split across sites**: per `parallel-safe-requires-different-files.md`, `cmd_init` / `cmd_update` / `cmd_migrate` each touch multiple regions of `bin/specflow-seed` (dispatcher arm + helper additions + manifest-write call + summary emit). DO NOT split across sites — all sites are in the same file; splitting forces same-file serialization at the task level for no gain. Matches the B2.a M2 / B2.b M4 precedent.
- **Test tasks are one per file**: each `t39`–`t50` is its own task. Test files are distinct; fully parallel-safe across any wave where they co-exist. Smoke registration (`test/smoke.sh`) is a single-editor task (T-smoke-register) in W5 — tests do NOT self-register. Matches the B2.a M4 / B2.b M7 precedent.
- **Merge R11 + R12 docs into one task**: T-docs in W5 edits `README.md` once for both the deprecation notice AND the verb-vocabulary table. Same file, same pass, same reviewer.
- **Quote the D3 manifest JSON schema verbatim** into T-scaffold-lib's task scope per `tpm/briefing-contradicts-schema.md` — do NOT paraphrase `schema_version: 1`, field names, or the nested `files` map shape. Paste the block from 04-tech.md §3.
- **Quote the D4 classifier pseudocode verbatim** into T-scaffold-lib's task scope — the tri-hash comparison logic is load-bearing for correctness; any paraphrase risks silent divergence.
- **Expected append-only collisions** (document in 06-tasks.md `## Wave schedule`):
  - `test/smoke.sh`: single editor (T-smoke-register) — zero collision.
  - `STATUS.md`: every task appends a Notes line; standard keep-both mechanical resolution.
  - `06-tasks.md` checkboxes: W2, W3, W4, W5 have multi-task waves (3, 4, 6 tasks); checkbox audit per `tpm/checkbox-lost-in-parallel-merge.md` applies but at these widths (max 6-way in W5) the precedent loss rate is 1–2 boxes per wave, predictable.
- **Flag for PM at tasks handoff**: the PRD R9 body text N1 contradiction from Architect §5. Not a blocker for tasks; is a post-archive doc-hygiene follow-up.

---

## Summary

- **Wave count**: 6 (Wave 0 skeleton, Wave 1 library, Wave 2 init+tests, Wave 3 update+tests, Wave 4 migrate+tests, Wave 5 skill+smoke+docs, Wave 6 dogfood-final).
- **Placeholder task count**: 12–13 (exact number depends on the Wave 1 sizing decision per §7; recommend 12 via bundling).
- **Critical path**: W0 (skeleton) → W1 (classifier+manifest library, MUST LAND FIRST — the crux D4 decision) → W2 (init) → W3 (update) → W4 (migrate) → W5 (skill/smoke/docs) → W6 (dogfood migration, LAST).
- **Load-bearing risks**: (1) tri-hash `drifted-ours` vs `user-modified` classifier correctness, (2) `migrate` D10 shared-symlink abstention, (3) dogfood final-migration staging.
- **TPM memory-consultation**: 4 TPM entries applied. `parallel-safe-requires-different-files` load-bearing for the 5 consecutive same-file waves (0–4 all edit `bin/specflow-seed`) — accepting that depth rather than compressing. `parallel-safe-append-sections` applied to smoke.sh registration single-editor pattern. `checkbox-lost-in-parallel-merge` flagged for W5 (6-way) post-merge audit. `briefing-contradicts-schema` directs tasks-stage to quote D3 + D4 verbatim. `shared/dogfood-paradox-third-occurrence` drives the entire W6 shape.
