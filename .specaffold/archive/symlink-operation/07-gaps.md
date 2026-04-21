# Gap analysis — symlink-operation
_2026-04-16 · QA-analyst · static_

## Verdict: PASS-WITH-NITS

Zero blockers. Two should-fix items and four nits. Advances to verify.

---

## A. PRD ↔ Tasks coverage

| R# | Requirement (one-liner) | Task(s) |
|----|-------------------------|---------|
| R1 | Repo root resolved as parent of script dir, absolute | T3 |
| R2 | Targets under `$HOME/.claude/`, never hard-coded | T5 |
| R3 | Symlink targets are absolute paths inside repo | T7 |
| R4 | Managed link set: agents/YHTW (dir), commands/YHTW (dir), team-memory/** (per-file) | T5 |
| R5 | team-memory/index.md files handled like any regular file; no exclusions | T5 |
| R6 | install creates full managed set; already/skip/continue-on-conflict | T7 |
| R7 | install creates missing parent dirs; records created dirs | T7 |
| R8 | uninstall removes only tool-owned links; empty-parent cleanup; never removes ~/.claude/ | T8 |
| R9 | update reconciler: add missing, replace broken-ours, prune orphans | T9 |
| R10 | Conflict matrix (8 states) | T6, T7 |
| R11 | No --force in v1 | T2, T7 |
| R12 | --dry-run on all subcommands; zero mutations; would-* verbs | T2, T7, T8, T9 |
| R13 | Per-path report; closed verb set; final summary line | T7, T8, T9, T10 |
| R14 | Exit codes: 0 converged, 1 conflict/failure, 2 usage/precondition | T1, T7, T8, T9, T10 |
| R15 | Verbose by default; no --quiet | T10 |
| R16 | POSIX bash 3.2; stock macOS + Linux toolset; Windows guard | T1, T3 |

All 16 requirements have task coverage. No uncovered R-ids.

### AC ↔ smoke.sh function mapping

| AC# | smoke.sh function | Covered? |
|-----|-------------------|----------|
| AC1 | `ac1_clean_install` | Yes |
| AC2 | `ac2_idempotent_install` | Yes |
| AC3 | `ac3_real_file_conflict` | Yes |
| AC4 | `ac4_uninstall_scope` | Yes |
| AC5 | `ac5_empty_dir_cleanup` | Yes |
| AC6 | `ac6_update_adds_missing` | Yes |
| AC7 | `ac7_update_prunes_orphans` | Yes |
| AC8 | `ac8_update_conflict` | Yes |
| AC9 | `ac9_dry_run_no_mutation` | Yes |
| AC10 | `ac10_absolute_link_targets` | Yes |
| AC11 | `ac11_report_exit_consistency` | Yes |
| AC12 | `ac12_cross_platform` | Yes (noop marker; see below) |

All 12 ACs have corresponding smoke.sh functions.

---

## B. PRD ↔ Diff coverage

| R# / AC# | Status | Notes |
|----------|--------|-------|
| R1 | OK | `resolve_repo_root` uses `${BASH_SOURCE[0]}` → `dirname` twice; caches in `$REPO`. |
| R2 | OK | `plan_links` uses `$HOME/.claude/` (env-sourced); no hard-coded paths. |
| R3 | OK | `create_link` passes absolute `$src` to `ln -s`. All sources in `PLAN_SRC` are absolute from `plan_links`. |
| R4 | OK | `plan_links` emits two fixed dir pairs plus `find ... -type f -print0` walk for team-memory. |
| R5 | OK | No filename exclusions in the walk; all regular files linked. |
| R6 | OK | `cmd_install` → `apply_plan`: missing→create, ok→already, conflict→skip, continue loop, MAX_CODE accumulates. |
| R7 | OK | `ensure_parent` does `mkdir -p`, appends to `CREATED_DIRS`. |
| R8 | OK | `cmd_uninstall` ownership-gated; never `rm -r`; `try_remove_empty_parents` stops at `$HOME/.claude/`. |
| R9 | OK | `cmd_update` pass-1 apply_plan + pass-2 orphan walk + pass-3 parent cleanup. |
| R10 | **DRIFT** | See D1 in section D below. `wrong-link-ours` is replaced (not skipped) — tech doc D5 overrides PRD R10 for this state. |
| R11 | OK | No `--force` flag. Unknown flags rejected with exit 2. |
| R12 | **DRIFT** | See D2 in section D. `uninstall --dry-run` double-reports: `remove_link` emits `would-remove` and then the caller also emits `removed` for the same path. |
| R13 | OK | `report` helper + `emit_summary`. Verb closed set present. Summary format `summary: created=N already=N removed=N skipped=N  (exit CODE)` on last line. |
| R14 | OK | `MAX_CODE` starts 0; bumps to 1 on conflict/mutation failure; 2 via `die`. `exit "$MAX_CODE"` at end. |
| R15 | OK | No `--quiet` flag. Output always printed. |
| R16 | OK | `#!/usr/bin/env bash`; `set -u -o pipefail`; no `set -e`; only `ln`, `readlink`, `rm`, `mkdir`, `find`, `test`. `resolve_path` loop avoids `readlink -f`. OS guard on MINGW/MSYS/CYGWIN. |
| AC1 | OK | `ac1_clean_install`: checks exit 0, agents/YHTW symlink, commands/YHTW symlink, team-memory link count. |
| AC2 | OK | `ac2_idempotent_install`: second install → no `created` verbs, some `already` verbs, exit 0. |
| AC3 | OK | `ac3_real_file_conflict`: real file → `skipped:real-file`, other links created, exit non-zero. |
| AC4 | OK | `ac4_uninstall_scope`: no owned links remain, foreign file untouched, `~/.claude/` present. |
| AC5 | OK | `ac5_empty_dir_cleanup`: empty `agents/`, `commands/` removed; non-empty `team-memory/shared/` kept. |
| AC6 | OK | `ac6_update_adds_missing`: creates new file in real repo (with cleanup trap), runs update, checks `created` verb. |
| AC7 | OK | `ac7_update_prunes_orphans`: removes victim source, checks `removed:orphan` verb, foreign symlink untouched. |
| AC8 | OK | `ac8_update_conflict`: real-file conflict → `skipped:real-file`, continue, exit non-zero. |
| AC9 | **PARTIAL** | `ac9_dry_run_no_mutation`: hash-check covers filesystem safety. Output verb check for `install --dry-run` looks for `[would-create]`. The `uninstall --dry-run` output is NOT checked for verb correctness — see D2 in section D. Filesystem safety still passes. |
| AC10 | OK | `ac10_absolute_link_targets`: iterates all links, checks `readlink` returns path starting with `REPO_ROOT`. |
| AC11 | OK | `ac11_report_exit_consistency`: asserts summary line format and exit-code/summary parity for clean, conflict, and dry-run runs. |
| AC12 | NOTE | `ac12_cross_platform`: noop marker that prints `uname -s`. Real cross-platform validation requires running on both macOS and Linux — this is not automated. The PRD/tech doc acknowledges this (04-tech.md §4 cross-platform section). Acceptable per design. |

---

## C. Tasks ↔ Diff

| Task | Deliverable claimed | Found in diff? |
|------|---------------------|----------------|
| T1 | `bin/claude-symlink` skeleton, shebang, OS guard, stub dispatch, executable bit | Yes — `bin/claude-symlink` created |
| T2 | `parse_flags` with `--dry-run`, `--help`, `-h`; unknown-flag rejection | Yes — `parse_flags` function in script |
| T3 | `resolve_path`, `resolve_repo_root`, `die`, `__probe` | Yes — all present; `__probe` gated behind `YHTW_PROBE=1` |
| T4 | `owned_by_us` with trailing-slash prefix check | Yes — `owned_by_us` with `"$REPO/.claude/"*` pattern + inline comment |
| T5 | `plan_links` with indexed arrays, `__probe plan` dump | Yes — `plan_links` populates `PLAN_SRC`/`PLAN_TGT`; `__probe plan` present |
| T6 | `classify_target` (8-state); `test/unit/classify_target.sh` → `test/t6_classify_target.sh` | Yes — function present; test present as `t6_classify_target.sh` |
| T7 | `cmd_install`, `ensure_parent`, `create_link`, `report` helpers; `test/t7_cmd_install.sh` | Yes — all helpers present; `t7_cmd_install.sh` present |
| T8 | `cmd_uninstall`, `remove_link`, `try_remove_empty_parents`; `test/t8_cmd_uninstall.sh` | Yes — all present; `t8_cmd_uninstall.sh` present |
| T9 | `cmd_update` with pass-1/pass-2/pass-3; `test/t9_cmd_update.sh` | Yes — present; `t9_cmd_update.sh` present |
| T10 | `emit_summary`; final exit wiring; `__probe` gated; `test/t10_summary.sh` | Yes — present; `__probe` behind `YHTW_PROBE=1`; `t10_summary.sh` present |
| T11 | `test/smoke.sh` with AC1–AC12 functions; sandbox-HOME preflight | Yes — `smoke.sh` with all 12 `ac*_` functions and `SANDBOX`/`HOME` preflight |
| T12 | Header comment in `bin/claude-symlink`; README section | Yes — header block present (lines 1–50); README section appended (lines 71–167) |

All 12 tasks have their deliverables present in the diff.

---

## D. Drift / extras / decision violations

**D1 (should-fix) — R10 / D5 conflict: `wrong-link-ours` is replaced, not skipped.**

- PRD R10 table: `Symlink → wrong path in this repo` → Action: **Skip** → Report: `skipped (conflict: wrong-source)`.
- Tech doc §3 (`apply_plan` table): `wrong-link-ours` → Action: **atomic relink** → Report: `created:replaced-broken` semantics.
- Implementation `bin/claude-symlink:515`: `broken-ours|wrong-link-ours)` → `rm + create_link` → `report "created:replaced-broken"`.
- The tech doc explicitly overrides the PRD here. However, PRD R11 states "conflicts are reported and skipped; the user resolves them manually" without carving out an exception for `wrong-link-ours`. The tech doc D5 action table is a functional decision that contradicts the PRD.
- Practically, `wrong-link-ours` means a symlink in the current repo pointing to the wrong managed path within the same `.claude/` tree — replacing it is safer and more useful than requiring the user to manually rm. However, the discrepancy is undocumented in the PRD.
- **Recommended action**: Either (a) update PRD R10/R11 to add an explicit carve-out for `wrong-link-ours`, or (b) confirm the tech doc override is an accepted design change and note it in 04-tech.md. No code change required if (b).

**D2 (should-fix) — `uninstall --dry-run` double-reports per path: `[would-remove]` + `[removed]`.**

- `bin/claude-symlink:588-593` (`remove_link`): when `DRY_RUN=1`, calls `report "would-remove"` and returns 0.
- `bin/claude-symlink:664-665` (`cmd_uninstall`): after `remove_link` succeeds (returns 0), calls `report "removed"`.
- Net effect: every owned link is reported twice under `uninstall --dry-run` — once as `[would-remove]` and once as `[removed]`. Only `would-remove` should appear (R12).
- Same issue in the team-memory loop at `bin/claude-symlink:686-687`.
- AC9's uninstall dry-run check only verifies filesystem hash equality (line 598-601); it does not inspect the output verbs, so this bug is not caught by the smoke harness.
- Note: `cmd_update`'s orphan section (lines 759-778) handles this correctly with an inline `if [ "$DRY_RUN" -eq 1 ]` guard; `remove_link`'s self-reporting pattern was added later without updating `cmd_uninstall`.
- **Recommended action**: In `cmd_uninstall`, replace the `if remove_link "$dl"; then report "removed"` pattern with an inline dry-run guard (matching the `cmd_update` orphan pattern): check `DRY_RUN` before deciding whether to call `remove_link` + `report "removed"` or just `report "would-remove"`. Alternatively, remove the self-reporting from `remove_link` and always let the caller decide the verb.

**D3 (note) — PRD R13 verb format uses parentheses; tech doc §2 and implementation use colons.**

- PRD R13: `created (replaced-broken)`, `removed (orphan)`, `skipped (conflict: real-file)`.
- Tech doc §2 output format: `created:replaced-broken`, `removed:orphan`, `skipped:real-file`.
- Implementation and smoke tests all use the colon format.
- The tech doc §2 is a deliberate design refinement of the PRD's format. All tests and docs are internally consistent with the colon format. No code change needed; record as an accepted override.
- **Recommended action**: Note the format change in 04-tech.md as a deliberate PRD override if not already clear. No code change.

**D4 (note) — Scope creep: `.claude/commands/YHTW/implement.md` and `next.md` modified.**

- Git diff shows `implement.md` changed by ~74 lines and `next.md` by ~4 lines. Neither file is listed as a deliverable in T1–T12 or mapped to any PRD requirement.
- The changes improve the `/YHTW:implement` command (single-wave → all-waves loop; `--one-wave` flag added). This is workflow tooling for the repo, not the `symlink-operation` feature itself.
- No PRD requirement or task covers these changes. They are extra code shipped with this feature's PR.
- **Recommended action**: Acknowledge as incidental improvement (no harm, no user-facing impact on symlink-operation). If the team wants clean feature-scoped PRs, these should be committed on a separate branch. Not a blocker.

---

## Findings to escalate

### BLOCKERS
None.

### SHOULD-FIX (2)

1. **D1** — `wrong-link-ours` replaced vs skipped: PRD R10/R11 says skip; tech doc D5 says replace; code follows tech doc. The behavior difference is material (replaces vs preserves a potentially intentional "wrong" symlink). Requires PM/Architect sign-off or PRD amendment before the ship is complete. `bin/claude-symlink:515`.

2. **D2** — `uninstall --dry-run` double-reports: `[would-remove]` + `[removed]` emitted per link. Violates R12 (dry-run must produce only `would-*` verbs and zero mutations). Filesystem is safe (no actual rm); output is incorrect. Fix in `cmd_uninstall` at `bin/claude-symlink:664` and `bin/claude-symlink:686`. AC9 does not catch this.

### NITS (4)

1. **t2 stale assertions** — `test/t2_flag_parsing.sh` lines 88–91 assert `stub: install` (T1 stub-era) and `dry-run=0` (T2 stub echo). The real script no longer prints either. These will fail if `t2_flag_parsing.sh` is run directly. Fixture rot; not a regression in the production script.

2. **T11 verify step 4 logical inconsistency** — `06-tasks.md` T11 verify step 4 states "Running with `HOME=/Users/yanghungtw` (real $HOME) aborts with exit 2." `smoke.sh` always sets `HOME="$SANDBOX/home"` at script start (before any user-controlled HOME can apply), so this step cannot be satisfied as written from outside the script. Developer interpreted it as "the safety property holds regardless" — which is correct and more conservative. Worth noting for future task authors.

3. **t3–t10 worktree-hardcoded paths** — Eight test files (`test/t3_resolve_path.sh` through `test/t10_summary.sh`) hardcode `WORKTREE="/Users/yanghungtw/Tools/spec-workflow/.worktrees/symlink-operation-T10"`. That path no longer exists after the worktrees were cleaned up. Running any of these unit tests in the current checkout will fail immediately on the `SCRIPT` not-found check. Does not affect `test/smoke.sh` (which uses `REPO_ROOT`-relative paths) or production code. Affects unit test maintainability.

4. **AC12 is a noop marker, not a test** — `ac12_cross_platform` always passes as long as `uname -s` returns a non-empty string. Real cross-platform validation requires a CI pipeline on both macOS and Linux runners. This is acknowledged in the tech doc but not wired into any automation. Acceptable for v1; flag for QA-tester to note.
