# Plan — bug: scaff-install-hook writes wrong settings.json path

- **Feature**: `20260426-fix-install-hook-wrong-path`
- **Stage**: plan
- **Author**: orchestrator (hand-written; bug-tiny short-circuit — see §1.3)
- **Date**: 2026-04-26
- **Tier**: tiny
- **Work-type**: bug

PRD: `03-prd.md` (R1–R6, T1–T3, AC1–AC4, D1–D3).

---

## 1. Approach

### 1.1 Scope

Single bug-fix change set bundling four edits and one test extension:

1. `bin/scaff-install-hook` (line 66 in `do_add`, line 109 in `do_remove`): replace the bare literal `p = "settings.json"` with `p = ".claude/settings.json"`. In `do_add`, add `os.makedirs(os.path.dirname(p), exist_ok=True)` before the first read/write so the helper creates `.claude/` when the consumer is fresh (R1, R2). `do_remove`'s early `FileNotFoundError → sys.exit(0)` already absorbs the missing-`.claude/` case; no makedirs needed there.

2. `bin/scaff-seed` lines 968–969 (init Step 10) and 1622–1623 (migrate counterpart): prepend `bash ` to each command argument so the strings written by the helper match Step 7's Python merge form (R6). The path argument itself stays unchanged — the helper's new default targets `.claude/settings.json`, and the call site doesn't pass an explicit settings-path, so R3 holds without further surgery (this answers PRD OQ1: lines 1620–1623 invoke the helper with no settings-path arg, so the default change covers migrate the same way it covers init).

3. `test/t7_scaff_install_hook.sh`, `test/t27_settings_json_preserves_keys.sh`, `test/t28_settings_json_idempotent.sh`: update each sandbox setup to expect the helper to write `<sandbox>/.claude/settings.json` (and `.bak`/`.tmp` next to it) rather than `<sandbox>/settings.json`. Where a check pre-seeds settings.json (e.g. t27's "preserves unrelated keys" path), pre-seed at the new location.

4. `test/t114_seed_settings_json.sh`: append a new assertion section (e.g. `A4` parallel to existing A1–A3) that runs `scaff-seed init` against a fresh empty consumer and asserts AC1+AC2+AC3:
   - `[ ! -e "$CONSUMER/settings.json" ]` (R5/AC1)
   - `[ ! -e "$CONSUMER/settings.json.bak" ]` (R5/AC1)
   - `<CONSUMER>/.claude/settings.json` exists and contains both `SessionStart` and `Stop` entries with command strings exactly `bash .claude/hooks/session-start.sh` and `bash .claude/hooks/stop.sh` (R1/R6/AC2)
   - Re-running `scaff-seed init` against the same consumer is a no-op: no new `.bak` produced anywhere; `<CONSUMER>/.claude/settings.json` is byte-identical to the first-run output (modulo whitespace/key-order normalisation already applied by Python `json.dump`) (R4/AC3)

   AC4 (migrate flow lands in `.claude/settings.json`, not at root) is covered by the existing migrate-coverage tests once they're updated under bullet (3); no separate test needed.

### 1.2 Why one task, not two

All four edits sit on a single failing-test → green-test arc: the production change in `bin/` makes the assertions added in `test/` pass. Splitting into a "code" task and a "test" task would create a same-codebase pair where the test task FAILS until the code task lands — no parallelism gain (different files, but logical dependency), and the merge order is forced. The chore-tiny precedent (`20260426-chore-t108-migrate-coverage` §1.2) used the same one-task folding for the same reason. Folded into one task T1.

### 1.3 Bug-tiny short-circuit (why no Architect/TPM dispatch)

The stage matrix for `bug × tiny` reports: `design = skipped`, `tech = skipped`, `plan = optional`, `implement = required`, `validate = required`. The `/scaff:plan` command (`.claude/commands/scaff/plan.md` step 1) hard-requires `04-tech.md` whenever `work-type ≠ chore` — the chore-tiny short-circuit landed in `20260426-chore-scaff-plan-chore-aware` (2026-04-26) covers chore only. For `work-type=bug`, the same matrix-vs-plumbing gap remains: tech is matrix-skipped on tier=tiny, so no `04-tech.md` exists, so `/scaff:plan` would error out. Rather than (a) surface a hard-stop or (b) upgrade the tier just to satisfy the dispatcher, the orchestrator hand-writes this minimal plan from the PRD's R/AC/T fields. This file exists primarily to satisfy `/scaff:implement`'s contract (it requires `05-plan.md` with at least one `^- \[ \]` line).

The pattern is identical to the legacy chore-tiny workaround documented in `tpm/chore-tiny-plan-short-circuit-plumbing-gap.md` (How-to-apply step 1, marked LEGACY since 2026-04-26). Surfacing this as a follow-up: the chore-tiny plumbing fix in `tpm.md` should be extended to cover bug-tiny too, OR `/scaff:plan` step 1 should be relaxed to "Require `04-tech.md` ONLY when `work-type ≠ chore` AND `tier ≠ tiny`" (or equivalent), OR the matrix should mark bug × tiny tech as `optional` rather than `skipped` so a degenerate `04-tech.md` could be auto-emitted.

### 1.4 Wave shape

Single wave (W1), single task (T1). No inline review (R16 default for tier=tiny). No worktree needed for one task; --serial mode acceptable, or a single bug-fix branch.

---

## 2. Tasks

## T1 — Fix scaff-install-hook default target + scaff-seed call-site command form + regression tests

- **Milestone**: M1
- **Requirements**: R1, R2, R3, R4, R5, R6 (PRD §Fix requirements); T1, T2, T3 (PRD §Regression test requirements); AC1, AC2, AC3, AC4 (PRD §Acceptance criteria); D1, D2, D3 (PRD §Decisions).
- **Decisions**: D1 (Option B — change helper default rather than cd in caller); D2 (no `--settings-path` flag this PR — call sites don't need it); D3 (no retro-cleanup of orphaned root-level files on existing consumers).
- **Scope**:
  1. **`bin/scaff-install-hook`** —
     - Line 66 (in `do_add` Python heredoc): change `p = "settings.json"` → `p = ".claude/settings.json"`.
     - Immediately after the new line 66 (or at the top of the heredoc body, before the `try: open(p)` block), add: `os.makedirs(os.path.dirname(p), exist_ok=True)` — `os` is already imported on line 62.
     - Line 109 (in `do_remove` Python heredoc): change `p = "settings.json"` → `p = ".claude/settings.json"`. No makedirs needed (the existing `FileNotFoundError → sys.exit(0)` covers the absent-`.claude/` case).
     - Update the header comment block (around lines 10–14) to say "Operates on `.claude/settings.json` relative to the caller's cwd; creates `.claude/` if missing" rather than "settings.json in the CURRENT DIRECTORY".
  2. **`bin/scaff-seed`** —
     - Lines 968–969: change the third positional arg from `".claude/hooks/session-start.sh"` / `".claude/hooks/stop.sh"` to `"bash .claude/hooks/session-start.sh"` / `"bash .claude/hooks/stop.sh"` (prepend `bash `).
     - Lines 1622–1623 (migrate counterpart, the matching `add SessionStart` / `add Stop` pair): apply the same prepend.
     - Lines 1620–1621 (the matching `remove SessionStart` / `remove Stop` pair on `~/.claude/hooks/...`): leave unchanged — these remove old global-install entries with `~/...` paths, not the new consumer-local ones.
  3. **`test/t7_scaff_install_hook.sh`** — adjust each Check that expects `settings.json` / `settings.json.bak` at the sandbox root to expect `.claude/settings.json` / `.claude/settings.json.bak` instead. The helper now creates `.claude/` itself, so no test-side `mkdir .claude` is needed; preserve the existing per-check `mktemp -d` sandbox discipline.
  4. **`test/t27_settings_json_preserves_keys.sh`** — same adjustment. Where a check pre-seeds an existing `settings.json` to verify key preservation, pre-seed it at `<sandbox>/.claude/settings.json` (and `mkdir -p <sandbox>/.claude` first since the helper's makedirs runs only on its own write path).
  5. **`test/t28_settings_json_idempotent.sh`** — same adjustment as t27.
  6. **`test/t114_seed_settings_json.sh`** — append a new assertion section (e.g. `# A4 — bug fix: scaff-seed init does NOT create root-level settings.json/.bak; both hooks land at .claude/settings.json with `bash ...` form`). Use a fresh `mktemp -d` consumer fixture, run `(cd "$CONSUMER" && "$REPO_ROOT/bin/scaff-seed" init --from "$REPO_ROOT" --ref HEAD)` (or whatever invocation the existing A1/A2/A3 sections use), then assert:
     - `[ ! -e "$CONSUMER/settings.json" ]`
     - `[ ! -e "$CONSUMER/settings.json.bak" ]`
     - `[ -f "$CONSUMER/.claude/settings.json" ]`
     - `python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); ...'` extracts SessionStart and Stop command strings and asserts each starts with `bash .claude/hooks/`.
     - Re-run init; assert `[ ! -e "$CONSUMER/.claude/settings.json.bak" ]` (no new backup means idempotent no-op fired).
     Bash 3.2 / BSD-portable per `.claude/rules/bash/bash-32-portability.md` (no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]`). Sandbox-HOME discipline preserved per `.claude/rules/bash/sandbox-home-in-tests.md` (the existing t114 file already implements it; new section reuses the same `$SANDBOX` / `$HOME` setup).
  7. **English-only**: every file written under this task is English content (per `.claude/rules/common/language-preferences.md` carve-outs (b)–(f); only chat replies to the user during this session are zh-TW).
- **Deliverables**:
  - `bin/scaff-install-hook` (edit; ~4–5 line delta — 2 string changes, 1 makedirs add, 1 comment update)
  - `bin/scaff-seed` (edit; 4 line delta — prepend `bash ` to 4 string args)
  - `test/t7_scaff_install_hook.sh` (edit; path adjustments only, no semantic change)
  - `test/t27_settings_json_preserves_keys.sh` (edit; path adjustments + added `mkdir -p .claude` before pre-seed)
  - `test/t28_settings_json_idempotent.sh` (edit; path adjustments)
  - `test/t114_seed_settings_json.sh` (edit; appended A4 section; existing A1/A2/A3 untouched except where they reference the bare-filename path)
- **Verify** (every command must exit 0):
  - `bash -n bin/scaff-install-hook` (syntax)
  - `bash -n bin/scaff-seed` (syntax)
  - `bash test/t7_scaff_install_hook.sh` (final line: `PASS: t7` or equivalent — read the existing exit-code convention)
  - `bash test/t27_settings_json_preserves_keys.sh`
  - `bash test/t28_settings_json_idempotent.sh`
  - `bash test/t114_seed_settings_json.sh` (final line includes a `PASS` marker matching the existing convention)
  - `bash test/smoke.sh` (full local smoke suite — catches any other test that touched the bare-filename assumption that wasn't enumerated above)
  - Manual replay of the bug repro from PRD §Repro on a fresh `mktemp -d` consumer: `(cd "$tmpc" && bin/scaff-seed init --from "$REPO_ROOT" --ref HEAD)` then assert `[ ! -e "$tmpc/settings.json" ] && [ ! -e "$tmpc/settings.json.bak" ] && [ -f "$tmpc/.claude/settings.json" ]` and that the JSON contains both SessionStart and Stop with `bash .claude/hooks/...` commands.
- **Depends on**: —
- **Parallel-safe-with**: — (single task in single wave)
- [x]

---

## 3. Risks

1. **Test discovery gap**: `grep -l 'scaff-install-hook' test/*.sh` shows seven hits (`t7`, `t27`, `t28`, `t42`, `t44`, `t45`, `t47`, `t114`). The Scope only enumerates t7/t27/t28/t114 explicitly; t42/t44/t45/t47 may also assert against the bare-filename path or the no-`bash`-prefix command form. The `bash test/smoke.sh` Verify step is the safety net — if any unenumerated test fails, the developer extends the diff to cover it (still in scope per "no enumerated subset of tests; the contract is 'all tests pass'"). Do NOT split that follow-on work into a new task unless the surface materially exceeds 1–2 additional files.
2. **Pre-existing consumers with root-level `settings.json`**: D3 declines retro-cleanup. The fix is forward-only — existing consumers keep their orphan `settings.json` / `.bak` until the user `rm`s them. The regression tests use fresh consumers, so they don't exercise the orphan-cleanup path.
3. **Idempotency under partial state**: AC3 (and the new t114 A4 idempotency assertion) assumes a clean second run. If the first run raced or partially wrote (e.g. helper crash mid-`os.replace`), idempotency might not hold. Out of scope for this PR — production `os.replace` on the same filesystem is atomic enough for the contract.
4. **`bin/scaff-install-hook` invocations from outside scaff-seed**: any other consumer-side tool that calls the helper directly (e.g. user-authored install scripts) will now write to `.claude/settings.json` instead of `settings.json`. This is the desired behaviour per R1 and is documented in the updated header comment. No CLI flag is added to revert (D2).

## 4. Open questions

None. PRD §OQ1 (does migrate at lines 1620–1623 fully cover under Option B?) is answered in §1.1 bullet 2: the migrate call site invokes the helper with no explicit settings-path argument, so the default change covers it identically to init. R6's command-string mismatch IS in scope and IS addressed by §1.1 bullet 2 alongside it.
