# PRD — chore: t114 migrate-path coverage

## Summary

Extend `test/t114_seed_settings_json.sh` with an `A4: migrate path` case that exercises `bin/scaff-seed migrate`'s settings.json merge arm (`cmd_migrate` dispatcher at `bin/scaff-seed:1402`), parallel in shape to the existing A1 (fresh-install) and A2 (merge) cases that cover `cmd_init`. Closes analyst Finding 1 from archived feature `20260426-chore-seed-copies-settings`.

## Scope

- Single file touched: `test/t114_seed_settings_json.sh`.
- Surface: a new `A4` block inserted after the existing `A3: update-mode parity` section (current end of file at line 270, just before the failure-summary block).
- Mirror reference: `bin/scaff-seed:1402` (`cmd_migrate` settings.json dispatcher arm) — byte-identical to the `cmd_init` arm at `bin/scaff-seed:760` already exercised by A1/A2.
- A4 must:
  - Build a sandboxed consumer git repo (reuse `make_consumer` helper at line 56).
  - Pre-seed the consumer with a manifest matching a prior init (run `scaff-seed init` first so `cmd_migrate`'s wiring-rewrite path — not init-from-scratch — is the path under test).
  - Run `(cd "$CONSUMER" && "$REPO_ROOT/bin/scaff-seed" migrate --from "$REPO_ROOT")`.
  - Assert exit 0; `.claude/settings.json` exists; SessionStart hook command references `.claude/hooks/session-start.sh`.
  - For the merge sub-case: pre-seed a consumer settings.json with an unrelated key before invoking migrate; assert `.claude/settings.json.bak` is present afterward.

## Reason

The parent feature `20260426-chore-seed-copies-settings` added byte-identical settings.json merge arms to both `cmd_init` (`bin/scaff-seed:760`) and `cmd_migrate` (`bin/scaff-seed:1402`). The shipped t114 covers only `init` (A1, A2) and `update` (A3); the `cmd_migrate` arm is untested. analyst Finding 1 flagged this as `should`-class `partial-wiring-trace-every-entry-point` — the runtime is currently correct because the two arms are byte-identical, but the next refactor that diverges them will silently regress the migrate path.

This is the second consecutive partial-wiring-trace finding on `bin/scaff-seed`'s emit pair (the first was T108 shim coverage, remediated by archived chore `20260426-chore-t108-migrate-coverage`). The retrospective rule `qa-analyst/scaff-seed-dual-emit-site-hazard.md` records that a third occurrence on this binary should escalate to `must` severity. Closing the gap now (one mechanical test addition, ~50 lines parallel to A1/A2) is far cheaper than letting the regression risk compound.

## Checklist

- [ ] Add an `A4: migrate path` section to `test/t114_seed_settings_json.sh` covering `scaff-seed migrate` (parallel to A1/A2; placed after the A3 block, before the summary) — verify: `grep -F 'A4: migrate path' test/t114_seed_settings_json.sh` returns the section header.
- [ ] A4 pre-seeds the consumer with a manifest matching a prior init (so the migrate wiring-rewrite path is exercised, not an init-from-scratch path) — verify: within the A4 block, `scaff-seed init` (or equivalent manifest-seeding step) runs before the `scaff-seed migrate` invocation; `grep -c 'scaff-seed migrate' test/t114_seed_settings_json.sh` returns >= 1.
- [ ] A4 asserts the post-migrate `.claude/settings.json` contains a `hooks.SessionStart[*].hooks[*].command` referencing `.claude/hooks/session-start.sh` (mirror of A1's python3-extracted assertion) — verify: within the A4 block, the python3 traversal asserts `.claude/hooks/session-start.sh` against the migrate-target settings.json.
- [ ] A4 includes a merge sub-case asserting `.claude/settings.json.bak` exists post-migrate when the consumer's settings.json existed pre-migrate (mirror of A2c) — verify: A4 contains an `[ -f "$CONSUMER/.claude/settings.json.bak" ]` (or equivalent POSIX) assertion gated on the merge sub-case.
- [ ] `bash test/t114_seed_settings_json.sh` exits 0 with all A4 PASS lines emitted — verify: `bash test/t114_seed_settings_json.sh; echo $?` prints `0`; `bash test/t114_seed_settings_json.sh 2>&1 | grep -c '^PASS: A4'` is >= 3.

## Verify assertions

Rolled-up commands a reviewer can run end-to-end against a green build:

```bash
# Test passes, including the new migrate-path assertions.
bash test/t114_seed_settings_json.sh
# expect: exit 0; final line "PASS: t114"; one or more "PASS: A4" lines printed.

# A4 section is present and exercises the migrate path.
grep -F 'A4: migrate path' test/t114_seed_settings_json.sh
grep -c 'scaff-seed migrate' test/t114_seed_settings_json.sh   # expect >= 1

# Migrate-path settings.json end-state and .bak are both asserted.
grep -F '.claude/hooks/session-start.sh' test/t114_seed_settings_json.sh
grep -F 'settings.json.bak' test/t114_seed_settings_json.sh
```

## Out-of-scope

- Production code in `bin/scaff-seed` — settings.json merge arms in `cmd_init` and `cmd_migrate` are unchanged by this chore; the runtime is already correct.
- Other test files (`test/t108_*`, `test/t113_*`, etc.) — only `t114` is in scope.
- Collapsing the `cmd_init` / `cmd_migrate` mirror in `bin/scaff-seed` via a shared dispatch helper — the dual-emit-site memory addresses the hazard at the test level, not the production level; helper-extraction is deferred per `common/minimal-diff.md` entry 2 ("three similar lines beats a premature abstraction") and per the explicit deferral in the parent feature's plan §1.2.
- Coverage for other `bin/scaff-seed` subcommands beyond `migrate` (e.g. additional `update`-mode scenarios) — only the migrate dispatcher arm is in scope.

## Decisions

- **Migrate invocation flag-set**: `scaff-seed migrate --from "$REPO_ROOT"` (no `--ref`); `cmd_migrate` defaults the recorded ref to `git rev-parse HEAD` of the source repo (`bin/scaff-seed:1311-1315`). This matches the parent feature's choice of relying on the implicit-HEAD default for the migrate path; using `--ref "$SRC_REF"` is also acceptable and equivalent.
- **Pre-init-then-migrate ordering**: A4 runs `scaff-seed init` first to author a manifest, then `scaff-seed migrate` to exercise the wiring-rewrite arm. This mirrors how `cmd_migrate` is reached in production (consumer already has a manifest from a prior init). The decision parallels the sibling chore `20260426-chore-t108-migrate-coverage` (A5) which also exercises migrate against a consumer that has been through init.

## Team memory

- `qa-analyst/scaff-seed-dual-emit-site-hazard.md` — applied: this chore is the explicit remediation of the second occurrence; PRD §Reason cites the rule and the third-occurrence escalation policy.
- `qa-analyst/partial-wiring-trace-every-entry-point.md` — applied: parent rule the dual-emit hazard specialises; informs the §Checklist shape (assert one test path per emit site).
- `common/minimal-diff.md` — applied: §Out-of-scope defers helper-extraction per entry 2 (premature abstraction at duplication count 2).
- No PM-tier memory directory present at `~/.claude/team-memory/pm/` or `.claude/team-memory/pm/` for this repo (dirs not present); no `shared/` PM-applicable entries surfaced for chore intake of this shape.
