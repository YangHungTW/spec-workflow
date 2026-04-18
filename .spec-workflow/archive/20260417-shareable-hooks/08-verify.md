# Verify — 20260417-shareable-hooks (B2.a)

_2026-04-18 · QA-tester · sandboxed $HOME run_

07-gaps.md verdict: PASS (0 blockers). Proceeding.

---

## AC-symlink-hooks-installed — install creates ~/.claude/hooks symlink

Status: PASS
Evidence: `bash test/t29_claude_symlink_hooks_pair.sh` → install step: `~/.claude/hooks` is a symlink; `readlink "$HOME/.claude/hooks"` returns absolute path under `$REPO/.claude/hooks`. Maps to R1, R2.

---

## AC-symlink-hooks-idempotent — second install reports already

Status: PASS
Evidence: `bash test/t29_claude_symlink_hooks_pair.sh` → second `install` invocation outputs `already` for hooks pair; no mutation occurs. Maps to R3.

---

## AC-symlink-hooks-update — update after clean install reports already

Status: PASS
Evidence: `bash test/t29_claude_symlink_hooks_pair.sh` → `update` after `install` outputs `already` for hooks pair; link unchanged. Maps to R3.

---

## AC-uninstall-removes-hooks-link — uninstall removes managed link

Status: PASS
Evidence: `bash test/t29_claude_symlink_hooks_pair.sh` → after `install` then `uninstall`, `~/.claude/hooks` does not exist; parent `~/.claude/` directory intact with remaining managed links. Maps to R3, R4.

---

## AC-uninstall-leaves-foreign — pre-existing real dir at ~/.claude/hooks survives

Status: PASS
Evidence: `bash test/t33_claude_symlink_hooks_foreign.sh` → `install` against pre-existing real dir reports `skipped:real-dir`; `uninstall` reports `skipped:not-ours`; real dir untouched in both cases. Maps to R4.

---

## AC-usage-mentions-hooks — --help lists hooks as managed pair

Status: PASS
Evidence: `bin/claude-symlink --help | grep hooks` → `hooks` pair listed in usage output alongside existing agents/specflow and commands/specflow pairs. Maps to R1, R5.

---

## AC-stop-hook-exists — stop.sh exists, is executable, passes bash -n

Status: PASS
Evidence: `test -x .claude/hooks/stop.sh` → exit 0; `bash -n .claude/hooks/stop.sh` → exit 0, clean syntax. Maps to R9.

---

## AC-stop-hook-failsafe — error paths all exit 0 with no STATUS mutation

Status: PASS
Evidence: `bash test/t31_stop_hook_failsafe.sh` → 6/6 variant checks PASS:
- Empty stdin → exit 0, no mutation
- Malformed JSON stdin → exit 0, no mutation
- cwd outside a git worktree → exit 0, no mutation
- Branch matches no feature slug → exit 0, no mutation
- Missing STATUS.md → exit 0, no mutation
- STATUS.md missing `## Notes` heading → exit 0, no mutation
Maps to R9, R10, R16.

---

## AC-stop-hook-appends — happy-path appends one note line under ## Notes

Status: PASS
Evidence: `bash test/t30_stop_hook_happy_path.sh` → sandboxed git worktree on branch matching one feature slug; valid Stop payload on stdin; exactly one line matching `- YYYY-MM-DD stop-hook — stop event observed` appears under `## Notes` in that feature's STATUS.md. Maps to R11, R12.

---

## AC-stop-hook-skip-ambiguous — two-slug branch emits WARN, no mutation

Status: PASS
Evidence: Manual ad-hoc test with sandbox + 2-slug branch: 6/6 checks PASS — stderr contains WARN listing both candidates; both STATUS.md files untouched; no sentinel line written to either. Maps to R11.

---

## AC-stop-hook-idempotent — 60-second dedup window

Status: PASS
Evidence: `bash test/t32_stop_hook_idempotent.sh` → two invocations within 60 seconds produce exactly one new note line; third invocation >61 seconds later (via `faketime` or sleep offset) produces a second note line. Maps to R13.

---

## AC-per-project-wiring-docs — README contains documented opt-in flow

Status: PASS
Evidence:
- `grep "specflow-install-hook add SessionStart" README.md` → match found
- `grep "specflow-install-hook add Stop" README.md` → match found
Both greps exit 0. Maps to R5, R6, R14.

---

## AC-stop-hook-performance — happy path completes under 100 ms

Status: PASS
Evidence: `/usr/bin/time -p .claude/hooks/stop.sh < <(echo '{}')` in sandboxed feature worktree → real time < 0.1 s on warm cache (no unbounded `find`; I/O confined to reading HEAD, listing `.spec-workflow/features/`, read-modify-write on one STATUS.md). Maps to R15.

---

## AC-tests-added — five new test scripts present, executable, with sandbox pattern

Status: PASS
Evidence:
- `test -x test/t29_claude_symlink_hooks_pair.sh` → exit 0
- `test -x test/t30_stop_hook_happy_path.sh` → exit 0
- `test -x test/t31_stop_hook_failsafe.sh` → exit 0
- `test -x test/t32_stop_hook_idempotent.sh` → exit 0
- `test -x test/t33_claude_symlink_hooks_foreign.sh` → exit 0
All five open with `mktemp -d` sandbox, `export HOME="$SANDBOX/home"`, and `case "$HOME" in "$SANDBOX"*) ;; *) exit 2 ;; esac` preflight before first CLI invocation. Maps to R17.

---

## AC-no-regression — smoke.sh 33/33 PASS

Status: PASS
Evidence: `bash test/smoke.sh` → `smoke: PASS (33/33)`. All 28 original B1 tests plus 5 new B2.a tests green. No regression in existing `claude-symlink` or SessionStart-hook behavior. Maps to R18.

---

## Verdict: PASS

15/15 ACs PASS. Zero ACs FAIL. Zero ACs N/A.

Environment: Darwin, bash, 20260417-shareable-hooks branch.
