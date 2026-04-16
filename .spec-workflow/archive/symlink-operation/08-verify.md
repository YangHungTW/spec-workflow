# Verify — symlink-operation
_2026-04-16 · QA-tester · sandboxed `$HOME` run_

## Verdict: PASS

All 12 ACs pass. SF-2 fix confirmed. smoke.sh 12/12 PASS.

## Environment
- OS: Darwin 25.3.0 arm64 (macOS Sequoia, arm64)
- bash: GNU bash 3.2.57(1)-release (arm64-apple-darwin25)
- Repo: /Users/yanghungtw/Tools/spec-workflow
- Branch: symlink-operation
- Sandbox: mktemp -d per test (auto-cleaned; representative path `/var/folders/st/…/tmp.*`)

## AC results

| AC | Status | Evidence |
|----|--------|----------|
| AC1 | PASS | `smoke.sh ac1_clean_install` → exit 0; 12 symlinks created (2 dir + 10 file). Independent run: `find $H/.claude -type l` yields 12 entries, all pointing into repo. |
| AC2 | PASS | `smoke.sh ac2_idempotent_install` → second run exit 0; 12 `[already]` verbs, 0 `[created]`. |
| AC3 | PASS | `smoke.sh ac3_real_file_conflict` → exit 1; `[skipped:real-file]` for `agents/YHTW`; real file byte-identical after run; `commands/YHTW` symlink still created. |
| AC4 | PASS | `smoke.sh ac4_uninstall_scope` → exit 0; 0 tool-owned links remain; foreign file `team-memory/shared/user-notes.txt` survives; `~/.claude/` dir still present. |
| AC5 | PASS | `smoke.sh ac5_empty_dir_cleanup` → `agents/` and `commands/` removed (were empty); `team-memory/shared/` kept (contained user file `keepme.txt`). |
| AC6 | PASS | `smoke.sh ac6_update_adds_missing` → exit 0; `[created]` for new `glossary_ac6.md`; `[already]` for all pre-existing paths. Source file cleaned up post-test. |
| AC7 | PASS | `smoke.sh ac7_update_prunes_orphans` → exit 0; `[removed:orphan]` for `shared/index.md` (victim); orphan link removed from disk; foreign broken symlink `foreign-ac7.md` untouched and not mentioned in output. |
| AC8 | PASS | `smoke.sh ac8_update_conflict` → exit 1; `[skipped:real-file]` for `agents/YHTW`; real file untouched; `commands/YHTW` still created. |
| AC9 | PASS | `smoke.sh ac9_dry_run_no_mutation` → `install --dry-run` exit 0, `[would-create]` verbs present, filesystem hash unchanged. `uninstall --dry-run` and `update --dry-run` both leave filesystem hash unchanged. |
| AC10 | PASS | `smoke.sh ac10_absolute_link_targets` → 12/12 links have targets starting with `/Users/yanghungtw/Tools/spec-workflow/.claude/`. Independent `readlink` inspection of all 12 links confirms absolute paths. |
| AC11 | PASS | `smoke.sh ac11_report_exit_consistency` → clean run: actual exit 0, summary `(exit 0)`; conflict run: actual exit 1, summary `(exit 1)`; dry-run conflict: actual exit 0, summary `(exit 0)`. Last line always starts with `summary:`. |
| AC12 | PASS (macOS only) | `smoke.sh ac12_cross_platform` → `uname -s` returns `Darwin`. Script ran end-to-end on macOS/BSD userland without modification. Linux validation is human-driven and out of scope per PRD R16. |

## SF-2 spot check

- Command: `HOME=<sandbox> bin/claude-symlink install` followed by `HOME=<sandbox> bin/claude-symlink uninstall --dry-run`
- `[would-*]` line count: 12 (expected 12 — one per managed link)
- `[removed]` line count: 0 (expected 0)
- Exit code: 0 (expected 0)
- Result: PASS

The T13 fix (`if [ "$DRY_RUN" != "1" ]` guard around `report "removed"` in `cmd_uninstall` steps 1 and 2) eliminates double-reporting. Under `--dry-run`, `remove_link` emits `[would-remove]` and returns 0; the caller's `report "removed"` is skipped by the guard. Output shows exactly N `[would-remove]` lines with no `[removed]` lines.

## smoke.sh run

```
smoke: PASS (12/12)
```

Command: `bash test/smoke.sh` from `/Users/yanghungtw/Tools/spec-workflow`
Exit: 0
All 12 AC functions reported `PASS`.

## Nits observed

1. **AC12 is a noop marker** — already noted in 07-gaps.md. `uname -s` non-empty is the only assertion; real Linux validation requires a CI runner. Consistent with PRD R16 and acknowledged.
2. **Summary line `would-*` counts not reflected in counter fields** — Under `uninstall --dry-run`, the summary line reads `created=0 already=0 removed=0 skipped=0` rather than exposing `would-remove=12`. The `COUNT_would_remove` counter is incremented internally (in `report`) but `emit_summary` only prints the four non-dry-run counters. This is cosmetically odd but R13 does not require dry-run summary fields; R12 only requires `would-*` per-path verbs and exit 0. Not a spec violation; noting for future improvement.
