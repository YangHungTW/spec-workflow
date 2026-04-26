# Validate: 20260426-chore-t114-migrate-coverage
Date: 2026-04-26
Axes: tester, analyst

## Consolidated verdict
Aggregate: NITS
Findings: 0 must, 2 should

## Tester axis

### AC1 — A4 section header present

```
$ grep -F 'A4: migrate path' test/t114_seed_settings_json.sh
printf '\n=== A4: migrate path ===\n'
```

Section header is present. PASS.

### AC2 — Pre-init runs before migrate; scaff-seed migrate invoked

```
$ grep -c 'scaff-seed migrate' test/t114_seed_settings_json.sh
7
```

Two real `scaff-seed migrate` invocations (lines 283, 346); five strings in pass/fail messages. Pre-init at lines 277 (consumer4) and 331 (consumer4b) precedes both migrate invocations. The A4 block exercises `cmd_migrate` (not `cmd_init`) — invocation is `scaff-seed migrate --from "$REPO_ROOT"`. PASS.

### AC3 — python3 traversal asserts .claude/hooks/session-start.sh

A4 block contains a python3 heredoc (lines 302-314) traversing `hooks.SessionStart[*].hooks[*].command` identical in shape to A1; the `grep -qF '.claude/hooks/session-start.sh'` check at line 317 confirms. Runtime emits `PASS: A4: SessionStart command references .claude/hooks/session-start.sh`. PASS.

### AC4 — .bak existence asserted in A4 merge sub-case

```
$ grep -F 'settings.json.bak' test/t114_seed_settings_json.sh
... BAK4B="$CONSUMER4B/.claude/settings.json.bak" ...
```

`[ -f "$BAK4B" ]` at line 356 gated on the merge sub-case (consumer4b had a pre-existing settings.json before migrate ran). Runtime emits `PASS: A4: merge sub-case: .claude/settings.json.bak exists`. PASS.

### AC5 — bash test/t114_seed_settings_json.sh exits 0; >= 3 PASS: A4 lines

```
$ bash test/t114_seed_settings_json.sh; echo "EXIT:$?"
=== A1: fresh-install path === ... 3 PASS
=== A2: merge path === ... 5 PASS
=== A3: update-mode parity === ... 2 PASS
=== A4: migrate path === ... 5 PASS
PASS: t114
EXIT:0

$ bash test/t114_seed_settings_json.sh 2>&1 | grep -c '^PASS: A4'
5
```

Exit code 0; 5 A4 PASS lines (>= 3 required). PASS.

### §Verify rolled-up commands

All five PRD-specified rolled-up commands executed and pass.

### Adjacent regression

`bash test/t113_scaff_src_resolver.sh` → exit 0, all PASS lines emitted. No regression. (t112 not run; pre-existing failure on parent commits per `developer/pre-existing-test-failure-before-changing.md`.)

### Constraint confirmation

`git diff 31ca49f...HEAD -- bin/scaff-seed` returns empty — chore makes no production-code changes. The A4 block actually exercises `cmd_migrate` (the previously-untested emit site at `bin/scaff-seed:1402`), not `cmd_init`. Parent feature's analyst Finding 1 (`partial-wiring-trace-every-entry-point` against `bin/scaff-seed`) is closed.

## Validate verdict
axis: tester
verdict: PASS
findings: []

## Analyst axis

### Diff scope

Three files changed: `05-plan.md` (task checkbox flip, 2 lines), `STATUS.md` (9 Notes lines added), and `test/t114_seed_settings_json.sh` (+102 lines). `bin/scaff-seed` is unmodified — confirmed by zero-line diff. No other test files touched.

### Missing

None. All 5 PRD §Checklist items are covered by the A4 block.

### Extra

None. No out-of-scope file edits; no new abstraction; no production-code changes.

### Drifted

**Finding 1 — should — partial mirror of A2c (`.bak` content fidelity not asserted)**

A4's merge sub-case asserts `.bak` *existence only*, while A2c additionally asserts `.bak` *content fidelity* (`BAK_CONTENT == ORIGINAL_CONTENT`). The PRD §Scope text says "mirror of A2c" but §Checklist item 4 (the binding acceptance text) says only "assert `.bak` is present". Given the binding checklist text does not require content fidelity, this is advisory — but the partial mirror reduces regression confidence on the backup path.

File: `test/t114_seed_settings_json.sh` line 355.

**Finding 2 — should — STATUS hygiene: [x] tech checked despite matrix-skipped tech stage**

Stage checklist marks `[x] tech (04-tech.md)` as done despite tech being matrix-skipped (no `04-tech.md` authored). Notes line 27 correctly records `stage_status chore/tiny/tech = skipped`. The checkbox-and-Notes pair are inconsistent on its face; the established chore-tiny convention (validated in archived `20260426-chore-t108-migrate-coverage` and `20260426-chore-seed-copies-settings`) is "checked-means-done-or-skipped, Notes are authoritative", but a fresh reader cannot tell from the checklist alone whether `04-tech.md` exists. Advisory.

File: `.specaffold/features/20260426-chore-t114-migrate-coverage/STATUS.md` line 16.

### A4 actually reaches `cmd_migrate`

`bin/scaff-seed:1402` is the `if [ "$relpath" = ".claude/settings.json" ]` guard inside the `cmd_migrate` manifest-replay loop. A4 invokes `scaff-seed migrate --from "$REPO_ROOT"` (not `init`); the pre-init step seeds the manifest so `cmd_migrate` enters its wiring-rewrite path. The gap from parent feature's analyst Finding 1 is closed.

### Out-of-scope discipline

`bin/scaff-seed`, `test/t108_*`, `test/t113_*` — all unchanged. No shared helper extracted across A1/A2/A4. Posture is clean.

### Minimal-diff posture

102 lines in A4. CONSUMER4 happy-path (~40 lines) + CONSUMER4B merge sub-case (~38 lines) + comments/printf (~24 lines). Every line justifiable from PRD §Checklist + §Scope. No drive-by edits, no premature abstractions, no defensive impossible-case code.

### STATUS hygiene (other lines)

Stage field `validate` correct. Chore-tiny short-circuit recorded (design / tech / plan). Developer T1-done line includes detail and gap-close reference. Skip-inline-review noted with reason. Wave-1-done and threshold-OK lines present. Stage advance implement → validate logged. `[x] implement` checked; `[ ] validate` and `[ ] archive` unchecked — correct.

### Threshold confirmation

STATUS records `3 files / 104 lines vs tiny limits 3/200; no upgrade SUGGESTED`. Confirmed: no SUGGESTED upgrade Notes line exists. Diff stayed within tiny limits.

## Validate verdict
axis: analyst
verdict: NITS
findings:
  - severity: should
    file: test/t114_seed_settings_json.sh
    line: 355
    rule: partial-mirror-of-A2c
    message: A4 merge sub-case asserts .bak existence but not content fidelity; A2c (line 206) additionally asserts BAK_CONTENT == ORIGINAL_CONTENT; PRD §Scope says "mirror of A2c" — content assertion is absent from A4 and reduces regression confidence on the backup path.
  - severity: should
    file: .specaffold/features/20260426-chore-t114-migrate-coverage/STATUS.md
    line: 16
    rule: status-hygiene
    message: Stage checklist marks "[x] tech (04-tech.md)" as done despite tech being matrix-skipped (no 04-tech.md authored); Notes line 27 correctly records "tech = skipped" — checklist box and Notes are inconsistent; template should leave the box unchecked for chore-tiny.

## Validate verdict
axis: aggregate
verdict: NITS
