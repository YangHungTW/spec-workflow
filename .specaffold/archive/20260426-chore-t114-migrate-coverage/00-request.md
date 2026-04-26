# Request

**Raw ask**: Extend `test/t114_seed_settings_json.sh` to cover the `scaff-seed migrate` path: pre-seed a manifest matching a prior init, run `scaff-seed migrate`, and assert `.claude/settings.json` is created/merged identically to the init path (with `.bak` when the consumer file pre-existed).

**Context**: Remediates analyst Finding 1 (`qa-analyst/scaff-seed-dual-emit-site-hazard`, partial-wiring-trace) from archived feature `20260426-chore-seed-copies-settings`. This is the second consecutive partial-wiring-trace finding on `bin/scaff-seed`'s `cmd_init` / `cmd_migrate` mirror pair (the first was T108 shim coverage); closing it now keeps the pattern from escalating to `must` severity on a third occurrence.

**Success looks like**: `bash test/t114_seed_settings_json.sh` exits 0 with a new `A4: migrate path` section that proves the `cmd_migrate` settings.json arm produces the same end-state shape as A1/A2 (file present, SessionStart hook command points at `.claude/hooks/session-start.sh`, `.bak` written when consumer settings.json pre-existed).

**Out of scope**: production code (`bin/scaff-seed`); other test files; helper-extraction to collapse the `cmd_init` / `cmd_migrate` mirror.

**UI involved?**: no (chore — `has-ui=false` by construction per D3).
