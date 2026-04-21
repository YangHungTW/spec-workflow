# Plan — shareable-hooks (B2.a)

_2026-04-17 · TPM_

## Team memory consulted

- `tpm/parallel-safe-requires-different-files.md` — load-bearing for the wave-schedule hints in §5. The M2 claude-symlink extension edits ONE file in four sites (`plan_links`, `cmd_uninstall`, `usage()`, header comment); bundle into a single task so wave-parallelism on M2 is not even a question. The M1 stop.sh work is a new file, no collision with M2.
- `tpm/parallel-safe-append-sections.md` — directly applied to §5. Expected append-only collisions (STATUS notes, `test/smoke.sh` registrations, `.claude/rules/index.md` if touched) stay parallel-safe; the orchestrator resolves them mechanically. Do NOT over-serialize on append-only grounds alone.
- `tpm/tasks-doc-format-migration.md` — n/a this round (no task-doc command-contract changes).
- `shared/` (both tiers) — empty; nothing to pull.

## 1. Scope summary

This plan delivers the two B2.a deliverables against the PRD (R-count=18, AC-count=15) and tech doc (D-count=9):
- **(5) Stop hook** — new `.claude/hooks/stop.sh`, pure bash 3.2, fail-safe envelope, branch-name classifier (D3), 60s dedup via sentinel (D4), fixed-generic date-stamped note (D5), `HOOK_TEST=1` gate (D6).
- **(7) `bin/claude-symlink` extension** — one new managed dir-pair (`~/.claude/hooks/` → `$REPO/.claude/hooks/`) via D7's 4-site mechanical edit. No classifier changes, no new states, no `--force`.

Items (4) per-task reviewer and (6) `/specflow:review` team are out of plan — deferred to feature B2.b (separate PRD, opens after this feature archives).

## 2. Milestones

### M1 — Stop hook script (`.claude/hooks/stop.sh`)

- **Output**: new executable `.claude/hooks/stop.sh`, bash 3.2 portable, no `jq` / `readlink -f` / `mapfile` / `[[ =~ ]]`. Structure per tech doc D1–D6:
  1. Fail-safe header (`set +e`, `trap 'exit 0' ERR INT TERM`, stderr-only logging helpers, unconditional final `exit 0`).
  2. Stdin sniff (D2) — `cat` stdin; `{`-prefix case check; `HOOK_TEST=1` dumps raw payload (first 200 chars) to stderr.
  3. `classify_env()` pure classifier (D3) — emits exactly one of `not-git | no-specflow | no-match | ambiguous:<list> | ok:<slug>`. No side effects.
  4. Dispatch `case` at top level — mutation happens here only. `ok:*` falls through to dedup + append; everything else logs stderr INFO/WARN and exits 0.
  5. `within_60s()` dedup check (D4) — awk-tails last `stop-hook` line under `## Notes`, then compares sentinel `<feature>/.stop-hook-last-epoch` against current `date +%s`. BSD/GNU `to_epoch()` wrapper dispatched by `uname -s`.
  6. `append_note()` (D5) — read STATUS.md into tmp, printf D5 line, `mv` atomic swap, write sentinel via tmp+mv. `HOOK_TEST=1` early-returns before any mutation (D6).
- **Requirements covered**: R9, R10, R11, R12, R13, R15, R16.
- **Decisions honored**: D1 (location + bash), D2 (stdin sniff), D3 (classifier), D4 (60s sentinel + date dispatch), D5 (fixed note), D6 (HOOK_TEST gate).
- **Verification signal**: `bash -n .claude/hooks/stop.sh` clean; t30/t31/t32 pass (tests land in M3).

### M2 — `bin/claude-symlink` extension (4-site edit)

- **Output**: single-file edit to `bin/claude-symlink` at exactly four sites per D7:
  1. `plan_links()` — insert 2 lines after the "Fixed pair 2" block: `PLAN_SRC+=("$REPO/.claude/hooks")` / `PLAN_TGT+=("$HOME/.claude/hooks")`.
  2. `cmd_uninstall` `dir_links=(...)` array — add `"$HOME/.claude/hooks"` as a third entry.
  3. `usage()` managed-set block — add a `hooks` row.
  4. Top-of-file header comment — add `hooks` to the enumerated managed set.
- **NOT changed**: `classify_target`, `owned_by_us`, `apply_plan`, `cmd_install`, `cmd_update`, probe harness. Explicitly per D7 (no classifier changes, no new states).
- **Requirements covered**: R1, R2, R3, R4, R5 (usage text part).
- **Decisions honored**: D7 (4-site edit), D8 (enumerate 3 pairs in usage), D9 (backward compat via existing `update` self-heal — no code to write).
- **Verification signal**: `bin/claude-symlink --help | grep -q hooks` passes; t29 and t33 pass (tests land in M3).

### M3 — Test harness additions (t29–t33)

- **Output**: 5 new `test/t{29..33}_*.sh` scripts per PRD R17 / tech doc §4 testing table, each with the mktemp sandbox + HOME preflight discipline (per `.claude/rules/bash/sandbox-home-in-tests.md`):
  - `t29_claude_symlink_hooks_pair.sh` — install/uninstall/update/idempotency of the new dir-pair.
  - `t30_stop_hook_happy_path.sh` — seeded sandbox git worktree + matching feature + JSON payload → one new `- <date> stop-hook — stop event observed` line under `## Notes`. Includes a `/usr/bin/time` spot-check (logged, not gated — R15 soft target).
  - `t31_stop_hook_failsafe.sh` — 6 variants (empty stdin, malformed JSON, non-git cwd, no-match branch, missing STATUS.md, missing `## Notes`). Each exits 0 with zero mutation.
  - `t32_stop_hook_idempotent.sh` — two invocations within 60s → one line; third invocation with sentinel aged >60s → second line. Tests BOTH BSD and GNU `date` paths where relevant.
  - `t33_claude_symlink_hooks_foreign.sh` — pre-existing real dir at `~/.claude/hooks/` → `skipped:real-dir` on install, `skipped:not-ours` (or equivalent) on uninstall. Never mutated.
- **Requirements covered**: R17, R18 (partial — smoke integration in M4).
- **Decisions honored**: bash-32 portability rule, sandbox-HOME rule, cwd-aware hook contract (R8).
- **Verification signal**: each `test/tNN_*.sh` exits 0 standalone.

### M4 — Smoke.sh integration + docs (README)

- **Output**:
  - `test/smoke.sh` registers t29–t33 alongside the existing 28 tests. Final count ≥ 33. All existing tests continue to pass (R18 / AC-no-regression).
  - Top-level `README.md` (or in-repo doc that already enumerates the managed set) updated to list 3 managed dir-level pairs instead of 2, and to include the three-command per-project opt-in flow from PRD R6 verbatim (SessionStart + Stop). Grep must find both `specflow-install-hook add SessionStart` and `specflow-install-hook add Stop`.
  - `.gitignore` entry for `.spec-workflow/features/*/.stop-hook-last-epoch` (mitigates the tech-doc §6 deferred "sentinel accidentally committed" risk upfront; cheap insurance).
- **Requirements covered**: R5, R6, R14, R18; AC-usage-mentions-hooks, AC-per-project-wiring-docs, AC-no-regression.
- **Decisions honored**: D8 (enumerate managed set in all 3 documented locations — usage / header / README).
- **Verification signal**: `bash test/smoke.sh` → green (≥33/33); `grep 'specflow-install-hook add Stop' README.md` resolves; sentinel paths are gitignored.

**Milestone count: 4** (M1–M4).

## 3. Cross-cutting concerns

- **Sandbox-HOME discipline** — every test in M3 MUST begin with the `mktemp -d` sandbox + `HOME=$SANDBOX/home` + case-pattern preflight per `.claude/rules/bash/sandbox-home-in-tests.md`. ANY test that invokes `bin/claude-symlink` without isolating `$HOME` is a flake-and-damage risk. Non-negotiable.
- **Don't clobber real `~/.claude/hooks/`** — during t29, t33, t30, t31, t32, all mutations MUST be under the mktemp sandbox. A misquoted `HOME` variable or a forgotten `export` would silently mutate the contributor's actual `~/.claude/hooks/` (currently a symlink we own — test iteration would destroy the live SessionStart hook wiring). The preflight check is the backstop.
- **Backward compat (D9)** — no migration code. An existing install pre-dating this feature has two live symlinks and no `hooks` pair; `claude-symlink update` on the new binary sees `hooks` as `missing` and creates it. Documented in M4's README note.
- **Hook fail-safe discipline (M1)** — the stop hook script is write-restricted: writes exactly ONE STATUS.md + ONE sentinel per invocation, both under `<cwd>/.spec-workflow/features/<slug>/`. No network, no shell-out beyond `date`/`awk`/`git symbolic-ref`/`cat`/`mv`. `set +e`, trap, unconditional final `exit 0` — NO path in stop.sh may exit non-zero (AC-stop-hook-failsafe).
- **Cwd-aware hooks (R8)** — stop.sh reads `<cwd>/.git/HEAD` and `<cwd>/.spec-workflow/features/*/STATUS.md`, NEVER its own install-location-relative paths. This is what makes globalization shallow (PRD R8); M1 must not regress it. The same contract governs the existing session-start.sh and must be preserved (nothing in M1 touches session-start.sh).
- **BSD/GNU `date` divergence** — M1's `to_epoch()` dispatches by `uname -s`. M3's t32 MUST exercise the dedup path on whatever platform the test runs on (macOS: BSD branch; Linux CI: GNU branch). A test that only validates one dialect is a coverage gap we're accepting per PRD §5 (not a blocker); document it in the task acceptance.
- **Concurrent Stop events + STATUS.md race** — D4 60s dedup via sentinel absorbs the most common case. D5 `.tmp`+`mv` guarantees no partial-write window. Last-writer-wins on near-simultaneous appends is accepted per PRD §6. M1's append_note must NOT introduce any `>>` open-for-append that could partial-write.

## 4. Dependencies & sequencing

```
M1 (stop.sh)            ──┐
                          ├──→ M3 (tests t29–t33) ──→ M4 (smoke + README + .gitignore)
M2 (claude-symlink ext) ──┘
```

**Key edges:**
- **M1 ⟂ M2** — different files (`.claude/hooks/stop.sh` vs `bin/claude-symlink`). Fully parallel-safe.
- **M3 depends on M1 + M2** — t29/t33 require M2's binary; t30/t31/t32 require M1's hook script. Individual test tasks may start red-first in the same wave as M1+M2 if the Developer is comfortable with TDD; see §5 for shape options.
- **M4 depends on M3** — smoke.sh registration is the last step; README doc edits can technically parallel with M3 but are gated on M2's usage() text being the documented-source-of-truth (keeps doc + `--help` output in sync per D8).

## 5. Wave schedule hints for TPM task-breakdown stage

This is advisory input for `/specflow:tasks`; actual wave schedule is set then. Given the small scope (4 milestones, ~7–9 tasks), exploit parallelism aggressively:

- **M1** — ONE task (`.claude/hooks/stop.sh` write). Parallel-safe with M2 (different file).
- **M2** — ONE task (4-site edit to `bin/claude-symlink`). Do NOT split across sites — all 4 sites are in the same file. Splitting would force serialization across waves for no gain (cf. `tpm/parallel-safe-requires-different-files.md`). Parallel-safe with M1.
- **M3** — 5 tasks, one per test file. Each file is separate → fully parallel-safe across the set. Can ALSO run in the same wave as M1+M2 if Developer writes tests red-first (TDD). Realistic shape: 7 tasks in one wave (M1 + M2 + 5 tests).
- **M4** — split or bundle:
  - **Option A (bundle, 1 task)**: one task edits smoke.sh + README + .gitignore. Serial after M3.
  - **Option B (split, 3 tasks)**: smoke.sh / README / .gitignore as three parallel tasks; each a different file. All serial after M3.
  - **Recommendation**: Option A. The edits are small and logically tied (doc sync); parallelism gain is negligible vs task-overhead.

**Recommended wave shape at `/specflow:tasks` time:**
- **Wave 1 (7 parallel)**: M1 (stop.sh) + M2 (claude-symlink) + 5 × M3 tests. Relies on TDD discipline; if Developer prefers green-first, split to Wave 1 impl + Wave 2 tests.
- **Wave 2 (1 serial)**: M4 (smoke + README + .gitignore bundled).

**Expected append-only collisions (per `tpm/parallel-safe-append-sections.md`)** — DO NOT over-serialize on these:
- `test/smoke.sh`: five M3 tasks (if they each self-register) and M4's registration pass collide; resolve mechanically keep-both. Alternative: M3 tasks write test files only; M4 is the sole register-in-smoke editor. **Recommended**: the latter — M3 tasks write the `tNN_*.sh` file; M4's smoke-registration step is the only place smoke.sh is edited. Zero append-collision.
- STATUS.md notes: every task writes a STATUS note on completion. Standard keep-both merge. Expected; not a planning concern.
- `.gitignore`: single editor (M4). No collision.

## 6. Risks / watch-items

- **Stop hook mis-fires on non-implement Stop events** — every Stop in every Claude Code session on a feature branch gets a note. PRD §6 accepts this noise; B2.b revisits. **Mitigation**: `HOOK_TEST=1` env gate (D6) lets contributors smoke-test without mutation; M3 t30 validates the happy path; t31 validates the 6 silent-skip variants.
- **Sentinel file `.stop-hook-last-epoch` accidentally committed** — M4 adds a `.gitignore` pattern `*/.stop-hook-last-epoch` (or equivalent) upfront instead of deferring it like tech doc §6 does. Cheap pre-emption, eliminates the risk category entirely.
- **BSD vs GNU `date` divergence in dedup window (D4)** — a bug in the `to_epoch()` dispatch could make dedup silently stop working on one platform. **Mitigation**: M3 t32 must seed both code paths (spoofing `uname -s` output, or via separate asserts against BSD and GNU formats). Document explicitly in t32's acceptance. Not a blocker if only one platform is covered in v1 — PRD §5 accepts.
- **Concurrent wave Stop events hitting STATUS.md** — N parallel agents Stop near-simultaneously during a B2.b wave. D4 60s dedup absorbs. D5 atomic `mv` prevents partial writes. Last-writer-wins on same-second collisions is accepted per PRD §6 (identical duplicates would have been deduped anyway). **Mitigation**: M1's append_note guarded: NEVER use `>>` on the live file — read-all, printf-append-to-tmp, atomic-mv.
- **Test iteration destroys contributor's real `~/.claude/hooks/`** — a forgotten `export HOME=` in a test script silently mutates the live symlink. **Mitigation**: every M3 test starts with the preflight assert from `.claude/rules/bash/sandbox-home-in-tests.md`. Non-negotiable; any test task that omits this fails gap-check.
- **Load-bearing claude-symlink logic changes during M2** — D7 says "4 mechanical edit sites, classifier unchanged". Temptation: "refactor while we're in there". **Mitigation**: M2 acceptance test is `bash test/smoke.sh` green on the existing 28 B1 tests PLUS t29/t33. Any behavior change outside the 4 sites will regress one of the existing 28. QA-analyst gap-check explicitly audits the diff scope.
- **Hook performance regression on slow filesystems** (R15 soft target) — 100ms budget on warm cache. **Mitigation**: not gated; t30 logs `/usr/bin/time` wall-clock, does not fail on it. Accept as watch-item for post-ship telemetry.

## 7. Out of plan

- Items (4) per-task reviewer, (6) `/specflow:review` parallel-reviewer team — deferred to feature **B2.b** (separate PRD, opens after this feature archives). TPM will not touch.
- Deep globalization of `.claude/rules/` — rejected Q1=b in brainstorm; rules stay per-project.
- Orchestrator-supplied rich Stop payload (role / task-id / PRD-req-id) — PRD §8 defer.
- Distributed lock for concurrent Stop events — PRD §6 accepts last-writer-wins; revisit only if telemetry shows >5% loss.
- `--force` on the hooks pair — explicitly forbidden by `.claude/rules/common/no-force-on-user-paths.md`. Inherited by the new pair through the existing skip-table.
- New slash command — `/specflow:review` naming reserved for B2.b; this feature MUST NOT preempt it.
- `.claude/hooks/README.md` — B1 D6 deferred; B2.a also defers. Two scripts is still self-explanatory.

---

## Summary

- **Milestone count**: 4 (M1 stop.sh, M2 claude-symlink extension, M3 5 tests, M4 smoke + docs + gitignore).
- **Key sequencing calls**:
  - M1 ⟂ M2 (different files, fully parallel).
  - M3 tests can co-wave with M1/M2 under TDD, or follow in a second wave under green-first.
  - M4 is always last (needs everything else to exist and pass).
- **Key risk flags to escalate now** (not archive-time):
  - Sandbox-HOME discipline is non-negotiable for M3 tests — single preflight miss = destroyed contributor `~/.claude/`.
  - D7's 4-site edit must stay within scope — any "while I'm in there" refactor regresses the existing 28 smoke tests.
  - BSD/GNU `date` dispatch in dedup — M3 t32 must exercise both paths or explicitly document single-platform coverage.
- **TPM memory-consultation summary**: 3 TPM memory entries consulted (`parallel-safe-requires-different-files`, `parallel-safe-append-sections`, `tasks-doc-format-migration`). First two directly shaped §5 wave hints — M2 bundled into one task (cross-file-edits-in-one-file rule), test/smoke.sh collisions called out as mechanically-resolvable (append-only rule). Third not applicable this round.
