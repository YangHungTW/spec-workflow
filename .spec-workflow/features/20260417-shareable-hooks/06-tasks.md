# Tasks — shareable-hooks (B2.a)

_2026-04-18 · TPM_

Legend: `[ ]` todo · `[x]` done · `[~]` in progress

Source of truth: `03-prd.md` (R1–R18), `04-tech.md` (D1–D9),
`05-plan.md` (M1–M4). Every task names the milestone, requirements, and
decisions it lands. `Verify` is a concrete runnable command (or filesystem
check) the Developer runs at the end of the task; if it passes, the task
is done.

All paths below are absolute under
`/Users/yanghungtw/Tools/spec-workflow/`. When this plan says "the stop
hook", it means `.claude/hooks/stop.sh` per D1. When it says "the symlink
tool", it means `bin/claude-symlink` per D7.

---

## T1 — Stop hook script (`.claude/hooks/stop.sh`)
- **Milestone**: M1
- **Requirements**: R9, R10, R11, R12, R13, R15, R16
- **Decisions**: D1 (location + bash 3.2), D2 (stdin sniff), D3 (branch-name classifier), D4 (60s sentinel + BSD/GNU `date` dispatch), D5 (fixed-generic note + `.tmp`+`mv` append), D6 (`HOOK_TEST=1` gate)
- **Scope**: Create `.claude/hooks/stop.sh` as a new executable file. Pure bash 3.2, BSD userland only; no `readlink -f`, no `realpath`, no `jq`, no `mapfile`, no `[[ =~ ]]` for portability-critical logic (per `.claude/rules/bash/bash-32-portability.md`). Structure:
  1. **Fail-safe header** (D1): shebang `#!/usr/bin/env bash`; `set +e` (NOT `-e`); `trap 'exit 0' ERR INT TERM` early; helpers `log_warn` / `log_info` emit `stop.sh: WARN: …` / `stop.sh: INFO: …` to stderr. Final line of the script is an unconditional `exit 0`. NO path in the script may exit with a non-zero code.
  2. **Stdin sniff** (D2): `raw_payload=$(cat 2>/dev/null)`. Under `HOOK_TEST=1`, `log_info` dumps first 200 chars of raw payload for forward-compat debugging. Minimal shape check: `case "$raw_payload" in '{'*) ;; *) log_info "stdin not a valid Stop payload"; exit 0 ;; esac`. No `jq`, no `python3` on the runtime path.
  3. **`classify_env()` pure classifier** (D3): emits EXACTLY ONE of `not-git | no-specflow | no-match | ambiguous:<list> | ok:<slug>` on stdout. No side effects, no stderr. Checks: `.git/HEAD` readable OR `git rev-parse --git-dir` succeeds; `.spec-workflow/features/` exists; `git symbolic-ref --short HEAD` non-empty; walk `.spec-workflow/features/*/` and match each slug as `case "$branch" in *"$slug"*)`. Zero matches → `no-match`; exactly one → `ok:<slug>`; >1 → `ambiguous:<space-list>`.
  4. **Dispatch `case`** (D3): single `case "$state"` at top level — mutation happens HERE only. `not-git` / `no-specflow` / `no-match` → `log_info` + `exit 0`. `ambiguous:*` → `log_warn "ambiguous: <list>"` + `exit 0`. `ok:*` → extract slug; fall through to dedup + append.
  5. **`to_epoch()` wrapper** (D4): dispatch by `uname -s` — `Darwin|*BSD` → `date -j -f "%Y-%m-%d %H:%M:%S" "$ts" +%s`; `Linux|*` → `date -d "$ts" +%s`.
  6. **`within_60s()` dedup** (D4): check per-feature sentinel at `<feature>/.stop-hook-last-epoch`. If sentinel exists and `now_epoch - prior < 60`, return 0 (recent — skip). Otherwise return 1.
  7. **`append_note()`** (D5): verify `^## Notes` heading present in STATUS.md (R16 edge case — WARN + return if missing); compose `- YYYY-MM-DD stop-hook — stop event observed` line; under `HOOK_TEST=1` log what would be appended and return WITHOUT mutation (D6); else write `{ cat "$status"; printf -- '- %s stop-hook — stop event observed\n' "$today"; } > "$tmp"` then atomic `mv "$tmp" "$status"`; write sentinel atomically (`date +%s > "$sentinel.tmp" && mv "$sentinel.tmp" "$sentinel"`). NEVER use `>>` on the live STATUS.md (partial-write risk).
  8. **`chmod +x`** on the finished script.
  9. **`.gitignore` entry**: append `.spec-workflow/features/*/.stop-hook-last-epoch` to `/Users/yanghungtw/Tools/spec-workflow/.gitignore` to keep the per-feature sentinel out of commits (per tech doc §6 "sentinel file accidentally committed" pre-emption).
- **Deliverables**: new file `.claude/hooks/stop.sh` (exec bit set); one-line append to `.gitignore`. No other files touched.
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh` exits 0 (syntax clean).
  - `test -x /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh` succeeds.
  - `/Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh < /dev/null` exits 0.
  - `/Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh < /dev/null 2>&1 >/dev/null | grep -q 'stdin not a valid Stop payload'` (empty stdin routes through the D2 sniff).
  - HOOK_TEST happy path (sandboxed, matching feature seeded): `HOOK_TEST=1 .claude/hooks/stop.sh <<<'{}' 2>&1 >/dev/null | grep -q 'test-mode would append'` AND the seeded `STATUS.md` is byte-identical before/after.
  - `grep -q '^\.spec-workflow/features/\*/\.stop-hook-last-epoch$' /Users/yanghungtw/Tools/spec-workflow/.gitignore`.
- **Depends on**: —
- **Parallel-safe-with**: T2, T3, T4, T5, T6, T7
- [ ]

## T2 — `bin/claude-symlink` 4-site extension (new `hooks` dir-pair)
- **Milestone**: M2
- **Requirements**: R1, R2, R3, R4, R5 (usage portion)
- **Decisions**: D7 (4-site mechanical edit), D8 (enumerate 3 pairs in usage), D9 (backward compat via existing `update` self-heal)
- **Scope**: Edit `bin/claude-symlink` at EXACTLY four sites per D7. NO refactors, NO classifier changes, NO new states, NO `--force` additions. Any edit outside these four sites is out of scope and regresses one of the 28 existing smoke tests.
  1. **`plan_links()` — insert 2 lines** after the "Fixed pair 2: commands/specflow" block and BEFORE the team-memory file walk:
     ```
     # Fixed pair 3: hooks (NEW, feature 20260417-shareable-hooks)
     PLAN_SRC+=("$REPO/.claude/hooks")
     PLAN_TGT+=("$HOME/.claude/hooks")
     ```
  2. **`cmd_uninstall` `dir_links=(...)` array** (lines ~656–658 in the current file) — add `"$HOME/.claude/hooks"` as a third entry so uninstall's Step 1 covers the new pair.
  3. **`usage()` managed-set block** (lines ~427–429) — add a `hooks` row with the same shape as the existing two dir-pair rows.
  4. **Top-of-file header comment** (the script-header block at lines ~23–28 enumerating the managed set) — add `hooks` to the enumerated set so the header is authoritative (D8 single-source-of-truth).
- **NOT changed**: `classify_target`, `owned_by_us`, `apply_plan`, `cmd_install`, `cmd_update`, the `__probe` harness, `emit_summary`. The 8-state classifier is not touched. The new pair flows through the existing dispatch without special-casing.
- **Deliverables**: one edited file, `/Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink`. Four edit sites only. No new files.
- **Verify** (sandbox-HOME discipline — run under `mktemp -d` per `.claude/rules/bash/sandbox-home-in-tests.md`):
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink` exits 0.
  - `/Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink --help | grep -q 'hooks'` — usage enumerates the new pair.
  - Sandbox install: `SB=$(mktemp -d); export HOME="$SB/home"; mkdir -p "$HOME"; case "$HOME" in "$SB"*) ;; *) exit 2 ;; esac; /Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink install; readlink "$HOME/.claude/hooks" | grep -q '^/Users/yanghungtw/Tools/spec-workflow/.claude/hooks$'` — absolute-target symlink created.
  - Idempotent re-install: run `install` twice in the same sandbox; second run reports `already` for the hooks pair; `readlink "$HOME/.claude/hooks"` unchanged.
  - Uninstall: `/Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink uninstall`; `test ! -e "$HOME/.claude/hooks"`.
  - Backward compat: `bash /Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` — all 28 existing B1 tests stay green (T8 will extend this to 33).
- **Depends on**: —
- **Parallel-safe-with**: T1, T3, T4, T5, T6, T7
- [ ]

## T3 — `test/t29_claude_symlink_hooks_pair.sh`
- **Milestone**: M3
- **Requirements**: R17
- **Decisions**: D7 (validates the 4-site edit); `.claude/rules/bash/sandbox-home-in-tests.md` (template)
- **Scope**: Create `test/t29_claude_symlink_hooks_pair.sh` — integration test covering the new dir-pair lifecycle. Structure:
  1. mktemp sandbox + `export HOME="$SANDBOX/home"` + `trap 'rm -rf "$SANDBOX"' EXIT` + case-pattern preflight (`case "$HOME" in "$SANDBOX"*) ;; *) echo "FAIL: HOME not isolated" >&2; exit 2 ;; esac`). NON-NEGOTIABLE (destroys contributor's real `~/.claude/hooks/` otherwise).
  2. Assert clean start: `test ! -e "$HOME/.claude/hooks"`.
  3. Run `/Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink install`; assert `readlink "$HOME/.claude/hooks"` returns an absolute path equal to `/Users/yanghungtw/Tools/spec-workflow/.claude/hooks`.
  4. Re-run `install`; assert output contains `already` for the hooks row AND the symlink target is byte-identical.
  5. Run `/Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink update`; assert `already` for the hooks row.
  6. Run `/Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink uninstall`; assert `test ! -e "$HOME/.claude/hooks"` AND other managed symlinks under `~/.claude/` were honored per the existing contract (don't over-assert — let t33 cover foreign cases).
  7. Print `PASS` and exit 0 on success; `FAIL: <reason>` and exit 1 on any assertion miss.
  8. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t29_claude_symlink_hooks_pair.sh` (exec bit set). No other files touched (smoke.sh registration is T8's job — D8 rule avoids append-only collisions between T3–T7 and T8).
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t29_claude_symlink_hooks_pair.sh` exits 0.
  - `test -x /Users/yanghungtw/Tools/spec-workflow/test/t29_claude_symlink_hooks_pair.sh` succeeds.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t29_claude_symlink_hooks_pair.sh` exits 0 (requires T2 merged).
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T4, T5, T6, T7
- [x]

## T4 — `test/t30_stop_hook_happy_path.sh`
- **Milestone**: M3
- **Requirements**: R17 (t30 row), R11, R12, R15 (soft target logging)
- **Decisions**: D1, D3 (ok-state), D5 (append discipline); sandbox-HOME template
- **Scope**: Create `test/t30_stop_hook_happy_path.sh` — integration test for the stop hook's happy path. Structure:
  1. mktemp sandbox + `export HOME="$SANDBOX/home"` + `trap 'rm -rf "$SANDBOX"' EXIT` + case-pattern preflight.
  2. Seed a sandbox git worktree: `cd "$SANDBOX"; git init -q; git checkout -q -b 20260418-fixture-feature; git config user.email t@example.com; git config user.name t; mkdir -p .spec-workflow/features/20260418-fixture-feature`.
  3. Write a minimal `STATUS.md` under `.spec-workflow/features/20260418-fixture-feature/STATUS.md` with a `## Notes` heading and one pre-existing note line. Commit it so `.git/HEAD` resolves cleanly.
  4. Pipe a valid JSON payload `{"event":"Stop"}` (or similar — D2 only requires `{`-prefix) into the absolute-path hook: `echo '{"event":"Stop"}' | /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh`.
  5. Assert exit code 0.
  6. Assert `grep -c 'stop-hook — stop event observed' .spec-workflow/features/20260418-fixture-feature/STATUS.md` increased by EXACTLY 1 from the pre-invocation count.
  7. Assert the new line matches `- YYYY-MM-DD stop-hook — stop event observed` (regex-checked, date = today's UTC or local date).
  8. Assert the sentinel file `.spec-workflow/features/20260418-fixture-feature/.stop-hook-last-epoch` exists and contains a numeric epoch.
  9. `/usr/bin/time` spot-check (if available): log wall-clock but do NOT gate on it — R15 is a soft target. Example: `{ /usr/bin/time -p /Users/yanghungtw/Tools/spec-workflow/.claude/hooks/stop.sh <<<'{}'; } 2>&1 | awk '/real/ {print}'` — print only, don't assert.
  10. Print `PASS` / exit 0 on success; `FAIL: <reason>` / exit 1 on any miss.
  11. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t30_stop_hook_happy_path.sh` (exec bit set).
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t30_stop_hook_happy_path.sh` exits 0.
  - `test -x /Users/yanghungtw/Tools/spec-workflow/test/t30_stop_hook_happy_path.sh` succeeds.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t30_stop_hook_happy_path.sh` exits 0 (requires T1 merged).
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T5, T6, T7
- [x]

## T5 — `test/t31_stop_hook_failsafe.sh`
- **Milestone**: M3
- **Requirements**: R17 (t31 row), R9, R10, R16 (all six silent-skip variants)
- **Decisions**: D1 (fail-safe), D2 (stdin sniff), D3 (classifier states); sandbox-HOME template
- **Scope**: Create `test/t31_stop_hook_failsafe.sh` — six fail-safe variants, each must exit 0 with ZERO STATUS.md mutation. Structure:
  1. mktemp sandbox + `export HOME="$SANDBOX/home"` + `trap 'rm -rf "$SANDBOX"' EXIT` + preflight.
  2. Define a helper `assert_no_mutation(before_hash, after_hash, label)` that shasums every STATUS.md under the sandbox before+after and fails if they differ.
  3. **Variant A — empty stdin**: invoke hook with `</dev/null`; assert exit 0; assert stderr contains `stdin not a valid Stop payload`; no STATUS.md mutation.
  4. **Variant B — malformed JSON**: `echo 'not json at all' | hook`; assert exit 0; same stderr; no mutation.
  5. **Variant C — non-git cwd**: `cd "$SANDBOX"` (no `.git/`); `echo '{}' | hook`; assert exit 0; stderr contains `not a git worktree`; no mutation (nothing to mutate, but still checked).
  6. **Variant D — branch matches no feature**: seed `.git/` with a branch name that doesn't contain any feature slug; seed `.spec-workflow/features/<some-slug>/STATUS.md`; invoke; assert exit 0; stderr contains `branch does not match any feature`; STATUS.md unchanged.
  7. **Variant E — missing STATUS.md**: matching branch + feature dir exists but `STATUS.md` absent; invoke; assert exit 0; stderr contains `STATUS.md not present` OR the classifier's `no-match` path (depends on implementation — accept either); no file created.
  8. **Variant F — missing `## Notes` heading**: `STATUS.md` present but no `## Notes`; invoke; assert exit 0; stderr contains `no ## Notes heading`; STATUS.md byte-identical.
  9. For every variant, assert the sentinel file `.stop-hook-last-epoch` was NOT written (fail-safe paths must not create state).
  10. Print `PASS` / exit 0 on all-variants-pass; `FAIL: <variant>: <reason>` / exit 1 on first miss.
  11. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t31_stop_hook_failsafe.sh` (exec bit set).
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t31_stop_hook_failsafe.sh` exits 0.
  - `test -x /Users/yanghungtw/Tools/spec-workflow/test/t31_stop_hook_failsafe.sh` succeeds.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t31_stop_hook_failsafe.sh` exits 0 (requires T1 merged).
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T6, T7
- [x]

## T6 — `test/t32_stop_hook_dedup.sh`
- **Milestone**: M3
- **Requirements**: R17 (t32 row), R13 (60s window)
- **Decisions**: D4 (sentinel-based dedup + BSD/GNU `date` dispatch); sandbox-HOME template
- **Scope**: Create `test/t32_stop_hook_dedup.sh` — idempotence test for the 60s window. Structure:
  1. mktemp sandbox + `export HOME="$SANDBOX/home"` + `trap 'rm -rf "$SANDBOX"' EXIT` + preflight.
  2. Seed sandbox git worktree + matching branch + feature dir + `STATUS.md` with `## Notes` (same fixture shape as t30).
  3. **First invocation**: `echo '{}' | hook`; assert one new stop-hook line under `## Notes`; assert `.stop-hook-last-epoch` sentinel exists.
  4. **Second invocation within 60s**: immediately run `echo '{}' | hook` again; assert LINE COUNT under `## Notes` unchanged (exactly one stop-hook line total); assert sentinel unchanged OR refreshed (accept either — D4 allows sentinel-refresh on every attempt).
  5. **Third invocation with sentinel aged >60s**: overwrite sentinel with an epoch 61 seconds in the past (`echo $(( $(date +%s) - 61 )) > "$feature/.stop-hook-last-epoch"`); run `echo '{}' | hook`; assert a SECOND stop-hook line is now present under `## Notes`.
  6. **Platform note**: both BSD (`uname -s` = `Darwin`) and GNU (`Linux`) paths exercise the same sentinel-based dedup — the `to_epoch()` wrapper is tested incidentally via D5's `date +%s` call. Explicit cross-platform date-parsing coverage is acknowledged as a single-platform gap per PRD §5 / plan §6 risks; document this in a comment at the top of the test.
  7. Print `PASS` / exit 0 on success; `FAIL: <step>: <reason>` / exit 1 on miss.
  8. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t32_stop_hook_dedup.sh` (exec bit set).
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t32_stop_hook_dedup.sh` exits 0.
  - `test -x /Users/yanghungtw/Tools/spec-workflow/test/t32_stop_hook_dedup.sh` succeeds.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t32_stop_hook_dedup.sh` exits 0 (requires T1 merged).
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T5, T7
- [x]

## T7 — `test/t33_claude_symlink_hooks_foreign.sh`
- **Milestone**: M3
- **Requirements**: R17 (t33 row), R4 (ownership gate)
- **Decisions**: D7 (validates existing classify_target path); sandbox-HOME template; `.claude/rules/common/no-force-on-user-paths.md`
- **Scope**: Create `test/t33_claude_symlink_hooks_foreign.sh` — foreign-content skip test. Structure:
  1. mktemp sandbox + `export HOME="$SANDBOX/home"` + `trap 'rm -rf "$SANDBOX"' EXIT` + preflight.
  2. Pre-create a real directory at `$HOME/.claude/hooks/` containing a sentinel file (`echo 'foreign' > "$HOME/.claude/hooks/foreign.txt"`).
  3. Run `/Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink install`; capture output.
  4. Assert stdout/stderr output contains `skipped:real-dir` (or equivalent per the existing classifier dispatch verb) for `$HOME/.claude/hooks`.
  5. Assert `test -d "$HOME/.claude/hooks" && test ! -L "$HOME/.claude/hooks"` — still a real dir.
  6. Assert `test -f "$HOME/.claude/hooks/foreign.txt"` AND `grep -q 'foreign' "$HOME/.claude/hooks/foreign.txt"` — contents untouched.
  7. Run `/Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink uninstall`; assert output contains `skipped:not-ours` (or equivalent) for the hooks path.
  8. Assert real dir still present AND foreign file still present after uninstall.
  9. Print `PASS` / exit 0 on success; `FAIL: <reason>` / exit 1 on miss.
  10. `chmod +x`.
- **Deliverables**: new file `/Users/yanghungtw/Tools/spec-workflow/test/t33_claude_symlink_hooks_foreign.sh` (exec bit set).
- **Verify**:
  - `bash -n /Users/yanghungtw/Tools/spec-workflow/test/t33_claude_symlink_hooks_foreign.sh` exits 0.
  - `test -x /Users/yanghungtw/Tools/spec-workflow/test/t33_claude_symlink_hooks_foreign.sh` succeeds.
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/t33_claude_symlink_hooks_foreign.sh` exits 0 (requires T2 merged).
- **Depends on**: —
- **Parallel-safe-with**: T1, T2, T3, T4, T5, T6
- [ ]

## T8 — Smoke integration + README docs + `.gitignore` verification
- **Milestone**: M4
- **Requirements**: R5, R6, R14, R18; AC-usage-mentions-hooks, AC-per-project-wiring-docs, AC-no-regression
- **Decisions**: D8 (enumerate 3 pairs in all documented locations); plan §5 "M4 bundle" (Option A — single task to avoid cross-file collisions with T3–T7)
- **Scope**: Three coordinated edits, bundled into a single serial task to eliminate append-collision risk against the T3–T7 test-file creations:
  1. **`test/smoke.sh` — register t29–t33**: extend the smoke driver to register the five new test scripts after the existing 28. Follow the existing registration pattern (whatever shape smoke.sh uses today — append new rows, don't renumber). Final expected tally: 33/33. The existing B1 tests (t1–t28) must remain intact; no renumbering.
  2. **Top-level `README.md` — 3-pair managed-set + per-project opt-in flow** (R5, R6): update the section that enumerates the managed symlink set (if present; if not, add a brief "Managed set" section) to list `agents/specflow`, `commands/specflow`, `hooks` — three dir-level pairs instead of two. Add the three-command per-project opt-in flow from PRD R6 verbatim:
     ```
     # one-time per machine, run from this repo:
     bin/claude-symlink install

     # one-time per consumer project, run from the consumer's repo root:
     bin/specflow-install-hook add SessionStart ~/.claude/hooks/session-start.sh

     # (optional) enable STATUS auto-sync in the consumer project:
     bin/specflow-install-hook add Stop ~/.claude/hooks/stop.sh
     ```
     Grep must find both `specflow-install-hook add SessionStart` and `specflow-install-hook add Stop` (AC-per-project-wiring-docs).
  3. **`.gitignore` verification**: confirm T1 added the sentinel pattern `.spec-workflow/features/*/.stop-hook-last-epoch`. If T1's entry is missing or malformed, FAIL this task back to T1 (do not silently re-add — that's a process violation; escalate via STATUS note). If correct, no edit.
- **Deliverables**: edits to `/Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` and `/Users/yanghungtw/Tools/spec-workflow/README.md`. Zero new files. No edit to `.gitignore` (T1's job — verify only).
- **Verify**:
  - `bash /Users/yanghungtw/Tools/spec-workflow/test/smoke.sh` exits 0; output includes PASS lines for t29–t33; final tally ≥ 33/33.
  - `grep -q 'specflow-install-hook add SessionStart' /Users/yanghungtw/Tools/spec-workflow/README.md` succeeds.
  - `grep -q 'specflow-install-hook add Stop' /Users/yanghungtw/Tools/spec-workflow/README.md` succeeds.
  - `grep -q 'hooks' /Users/yanghungtw/Tools/spec-workflow/README.md` (managed-set mention).
  - `grep -q '^\.spec-workflow/features/\*/\.stop-hook-last-epoch$' /Users/yanghungtw/Tools/spec-workflow/.gitignore` — T1's pre-emption verified.
  - `/Users/yanghungtw/Tools/spec-workflow/bin/claude-symlink --help | grep -q 'hooks'` — usage still enumerates hooks (not regressed since T2).
- **Depends on**: T1, T2, T3, T4, T5, T6, T7
- **Parallel-safe-with**: —
- [ ]

---

## Sequencing notes

- **T1 and T2 are independent** — different files (`.claude/hooks/stop.sh` vs `bin/claude-symlink`). Parallel-safe.
- **T3–T7 (five test files)** are independent of each other and of T1/T2 — each test creates its OWN new `test/tNN_*.sh` file with zero shared-file surface among the five. TDD-compatible: the tests can be written red-first alongside T1/T2. The tests run green only after T1 (for T4–T6) and T2 (for T3, T7) land, but the scripts themselves can be authored in the same wave.
- **T8 serializes after everything else** — it edits `test/smoke.sh` (single registration editor — avoids append-collisions with T3–T7 per plan §5 Option A) and `README.md`, and verifies T1's `.gitignore` entry. Running T8 before T3–T7 is nonsensical (nothing to register). Running T8 alongside T3–T7 risks mechanical collisions on `smoke.sh` — eliminated by serialization.
- **Known mechanical append collisions** (per `tpm/parallel-safe-append-sections.md`): STATUS.md notes at task completion collide across the 7-wide wave. These are expected and mechanically resolved by keeping both sides. DO NOT over-serialize on STATUS-note grounds. B1's Wave 2 (6 parallel) and Wave 5 (7 parallel) survived the same collision pattern with zero rework.
- **Worktree safety** — T1, T3, T4, T5, T6 all depend on `.claude/hooks/stop.sh` existing at test-run time. In per-task worktrees, the hook either exists (after T1 merges into the worktree base) or the test is expected to be red pre-merge. Per B1 experience, tests are written in the same wave as the implementation; TDD discipline makes red-first the norm.

## Task sizing

Target: each task ≤ 60 min focused work.
- **T1 (stop.sh script)** is the largest — classifier + dispatch + dedup + append + HOOK_TEST gate + .gitignore touch. Estimate 45–60 min. Fits in one task; splitting would force serialization across waves for minimal gain.
- **T2 (claude-symlink edit)** is mechanical — 4 edit sites, ~5 lines of net diff. Estimate 15–20 min.
- **T3–T7 (five test files)** — each ~15–25 min of sandbox scaffolding + 3–8 asserts. Uniform shape makes them muscle-memory after the first one lands.
- **T8 (smoke + README + gitignore verify)** — ~20 min. Small bundle.

---

## STATUS Notes

_(populated by Developer as tasks complete; expected mechanical append-collisions on this section are resolved keep-both per `tpm/parallel-safe-append-sections.md`)_

- 2026-04-17 T3 DONE — created `test/t29_claude_symlink_hooks_pair.sh`; sandbox preflight + 5-step lifecycle (install/idempotent/update/uninstall); RED pre-T2-merge (hooks pair absent from plan — correct failure), syntax OK, exec bit set.
- **T5 done** 2026-04-17 — Created `test/t31_stop_hook_failsafe.sh` (exec bit set). Six fail-safe variants (A–F: empty stdin, malformed JSON, non-git cwd, branch-no-match, missing STATUS.md, missing Notes heading). Syntax clean; exec bit set; runs RED (exit 1) pre-T1 for the right reason (hook absent). Will go GREEN once T1 merges.
- 2026-04-17 T6 complete — `test/t32_stop_hook_dedup.sh` created (exec bit set, syntax clean, RED pending T1 for the right reason: hook not found); exercises 3-step dedup scenario + platform-dispatch note; date path exercised on this run: BSD Darwin.

---

## Wave schedule

- **Wave 1** (7 parallel): T1, T2, T3, T4, T5, T6, T7
- **Wave 2** (1 serial): T8

**Parallel-safety analysis per wave:**

- **Wave 1 (7-wide)** — Files:
  - T1: `.claude/hooks/stop.sh` (new) + `.gitignore` (append one line)
  - T2: `bin/claude-symlink` (4-site edit to one file)
  - T3: `test/t29_claude_symlink_hooks_pair.sh` (new)
  - T4: `test/t30_stop_hook_happy_path.sh` (new)
  - T5: `test/t31_stop_hook_failsafe.sh` (new)
  - T6: `test/t32_stop_hook_dedup.sh` (new)
  - T7: `test/t33_claude_symlink_hooks_foreign.sh` (new)

  All seven tasks write to DISJOINT files — no shared file in the set. The only near-miss is T1's `.gitignore` append, which T8 only READS for verification (not writes). Expected append-only collisions on `06-tasks.md` STATUS Notes when each task checks its box: resolved mechanically keep-both per plan §5 / `tpm/parallel-safe-append-sections.md`.

  Test isolation: each T3–T7 test uses its own `mktemp -d` sandbox with HOME override; no /tmp collision, no shared ports, no shared fixtures. The five tests can run concurrently in parallel worktrees without any cross-contamination.

  Shared infrastructure: none. No config file mutated by two tasks. No schema change. No registration file (smoke.sh registration is deliberately deferred to T8).

  B1 precedent: Wave 2 (6-wide) and Wave 5 (7-wide) in `.spec-workflow/archive/20260416-prompt-rules-surgery/06-tasks.md` successfully ran at 7-wide width with ~11 mechanical STATUS/index append collisions; zero rework. 7-wide here mirrors that pattern.

- **Wave 2 (size 1)** — T8 edits `test/smoke.sh` (sole registration editor by design), `README.md`, and verifies `.gitignore`. Depends on all of T1–T7 having landed. Serial is the right choice — size-1 is intentional per plan §5 Option A to avoid append-collision on `smoke.sh` across multiple editors.

**Total tasks**: 8. **Total waves**: 2. Wave widths: `7, 1`. Widest wave: Wave 1 (7-wide), matching B1's widest wave without exceeding it. No new process risk vs. B1.
