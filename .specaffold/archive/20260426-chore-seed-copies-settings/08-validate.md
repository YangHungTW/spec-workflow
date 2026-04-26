# Validate: 20260426-chore-seed-copies-settings
Date: 2026-04-26
Axes: tester, analyst

## Consolidated verdict
Aggregate: NITS
Findings: 0 must, 2 should

## Tester axis

### AC1 — `plan_copy` enumerates `.claude/settings.json` for `init` and `migrate` modes

Command run:
```
grep -n -F '.claude/settings.json' bin/scaff-seed
```

Output (trimmed):
```
485:      if [ -f "${src_root}/.claude/settings.json" ]; then
486:        printf '.claude/settings.json\n'
757:    # .claude/settings.json is always merged (read-merge-write) rather than
760:    if [ "$relpath" = ".claude/settings.json" ]; then
1399:    # .claude/settings.json is always merged (read-merge-write) rather than
1402:    if [ "$relpath" = ".claude/settings.json" ]; then
```

Lines 483-489 show the `plan_copy` enumerator guarded by `case "$mode" in init|migrate)` — the `update` arm is not present. Lines 760 and 1402 are the dispatcher arms in the init and migrate flow bodies respectively, each handling the merge case when `relpath = ".claude/settings.json"`.

Result: PASS.

### AC2 — `scaff-seed init` on fresh consumer creates `.claude/settings.json` with SessionStart hook

Executed:
```
bash test/t114_seed_settings_json.sh
```

Relevant output:
```
=== A1: fresh-install path ===
PASS: A1: scaff-seed init exited 0
PASS: A1: .claude/settings.json exists after init
PASS: A1: SessionStart command references .claude/hooks/session-start.sh
```

The test uses a `mktemp -d` sandbox, exports `HOME="$SANDBOX/home"`, and applies the POSIX `case`-based preflight guard per `sandbox-home-in-tests.md`. The python3 extractor traverses `hooks.SessionStart[*].hooks[*].command` and asserts the value contains `.claude/hooks/session-start.sh`.

Result: PASS.

### AC3 — Merge preserves pre-existing keys; `.bak` written on merge path

Consumer is pre-seeded with `{"permissions": {"allow": [...]}}` (no hooks block), then `scaff-seed init` runs.

Relevant output:
```
=== A2: merge path ===
PASS: A2: scaff-seed init exited 0
PASS: A2a: pre-existing permissions key preserved
PASS: A2b: SessionStart hook command added during merge
PASS: A2c: .claude/settings.json.bak exists
PASS: A2c: .bak content matches original pre-merge content
```

All three sub-assertions pass: unrelated key preserved, hook added, `.bak` byte-identical to original.

Result: PASS.

### AC4 — `t114_*.sh` covers both fresh-install and merge paths; exits 0

`bash test/t114_seed_settings_json.sh` → exit 0, 11 PASS, 0 FAIL. Covers fresh-install (A1), merge (A2), and update-mode parity (A3 — bonus per 05-plan.md §3).

Result: PASS.

### §Verify rolled-up assertions

1. `grep -F '.claude/settings.json' bin/scaff-seed` — returns 6 lines (enumerator + two dispatcher arms). PASS.
2. `ls test/t1*.sh | sort | tail -5` — t114 is in the listing; t113 was the previous max. PASS.
3. `bash test/t114_*.sh` — exits 0. PASS.

Adjacent regression `bash test/t113_scaff_src_resolver.sh` → PASS (no regression).

Note: t112 was pre-existing failure on parent commit `c0fd5f5` (verified by orchestrator); not a T1 finding.

## Validate verdict
axis: tester
verdict: PASS
findings: []

## Analyst axis

### Missing

None. All four PRD §Checklist items have corresponding implementation and test coverage.

### Extra

None. The diff touches only:
- `bin/scaff-seed` (plan_copy enumerator + init dispatcher arm + migrate dispatcher arm)
- `test/t114_seed_settings_json.sh` (new)
- Feature bookkeeping files (`05-plan.md`, `STATUS.md`)

No changes to `.claude/hooks/session-start.sh`, no general-purpose JSON-merge helper extracted, no `update`-mode changes to settings.json handling. Out-of-scope discipline is clean.

### Drifted

**Finding 1 — should — migrate-arm has no test path (partial-wiring-trace)**

The PRD §Scope explicitly names both `init` and `migrate` as affected modes. The diff correctly adds a settings.json merge arm to both `cmd_init` (hunk at line 754) and `cmd_migrate` (hunk at line 1396). These two inline Python blocks are byte-identical (confirmed). However, `t114` contains zero `scaff-seed migrate` invocations — A1 and A2 both use `init`, A3 uses `update`. The migrate-arm dispatcher code is entirely untested.

Per team-memory `partial-wiring-trace-every-entry-point.md`: each emit site (cmd_init and cmd_migrate) requires its own test path. The migrate arm is a mirror site with no coverage.

File: `test/t114_seed_settings_json.sh` — missing A4 migrate-path assertion.

**Finding 2 — should — double `.bak` write in malformed-JSON code path**

In the inline Python merge block (both `cmd_init` at line 791 and `cmd_migrate` at line 1433), when the consumer's `settings.json` is malformed JSON (`ValueError`), the code writes `.bak` at line 791, then the `os.path.exists(dst_p)` check at line 795–796 fires (the malformed file still exists on disk) and writes `.bak` again, clobbering the first backup with identical content. While the data is not lost in this scenario (both copies of the malformed file are identical), the pattern contradicts `no-force-on-user-paths.md` rule 4 ("If the backup step itself would overwrite a previous backup, either version the backup name or warn the user — never lose data silently") and creates a logical inconsistency: the backup-before-mutation guard runs twice in the same code path.

File: `bin/scaff-seed` lines 789–796 (and mirror at lines 1431–1438).

### Minimal-diff posture

The diff is 161 added lines in `bin/scaff-seed` and 270 in the new test. The 161 lines in `bin/scaff-seed` consist of: 9 lines for the `plan_copy` enumerator case block, and two near-identical 76-line dispatcher arm blocks (one for `cmd_init`, one for `cmd_migrate`). The duplication is expected given the PRD requirement covers both modes and the plan explicitly prohibits extracting a general-purpose helper (minimal-diff entry 2: "three similar lines beats a premature abstraction"). No drive-by edits, no premature abstractions, no defensive code for impossible cases were found. The 270-line test is proportionate to three distinct scenario paths (A1/A2/A3) with failure accumulation, sandbox setup, and consumer git-repo initialisation.

### STATUS hygiene

The STATUS checklist shows `[x] design` and `[x] tech` while the Notes log records both as "skipped (chore/tiny/matrix)". This matches the established convention in at least one prior archived chore-tiny feature (`20260426-chore-t108-migrate-coverage`) — checked-means-done-or-skipped, Notes are authoritative. No contradiction. The `[x] implement` is consistent with the Developer T1-done Notes line. The stage field reads `validate`, consistent with the last Notes entry. No contradictions found.

### Threshold-upgrade note (informational)

STATUS records `auto-upgrade SUGGESTED tiny→standard (diff: 433 lines, 4 files; threshold 200/3)`. The diff measures 161+270=431 added lines across 2 substantive files (plus 2 bookkeeping files), which exceeds the 200-line/3-file threshold. This is an informational advisory for the TPM to confirm or decline at archive time. It is not a validate gate condition.

## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    file: test/t114_seed_settings_json.sh
    line: 1
    rule: partial-wiring-trace-every-entry-point
    message: migrate-arm dispatcher (bin/scaff-seed:1396) is untested — t114 invokes only `scaff-seed init` (A1, A2) and `scaff-seed update` (A3); no A4 migrate-path assertion exists for the mirror emit site
  - severity: should
    file: bin/scaff-seed
    line: 789
    rule: no-force-on-user-paths
    message: malformed-JSON code path writes .bak at line 791 then the os.path.exists guard at line 795 writes .bak again (same content, but double-clobber pattern violates no-force-on-user-paths.md rule 4); mirror at line 1431/1438 in cmd_migrate arm

## Validate verdict
axis: aggregate
verdict: NITS
