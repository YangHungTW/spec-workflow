# Plan — fix init missing preflight files

- **Feature**: `20260426-fix-init-missing-preflight-files`
- **Stage**: plan
- **Author**: TPM
- **Date**: 2026-04-26
- **Tier**: standard
- **Work-type**: bug

PRD: `03-prd.md` (5 R-clauses, 7 ACs, 4 Decisions). Tech: `04-tech.md` (D1–D7).

## 1. Wave plan (narrative)

### 1.1 Scope summary

This is a bug fix: `bin/scaff-seed init` and `bin/scaff-seed migrate` do not produce `.specaffold/config.yml` or `.specaffold/preflight.md` in fresh consumer repos, so the preflight gate (shipped by `20260426-scaff-init-preflight`) fails closed with `REFUSED:PREFLIGHT` on every freshly-init'd repo. The fix wires both files into the existing manifest emit pipeline:

- `.specaffold/preflight.md` flows verbatim through the existing `plan_copy → classify_copy_target → dispatcher` machinery via a single new sibling-block emit (D2, D6).
- `.specaffold/config.yml` cannot be verbatim-copied (source repo has `lang.chat: zh-TW`; consumer default is `lang.chat: en` per the language-preferences rule). A new helper `emit_default_config_yml()` runs a separate classify-and-dispatch block called from BOTH `cmd_init` (after the existing pre-commit shim block ~line 727-748) AND `cmd_migrate` (mirror block ~line 1308-1329) (D1, D4, D5).
- A new structural test `test/t112_init_seeds_preflight_files.sh` exercises AC1–AC7 including A7 migrate-path mirror (D7), closing the partial-wiring-trace gap that allowed the parent feature to ship without this regression caught.

### 1.2 Why two tasks (not three)

The architect handoff suggested three logical pieces: (i) plan_copy entry for preflight.md, (ii) emit_default_config_yml helper + both call sites, (iii) the regression test. Pieces (i) and (ii) both edit `bin/scaff-seed`. Per `tpm/parallel-safe-requires-different-files.md`, two tasks may only be marked `Parallel-safe-with` each other if they edit different files (or genuinely disjoint, far-apart regions). The two scaff-seed edits are NOT far-apart: the helper `emit_default_config_yml` is called from cmd_init at the same insertion point family as the pre-commit shim (line 727-748), and `plan_copy` lives at line 361-400 — distinct functions but the same file, and a future refactor of `plan_copy`'s prefix-list scaffolding could textually overlap with helper-function placement.

Resolution: **fold (i) and (ii) into a single task T1 that lands all `bin/scaff-seed` edits atomically**. This avoids: (a) any same-file conflict risk, (b) any partial-wiring window where preflight.md is wired but config.yml emission is not (or vice versa), (c) the dogfood-paradox scenario where the test would pass on a half-wired state. Wave count drops to 1; task count is 2 (T1 production change + T2 regression test).

### 1.3 Dogfood-paradox handling

This bug fix does NOT itself ship a self-enforcing mechanism. The new files (`.specaffold/config.yml`, `.specaffold/preflight.md`) are inert per-consumer state created in the consumer's working tree at init time; they are not gate-enforcing artefacts in the source repo. The pre-commit hook installed today (scaff-lint scan-staged + preflight-coverage) is unaffected. Therefore:

- No `--no-verify` discipline is needed at any commit.
- No bookkeeping commit needs special handling.
- The `--no-verify` memory `tpm/no-verify-bookkeeping-when-feature-ships-its-own-precommit.md` does NOT apply here.

The only "self-test" property is that the source repo's own `.specaffold/preflight.md` becomes part of the seed manifest — but the source repo already has its own `config.yml` (lang.chat: zh-TW) that is intentionally NOT wired into the manifest (D1's whole point). No paradox.

### 1.4 Inline review posture

Tier=standard ⇒ inline review runs (R16 default). Relevance per axis:

- **Security** (must): high relevance. T1 touches `bin/scaff-seed` which writes under user-owned paths. The change inherits the no-force-on-user-paths discipline via the existing classifier states (`user-modified` → skip), and the helper writes via `write_atomic`. Reviewer must confirm: (a) no `--force` flag introduced, (b) no string-built shell command that includes external input, (c) atomic write through `write_atomic` (not direct `>` redirect).
- **Style** (should): standard. New helpers must match neighbour file conventions (snake_case, `set -euo pipefail` already at file head, bash 3.2 portable per the existing file). New test must follow the t108–t111 sandbox-HOME template.
- **Performance** (should): low relevance. T1 adds one `[ -f ]` test in `plan_copy` (O(1)) and one helper invocation per init/migrate run (no loop, no per-iteration shell-out). T2 is a test script that runs once. No hot path.

### 1.5 Out-of-scope (deferred per tech §6)

- `config.yml` schema validation (`bin/scaff-lint config-yml`) — deferred until a future feature adds non-trivial keys.
- Auto-update of consumer `config.yml` when source default changes — current behaviour (existing file → state=user-modified → skipped) is correct.
- `cmd_update` emitting these files — `plan_copy update` mode does NOT include the new entries; consumer recovery path on update is intentionally not changed in this fix.

### 1.6 Risks

1. **Same-file conflict between scaff-seed edits** — RESOLVED by folding both edits into T1 (see §1.2). No further mitigation needed.
2. **Helper byte-identity drift** — the `emit_default_config_yml` helper is called from BOTH `cmd_init` and `cmd_migrate`. Per D5, the helper is the single source of truth (no inlined heredocs); T2's A7 assertion pins migrate-path parity so any future drift surfaces immediately.
3. **Plan-time anchor staleness** — line numbers cited in tech §1 (lines 733, 1314 for pre-commit shim) and §3 D6 (lines 365-378 for plan_copy prefix loop) are accurate as of plan-write time but may drift if other features land first. Each task scope below embeds the verbatim `grep -n` command the developer should run at dispatch time per `tpm/plan-time-file-existence-checks-must-re-run-at-sub-agent-dispatch.md`.
4. **Test counter collision** — `test/t112_*` is the next free counter (last used = `t111_baseline_diff_shape.sh`). Pre-declared as `test/t112_init_seeds_preflight_files.sh` per `tpm/pre-declare-test-filenames-in-06-tasks.md`.

### 1.7 Escalations

None. No PRD ambiguities, no tech blockers, no missing decisions. PRD D1–D4 + tech D1–D7 fully resolve scope.

## 2. Wave schedule

- **Wave 1**: T1, T2 (parallel — different files: T1 → `bin/scaff-seed`; T2 → `test/t112_init_seeds_preflight_files.sh`)

### Parallel-safety analysis (Wave 1)

- **File overlap check**: T1 touches `bin/scaff-seed` only. T2 creates `test/t112_init_seeds_preflight_files.sh` only. No bookkeeping files (`05-plan.md`, `STATUS.md`) touched by task agents — orchestrator handles bookkeeping per `tpm/wave-bookkeeping-commit-per-wave.md`.
- **Test isolation**: T2's structural test uses `mktemp -d` sandbox + sandbox-HOME preflight (per `.claude/rules/bash/sandbox-home-in-tests.md`). It runs `bin/scaff-seed init` against the sandbox; it does NOT depend on T1's edits being present at the time the test SCRIPT is authored — the test script is authored independently and run as a structural check post-merge. The test will only PASS once T1's changes are in the same commit set, but authoring the test does not require T1 in scope.
- **Shared infrastructure**: none. No migrations, no schema changes, no config-file edits.
- **Wave size = 2**: justified by file disjointness. T1 and T2 are logically independent (production code vs structural test) AND file-disjoint.

## 3. Task checklist

## T1 — Wire `.specaffold/preflight.md` and default `config.yml` into `bin/scaff-seed` init+migrate emit pipeline

- **Milestone**: M1
- **Requirements**: R1, R2, R3, R4
- **Decisions**: D1 (default content `lang:\n  chat: en\n`), D2 (preflight.md via plan_copy), D3 (reuse classifier states), D4 (cmd_migrate parity), D5 (single helper, no inlined heredoc duplication), D6 (sibling block in plan_copy)
- **Scope**:
  - Anchor verification at dispatch time (re-run these commands first, do not trust plan line numbers blind):
    - `grep -n "for prefix in" /Users/yanghungtw/Tools/specaffold/bin/scaff-seed | head -5` — locate the existing `plan_copy` prefix loop (expected near line 365).
    - `grep -n "Step 8b: Install pre-commit shim" /Users/yanghungtw/Tools/specaffold/bin/scaff-seed` — locate the two pre-commit shim blocks (expected lines 722 and 1303). The new `emit_default_config_yml` invocation goes adjacent to these blocks at BOTH call sites.
    - `grep -n "team-memory case block\|.specaffold/features/_template" /Users/yanghungtw/Tools/specaffold/bin/scaff-seed | head -5` — confirm the case block referenced in tech D6 (after the prefix loop, before any team-memory enumeration).
  - Edit 1: in `plan_copy`, after the existing prefix loop and before the team-memory case block, add the explicit sibling block from tech D6:
    ```bash
    if [ -f "${src_root}/.specaffold/preflight.md" ]; then
      printf '.specaffold/preflight.md\n'
    fi
    ```
    The `[ -f ]` guard preserves the "skip skeleton paths where the source file genuinely does not exist" property.
  - Edit 2: add two new top-level helper functions to `bin/scaff-seed` (placement: near other classifier+dispatcher pairs, e.g. just before or after `classify_precommit_shim`):
    - `classify_default_config_yml(consumer_root)` — pure classifier per tech §3 D3 implementation note (returns `missing | ok | user-modified`; `ok` = file exists with byte-identical default content).
    - `emit_default_config_yml(consumer_root)` — dispatcher per tech §3 D3 implementation note (writes via `write_atomic` on `missing`; emits `already:` on `ok`; emits `skipped:user-modified:` and bumps `MAX_CODE` on `user-modified`).
  - Edit 3: in `cmd_init`, add a new dispatcher block adjacent to the pre-commit shim install (Step 8b area, ~line 722-748) that calls `emit_default_config_yml "$consumer_root"`. The `consumer_root` variable is already in scope; no new local variables needed.
  - Edit 4: in `cmd_migrate`, mirror Edit 3 — adjacent to the migrate's pre-commit shim install (~line 1303-1329), call `emit_default_config_yml "$consumer_root"`. BYTE-IDENTICAL invocation at both call sites — single helper, single `printf` source-of-truth for the default content.
  - All bash must remain bash 3.2 / BSD portable per `.claude/rules/bash/bash-32-portability.md`.
  - No-force-on-user-paths discipline: every state with a pre-existing non-matching file routes to `skipped:user-modified` with NO write. Use existing `write_atomic` helper (do NOT introduce a new `>` redirect).
- **Deliverables**:
  - Modified: `bin/scaff-seed` (one file; ~30-40 net new lines: 3-line sibling block in plan_copy + two helper functions + two adjacent dispatcher invocations in cmd_init and cmd_migrate).
- **Verify**: T2's `test/t112_init_seeds_preflight_files.sh` covers AC1–AC7 end-to-end. Pre-flight syntax check via `bash -n /Users/yanghungtw/Tools/specaffold/bin/scaff-seed`. Then run T2's test script as the integration verification.
- **Depends on**: —
- **Parallel-safe-with**: T2 (file-disjoint: T1 → `bin/scaff-seed`; T2 → `test/t112_init_seeds_preflight_files.sh`)
- [x]

## T2 — Author regression test `test/t112_init_seeds_preflight_files.sh` covering AC1–AC7

- **Milestone**: M1
- **Requirements**: R5
- **Decisions**: D7 (new test, not extension of t108)
- **Scope**:
  - Anchor verification at dispatch time:
    - `ls /Users/yanghungtw/Tools/specaffold/test/t1{0,1}*.sh | sort | tail -5` — confirm last-used counter is `t111` and `t112` is free.
    - `ls /Users/yanghungtw/Tools/specaffold/test/t108_precommit_preflight_wiring.sh` — confirm structural template exists; reuse its sandbox-HOME preamble + `make_consumer` helper pattern.
    - `ls /Users/yanghungtw/Tools/specaffold/test/t110_runtime_sandbox_acs.sh` — confirm the awk extract-and-run pattern for the gate body (used by A6).
  - Author `test/t112_init_seeds_preflight_files.sh` per tech §3 D7 specification (sandbox HOME, mktemp, `make_consumer` helper, sequential A1…A7 assertions, exit on first failure, BSD-portable bash):
    - Top-of-file must follow `.claude/rules/bash/sandbox-home-in-tests.md`: `SANDBOX="$(mktemp -d)"`, `trap 'rm -rf "$SANDBOX"' EXIT`, `export HOME="$SANDBOX/home"`, preflight `case "$HOME" in "$SANDBOX"*) ;; *) ... exit 2 ;; esac`.
    - SCAFF_SRC resolution: use the same pattern as t108–t111 (resolve via the test's own location).
    - **A1** (AC1): after `bin/scaff-seed init --from $SCAFF_SRC --ref HEAD` against a fresh `make_consumer` repo, both `[ -f $CONSUMER/.specaffold/config.yml ]` AND `[ -f $CONSUMER/.specaffold/preflight.md ]`.
    - **A2** (AC2): `cmp $SCAFF_SRC/.specaffold/preflight.md $CONSUMER/.specaffold/preflight.md` exits 0.
    - **A3** (AC3): `grep -E '^lang:' $CONSUMER/.specaffold/config.yml` AND `grep -E '^[[:space:]]+chat:' $CONSUMER/.specaffold/config.yml` succeed AND `grep -F 'chat: en' $CONSUMER/.specaffold/config.yml` succeeds.
    - **A4** (AC4): second `bin/scaff-seed init` is idempotent — output contains `already: .specaffold/config.yml` AND `already: .specaffold/preflight.md`; shasum-before == shasum-after for both files.
    - **A5** (AC5): pre-existing user-edited `config.yml` (set fixture content `lang:\n  chat: zh-TW\nuser_added: true\n` BEFORE running init) is unchanged after init; output contains `skipped:user-modified: .specaffold/config.yml`.
    - **A6** (AC6): extract the SCAFF PREFLIGHT block from `$CONSUMER/.specaffold/preflight.md` (same awk pattern as t110), run it from `$CONSUMER` CWD, assert exit 0 AND empty stdout (passthrough).
    - **A7** (AC7 / R3 partial-wiring-trace): on a separate fresh consumer, run `bin/scaff-seed migrate --from $SCAFF_SRC --ref HEAD`, assert both files present AND byte-identical to what init would produce (re-check via shasum from a parallel init sandbox, OR re-assert A1+A2+A3 against the migrate-produced files).
  - All bash must remain bash 3.2 / BSD portable. No `mapfile`, no `readlink -f`, no `[[ =~ ]]` for portability-critical match logic.
  - End with `echo "PASS: t112"` (or equivalent) on success.
- **Deliverables**:
  - New: `test/t112_init_seeds_preflight_files.sh` (executable, mode 755).
- **Verify**: `bash -n /Users/yanghungtw/Tools/specaffold/test/t112_init_seeds_preflight_files.sh` for syntax; then run `/Users/yanghungtw/Tools/specaffold/test/t112_init_seeds_preflight_files.sh` end-to-end after T1's edits are in the same commit set — must exit 0 with PASS marker. Single file is the sole deliverable; the test command itself IS the verify command per tpm.appendix `Verify` rule.
- **Depends on**: —
- **Parallel-safe-with**: T1 (file-disjoint: T1 → `bin/scaff-seed`; T2 → `test/t112_init_seeds_preflight_files.sh`)
- [x]
